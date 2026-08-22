//
//  TaskRowView.swift
//  shove95
//
//  One task row. Rebuilt from scratch 2026-08-04 against the interaction
//  contract in design.md §16 — read that table first; this file implements it
//  line by line and nothing else.
//
//  Division of labour:
//    · RowInteraction.swift  — the UIKit touch state machine (no SwiftUI
//      gestures exist on this row; §16 records why)
//    · this file             — layout, visual state, and the handlers the
//      state machine calls
//    · TaskListView          — zIndex for the lifted row, neighbours parting,
//      scrollDisabled while armed, keyboard lifting
//

import SwiftUI
import PhotosUI
import Shove95Kit

struct TaskRowView: View {
    let task: TaskItem

    @Environment(TaskStore.self) private var store
    @Environment(MenuCoordinator.self) private var menu
    @Environment(EditingCoordinator.self) private var editing
    @Environment(\.pixel) private var pixel
    /// The RESOLVED scheme — AppShell puts the dark twin here when the
    /// appearance calls for it. The pulse asks it, not the system, which way
    /// this look's page points; see the pin glyph.
    @Environment(\.win95Scheme) private var scheme

    // Visual state
    @State private var isPressing = false
    @State private var dragOffset: CGFloat = 0      // horizontal, swipe
    @State private var rubberBandBuzzed = false
    /// True while the swipe is past the point where letting go commits — see
    /// `swipeChanged`. Kept so the tick fires on the crossing, not every frame.
    @State private var passedThreshold = false

    // Geometry
    /// Not @State — see RowFrameBox.
    @State private var frames = RowFrameBox()
    @State private var rowWidth: CGFloat = 390

    // Inline edit
    @State private var isEditing = false
    @State private var draft = ""
    @FocusState private var editFocused: Bool

    // Photos
    @State private var showPhotoPicker = false
    @State private var showCamera = false
    /// Camera vs Library — asked once per add, as a Win95 menu (TASK-044).
    @State private var showSourceChoice = false
    @State private var pickedItem: PhotosPickerItem?
    /// Index into task.allPhotos of the photo open in the viewer.
    @State private var viewerIndex: Int?
    /// Which thumbnail is mid press-in (the tiny open animation).
    @State private var pressedThumb: Int?
    /// The photo waiting on a yes — see the viewer's bin.
    @State private var pendingPhotoDelete: Int?
    /// True while the day list is up.
    @State private var showDayPicker = false
    /// A day picked in the calendar that would take this task OUT of Soon.
    /// Held until the edit ends — see `pickDay`.
    @State private var pendingLeaveDay: Date?
    /// One photo per edit session: the plus disappears after a pick and
    /// returns the next time the task enters edit mode.
    @State private var addedPhotoThisEdit = false

    // Swipe commit thresholds (§16: one flick, not a screen-crossing drag).
    // The distance bar scales with RUNWAY: a swipe starting right of centre
    // physically can't travel 86pt before the screen edge, which made
    // off-text swipes on short rows bounce forever (traced 2026-08-04:
    // dx 83 against a bar of 86). Half of what the finger COULD travel,
    // capped at 22% of the row.
    private static let commitFraction: CGFloat = 0.22
    private static let runwayFraction: CGFloat = 0.5
    private static let commitVelocity: CGFloat = 300
    private static let rubberResistance: CGFloat = 0.3

    // MARK: - Body

