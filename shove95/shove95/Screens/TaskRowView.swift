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
import PhotosUI
import Shove95Kit

struct TaskRowView: View {
    let task: TaskItem
    /// Position in the active list — nil for completed rows, which don't reorder.
    let index: Int?
    @Environment(TaskStore.self) private var store
    @Environment(MenuCoordinator.self) private var menu
    @Environment(ReorderCoordinator.self) private var reorder
    @Environment(EditingCoordinator.self) private var editing
    @Environment(\.pixel) private var pixel

    // Reorder session (FR-004). Same long-press that opens the menu: holding
    // still shows it, moving cancels it and picks the row up instead.
    @State private var isReordering = false
    @State private var reorderOffset: CGFloat = 0
    @State private var rowFrame: CGRect = .zero
    @State private var isPressing = false



    @State private var isEditing = false
    @State private var draft = ""
    @FocusState private var editFocused: Bool

    // Photo capture (FR from Phase 4, pulled forward 2026-08-04)
    @State private var showPhotoPicker = false
    @State private var pickedItem: PhotosPickerItem?
    @State private var showPhotoViewer = false

    // Swipe state (FR-002)
    @State private var dragOffset: CGFloat = 0
    @State private var rubberBandBuzzed = false
    @State private var rowWidth: CGFloat = 390

