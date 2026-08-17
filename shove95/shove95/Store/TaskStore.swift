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
import UIKit
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
    /// Raw bytes, oldest first — the records themselves are gone by the time
    /// undo runs (cascade delete), so the snapshot has to carry the payload.
    let photos: [Data]
}

enum LastAction {
    case moved(taskID: UUID, title: String, to: Bucket,
               previousDueDate: Date?, previousSortOrder: Double, previousOverduePlaced: Bool)
    case deleted(snapshot: TaskSnapshot)

    /// Status-panel text (voice rules: terse, no exclamation marks).
    /// `name` resolves the destination label so renamed tabs read correctly.
    func statusText(name: (Bucket) -> String) -> String {
        switch self {
        case let .moved(_, title, destination, _, _, _): "\(title) → \(name(destination))"
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

    /// Single-level undo (PRD FR-009). The panel that surfaces it retires
    /// itself on a timer — it reports a change, it is not standing chrome.
    private(set) var lastAction: LastAction?

    /// Retires the status panel without undoing anything.
    func dismissLastAction() {
        lastAction = nil
    }

    /// The active workspace. nil = the default workspace (and every task
    /// created before workspaces existed). RootView keeps this in sync with
    /// AppSettings; every query below is scoped to it, so switching workspace
    /// swaps the entire visible world in one assignment.
    /// Guarded against no-op writes. `workspaces()` reads `revision`, and
    /// RootView re-syncs the scope whenever `revision` changes — so a setter
    /// that bumped unconditionally span the update loop until the UI rendered
    /// nothing at all (2026-08-04).
    var workspaceID: String? {
        didSet { if workspaceID != oldValue { revision += 1 } }
    }

    /// Workspace ids this device knows about, so unknown ones can be shown in
    /// the default workspace rather than vanishing. Kept in sync by RootView.
    var knownWorkspaceIDs: Set<String> = [] {
        didSet { if knownWorkspaceIDs != oldValue { revision += 1 } }
    }

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: Synced preferences (see AppPreferences.swift)

    /// The account-wide preference record, created on first use. Deduped by
    /// fixed id, oldest wins — two devices can each make one before they meet.
    func preferences() -> AppPreferences {
        _ = revision
        let all = ((try? context.fetch(FetchDescriptor<AppPreferences>())) ?? [])
            .filter { $0.id == AppPreferences.singletonID }
            .sorted { $0.createdAt < $1.createdAt }
        if let existing = all.first { return existing }
        let fresh = AppPreferences()
        context.insert(fresh)
        commit()
        return fresh
    }

    func setFontID(_ id: String) {
        let preferences = preferences()
        guard preferences.fontID != id else { return }
        preferences.fontID = id
        commit()
    }

    func setSchemeID(_ id: String) {
        let preferences = preferences()
        guard preferences.schemeID != id else { return }
        preferences.schemeID = id
        commit()
    }

    // MARK: Workspaces (synced records — see Workspace.swift)

    /// Deduped by id: the store cannot enforce uniqueness under CloudKit, and
    /// two devices seeding the same fixed ids independently would otherwise
    /// show "Personal" twice. Oldest record wins so the pick is stable.
    func workspaces() -> [Workspace] {
        _ = revision
        let all = (try? context.fetch(FetchDescriptor<Workspace>())) ?? []
        var byID: [String: Workspace] = [:]
        for workspace in all {
            if let existing = byID[workspace.id], existing.createdAt <= workspace.createdAt {
                continue
            }
            byID[workspace.id] = workspace
        }
        // Default first, then oldest to newest.
        let unique = byID.values.sorted {
            if $0.isDefault != $1.isDefault { return $0.isDefault }
            return $0.createdAt < $1.createdAt
        }

        // ...and then deduped by NAME as well (founder bug report 2026-08-16:
        // "Work" appeared twice on the phone).
        //
        // Deduping by id alone cannot catch this. Two records with the SAME
        // name and DIFFERENT ids are exactly what the legacy migration
        // produces: a device that had workspaces in preferences creates "Work"
        // with a generated id, while a device seeding fresh creates it with
        // the fixed `Workspace.workID`. CloudKit then delivers both, and the
        // id-dedup above sees two legitimately distinct records.
        //
        // Oldest wins, matching the id rule, so every device converges on the
        // same survivor. The loser's tasks fall back to the default workspace
        // for display via the existing unknown-id path in `allTasksSorted` —
        // they are not lost, and nothing is written, so a real merge (or an
        // undo) is still possible later.
        var seenNames = Set<String>()
        return unique.filter { workspace in
            let key = workspace.name.trimmingCharacters(in: .whitespaces).lowercased()
            guard !key.isEmpty else { return true }
            return seenNames.insert(key).inserted
        }
    }

    func workspace(withID id: String) -> Workspace? {
        workspaces().first { $0.id == id }
    }

    /// First run: Personal + Work, with FIXED ids so a second device converges
    /// on the same two rather than adding its own pair. `legacy` carries any
    /// workspaces this device had in preferences before they were records, so
    /// existing task assignments survive the change.
    func seedWorkspacesIfNeeded(legacy: [(id: String, name: String)]) {
        guard workspaces().isEmpty else { return }
        var seeded: [(String, String)] = [(Workspace.defaultID, "Personal")]
        if legacy.isEmpty {
            seeded.append((Workspace.workID, "Work"))
        } else {
            // Preserve the ids tasks are already stamped with.
            for entry in legacy where entry.id != Workspace.defaultID {
                seeded.append((entry.id, entry.name))
            }
            if let defaultName = legacy.first(where: { $0.id == Workspace.defaultID })?.name {
                seeded[0].1 = defaultName
            }
        }
        for (id, name) in seeded {
            context.insert(Workspace(id: id, name: name))
        }
        commit()
    }

    /// The key `workspaces()` dedupes on. Anything that WRITES a name has to
    /// ask this first, or it writes a record the list will then hide —
    /// which is how Add came to look like a dead button and Rename came to
    /// look like a delete (founder decision 2026-08-16: forbid duplicates
    /// outright rather than hide them).
    private func nameKey(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// True when some OTHER workspace already answers to this name.
    ///
    /// Checked against every record, not just the deduped list: a legacy
    /// twin that dedup is currently hiding still owns its name, and letting
    /// a third record land on it would only deepen the pile.
    func workspaceNameIsTaken(_ raw: String, excluding workspace: Workspace? = nil) -> Bool {
        let key = nameKey(raw)
        guard !key.isEmpty else { return false }
        let all = (try? context.fetch(FetchDescriptor<Workspace>())) ?? []
        return all.contains { nameKey($0.name) == key && $0.id != workspace?.id }
    }

    /// Returns nil when the name is empty or already taken — the caller is
    /// expected to leave the typed text in place rather than clear a field
    /// whose contents were never accepted.
    @discardableResult
    func addWorkspace(named raw: String) -> Workspace? {
        // Bounded like tab names: a workspace name rides in the home
        // screen's pill, and an unbounded one carried the settings gear off
        // the edge (founder bug report 2026-08-17).
        let name = String(raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(AppSettings.maxNameLength))
        guard !name.isEmpty, !workspaceNameIsTaken(name) else { return nil }
        let workspace = Workspace(id: UUID().uuidString, name: name)
        context.insert(workspace)
        commit()
        return workspace
    }

    /// False when the rename was refused, so the caller can put the field
    /// back to the name that is still in force.
    @discardableResult
    func renameWorkspace(_ workspace: Workspace, to raw: String) -> Bool {
        // Bounded like tab names: a workspace name rides in the home
        // screen's pill, and an unbounded one carried the settings gear off
        // the edge (founder bug report 2026-08-17).
        let name = String(raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(AppSettings.maxNameLength))
        guard !name.isEmpty, name != workspace.name else { return false }
        guard !workspaceNameIsTaken(name, excluding: workspace) else { return false }
        workspace.name = name
        commit()
        return true
    }

    /// The default is undeletable; a deleted workspace's tasks fold back into
    /// it rather than being destroyed — deleting a label must never delete work.
    func deleteWorkspace(_ workspace: Workspace) {
        guard !workspace.isDefault, let stamp = workspace.taskStampID else { return }
        for task in (try? context.fetch(FetchDescriptor<TaskItem>())) ?? []
        where task.workspaceID == stamp {
            task.workspaceID = nil
        }
        context.delete(workspace)
        commit()
    }

    // MARK: Queries

    private func allTasksSorted() -> [TaskItem] {
        // createdAt is the deterministic tie-breaker: legacy data written before
        // the 2026-08-04 collision fix can hold equal sortOrders, and midpoint
        // math can in principle land on a completed task's order.
        let descriptor = FetchDescriptor<TaskItem>(
            sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.createdAt)])
        let all = (try? context.fetch(descriptor)) ?? []
        // Workspace scoping happens HERE, the one choke point every query uses,
        // so buckets, archive, placement and rollover are all scoped for free.
        //
        // A task whose workspace this device doesn't know about falls back to
        // the DEFAULT workspace for display only — its record is never
        // rewritten. That matters under sync: workspaces are still per-device
        // preferences, so a task arriving from another device carries an id
        // this one has never seen, and "fixing" the record would push the
        // damage back to the device it came from.
        return all.filter { task in
            if task.workspaceID == workspaceID { return true }
            guard workspaceID == nil, let id = task.workspaceID else { return false }
            return !knownWorkspaceIDs.contains(id)
        }
    }

    /// Every task currently mapping to the bucket — completed included.
    /// Bottom-anchor placements must clear completed tasks' kept sortOrders,
    /// or unticking loses its position (bug report 2026-08-04).
    private func allInBucket(_ bucket: Bucket) -> [TaskItem] {
        let now = now()
        return allTasksSorted().filter { $0.bucket(now: now, calendar: calendar) == bucket }
    }

    /// Look up a live task by id — used by the menu overlay, which holds an
    /// id rather than a model reference so it can't go stale.
    func task(withID id: UUID) -> TaskItem? {
        allTasksSorted().first { $0.id == id }
    }

    /// The same lookup, unscoped: across every workspace, pinned or not.
    ///
    /// The Lock Screen's tick button carries the id of the task ITS CARD was
    /// drawn for. Resolving that through `pinnedTask()` and comparing ids
    /// looked equivalent and is not: a card outlives the state it was drawn
    /// from, so pinning something else on another device — or two devices
    /// each pinning offline, where the fetch returns an arbitrary one of the
    /// two — made the guard fall through and the tap vanish with no signal.
    /// The card names its own task; honour that.
    func anyTask(withID id: UUID) -> TaskItem? {
        _ = revision // observation hook
        var descriptor = FetchDescriptor<TaskItem>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
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

    // MARK: Photos (Phase 4, pulled forward 2026-08-04)

    /// Appends — photos accumulate left to right in the order added.
    func addPhoto(_ task: TaskItem, data: Data?) {
        guard let data else { return }
        insertPhoto(data, into: task, order: task.nextPhotoOrder)
        commit()
    }

    /// Removes one photo by its position in the strip. Orders are sparse on
    /// purpose — nothing is renumbered, so a removal can't disturb the rest.
    func removePhoto(_ task: TaskItem, at index: Int) {
        let ordered = task.orderedPhotos
        guard ordered.indices.contains(index) else { return }
        context.delete(ordered[index])
        commit()
    }

    private func insertPhoto(_ data: Data, into task: TaskItem, order: Int) {
        let photo = TaskPhoto()
        photo.data = data
        photo.order = order
        photo.task = task
        context.insert(photo)
    }

    /// One-time move of photos out of the pre-CloudKit fields and into their
    /// own records. Idempotent: a task is only touched while it still holds
    /// legacy data, and the slots are cleared as it goes.
    func migrateLegacyPhotos() {
        let descriptor = FetchDescriptor<TaskItem>()
        var moved = false
        for task in (try? context.fetch(descriptor)) ?? [] where task.needsPhotoMigration {
            var order = task.nextPhotoOrder
            for data in task.legacyPhotos {
                insertPhoto(data, into: task, order: order)
                order += 1
            }
            task.clearLegacyPhotos()
            moved = true
        }
        if moved { commit() }
    }

    // MARK: Mutations

    /// Creates in the given bucket with bottom placement. Whitespace-only
    /// titles are a no-op; pasted newlines collapse to spaces (PRD edge table).
    @discardableResult
    func addTask(title raw: String, in bucket: Bucket) -> TaskItem? {
        let title = raw
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return nil }

        let task = TaskItem()
        task.title = title
        task.workspaceID = workspaceID // born into the active workspace
        task.dueDate = DateEngine.targetDate(for: bucket, now: now(), calendar: calendar)
        task.sortOrder = Placement.sortOrderForNewTask(allInBucket: allInBucket(bucket))
        context.insert(task)
        commit()
        return task
    }

    /// Empty result reverts (delete is the menu's job — PRD FR-007).
    func editTitle(_ task: TaskItem, to raw: String) {
        let title = raw
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        let changed = title != task.title
        task.title = title
        // An overdue task whose text was actually rewritten is a NEW task in
        // spirit — it re-dates to today and the overdue chip disappears
        // (founder request 2026-08-04). Tapping in and out without changing
        // anything keeps the chip.
        if changed, let due = task.dueDate,
           due < calendar.startOfDay(for: now()) {
            task.dueDate = calendar.startOfDay(for: now())
            task.overduePlaced = false
        }
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
        // A finished task stops following you. Unticking does NOT re-pin it —
        // pinning is a deliberate act, and silently re-pinning something you
        // un-ticked by accident would put it back on the Lock Screen.
        if task.isCompleted { task.isPinned = false }
        commit()
    }

    // MARK: - The pinned task (mononote)

    /// The one task pinned to the Lock Screen, or nil.
    ///
    /// Searched WITHOUT the workspace filter that `allTasksSorted` applies:
    /// the pin is app-wide, so a task pinned in Work must still be found
    /// while Personal is open — otherwise switching workspace would look
    /// like the pin had been lost, and pinning again would leave two.
    func pinnedTask() -> TaskItem? {
        _ = revision // observation hook
        var descriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate { $0.isPinned })
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    /// Pins `task`, releasing whatever held the pin.
    ///
    /// Exactly one, app-wide. The unpin loop is defensive rather than
    /// decorative: two devices can each pin a different task offline, and
    /// sync then delivers a store with two. Whoever pins next cleans it up.
    func pin(_ task: TaskItem) {
        let descriptor = FetchDescriptor<TaskItem>(predicate: #Predicate { $0.isPinned })
        for held in (try? context.fetch(descriptor)) ?? [] where held.id != task.id {
            held.isPinned = false
        }
        task.isPinned = true
        commit()
    }

    func unpin(_ task: TaskItem) {
        guard task.isPinned else { return }
        task.isPinned = false
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
            overduePlaced: task.overduePlaced, photos: task.allPhotos))
        context.delete(task)
        commit()
    }

