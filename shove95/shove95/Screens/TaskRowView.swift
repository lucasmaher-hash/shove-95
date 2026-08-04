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
    /// Position in the active list — nil for completed rows, which don't reorder.
    let index: Int?
    @Environment(TaskStore.self) private var store
    @Environment(MenuCoordinator.self) private var menu
    @Environment(ReorderCoordinator.self) private var reorder
    @Environment(\.pixel) private var pixel

    // Reorder session (FR-004). Same long-press that opens the menu: holding
    // still shows it, moving cancels it and picks the row up instead.
    @State private var isReordering = false
    @State private var reorderOffset: CGFloat = 0
    @State private var rowFrame: CGRect = .zero
    @GestureState private var isPressing = false
    @State private var didLongPress = false


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
                    Color.clear
                        .onAppear { rowWidth = proxy.size.width }
                        .onChange(of: proxy.frame(in: .global)) { _, frame in
                            rowFrame = frame
                        }
                        .task { rowFrame = proxy.frame(in: .global) }
                }
            }
            .scaleEffect(isPressing && !isReordering ? 0.97 : 1, anchor: .center)
            .animation(.spring(duration: 0.22), value: isPressing)
            .animation(.easeOut(duration: 0.12), value: isMenuOpen)
            .offset(y: reorderOffset)
            .simultaneousGesture(panGesture)
            .simultaneousGesture(pressGesture)
            .onTapGesture {
                // A long press ends with a lift, which SwiftUI also reports as
                // a tap — so a plain tap handler would open the keyboard every
                // time the menu appeared. Consume that one.
                if didLongPress { didLongPress = false; return }
                guard !task.isCompleted, !isEditing else { return }
                draft = task.title
                isEditing = true
                editFocused = true
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityDescription)
            .accessibilityActions { accessibilityMoveActions }
    }

    // MARK: - Content

    private var rowContent: some View {
        HStack(spacing: Win95.Px.grid * pixel) {
            Win95Checkbox(isChecked: task.isCompleted) {
                // Position changes always animate (design.md §8): the row
                // travels to or from the completed section rather than jumping.
                withAnimation(.spring(duration: 0.35)) {
                    store.toggleCompleted(task)
                }
            }

            if isEditing {
                TextField("", text: $draft)
                    .font(W95Font.standard(pixel))
                    .foregroundStyle(Win95.text)
                    .focused($editFocused)
                    .onSubmit { commitEdit() }
                    .onChange(of: editFocused) { _, focused in
                        if !focused { commitEdit() }
                    }
            } else {
                Text(task.title)
                    .font(W95Font.standard(pixel))
                    .strikethrough(task.isCompleted)
                    // Colour carries exactly one meaning: red = Important.
                    // Completed is grey + strikethrough; overdue is the chip.
                    .foregroundStyle(isReordering ? Win95.selectionText
                                     : (task.isCompleted ? Win95.shadow
                                        : (task.isImportant ? Win95.important : Win95.text)))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .allowsHitTesting(false) // the ROW owns tap-to-edit (see body)
            }

            Spacer(minLength: Win95.Px.grid * pixel)

            // Trailing chip column — fixed width so chips align (locked Q23).
            Group {
                if let chip = ChipFormat.label(dueDate: task.dueDate, isCompleted: task.isCompleted,
                                               now: store.now(), calendar: store.calendar) {
                    DateChip(label: chip)
                }
            }
            .frame(width: Win95.Px.grid * 8 * pixel, alignment: .trailing)
        }
        .padding(.trailing, Win95.Px.grid * pixel)
        .frame(maxWidth: .infinity, minHeight: Win95.rowHeight(pixel))
        .background(rowBackground) // grey while pressed, navy while dragged
        .contentShape(Rectangle())   // the ENTIRE row is swipeable, not just the text
    }

    private var rowBackground: Color {
        if isReordering { return Win95.selectionBG }
        // The tint outlives the finger: while this row's menu is open the row
        // stays held, so it is obvious what the menu is acting on.
        if isPressing || isMenuOpen { return Win95.light }
        return Win95.well
    }

    private var isMenuOpen: Bool { menu.isShowing(task) }

    // MARK: - Pan: swipe, or reorder once armed
    //
    // SCROLLING (fixed 2026-08-04). This row may attach exactly ONE DragGesture.
    // The reorder used to be `LongPressGesture.sequenced(before: DragGesture(
    // minimumDistance: 0))`, and a press tint added a second
    // `DragGesture(minimumDistance: 0)`. Either one stops the enclosing
    // ScrollView dead — a zero-distance drag claims the touch the instant the
    // finger lands, so the scroll view never sees the pan. Bisected on device:
    // with only this gesture attached the list scrolls; adding the sequenced
    // one back stops it. So the long press is now a press MODIFIER (which
    // yields to the scroll view), and once it succeeds this same pan handles
    // the reorder.
    //
    // DIRECTION REVERSED 2026-08-04 on device feedback. The original spec said
    // left = defer, but that fights the taskbar: the tabs read
    // Today | Tomorrow | Week | General left-to-right, so dragging a row LEFT
    // should carry it toward the LEFT tab (Today = pull forward) and dragging
    // RIGHT should carry it toward the right tabs (defer). Content follows the
    // finger, which is what a spatial interface demands.
    //   swipe left  → pull forward (toward Today)
    //   swipe right → defer        (toward General)

    private var panGesture: some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .local)
            .onChanged { value in
                if reorder.isArmed(task.id) {
                    trackReorder(value.translation.height)
                    return
                }
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
                    let direction: StepDirection = t.width < 0 ? .pullOne : .deferOne
                    if currentBucket.steppedOnce(direction) == nil {
                        // Dead end: resistance + one light haptic (FR-002/021).
                        dragOffset = snapped(t.width * Self.rubberResistance)
                        if abs(t.width) > 20, !rubberBandBuzzed {
                            rubberBandBuzzed = true
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                    } else {
                        dragOffset = snapped(t.width)
                    }
                }
            }
            .onEnded { value in
                if isReordering { finishReorder(); return }
                let axis = panAxis
                panAxis = .undecided
                rubberBandBuzzed = false
                guard axis == .horizontal, !task.isCompleted else { return }

                let translation = value.translation.width
                let velocity = value.velocity.width
                let direction: StepDirection = translation < 0 ? .pullOne : .deferOne

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

    /// Movement travels in whole 1995-pixels — smooth but quantised, like a
    /// sprite (design.md §8). Appearance changes stay instant.
    private func snapped(_ value: CGFloat) -> CGFloat {
        (value / pixel).rounded() * pixel
    }

    /// The menu drops from the row's bottom-left, like a Win95 menu dropping
    /// from a menu-bar title.
    private var menuAnchor: CGPoint {
        CGPoint(x: rowFrame.minX + Win95.Px.grid * pixel, y: rowFrame.maxY)
    }

    private var currentBucket: Bucket {
        task.bucket(now: store.now(), calendar: store.calendar)
    }

    // MARK: - Long-press: menu vs reorder (locked Q10 rule)
    //
    // Hold still → the Win95 menu opens at the row's bottom-left.
    // Hold, then move → the menu is cancelled and the row is picked up instead.
    // Both branches are still owned by one press, which is only possible
    // because the system context menu is gone (it swallowed the long press
    // entirely). The difference now is that the press is a MODIFIER and the
    // drag is the row's one pan gesture — see the scroll note above.

    /// Touch-down tints the row; success at 0.4s arms it and opens the menu.
    /// `@GestureState` resets the tint by itself when the touch ends or is
    /// cancelled — no manual cleanup, and nothing left stuck on.
    private var pressGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.4, maximumDistance: 24)
            .updating($isPressing) { value, state, _ in state = value }
            .onEnded { _ in longPressSucceeded() }
    }

    private func longPressSucceeded() {
        guard !isReordering else { return }
        reorder.arm(taskID: task.id)
        didLongPress = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        menu.show(task: task, at: menuAnchor)
    }

    /// The armed pan: the row rides the finger and its neighbours part.
    private func trackReorder(_ height: CGFloat) {
        guard !task.isCompleted, let index else { return }
        if !isReordering {
            isReordering = true
            menu.dismiss() // moving means this was never a menu
            reorder.begin(taskID: task.id, at: index)
            UISelectionFeedbackGenerator().selectionChanged()
        }
        reorderOffset = snapped(height)
        let steps = Int((reorderOffset / Win95.rowHeight(pixel)).rounded())
        if steps != reorder.steps {
            UISelectionFeedbackGenerator().selectionChanged()
            withAnimation(.spring(duration: 0.22)) { reorder.update(steps: steps) }
        }
    }

    private func finishReorder() {
        let steps = reorder.steps
        isReordering = false
        reorderOffset = 0
        reorder.end()
        guard steps != 0 else { return }
        UISelectionFeedbackGenerator().selectionChanged()
        withAnimation(.spring(duration: 0.25)) {
            store.reorder(task, byRowSteps: steps)
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