    // Loosened 2026-08-04: 40% of the row (≈156pt) or 800pt/s meant a swipe
    // had to cross most of the screen to register, which fights the whole
    // premise — moving a task between days is THE thing this app is for, and
    // it has to cost one flick.
    private static let commitFraction: CGFloat = 0.22  // ≈86pt at 2×
    private static let commitVelocity: CGFloat = 350   // or a brisk flick
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
        // GESTURE BUDGET (hard-won, 2026-08-04, two rounds):
        //  · SwiftUI LongPressGesture — in ANY form — stalls slow vertical pans
        //    on a ScrollView descendant. Bisected: identical slow drag scrolls
        //    on the empty well, dies on a row; remove the press, it revives.
        //  · Wrapping the row in a Button with a simultaneous DragGesture kills
        //    the Button outright — not even its nested checkbox fired.
        // So: ONE DragGesture for swipe+reorder, and touch-down/tap/hold come
        // from raw UIView touches (RowTouchHandler below) — the one layer
        // UIScrollView cooperates with natively.
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
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityDescription)
            .accessibilityActions { accessibilityMoveActions }
    }

    // MARK: - Content

    private var rowContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            mainLine
            if let data = task.photoData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: Win95.Px.thumbnail * 2 * pixel,
                           height: Win95.Px.thumbnail * pixel)
                    .clipped()
                    .bevelSunken(pixel)
                    // Indented to the text column, under the title (locked Q17).
                    .padding(.leading, Win95.rowHeight(pixel) + Win95.Px.grid * pixel)
                    .padding(.bottom, Win95.Px.grid * pixel)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // The viewer opens INSTANTLY — no transition (locked Q16).
                        var t = Transaction(); t.disablesAnimations = true
                        withTransaction(t) { showPhotoViewer = true }
                    }
                    .accessibilityLabel("Photo, opens full screen")
            }
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $pickedItem, matching: .images)
        .onChange(of: pickedItem) { _, item in
            guard let item else { return }
            Task { @MainActor in
                if let data = try? await item.loadTransferable(type: Data.self) {
                    store.setPhoto(task, data: TaskStore.downscaledJPEG(from: data))
                }
                pickedItem = nil
            }
        }
        .fullScreenCover(isPresented: $showPhotoViewer) {
            PhotoViewer(task: task) {
                var t = Transaction(); t.disablesAnimations = true
                withTransaction(t) { showPhotoViewer = false }
            }
        }
    }

    /// Half the slack between one line of text and the 44pt row band. Padding
    /// the text by this on both sides centres a SINGLE line against the
    /// checkbox, and — because it's padding rather than centring — leaves the
    /// FIRST line of a wrapped title in exactly the same place while the rest
    /// flow downward (founder request 2026-08-04). Measured from the real font
    /// so it stays correct at 2×/3×/4×.
    private var firstLineInset: CGFloat {
        let lineHeight = UIFont(name: W95Font.postScriptName,
                                size: Win95.Px.fontStandard * pixel)?.lineHeight
            ?? Win95.Px.fontStandard * pixel * 1.2
        return max(0, (Win95.rowHeight(pixel) - lineHeight) / 2)
    }

    private var mainLine: some View {
        // .top, not centre: the checkbox belongs on the first line of a wrapped
        // task, not floating halfway down the block.
        HStack(alignment: .top, spacing: Win95.Px.grid * pixel) {
            Win95Checkbox(isChecked: task.isCompleted) {
                // Position changes always animate (design.md §8): the row
                // travels to or from the completed section rather than jumping.
                withAnimation(.spring(duration: 0.35)) {
                    store.toggleCompleted(task)
                }
            }

            if isEditing {
                // Grows a line at a time as the text wraps (founder request
                // 2026-08-04 — a single line just swallowed long titles).
                // A vertical-axis TextField wraps by itself as the text grows,
                // which is the ONLY way a task should gain a line. Return is a
                // commit, not a line break — but a vertical field inserts a
                // newline instead of firing `onSubmit`, so the newline is what
                // we watch for, strip, and treat as "done" (founder request
                // 2026-08-04).
                TextField("", text: returnCommitting($draft), axis: .vertical)
                    .font(W95Font.standard(pixel))
                    .foregroundStyle(Win95.text)
                    .lineLimit(1...6)
                    .focused($editFocused)
                    .submitLabel(.done)
                    .onChange(of: editFocused) { _, focused in
                        if !focused { commitEdit() }
                    }
                    .padding(.vertical, firstLineInset)
            } else {
                Text(task.title)
                    .font(W95Font.standard(pixel))
                    .strikethrough(task.isCompleted)
                    // Colour carries exactly one meaning: red = Important.
                    // Completed is grey + strikethrough; overdue is the chip.
                    .foregroundStyle(isReordering ? Win95.selectionText
                                     : (task.isCompleted ? Win95.shadow
                                        : (task.isImportant ? Win95.important : Win95.text)))
                    .fixedSize(horizontal: false, vertical: true) // wraps, never truncates
                    .padding(.vertical, firstLineInset)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .allowsHitTesting(false) // the ROW owns tap-to-edit (see body)
            }

            // Trailing column: while editing, the add-photo plus — a bare
            // glyph in the theme colour, deliberately not a button (founder
            // spec 2026-08-04). Otherwise the date chip (locked Q23).
            Group {
                if isEditing {
                    PlusGlyph()
                        .fill(Win95.accent)
                        .frame(width: Win95.Px.checkbox * pixel, height: Win95.Px.checkbox * pixel)
                        .frame(width: Win95.rowHeight(pixel), height: Win95.rowHeight(pixel))
                        .contentShape(Rectangle())
                        .onTapGesture { showPhotoPicker = true }
                        .accessibilityLabel("Add photo")
                } else if let chip = ChipFormat.label(dueDate: task.dueDate, isCompleted: task.isCompleted,
                                                      now: store.now(), calendar: store.calendar) {
                    DateChip(label: chip)
                        .allowsHitTesting(false)
                }
            }
            // Fixed to the first row's band so the chip and the plus ride the
            // first line too, however tall the row grows.
            .frame(width: Win95.Px.grid * 8 * pixel,
                   height: Win95.rowHeight(pixel), alignment: .trailing)
        }
        .padding(.trailing, Win95.Px.grid * pixel)
        .frame(maxWidth: .infinity, minHeight: Win95.rowHeight(pixel))
        // Touch plumbing sandwich: the catcher sits ABOVE the colour fill but
        // BELOW the content, so the checkbox and the edit field keep their
        // touches and everything else lands on the catcher. There must be NO
        // contentShape on the HStack — that one modifier would swallow every
        // touch before the catcher saw it.
        .background(RowTouchHandler(
            onDown: { pressChanged(true) },
            onRelease: { pressChanged(false) },
            onTap: handleTap,
            onHold: longPressSucceeded,
            isArmed: { reorder.isArmed(task.id) },
            onSwipe: swipeChanged,
            onSwipeEnd: swipeEnded,
            onSwipeCancel: swipeCancelled,
            onReorder: trackReorder,
            onReorderEnd: finishReorder
        ))
        .background(rowBackground) // grey while pressed, navy while dragged
    }

    private var rowBackground: Color {
        if isReordering { return Win95.selectionBG }
        // The tint outlives the finger: while this row's menu is open the row
        // stays held, so it is obvious what the menu is acting on.
        if isPressing || isMenuOpen { return Win95.light }
        return Win95.well
    }

    private var isMenuOpen: Bool { menu.isShowing(task) }

    // MARK: - Drag: swipe, or reorder once armed
    //
    // NO SwiftUI DragGesture. Round three (2026-08-04): even a lone
    // `DragGesture(minimumDistance: 12)` kills SLOW vertical pans on rows —
    // it claims the touch as soon as the finger passes 12pt, and although the
    // axis logic then decides "vertical, not mine", the gesture has already
    // taken the pan and the scroll view never gets it. Fast flicks worked only
    // because UIScrollView's own recognizer won the race first, which is
    // exactly the reported symptom: flick scrolls, slow drag is dead.
    //
    // So the drag rides the same UIView touches as press/tap/hold. UIKit then
    // arbitrates the way it always has: a vertical pan makes the scroll view
    // start scrolling and CANCEL our touches, so the swipe aborts by itself; a
    // horizontal pan never triggers the vertical scroll view, so we keep the
    // touches and the swipe runs.
    //
    // DIRECTION REVERSED 2026-08-04 on device feedback. The original spec said
    // left = defer, but that fights the taskbar: the tabs read
    // Today | Tomorrow | Week | General left-to-right, so dragging a row LEFT
    // should carry it toward the LEFT tab (Today = pull forward) and dragging
    // RIGHT should carry it toward the right tabs (defer). Content follows the
    // finger, which is what a spatial interface demands.
    //   swipe left  → pull forward (toward Today)
    //   swipe right → defer        (toward General)

    private func swipeChanged(_ dx: CGFloat) {
        guard !task.isCompleted else { return } // completed rows don't move
        let direction: StepDirection = dx < 0 ? .pullOne : .deferOne
        if currentBucket.steppedOnce(direction) == nil {
            // Dead end: resistance + one light haptic (FR-002/021).
            dragOffset = snapped(dx * Self.rubberResistance)
            if abs(dx) > 20, !rubberBandBuzzed {
                rubberBandBuzzed = true
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        } else {
            dragOffset = snapped(dx)
        }
    }

    private func swipeEnded(_ dx: CGFloat, velocity: CGFloat) {
        rubberBandBuzzed = false
        guard !task.isCompleted else { return }

        let direction: StepDirection = dx < 0 ? .pullOne : .deferOne
        let overThreshold = abs(dx) > rowWidth * Self.commitFraction
            || abs(velocity) > Self.commitVelocity
        let sameSign = (dx < 0) == (velocity < 0) || abs(velocity) < 50

        guard currentBucket.steppedOnce(direction) != nil, overThreshold, sameSign else {
            withAnimation(.spring(duration: 0.3)) { dragOffset = 0 }
            return
        }

        // Commit: slide off the screen edge, then the model updates and the
        // list closes the gap (FR-002; motion = position only).
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.easeOut(duration: 0.15)) {
            dragOffset = dx < 0 ? -rowWidth * 1.2 : rowWidth * 1.2
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))
            withAnimation(.spring(duration: 0.25)) {
                store.step(task, direction: direction)
            }
            dragOffset = 0 // row identity survives the move; clear the committed offset
        }
    }

    /// The scroll view took the touch (or the system did) — put the row back.
    private func swipeCancelled() {
        rubberBandBuzzed = false
        guard dragOffset != 0 else { return }
        withAnimation(.spring(duration: 0.3)) { dragOffset = 0 }
    }

    /// Movement travels in whole 1995-pixels — smooth but quantised, like a
    /// sprite (design.md §8). Appearance changes stay instant.
    private func snapped(_ value: CGFloat) -> CGFloat {
        (value / pixel).rounded() * pixel
    }

    /// The menu opens AT the pressed row (top-left aligned), not below it —
    /// anchoring at maxY put it a full row down, which read as belonging to the
    /// task underneath (founder bug report 2026-08-04).
    private var menuAnchor: CGPoint {
        CGPoint(x: rowFrame.minX + Win95.Px.grid * pixel, y: rowFrame.minY)
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

    private func pressChanged(_ pressed: Bool) {
        isPressing = pressed
    }

    /// Only called for a genuine tap — the catcher never reports one after
    /// movement or a recognised hold, so no lift-after-long-press guard needed.
    private func handleTap() {
        guard !task.isCompleted, !isEditing, !isReordering else { return }
        draft = task.title
        isEditing = true
        editFocused = true
        editing.begin(task.id.uuidString, bottom: rowFrame.maxY)
    }

    private func longPressSucceeded() {
        guard !isReordering else { return }
        reorder.arm(taskID: task.id)
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

    /// Swallows the Return key. A vertical-axis TextField inserts a newline
    /// instead of firing `onSubmit`, and stripping it in `onChange` loses the
    /// race with the field's own editing state — the newline was already in
    /// the text view, so it stayed. Intercepting in the BINDING catches it
    /// before it lands: the field only ever wraps by itself as the text grows,
    /// and Return means done (founder request 2026-08-04).
    private func returnCommitting(_ source: Binding<String>) -> Binding<String> {
        Binding(
            get: { source.wrappedValue },
            set: { new in
                guard new.contains("\n") else { source.wrappedValue = new; return }
                source.wrappedValue = new.replacingOccurrences(of: "\n", with: "")
                // Deferred: mutating focus from inside a binding setter runs
                // mid-update and SwiftUI drops it — the keyboard stayed open
                // and the newline survived. Next runloop turn it sticks.
                Task { @MainActor in editFocused = false } // commit follows
            }
        )
    }

    private func commitEdit() {
        guard isEditing else { return }
        isEditing = false
        editing.end(task.id.uuidString)
        store.editTitle(task, to: draft) // empty draft → store reverts (no-op)
    }
}

// MARK: - Touch plumbing
//
// THE PRESS CANNOT BE A SWIFTUI CONSTRUCT. Four attempts, all bisected on
// device 2026-08-04:
//   · LongPressGesture (any form)          → slow vertical pans die on rows
//   · DragGesture(minimumDistance: 0)      → list stops scrolling entirely
//   · UIKit recognizers via UIGestureRecognizerRepresentable → same stall;
//     SwiftUI overrides the delegate, so simultaneity never reaches the pan
//   · Button wrapper                       → starves EVERYTHING inside it,
//     including the nested checkbox, whether or not a pan is attached
// What works is the layer UIKit built for exactly this: a plain UIView's
// touches methods. UIScrollView delays content touches, then CANCELS them the
// moment it starts panning — so scroll always wins, a stationary hold sails
// through, and we get touch-down (tint), tap, and hold from four overrides.

private struct RowTouchHandler: UIViewRepresentable {
    var onDown: () -> Void
    var onRelease: () -> Void
    var onTap: () -> Void
    var onHold: () -> Void
    var isArmed: () -> Bool
    var onSwipe: (CGFloat) -> Void
    var onSwipeEnd: (CGFloat, CGFloat) -> Void
    var onSwipeCancel: () -> Void
    var onReorder: (CGFloat) -> Void
    var onReorderEnd: () -> Void

    func makeUIView(context: Context) -> TouchCatcher {
        let view = TouchCatcher()
        view.backgroundColor = .clear
        bind(view)
        return view
    }

    func updateUIView(_ view: TouchCatcher, context: Context) {
        bind(view) // closures capture the current task — rebind on update
    }

    private func bind(_ view: TouchCatcher) {
        view.onDown = onDown
        view.onRelease = onRelease
        view.onTap = onTap
        view.onHold = onHold
        view.isArmed = isArmed
        view.onSwipe = onSwipe
        view.onSwipeEnd = onSwipeEnd
        view.onSwipeCancel = onSwipeCancel
        view.onReorder = onReorder
        view.onReorderEnd = onReorderEnd
    }
}

final class TouchCatcher: UIView {
    var onDown: (() -> Void)?
    var onRelease: (() -> Void)?
    var onTap: (() -> Void)?
    var onHold: (() -> Void)?
    var isArmed: (() -> Bool)?
    var onSwipe: ((CGFloat) -> Void)?
    var onSwipeEnd: ((CGFloat, CGFloat) -> Void)?
    var onSwipeCancel: (() -> Void)?
    var onReorder: ((CGFloat) -> Void)?
    var onReorderEnd: (() -> Void)?

    /// What this touch turned out to be. Decided once, on first real movement.
    private enum Kind { case undecided, swipe, reorder, scrolling }
    private var kind: Kind = .undecided

    private var startPoint: CGPoint = .zero
    private var startTime: TimeInterval = 0
    private var lastPoint: CGPoint = .zero
    private var lastTime: TimeInterval = 0
    private var velocityX: CGFloat = 0
    private var moved = false
    private var held = false
    private var holdWork: DispatchWorkItem?

    /// Touches are measured in WINDOW space, never `location(in: self)`. The
    /// row translates with the swipe, so a self-relative reading double-counts:
    /// the finger moves 250pt, the view chases it, and the touch's position
    /// *within* the view advances only ~125 — half the real distance, so the
    /// commit threshold was never reached. Same trap on the vertical axis
    /// during a reorder.
    private func point(_ touch: UITouch) -> CGPoint {
        touch.location(in: window ?? self)
    }

    /// Movement needed before a touch stops being a tap/hold candidate.
    private static let slop: CGFloat = 10
    /// A pan must be this much more horizontal than vertical to be a swipe;
    /// anything else is left to the scroll view.
    private static let axisBias: CGFloat = 1.2

    /// UIScrollView holds content touches back ~150ms to see whether the
    /// gesture is a scroll. A quick swipe is OVER by then, so the catcher saw
    /// almost none of it and the swipe silently never fired. Turning the delay
    /// off delivers touches immediately; cancellation still does the
    /// arbitration — the scroll view yanks the touch the moment its pan
    /// recognises, which is what makes a vertical drag scroll instead of swipe.
    override func didMoveToWindow() {
        super.didMoveToWindow()
        configureEnclosingScrollView()
    }

    /// Re-run on every touch as well as on attach: at `didMoveToWindow` the
    /// SwiftUI scroll view is not always in the ancestor chain yet, and if the
    /// delay is still on, the first ~150ms of a swipe is swallowed — the row
    /// then measures a drag far shorter than the finger actually travelled and
    /// never reaches the commit threshold.
    private func configureEnclosingScrollView() {
        var ancestor: UIView? = superview
        while let view = ancestor {
            if let scrollView = view as? UIScrollView {
                scrollView.delaysContentTouches = false
                scrollView.canCancelContentTouches = true
                return
            }
            ancestor = view.superview
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        guard let touch = touches.first else { return }
        configureEnclosingScrollView()
        startPoint = point(touch)
        startTime = touch.timestamp
        lastPoint = startPoint
        lastTime = touch.timestamp
        velocityX = 0
        kind = .undecided
        moved = false
        held = false
        onDown?()

        let work = DispatchWorkItem { [weak self] in
            guard let self, !self.moved else { return }
            self.held = true
            self.onHold?()
        }
        holdWork?.cancel()
        holdWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        guard let touch = touches.first else { return }
        let p = point(touch)
        let dx = p.x - startPoint.x
        let dy = p.y - startPoint.y

        let dt = touch.timestamp - lastTime
        if dt > 0 { velocityX = (p.x - lastPoint.x) / CGFloat(dt) }
        lastPoint = p
        lastTime = touch.timestamp

        if hypot(dx, dy) > Self.slop {
            moved = true
            holdWork?.cancel()
        }

        // A hold that already fired owns the vertical axis: this is a reorder.
        if isArmed?() == true, kind != .swipe {
            kind = .reorder
            onReorder?(dy)
            return
        }

        switch kind {
        case .undecided:
            guard hypot(dx, dy) > Self.slop else { return }
            if abs(dx) > abs(dy) * Self.axisBias {
                kind = .swipe
                onSwipe?(dx)
            } else {
                // Vertical: hand it to the scroll view and never look again.
                // It will cancel our touches as soon as it starts scrolling.
                kind = .scrolling
            }
        case .swipe:
            onSwipe?(dx)
        case .reorder, .scrolling:
            break
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        holdWork?.cancel()
        let wasTap = !moved && !held
        let dx = (touches.first.map { point($0).x } ?? lastPoint.x) - startPoint.x
        onRelease?()

        // Synthesised touches can carry identical timestamps, leaving the
        // per-segment velocity at zero; fall back to the whole gesture's
        // average so a fast flick is still recognised as one.
        var velocity = velocityX
        if velocity == 0 {
            let elapsed = (touches.first?.timestamp ?? lastTime) - startTime
            if elapsed > 0 { velocity = dx / CGFloat(elapsed) }
        }

        switch kind {
        case .swipe: onSwipeEnd?(dx, velocity)
        case .reorder: onReorderEnd?()
        case .undecided, .scrolling: break
        }
        if wasTap { onTap?() }
        kind = .undecided
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        holdWork?.cancel()
        onRelease?() // the scroll view took the touch — never a tap
        switch kind {
        case .swipe: onSwipeCancel?()
        case .reorder: onReorderEnd?()
        case .undecided, .scrolling: break
        }
        kind = .undecided
    }
}

// MARK: - Photo pieces

/// Bare pixel plus on a 12×12 grid — an affordance, not a button (no bevel).
private struct PlusGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        let u = rect.width / 12
        var path = Path()
        path.addRect(CGRect(x: 5 * u, y: 1 * u, width: 2 * u, height: 10 * u))
        path.addRect(CGRect(x: 1 * u, y: 5 * u, width: 10 * u, height: 2 * u))
        return path
    }
}

/// Full-screen photo: a maximized Win95 window (locked Q16 + the founder's
/// "opens like a windows style window" rider). Opens and closes instantly;
/// tapping anywhere closes it.
private struct PhotoViewer: View {
    @Environment(\.pixel) private var pixel
    let task: TaskItem
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            TitleBar(title: task.title, isClose: true, onSettings: onClose)
            if let data = task.photoData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
            }
        }
        .background(Color.black)
        .contentShape(Rectangle())
        .onTapGesture(perform: onClose)
        .preferredColorScheme(.light)
    }
}