    /// Long-press-drag reorder (TASK-025): move `task` by whole row steps
    /// within its bucket's active list. Free placement — the user's order is
    /// theirs afterwards (locked Q17-B).
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
            for (index, data) in snapshot.photos.enumerated() {
                insertPhoto(data, into: task, order: index)
            }
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

    /// 15 filler rows in Today — enough height to exercise scrolling
    /// against the row pan (TASK-019 spike verification).
    /// `-seedDemo YES` fills the store with the App Store screenshot content.
    /// Deliberately mundane: a to-do list in a screenshot should look like
    /// somebody's actual Tuesday, not a product diagram where every row is the
    /// same length and nothing is late.
    func seedDemo() {
        let today = DateEngine.startOfToday(now: now(), calendar: calendar)
        let tomorrow = DateEngine.startOfTomorrow(now: now(), calendar: calendar)
        let week = DateEngine.targetDate(for: .week, now: now(), calendar: calendar)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!

        // (title, due, important, completed, photo)
        let rows: [(String, Date?, Bool, Bool, Data?)] = [
            ("call the dentist back",         twoDaysAgo, true,  false, nil),
            ("pick up the parcel",            yesterday,  false, false, DemoPhotos.parcelLabel()),
            ("sort out the bike light",       yesterday,  true,  false, DemoPhotos.receipt()),
            ("finish the ergonomics reading", today,      false, false, DemoPhotos.lectureNote()),
            ("book train to Hamburg",         today,      true,  false, nil),
            ("water the plants",              today,      false, true,  nil),
            ("send Marie the photos",         tomorrow,   false, false, nil),
            ("renew the Bahncard",            tomorrow,   false, false, nil),
            ("dentist follow-up",             week,       false, false, nil),
            ("read the Rams book",            nil,        false, false, nil),
            ("find a decent desk lamp",       nil,        false, false, nil),
        ]

        var order = 0.0
        for (title, due, important, completed, photo) in rows {
            let task = TaskItem()
            task.title = title
            task.dueDate = due
            task.isImportant = important
            task.workspaceID = workspaceID
            task.sortOrder = order
            order += 1
            if completed {
                task.isCompleted = true
                task.completedAt = now()
            }
            context.insert(task)
            if let photo { addPhoto(task, data: photo) }
        }
        commit()
    }

    func seedScrollFillers() {
        for i in 1...15 {
            let task = TaskItem()
            task.title = "Filler \(i)"
            task.dueDate = DateEngine.startOfToday(now: now(), calendar: calendar)
            task.sortOrder = Placement.sortOrderForNewTask(allInBucket: allInBucket(.today))
            context.insert(task)
            try? context.save()
        }
        revision += 1
    }
    #endif

    // MARK: - Private

    private func commit() {
        try? context.save()
        revision += 1
    }
}
