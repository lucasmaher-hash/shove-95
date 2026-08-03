//
//  TaskStore.swift
//  shove95
//
//  The @Observable façade (PRD §4). The ONLY object that touches the
//  ModelContext — views never do. All date logic delegates to Shove95Kit's
//  DateEngine; `now`/`calendar` are injected here and nowhere else.
//

import Foundation
import SwiftData
import Shove95Kit

// MARK: - Undo record (PRD §4)

/// Full field copy for delete-undo resurrection.
struct TaskSnapshot {
    let title: String
    let dueDate: Date?
    let isImportant: Bool
    let isCompleted: Bool
    let completedAt: Date?
    let createdAt: Date
    let sortOrder: Double
    let overduePlaced: Bool
    let photoData: Data?
}

enum LastAction {
    case moved(taskID: UUID, title: String, to: Bucket,
               previousDueDate: Date?, previousSortOrder: Double, previousOverduePlaced: Bool)
    case deleted(snapshot: TaskSnapshot)

    /// Status-bar text (voice rules: terse, no exclamation marks).
    var statusText: String {
        switch self {
        case let .moved(_, title, destination, _, _, _): "\(title) → \(destination.displayName)"
        case let .deleted(snapshot): "\(snapshot.title) deleted"
        }
    }
}

// MARK: - Store

@Observable @MainActor
final class TaskStore {
    @ObservationIgnored private let context: ModelContext
    @ObservationIgnored let calendar = Calendar.current
    /// Injectable clock — the one place real time enters the system.
    @ObservationIgnored var now: () -> Date = { .now }

    /// Bumped on every mutation. Query methods read it so views re-render;
    /// the CloudKit phase adds a remote-change observer that bumps it too.
    private(set) var revision = 0

    /// Single-level undo, persistent until replaced (PRD FR-009).
    private(set) var lastAction: LastAction?

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: Queries