    var body: some View {
        content
            .offset(x: dragOffset)
            .scaleEffect(isPressing ? 0.97 : 1, anchor: .center)
            .animation(.spring(duration: 0.22), value: isPressing)
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { rowWidth = proxy.size.width }
                        .onChange(of: proxy.frame(in: .global)) { _, frame in
                            frames.rect = frame
                        }
                        .task { frames.rect = proxy.frame(in: .global) }
                }
            }
            .onAppear {
                dragOffset = 0 // row identity survives tab switches
                // This row may BE the one that just moved into another day.
                // The old one handed the edit over on its way out; pick it up.
                if editing.reopenTaskID == task.id {
                    editing.reopenTaskID = nil
                    beginEditing()
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityDescription)
            .accessibilityActions { accessibilityMoveActions }
    }

    // MARK: - Layout

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            mainLine
            if !task.allPhotos.isEmpty {
                photoStrip
            }
        }
        // Touch sandwich (§16 trap 4): catcher above the colour fill, below
        // the content. Checkbox and TextField win their own touches; no
        // contentShape anywhere on this stack.
        .background(RowGestureView(handlers: gestureHandlers))
        // The held tint runs to the screen edges, past the list's inset — the
        // heading bands do the same, and a highlight that stops at the margin
        // reads as a misdrawn row rather than a state (founder direction
        // 2026-08-17). Negative padding on the COLOUR, inside the background:
        // it widens what it wraps, and out here the row's own frame — and the
        // swipe geometry with it — stays untouched.
        .background {
            rowBackground.padding(.horizontal, -(Win95.Px.windowMargin * pixel))
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $pickedItem, matching: .images)
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { data in
                showCamera = false
                guard let data else { return }
                store.addPhoto(task, data: ImageImport.prepare(data))
                addedPhotoThisEdit = true
            }
            .ignoresSafeArea()
        }
        // Source choice: a plain confirmation dialog is the one system sheet
        // worth keeping — a hand-drawn Win95 menu for a two-item OS-level
        // permission flow would be more costume than interface.
        .confirmationDialog("Add photo", isPresented: $showSourceChoice) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Camera") { showCamera = true }
            }
            Button("Photo Library") { showPhotoPicker = true }
            Button("Cancel", role: .cancel) {}
        }
        // The calendar in the editing row set this flag and nothing listened:
        // the Win95 row had the control but never the sheet, so scheduling an
        // existing task was only ever possible in skeu (found while fixing the
        // control's placement, 2026-08-17). Undo IS recorded here — unlike the
        // add row, this task exists and genuinely moves.
        .sheet(isPresented: $showDayPicker) {
            Win95DayPickerSheet(current: task.dueDate) { picked in
                showDayPicker = false
                pickDay(picked)
            }
        }
        .onChange(of: pickedItem) { _, item in
            guard let item else { return }
            Task { @MainActor in
                if let data = try? await item.loadTransferable(type: Data.self) {
                    store.addPhoto(task, data: ImageImport.prepare(data))
                    addedPhotoThisEdit = true // the plus retires for this session
                }
                pickedItem = nil
            }
        }
        .fullScreenCover(isPresented: Binding(
            get: { viewerIndex != nil },
            set: { if !$0 { viewerIndex = nil } }
        )) {
            if let index = viewerIndex, index < task.allPhotos.count,
               let image = PhotoCache.image(task.allPhotos[index]) {
                PhotoViewer(
                    title: task.title,
                    image: image,
                    onRemove: {
                        // ASKED first, as the skeu viewer does — a photo
                        // cannot be recovered (founder direction 2026-08-17).
                        pendingPhotoDelete = index
                    },
                    onClose: {
                        // Closing stays instant (locked Q16).
                        var t = Transaction(); t.disablesAnimations = true
                        withTransaction(t) { viewerIndex = nil }
                    }
                )
                // Same fix as the pin dialog's scrim: a scheme whose darkest
                // tone is not black must not veil itself in black.
                .presentationBackground(Win95.darkShadow.opacity(0.55))
                .overlay {
                    if let at = pendingPhotoDelete {
                        Win95PinReplaceDialog(
                            outgoing: "",
                            title: "Delete photo",
                            message: "This photo goes for good. The task itself is not touched.",
                            confirmLabel: "Delete",
                            destructive: true
                        ) {
                            pendingPhotoDelete = nil
                            var t = Transaction(); t.disablesAnimations = true
                            withTransaction(t) { viewerIndex = nil }
                            store.removePhoto(task, at: at)
                        } onCancel: {
                            pendingPhotoDelete = nil
                        }
                    }
                }
            }
        }
    }

    private var mainLine: some View {
        // .top: the checkbox belongs on the FIRST line of a wrapped task.
        HStack(alignment: .top, spacing: Win95.Px.grid * pixel) {
            Win95Checkbox(isChecked: task.isCompleted) {
                // Position changes always animate (design.md §8).
                withAnimation(.spring(duration: 0.35)) {
                    store.toggleCompleted(task)
                }
            }

            if isEditing {
                editor
            } else {
                title
            }

            trailingColumn
        }
        // NO trailing padding of the row's own: the list already insets its
        // rows by the window margin, and this extra unit put the chips and
        // controls on a different right-hand line from the gear, the taskbar
        // and the headings (founder bug report 2026-08-17).
        .frame(maxWidth: .infinity, minHeight: Win95.rowHeight(pixel))
    }

    private var title: some View {
        Text(task.title)
            .font(W95Font.standard(pixel))
            .strikethrough(task.isCompleted)
            // Colour carries one meaning: red = Important. Completed is grey.
            .foregroundStyle(task.isCompleted ? Win95.textMuted
                             : (task.isImportant ? Win95.important : Win95.text))
            .fixedSize(horizontal: false, vertical: true) // wraps, never truncates
            .padding(.vertical, firstLineInset)
            .frame(maxWidth: .infinity, alignment: .leading)
            .allowsHitTesting(false) // the ROW owns tap-to-edit
    }

    private var editor: some View {
        // Wraps by itself as the text grows — the only way a task gains a
        // line. Return commits: intercepted in the binding (§16).
        TextField("", text: returnCommitting, axis: .vertical)
            .font(W95Font.standard(pixel))
            // Important stays red while you edit it — the flag doesn't pause
            // because the caret is in the field (founder request 2026-08-04).
            .foregroundStyle(task.isImportant ? Win95.important : Win95.text)
            .lineLimit(1...6)
            .focused($editFocused)
            .submitLabel(.done)
            // Return arrives EITHER as a "\n" in the binding or as a submit,
            // depending on the iOS build — see AddRowView.returnCommitting for
            // the full story. Both paths just drop focus; `onChange` below is
            // the single place the edit is actually committed, so a build where
            // both fire commits once.
            .onSubmit { editFocused = false }
            .onChange(of: editFocused) { _, focused in
                if !focused { commitEdit() }
            }
            .padding(.vertical, firstLineInset)
    }

    private var trailingColumn: some View {
        HStack(spacing: 0) {
            // The pin sits LEFT of the camera while editing, and stays behind
            // — left of the date chip — once it holds. That is the whole
            // grammar of it: while you are working on a task you can always
            // reach for it, and afterwards it is only there when it means
            // something (founder direction 2026-08-16).
            // NO pin here. A task becomes live by being typed into the Live
            // section, and that is the only door (founder direction
            // 2026-08-17).


            // An HStack, NOT a Group. A modifier on a Group is applied to each
            // CHILD separately, so the width below gave the camera its own
            // 128pt trailing-aligned column and the calendar another one — the
            // two controls ended up a whole column apart, with the camera
            // stranded in the middle of the row (founder bug report
            // 2026-08-17). The pair belongs side by side at the trailing edge;
            // the fixed width is there so the text does not shift when a chip
            // becomes a camera.
            HStack(spacing: 0) {
                if isEditing && !addedPhotoThisEdit {
                    // Add-photo plus: a bare glyph in the theme colour, not a
                    // button. One photo per edit session — the plus retires
                    // after a pick and returns on the next edit.
                    CameraGlyph()
                        .fill(Win95.accent)
                        .frame(width: Win95.Px.checkbox * pixel, height: Win95.Px.checkbox * pixel)
                        .frame(width: Win95.rowHeight(pixel), height: Win95.rowHeight(pixel))
                        .contentShape(Rectangle())
                        .onTapGesture { chooseSource() }
                        .accessibilityLabel("Add photo")
                } else if let chip = ChipFormat.label(dueDate: task.dueDate, isCompleted: task.isCompleted,
                                                      now: store.now(), calendar: store.calendar) {
                    DateChip(label: chip)
                        .allowsHitTesting(false)
                }

                // The calendar, only in Soon and only while editing (founder
                // direction 2026-08-17). Asked of the TASK, not the screen: a
                // row does not know which tab is showing, and its date already
                // answers the question.
                if isEditing,
                   task.bucket(now: store.now(), calendar: store.calendar) == .general {
                    CalendarGlyph()
                        .fill(Win95.accent)
                        .frame(width: Win95.Px.checkbox * pixel, height: Win95.Px.checkbox * pixel)
                        .frame(width: Win95.rowHeight(pixel), height: Win95.rowHeight(pixel))
                        .contentShape(Rectangle())
                        .onTapGesture { SkeuHaptic.press(); showDayPicker = true }
                        .accessibilityLabel("Schedule")
                }
            }
            .frame(width: Win95.Px.grid * 16 * pixel, alignment: .trailing)
        }
        // Pinned to the first line's band, however tall the row grows.
        .frame(height: Win95.rowHeight(pixel), alignment: .trailing)
    }

    /// Thumbnails accumulate LEFT TO RIGHT in the order added. Tapping one
    /// presses it in briefly — you see the press — then the viewer opens
    /// (founder request 2026-08-04). Closing stays instant.
    ///
    /// A plain HStack, NOT a horizontal ScrollView: a nested scroll view owns
    /// horizontal pans, so swiping across a photo moved nothing while swiping
    /// across the text moved the task. Square 64pt thumbnails (TASK-045's spec
    /// size) fit four across, so scrolling isn't needed anyway.
    private var photoStrip: some View {
        HStack(spacing: Win95.Px.grid * pixel) {
            ForEach(Array(task.allPhotos.enumerated()), id: \.offset) { index, data in
                if let image = PhotoCache.image(data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: Win95.Px.thumbnail * pixel,
                               height: Win95.Px.thumbnail * pixel)
                        .clipped()
                        .bevelSunken(pixel)
                        .scaleEffect(pressedThumb == index ? 0.92 : 1)
                        .animation(.easeOut(duration: 0.1), value: pressedThumb)
                        // Hit-transparent, exactly like the title text: a
                        // foreground view with its own tap gesture takes the
                        // whole touch, so swiping across a photo moved nothing
                        // (founder bug report 2026-08-04). The catcher behind
                        // owns every touch and routes taps by region below.
                        .allowsHitTesting(false)
                        .accessibilityLabel("Photo \(index + 1), opens in a window")
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.leading, Win95.rowHeight(pixel) + Win95.Px.grid * pixel)
        .padding(.bottom, Win95.Px.grid * pixel)
    }

    /// No camera on the simulator (and none on some devices) — skip straight
    /// to the library rather than offering a dead option.
    private func chooseSource() {
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            showSourceChoice = true
        } else {
            showPhotoPicker = true
        }
    }

    /// Which thumbnail (if any) sits under a row-local point. The strip is a
    /// fixed grid — leading inset, square thumbs, even spacing — so this is
    /// arithmetic rather than a hit test.
    private func photoIndex(at local: CGPoint) -> Int? {
        guard !task.allPhotos.isEmpty else { return nil }
        let thumb = Win95.Px.thumbnail * pixel
        let gap = Win95.Px.grid * pixel
        let stripHeight = thumb + gap
        // The strip is always the bottom band, whatever height the title grew to.
        guard local.y > frames.rect.height - stripHeight else { return nil }

        let leading = Win95.rowHeight(pixel) + gap
        guard local.x >= leading else { return nil }
        let index = Int((local.x - leading) / (thumb + gap))
        // Reject the gaps between thumbnails.
        let withinThumb = (local.x - leading).truncatingRemainder(dividingBy: thumb + gap) <= thumb
        guard withinThumb, index >= 0, index < task.allPhotos.count else { return nil }
        return index
    }

    private func openViewer(_ index: Int) {
        pressedThumb = index
        Task { @MainActor in
            // Long enough to SEE the press, short enough to feel instant.
            try? await Task.sleep(for: .milliseconds(140))
            pressedThumb = nil
            var t = Transaction(); t.disablesAnimations = true
            withTransaction(t) { viewerIndex = index }
        }
    }

    // MARK: - Visual state

    private var rowBackground: Color {
        // One rule (founder 2026-08-04): whenever the row is the thing being
        // ACTED ON — pressed, menu open, mid-swipe, or in edit mode — it
        // carries the same held-grey tint.
        if isPressing || isMenuOpen || isEditing || dragOffset != 0 {
            return Win95.light
        }
        return Win95.well
    }

    private var isMenuOpen: Bool { menu.isShowing(task) }

    /// Half the slack between one text line and the 44pt row band. Padding
    /// rather than centring: line one lands identically whether the row is one
    /// line or four. Measured from the real font so it holds at 2×/3×/4×.
    private var firstLineInset: CGFloat {
        let lineHeight = UIFont(name: W95Font.postScriptName,
                                size: Win95.Px.fontStandard * pixel)?.lineHeight
            ?? Win95.Px.fontStandard * pixel * 1.2
        return max(0, (Win95.rowHeight(pixel) - lineHeight) / 2)
    }

    /// Movement travels in whole 1995-pixels — smooth but quantised, like a
    /// sprite (design.md §8).
    private func snapped(_ value: CGFloat) -> CGFloat {
        (value / pixel).rounded() * pixel
    }

    private var currentBucket: Bucket {
        task.bucket(now: store.now(), calendar: store.calendar)
    }

    // MARK: - Gesture handlers (one per contract row, §16)

    private var gestureHandlers: RowGestureHandlers {
        RowGestureHandlers(
            onPressChanged: { isPressing = $0 },
            onTap: handleTap,
            onHold: handleHold,
            onSwipeChanged: swipeChanged,
            onSwipeEnded: swipeEnded,
            onSwipeCancelled: swipeCancelled
        )
    }

    /// Routes a tap by where it landed: a thumbnail opens the viewer, anything
    /// else starts an edit. Geometry, not gestures — see the note on the photo
    /// strip for why the images can't handle their own taps.
    private func handleTap(at point: CGPoint) {
        let local = CGPoint(x: point.x - frames.rect.minX, y: point.y - frames.rect.minY)
        if let index = photoIndex(at: local) {
            openViewer(index)
            return
        }
        guard !task.isCompleted, !isEditing else { return }
        beginEditing()
    }

    /// Opens the row for typing. Split out of the tap handler because the row
    /// also opens itself when it arrives carrying a handed-over edit — see
    /// `reopenTaskID`.
    private func beginEditing() {
        draft = task.title
        isEditing = true
        addedPhotoThisEdit = false // fresh session, the plus returns
        editing.begin(task.id.uuidString, bottom: frames.rect.maxY)
        // Focus must land AFTER the TextField exists. Setting it in the same
        // pass that creates the field is a race — sometimes the keyboard never
        // came up because focus was applied to a view not yet in the tree.
        Task { @MainActor in editFocused = true }
    }

    /// Hold → menu just BELOW the row, so the task it acts on stays visible
    /// (founder request 2026-08-04 — anchored at the top it covered the row).
    /// Global→local conversion happens in MenuOverlay.
    private func handleHold() {
        guard !isEditing else { return }
        SkeuHaptic.press()
        menu.show(task: task, rowFrame: frames.rect)
    }

    /// Swipe left = pull forward (toward Today), right = defer (toward
    /// General) — content follows the finger, matching the taskbar's order.
    /// Swiping LEFT out of Today lands in Live.
    ///
    /// That end of the line used to rubber-band against nothing, and Live sits
    /// exactly there in the bar — one frame left of Today. So the gesture is
    /// already the right shape; it just had no destination until now (founder
    /// direction 2026-08-17).
    private var pullGoesLive: Bool { currentBucket == .today }

    /// A dead end only if the step is impossible AND Live is not the answer.
    private func isDeadEnd(_ direction: StepDirection) -> Bool {
        if direction == .pullOne, pullGoesLive { return false }
        return currentBucket.steppedOnce(direction) == nil
    }

    private func swipeChanged(_ dx: CGFloat) {
        guard !task.isCompleted else { return }
        let direction: StepDirection = dx < 0 ? .pullOne : .deferOne
        if isDeadEnd(direction) {
            // Dead end: rubber-band + one light haptic.
            dragOffset = snapped(dx * Self.rubberResistance)
            if abs(dx) > 20, !rubberBandBuzzed {
                rubberBandBuzzed = true
                SkeuHaptic.press()
            }
        } else {
            dragOffset = snapped(dx)
            // Passing the bar is the moment worth feeling — after this,
            // letting go commits. Fires once per crossing, not per frame.
            //
            // Measured against the row alone, not the runway `swipeEnded`
            // uses: the finger's start x is not carried into this handler, and
            // for a HAPTIC the exact bar matters far less than buzzing once,
            // near it, in both looks alike.
            let past = abs(dx) > rowWidth * Self.commitFraction
            if past != passedThreshold {
                passedThreshold = past
                if past { SkeuHaptic.threshold() }
            }
        }
    }

    private func swipeEnded(_ dx: CGFloat, velocity: CGFloat, startX: CGFloat) {
        rubberBandBuzzed = false
        passedThreshold = false
        guard !task.isCompleted else { return }

        let direction: StepDirection = dx < 0 ? .pullOne : .deferOne
        let runway = dx > 0 ? max(1, rowWidth - startX) : max(1, startX)
        let bar = min(rowWidth * Self.commitFraction, runway * Self.runwayFraction)
        let overThreshold = abs(dx) > bar || abs(velocity) > Self.commitVelocity
        let sameSign = (dx < 0) == (velocity < 0) || abs(velocity) < 50

        guard !isDeadEnd(direction), overThreshold, sameSign else {
            withAnimation(.spring(duration: 0.3)) { dragOffset = 0 }
            return
        }

        // Commit: slide off the edge, then the model moves and the list
        // closes the gap.
        SkeuHaptic.press()
        withAnimation(.easeOut(duration: 0.15)) {
            dragOffset = dx < 0 ? -rowWidth * 1.2 : rowWidth * 1.2
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))
            withAnimation(.spring(duration: 0.25)) {
                if direction == .pullOne, pullGoesLive {
                    // Asks first when something already holds Live; if it is
                    // cancelled the row simply comes back, because the task
                    // never left Today.
                    menu.goLive(task, store: store)
                } else {
                    _ = store.step(task, direction: direction)
                }
            }
            dragOffset = 0 // row identity survives the move
        }
    }

    private func swipeCancelled() {
        rubberBandBuzzed = false
        guard dragOffset != 0 else { return }
        withAnimation(.spring(duration: 0.3)) { dragOffset = 0 }
    }

    // MARK: - Inline edit

    /// Return commits (§16): a vertical-axis TextField inserts a newline
    /// instead of firing onSubmit, so the newline is intercepted in the
    /// binding — before it lands — and the focus change is deferred a runloop
    /// turn (inline it runs mid-update and SwiftUI drops it).
    private var returnCommitting: Binding<String> {
        Binding(
            get: { draft },
            set: { new in
                guard new.contains("\n") else { draft = new; return }
                draft = new.replacingOccurrences(of: "\n", with: "")
                Task { @MainActor in editFocused = false } // commit follows
            }
        )
    }

    /// A day chosen from the calendar while editing.
    ///
    /// A day still in Soon is applied AT ONCE, so the task appears under that
    /// heading while you are still typing into it — and the edit follows it
    /// there, handed over through `reopenTaskID`. Today and Tomorrow are held
    /// instead: they take the task out of this tab altogether, and a row that
    /// vanishes mid-word is not an edit continuing anywhere (founder direction
    /// 2026-08-17). They land when the edit ends, with the same leftward wipe
    /// the gesture would have made.
    private func pickDay(_ day: Date) {
        let destination = DateEngine.bucket(for: store.calendar.startOfDay(for: day),
                                            now: store.now(), calendar: store.calendar)
        guard destination == .general else {
            pendingLeaveDay = day
            return
        }
        guard isEditing else {
            store.schedule(task, on: day)
            return
        }
        // The text first: the row is about to be rebuilt elsewhere, and its
        // draft does not travel.
        store.editTitle(task, to: draft)
        editing.reopenTaskID = task.id
        store.schedule(task, on: day)
    }

    private func commitEdit() {
        guard isEditing else { return }
        isEditing = false
        editing.end(task.id.uuidString)
        store.editTitle(task, to: draft) // empty draft → store reverts

        // A day that takes the task out of this tab was held until now. It
        // leaves the way a swipe would send it: leftward, off the edge, then
        // the move — so the list closing up is the end of one movement rather
        // than a row blinking out of existence.
        if let day = pendingLeaveDay {
            pendingLeaveDay = nil
            withAnimation(.easeIn(duration: 0.22)) { dragOffset = -rowWidth }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(220))
                store.schedule(task, on: day)
            }
        }
    }

    // MARK: - VoiceOver (FR-016)
    // The swipe is custom, so every move must also exist as a named action.

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
}

