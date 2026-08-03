//
//  TaskRowView.swift
//  shove95
//
//  The row carries the app's core interactions:
//   · horizontal pan  → one step along the line; rubber-band at dead ends (FR-002)
//   · long-press hold → context menu: contextual moves, Important, Delete (FR-003)
//   · tap checkbox    → complete · tap text → inline edit (FR-007)
//  Styling is still Phase-1 plain; the Win95 skin lands in Phase 3.
//

import SwiftUI
import Shove95Kit

struct TaskRowView: View {
    let task: TaskItem
    @Environment(TaskStore.self) private var store

    @State private var isEditing = false
    @State private var draft = ""
    @FocusState private var editFocused: Bool

    // Swipe state (FR-002)
    @State private var dragOffset: CGFloat = 0
    @State private var rubberBandBuzzed = false
    @State private var rowWidth: CGFloat = 390

    /// Per-gesture axis decision; reset on end.
    private enum PanAxis { case undecided, horizontal, vertical }
    @State private var panAxis: PanAxis = .undecided

    private static let commitFraction: CGFloat = 0.4   // >40% of row width
    private static let commitVelocity: CGFloat = 800   // or >800 pt/s
    private static let rubberResistance: CGFloat = 0.3 // dead-end drag factor

    // ─────────────────────────────────────────────────────────────────────
    // TASK-019 SPIKE RESULT + TASK-025 DEFERRAL (2026-08-04)
    //
    // Container: ScrollView + LazyVStack, NOT List. List's cell machinery
    // consumes horizontal pans before row-level SwiftUI gestures see them, so
    // the swipe never fires inside it (proven: the identical gesture fires on
    // the same view outside List). Full record in TaskListView.
    //
    // Reorder (TASK-025) is DEFERRED TO PHASE 3. Four approaches were built
    // and isolation-tested here; none can coexist with the system context menu:
    //   · SwiftUI LongPressGesture on the row  → suppresses .contextMenu
    //     entirely (menu reappears the instant the gesture is removed)
    //   · .draggable / .dropDestination        → same suppression
    //   · UIGestureRecognizerRepresentable     → recognizer is never even
    //     instantiated (makeUIGestureRecognizer never called), in List or
    //     ScrollView
    //   · sequenced LongPress→Drag             → fires no phases at all here
    //
    // The clean fix is to stop using the system menu — which Phase 3 requires
    // regardless, since it has rounded corners, blur, and translucency, all
    // three prohibited by design.md §9. Once the menu is a hand-drawn Win95
    // popup driven by our own long-press, one gesture owns both branches and
    // the locked rule (hold-still → menu, hold-and-move → reorder) falls out.
    // `TaskStore.reorder(_:byRowSteps:)` is already implemented and waiting.
    // ─────────────────────────────────────────────────────────────────────