    private func allTasksSorted() -> [TaskItem] {
        // createdAt is the deterministic tie-breaker: legacy data written before
        // the 2026-08-04 collision fix can hold equal sortOrders, and midpoint
        // math can in principle land on a completed task's order.
        let descriptor = FetchDescriptor<TaskItem>(
            sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.createdAt)])
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Every task currently mapping to the bucket — completed included.
    /// Bottom-anchor placements must clear completed tasks' kept sortOrders,
    /// or unticking loses its position (bug report 2026-08-04).
    private func allInBucket(_ bucket: Bucket) -> [TaskItem] {
        let now = now()
        return allTasksSorted().filter { $0.bucket(now: now, calendar: calendar) == bucket }
    }

    /// A tab's visible tasks: active (by sortOrder) and completed-not-archived
    /// (by completion time). Completed keep their sortOrder untouched, so
    /// unticking returns a task to its exact former spot (locked Q11).
    func tasks(in bucket: Bucket) -> (active: [TaskItem], completed: [TaskItem]) {
        _ = revision // observation hook
        let now = now()
        let visible = allTasksSorted().filter { $0.isVisible(in: bucket, now: now, calendar: calendar) }
        let active = visible.filter { !$0.isCompleted }
        let completed = visible.filter(\.isCompleted)
            .sorted { ($0.completedAt ?? .distantPast) < ($1.completedAt ?? .distantPast) }
        return (active, completed)
    }

    /// Archive: completed tasks past their visibility window, grouped by
    /// completion day, newest day first (PRD § UI/UX > Archive).
    func archivedTasksByDay() -> [(day: Date, tasks: [TaskItem])] {
        _ = revision
        let now = now()
        let archived = allTasksSorted().filter { $0.isArchived(now: now, calendar: calendar) }
        let grouped = Dictionary(grouping: archived) { task in
            calendar.startOfDay(for: task.completedAt ?? task.createdAt)
        }
        return grouped
            .map { (day: $0.key, tasks: $0.value.sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }) }
            .sorted { $0.day > $1.day }
    }

    // MARK: Mutations

    /// Creates in the given bucket with bottom placement. Whitespace-only
    /// titles are a no-op; pasted newlines collapse to spaces (PRD edge table).
    func addTask(title raw: String, in bucket: Bucket) {
        let title = raw
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }

        let task = TaskItem()
        task.title = title
        task.dueDate = DateEngine.targetDate(for: bucket, now: now(), calendar: calendar)
        task.sortOrder = Placement.sortOrderForNewTask(allInBucket: allInBucket(bucket))
        context.insert(task)
        commit()
    }

    /// Empty result reverts (delete is the menu's job — PRD FR-007).
    func editTitle(_ task: TaskItem, to raw: String) {
        let title = raw
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        task.title = title
        commit()
    }

    /// One step along the line. Returns nil at a dead end — caller rubber-bands.
    @discardableResult
    func step(_ task: TaskItem, direction: StepDirection) -> Bucket? {
        let current = task.bucket(now: now(), calendar: calendar)
        guard let destination = current.steppedOnce(direction) else { return nil }
        move(task, to: destination)
        return destination
    }

    /// Direct move (swipe commit or context menu). Records undo, applies
    /// arrival placement (important → under the destination's important block).
    func move(_ task: TaskItem, to bucket: Bucket) {
        let destinationActive = tasks(in: bucket).active.filter { $0 !== task }
        let destinationAll = allInBucket(bucket).filter { $0 !== task }
        lastAction = .moved(
            taskID: task.id, title: task.title, to: bucket,
            previousDueDate: task.dueDate, previousSortOrder: task.sortOrder,
            previousOverduePlaced: task.overduePlaced)
        task.dueDate = DateEngine.targetDate(for: bucket, now: now(), calendar: calendar)
        task.overduePlaced = false // dueDate changed → eligible for future rollover placement
        task.sortOrder = Placement.sortOrderForArrival(
            isImportant: task.isImportant, visible: destinationActive, allInBucket: destinationAll)
        commit()
    }

    /// Tick/untick. Never touches sortOrder — the completed section renders
    /// separately, so unticking restores the exact prior position.
    func toggleCompleted(_ task: TaskItem) {
        task.isCompleted.toggle()
        task.completedAt = task.isCompleted ? now() : nil
        commit()
    }

    /// Flagging jumps to the very top of the current tab; unflagging leaves
    /// the task exactly where it is (locked Q17).
    func toggleImportant(_ task: TaskItem) {
        if task.isImportant {
            task.isImportant = false
        } else {
            let bucket = task.bucket(now: now(), calendar: calendar)
            task.sortOrder = Placement.sortOrderForFlagImportant(visible: tasks(in: bucket).active)
            task.isImportant = true
        }
        commit()
    }

    /// Immediate delete — no confirmation dialogs, ever (locked Q11). The
    /// status bar's persistent Undo is the safety net.
    func delete(_ task: TaskItem) {
        lastAction = .deleted(snapshot: TaskSnapshot(
            title: task.title, dueDate: task.dueDate, isImportant: task.isImportant,
            isCompleted: task.isCompleted, completedAt: task.completedAt,
            createdAt: task.createdAt, sortOrder: task.sortOrder,
            overduePlaced: task.overduePlaced, photoData: task.photoData))
        context.delete(task)
        commit()
    }

    /// Drag-reorder to a slot between two neighbors' sortOrders.
    func reorder(_ task: TaskItem, betweenSortOrders above: Double?, and below: Double?) {
        task.sortOrder = Placement.sortOrder(between: above, and: below)
        let bucket = task.bucket(now: now(), calendar: calendar)
        let visible = tasks(in: bucket).active
        if Placement.needsRenormalization(visible: visible) {
            for (t, order) in Placement.renormalized(visible: visible) {
                t.sortOrder = order
            }
        }
        commit()
    }

    /// Restores the last move (exact position, date, and rollover flag) or
    /// resurrects the last delete. Single level; cleared after use.
    func undoLastAction() {
        switch lastAction {
        case let .moved(taskID, _, _, previousDueDate, previousSortOrder, previousOverduePlaced):
            if let task = allTasksSorted().first(where: { $0.id == taskID }) {
                task.dueDate = previousDueDate
                task.sortOrder = previousSortOrder
                task.overduePlaced = previousOverduePlaced
            }
        case let .deleted(snapshot):
            let task = TaskItem()
            task.title = snapshot.title
            task.dueDate = snapshot.dueDate
            task.isImportant = snapshot.isImportant
            task.isCompleted = snapshot.isCompleted
            task.completedAt = snapshot.completedAt
            task.createdAt = snapshot.createdAt
            task.sortOrder = snapshot.sortOrder
            task.overduePlaced = snapshot.overduePlaced
            task.photoData = snapshot.photoData
            context.insert(task)
        case nil:
            return
        }
        lastAction = nil
        commit()
    }

    /// Day-rollover placement pass (PRD §3). Runs on app-active and
    /// significant-time-change. Idempotent: the `overduePlaced` flag guards
    /// every task, so re-running is free and dragged tasks are never touched.
    func runDayRolloverPassIfNeeded() {
        let now = now()
        let visibleToday = tasks(in: .today).active
        for (task, order) in Placement.rolloverPlacements(visibleToday: visibleToday, now: now, calendar: calendar) {
            task.sortOrder = order
        }
        // Mark every newly-overdue task placed (importants included — they
        // already sit in the top tier by their own placement).
        for task in visibleToday where task.isOverdue(now: now, calendar: calendar) && !task.overduePlaced {
            task.overduePlaced = true
        }
        commit()
    }

    // MARK: - Debug seeding

    #if DEBUG
    /// Sample data covering every tier: important, overdue, today, tomorrow,
    /// week, general (TASK-015 verify).
    func seedDebugData() {
        let now = now()
        func make(_ title: String, bucket: Bucket, important: Bool = false, daysAgo: Int? = nil) {
            let task = TaskItem()
            task.title = title
            if let daysAgo {
                task.dueDate = calendar.date(byAdding: .day, value: -daysAgo,
                                             to: DateEngine.startOfToday(now: now, calendar: calendar))
            } else {
                task.dueDate = DateEngine.targetDate(for: bucket, now: now, calendar: calendar)
            }
            task.isImportant = important
            task.sortOrder = Placement.sortOrderForNewTask(allInBucket: allInBucket(bucket))
            if important {
                task.sortOrder = Placement.sortOrderForFlagImportant(visible: tasks(in: bucket).active)
            }
            context.insert(task)
            try? context.save()
        }
        make("Ship the shell", bucket: .today, important: true)
        make("Repair bike", bucket: .today)
        make("From yesterday", bucket: .today, daysAgo: 1)
        make("From last week", bucket: .today, daysAgo: 8)
        make("Call dentist", bucket: .tomorrow)
        make("File taxes", bucket: .week)
        make("Build portfolio", bucket: .general)
        revision += 1
    }
    #endif

    // MARK: - Private

    private func commit() {
        try? context.save()
        revision += 1
    }
}