// MARK: - Photo viewer

/// Photo viewer, redesigned 2026-08-04: a floating Win95 window at ~3/4 of
/// the screen that HUGS the image — title bar with ✕ on top, image inside a
/// bevelled frame. The app stays visible behind, dimmed. Only the ✕ or the
/// dimmed background closes it; the image itself is inert. Opens after the
/// thumbnail's press-in; closes instantly.
private struct PhotoViewer: View {
    @Environment(\.pixel) private var pixel
    let title: String
    let image: UIImage
    var onRemove: () -> Void
    var onClose: () -> Void

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // The dimmed background IS the close control (besides the ✕).
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onClose)

                // 0.75 → 0.86: the founder asked for 15% more window
                // (2026-08-04). Still short of the edges, so the app stays
                // visible behind it and the thing reads as a window.
                window(maxWidth: geo.size.width * 0.86,
                       maxHeight: geo.size.height * 0.86)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func window(maxWidth: CGFloat, maxHeight: CGFloat) -> some View {
        // The window wraps the image: scale to fit 3/4 of the screen, then
        // size the chrome to the image — the frame hugs, never letterboxes.
        let scale = min(maxWidth / image.size.width,
                        (maxHeight - Win95.Px.titleBar * pixel) / image.size.height)
        let fitted = CGSize(width: image.size.width * scale,
                            height: image.size.height * scale)

        return VStack(spacing: 0) {
            TitleBar(title: title, isClose: true, onDelete: onRemove, onSettings: onClose)
            // Zoomable, with Live Text — the photo is the one place the Win95
            // costume gives way, because selecting text in an image is an
            // interaction people already know from Photos.
            ZoomableImageView(image: image)
                .frame(width: fitted.width, height: fitted.height)
                .padding(pixel * 2)
                .background(Win95.surface)
        }
        .frame(width: fitted.width + pixel * 4)
        .bevelRaised(pixel)
        // Swallow taps so only the ✕ and the background close the window.
        .contentShape(Rectangle())
        .onTapGesture {}
    }
}


