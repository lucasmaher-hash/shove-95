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
    @Environment(MenuCoordinator.self) private var menu
    @Environment(\.pixel) private var pixel

    // Reorder session (FR-004). Same long-press that opens the menu: holding
    // still shows it, moving cancels it and picks the row up instead.
    @State private var isReordering = false
    @State private var reorderOffset: CGFloat = 0
    @State private var rowFrame: CGRect = .zero
    @State private var isPressing = false
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
            .zIndex(isReordering ? 1 : 0)
            .simultaneousGesture(swipeGesture)
            .simultaneousGesture(pressInteraction)
            .simultaneousGesture(pressFeedback)
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

    /// Touch-down / touch-up only — it never claims the touch, so the swipe and
    /// the long press are unaffected.
    private var pressFeedback: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in if !isPressing { isPressing = true } }
            .onEnded { _ in isPressing = false }
    }

    // MARK: - Swipe
    //
    // DIRECTION REVERSED 2026-08-04 on device feedback. The original spec said
    // left = defer, but that fights the taskbar: the tabs read
    // Today | Tomorrow | Week | General left-to-right, so dragging a row LEFT
    // should carry it toward the LEFT tab (Today = pull forward) and dragging
    // RIGHT should carry it toward the right tabs (defer). Content follows the
    // finger, which is what a spatial interface demands.
    //   swipe left  → pull forward (toward Today)
    //   swipe right → defer        (toward General)

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
    // Hold still → the Win95 menu opens at the finger.
    // Hold and move vertically → the menu is cancelled and the row is picked up.
    // One gesture owns both branches, which is only possible because the
    // system context menu is gone (it swallowed the long-press entirely).

    private var pressInteraction: some Gesture {
        LongPressGesture(minimumDuration: 0.4, maximumDistance: 24)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .global))
            .onChanged { value in
                guard case .second(true, let drag) = value else { return }

                guard let drag else {
                    // Press recognised, finger still: open the menu.
                    if !isReordering, menu.request == nil {
                        didLongPress = true
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        menu.show(task: task, at: menuAnchor)
                    }
                    return
                }

                if abs(drag.translation.height) > 10, !task.isCompleted {
                    // The finger travelled: this is a reorder, not a menu.
                    if !isReordering {
                        isReordering = true
                        didLongPress = true
                        menu.dismiss()
                        UISelectionFeedbackGenerator().selectionChanged()
                    }
                    reorderOffset = snapped(drag.translation.height)
                }
            }
            .onEnded { _ in
                isPressing = false
                let steps = Int((reorderOffset / Win95.rowHeight(pixel)).rounded())
                let wasReordering = isReordering
                isReordering = false
                reorderOffset = 0
                guard wasReordering, steps != 0 else { return }
                UISelectionFeedbackGenerator().selectionChanged()
                withAnimation(.spring(duration: 0.25)) {
                    store.reorder(task, byRowSteps: steps)
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