    var body: some View {
        rowContent
            .onAppear { dragOffset = 0 } // stale-state guard: row identity survives tab switches
            .offset(x: dragOffset)
            .background {
                GeometryReader { proxy in
                    Color.clear.onAppear { rowWidth = proxy.size.width }
                }
            }
            .simultaneousGesture(swipeGesture)
            .contextMenu { menuItems }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityDescription)
            .accessibilityActions { accessibilityMoveActions }
    }

    // MARK: - Content

    private var rowContent: some View {
        HStack(spacing: 12) {
            Button {
                store.toggleCompleted(task)
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.square.fill" : "square")
                    .foregroundStyle(task.isCompleted ? Color.gray : Color.primary)
            }
            .buttonStyle(.plain)
            .frame(minWidth: 32, minHeight: Win95.rowMinHeight)

            if isEditing {
                TextField("", text: $draft)
                    .focused($editFocused)
                    .onSubmit { commitEdit() }
                    .onChange(of: editFocused) { _, focused in
                        if !focused { commitEdit() }
                    }
            } else {
                Text(task.title)
                    .strikethrough(task.isCompleted)
                    .foregroundStyle(task.isCompleted ? Color.gray : (task.isImportant ? Win95.important : Color.primary))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard !task.isCompleted else { return }
                        draft = task.title
                        isEditing = true
                        editFocused = true
                    }
            }

            Spacer(minLength: 8)

            // Trailing chip column — fixed width so chips align (locked Q23).
            if let chip = ChipFormat.label(dueDate: task.dueDate, isCompleted: task.isCompleted,
                                           now: store.now(), calendar: store.calendar) {
                Text(chip)
                    .foregroundStyle(Color.gray)
                    .monospacedDigit()
                    .frame(width: 44, alignment: .trailing)
            }
        }
        .frame(minHeight: Win95.rowMinHeight)
    }

    // MARK: - Swipe (FR-002: left = defer, right = pull forward)

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .local)
            .onChanged { value in
                guard !task.isCompleted else { return } // completed rows don't move
                let t = value.translation
                switch panAxis {
                case .undecided:
                    // Decide the axis once per gesture (the spike's core rule).
                    if abs(t.width) > abs(t.height) * 1.2 {
                        panAxis = .horizontal
                    } else {
                        panAxis = .vertical // scroll owns this touch; stay out
                    }
                case .vertical:
                    break
                case .horizontal:
                    let direction: StepDirection = t.width < 0 ? .deferOne : .pullOne
                    if currentBucket.steppedOnce(direction) == nil {
                        // Dead end: resistance + one light haptic (FR-002/021).
                        dragOffset = t.width * Self.rubberResistance
                        if abs(t.width) > 20, !rubberBandBuzzed {
                            rubberBandBuzzed = true
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                    } else {
                        dragOffset = t.width
                    }
                }
            }
            .onEnded { value in
                let axis = panAxis
                panAxis = .undecided
                rubberBandBuzzed = false
                guard axis == .horizontal, !task.isCompleted else { return }

                let translation = value.translation.width
                let velocity = value.velocity.width
                let direction: StepDirection = translation < 0 ? .deferOne : .pullOne

                let overThreshold = abs(translation) > rowWidth * Self.commitFraction
                    || abs(velocity) > Self.commitVelocity
                let sameSign = (translation < 0) == (velocity < 0) || abs(velocity) < 50

                guard currentBucket.steppedOnce(direction) != nil,
                      overThreshold, sameSign else {
                    withAnimation(.spring(duration: 0.3)) { dragOffset = 0 }
                    return
                }

                // Commit: slide off the screen edge, then the model updates and
                // the list closes the gap (FR-002; motion = position only).
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.easeOut(duration: 0.15)) {
                    dragOffset = translation < 0 ? -rowWidth * 1.2 : rowWidth * 1.2
                }
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(150))
                    withAnimation(.spring(duration: 0.25)) {
                        store.step(task, direction: direction)
                    }
                    dragOffset = 0 // row identity survives the move; clear the committed offset
                }
            }
    }

    private var currentBucket: Bucket {
        task.bucket(now: store.now(), calendar: store.calendar)
    }

    // MARK: - Context menu (FR-003, locked table)

    @ViewBuilder
    private var menuItems: some View {
        if task.isCompleted {
            // Completed rows: untick to act on them; menu offers only Delete.
            Button(role: .destructive) {
                store.delete(task)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        } else {
            ForEach(currentBucket.menuDestinations, id: \.label) { destination in
                Button {
                    withAnimation(.spring(duration: 0.25)) {
                        store.move(task, to: destination.bucket)
                    }
                } label: {
                    Text(destination.label)
                }
            }
            Button {
                withAnimation(.spring(duration: 0.25)) {
                    store.toggleImportant(task)
                }
            } label: {
                Text(task.isImportant ? "Unmark Important" : "Mark as Important")
            }
            Button(role: .destructive) {
                store.delete(task)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - VoiceOver (FR-016)
    // The swipe is custom, so every move must also exist as a named action or
    // the app's core interaction is unreachable without sight.

    private var accessibilityDescription: String {
        var parts = [task.title]
        if task.isImportant { parts.append("important") }
        if let chip = ChipFormat.label(dueDate: task.dueDate, isCompleted: task.isCompleted,
                                       now: store.now(), calendar: store.calendar) {
            parts.append("overdue since \(chip)")
        }
        if task.isCompleted { parts.append("completed") }
        return parts.joined(separator: ", ")
    }

    @ViewBuilder
    private var accessibilityMoveActions: some View {
        Button(task.isCompleted ? "Uncomplete" : "Complete") { store.toggleCompleted(task) }
        if !task.isCompleted {
            if currentBucket.steppedOnce(.deferOne) != nil {
                Button("Defer one step") { store.step(task, direction: .deferOne) }
            }
            if currentBucket.steppedOnce(.pullOne) != nil {
                Button("Pull forward one step") { store.step(task, direction: .pullOne) }
            }
            ForEach(currentBucket.menuDestinations, id: \.label) { destination in
                Button("Move to \(destination.bucket.displayName)") {
                    store.move(task, to: destination.bucket)
                }
            }
            Button(task.isImportant ? "Unmark Important" : "Mark as Important") {
                store.toggleImportant(task)
            }
        }
        Button("Delete") { store.delete(task) }
    }

    // MARK: - Inline edit

    private func commitEdit() {
        guard isEditing else { return }
        isEditing = false
        store.editTitle(task, to: draft) // empty draft → store reverts (no-op)
    }
}