// MARK: - Day picker

/// The next four weeks, one row per day, in this look's parts. See
/// `DayPickerRange` for why a list rather than a month grid.
struct Win95DayPickerSheet: View {
    @Environment(\.pixel) private var pixel
    @Environment(\.win95Scheme) private var scheme
    @Environment(AppSettings.self) private var settings
    @Environment(TaskStore.self) private var store
    let current: Date?
    let onPick: (Date) -> Void

    private var chosen: Date? { current.map { store.calendar.startOfDay(for: $0) } }
    private var today: Date { store.calendar.startOfDay(for: store.now()) }

    /// Which month is on show. The sheet pages rather than scrolls, so this is
    /// the only thing that moves — see DayPicker.swift.
    @State private var monthIndex = 0

    private var months: [Date] {
        DayPickerRange.monthStarts(now: today, calendar: store.calendar)
    }

    /// The sheet's own height, measured from what it holds. A `.medium` detent
    /// cut the last week off the month; `.large` fixed that by taking the whole
    /// screen, which is far more room than a month needs (founder direction
    /// 2026-08-17). Measured, the sheet is exactly as tall as the calendar.
    @State private var sheetHeight: CGFloat = 520

    var body: some View {
        // NO sunken well. The sheet already arrives as a rounded card, and a
        // bevelled panel inside it read as two frames stacked — pointy corners
        // sitting inside round ones (founder direction 2026-08-17).
        ZStack(alignment: .top) {
            Color(hex: scheme.surface).ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: Win95.Px.grid * 3 * pixel) {
                    shortcuts
                    if monthIndex < months.count {
                        monthBlock(months[monthIndex])
                    }
                }
                .padding(Win95.Px.grid * 4 * pixel)
                // Less room under the grid than around it: the scroll view
                // already adds the home indicator's inset below, so a full
                // margin there stacks on top of one and leaves a visibly empty
                // band (founder direction 2026-08-17).
                .padding(.bottom, -(Win95.Px.grid * 2 * pixel))
                // In a BACKGROUND, never as a wrapper: a GeometryReader that
                // wraps content lays it out rather than measuring it, which is
                // how four screens once lost their headers under the status bar.
                .background {
                    GeometryReader { proxy in
                        Color.clear
                            .task { sheetHeight = proxy.size.height + bottomSlack }
                            .onChange(of: proxy.size.height) { _, h in
                                sheetHeight = h + bottomSlack
                            }
                    }
                }
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .presentationDetents([.height(sheetHeight)])
    }

    /// Room under the grid for the home indicator, so the last week is not
    /// sitting on the bezel. Small: the scroll view contributes that inset
    /// too, and the two together were most of a blank band.
    private var bottomSlack: CGFloat { Win95.Px.grid * pixel }

    /// Stacked, not side by side — the skeu sheet has always read as a column
    /// and these are the same two answers (founder direction 2026-08-17).
    ///
    /// Both carry the row menu's arrows, which say how far along the line the
    /// task travels: `<` one step toward Today, `<<` two. The picker only ever
    /// opens on a task in Soon, so Tomorrow is one step back and Today is two —
    /// the same grammar, and the same shove, as holding a row down.
    private var shortcuts: some View {
        let tomorrow = store.calendar.date(byAdding: .day, value: 1, to: today) ?? today

        return VStack(spacing: Win95.Px.grid * 2 * pixel) {
            shortcut("<< Today", day: today)
            shortcut("< Tomorrow", day: tomorrow)
        }
    }

    private func shortcut(_ label: String, day: Date) -> some View {
        // Full button height, not compact. These two ARE the sheet's primary
        // answers, and at compact height they read as settings-row furniture
        // (founder direction 2026-08-17).
        Win95Button(action: { onPick(day) }) {
            TypedText(text: label, face: settings.face, role: .content)
                .font(W95Font.standard(pixel))
                .foregroundStyle(Win95.text)
                // Inside the label, so the bevel grows with it — a frame on the
                // outside would leave the button at its text's size.
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// The month's name between two chevrons, holding still above the grid.
    private func monthHeader(_ month: Date) -> some View {
        HStack(spacing: 0) {
            chevron(pointsLeft: true, enabled: monthIndex > 0) { monthIndex -= 1 }

            TypedText(text: DayPickerRange.title(for: month, calendar: store.calendar),
                      face: settings.face, role: .chrome)
                .font(W95Font.heading(pixel))
                .foregroundStyle(Win95.text)
                .lineLimit(1)
                .frame(maxWidth: .infinity)

            chevron(pointsLeft: false,
                    enabled: monthIndex < DayPickerRange.months - 1) { monthIndex += 1 }
        }
    }

    /// Faded rather than hidden at the ends of the range: a control that
    /// vanishes moves the month's name, and the name is what you are reading.
    private func chevron(pointsLeft: Bool, enabled: Bool,
                         step: @escaping () -> Void) -> some View {
        PixelChevron(pointsLeft: pointsLeft)
            .fill(Win95.text)
            .frame(width: Win95.Px.checkbox * pixel, height: Win95.Px.checkbox * pixel)
            .frame(width: Win95.rowHeight(pixel), height: Win95.rowHeight(pixel))
            .opacity(enabled ? 1 : 0.25)
            .contentShape(Rectangle())
            .onTapGesture {
                guard enabled else { return }
                SkeuHaptic.selection()
                step()
            }
            .accessibilityLabel(pointsLeft ? "Previous month" : "Next month")
    }

    private func monthBlock(_ month: Date) -> some View {
        VStack(alignment: .leading, spacing: Win95.Px.grid * pixel) {
            monthHeader(month)

            HStack(spacing: 0) {
                ForEach(DayPickerRange.weekdayHeaders, id: \.self) { day in
                    Text(day)
                        .font(W95Font.small(pixel))
                        .foregroundStyle(Win95.textMuted)
                        .frame(maxWidth: .infinity)
                }
            }

            let cells = DayPickerRange.grid(for: month, calendar: store.calendar)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7),
                      spacing: pixel) {
                ForEach(Array(cells.enumerated()), id: \.offset) { _, day in
                    if let day { dayCell(day) } else { Color.clear.frame(height: 1) }
                }
            }
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let isChosen = day == chosen
        // A day already gone is not a schedule, it is a mistake waiting to
        // happen — shown, so the month reads as a month, but not tappable.
        let isPast = day < today

        return Text("\(store.calendar.component(.day, from: day))")
            .font(W95Font.standard(pixel))
            .foregroundStyle(isChosen ? Color(hex: scheme.selectionText)
                                      : (isPast ? Win95.textMuted : Win95.text))
            .frame(maxWidth: .infinity)
            // Six of these stack up, so every spare pixel here is six on the
            // sheet's height. Still clear of the 44pt floor.
            .frame(height: Win95.Px.grid * 6 * pixel)
            // The 1995 way to say "this one": the selection bar, not a tick.
            .background(isChosen ? Color(hex: scheme.selectionBG) : .clear)
            .contentShape(Rectangle())
            .onTapGesture {
                guard !isPast else { return }
                SkeuHaptic.selection()
                onPick(day)
            }
            .accessibilityAddTraits(isChosen ? [.isButton, .isSelected] : .isButton)
    }
}
