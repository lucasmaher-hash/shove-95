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

    // Visual state
    @State private var isPressing = false
    @State private var dragOffset: CGFloat = 0      // horizontal, swipe
    @State private var rubberBandBuzzed = false

    // Geometry
    @State private var rowFrame: CGRect = .zero
    @State private var rowWidth: CGFloat = 390

    // Inline edit
    @State private var isEditing = false
    @State private var draft = ""
    @FocusState private var editFocused: Bool

    // Photos
    @State private var showPhotoPicker = false
    @State private var pickedItem: PhotosPickerItem?
    /// Index into task.allPhotos of the photo open in the viewer.
    @State private var viewerIndex: Int?
    /// Which thumbnail is mid press-in (the tiny open animation).
    @State private var pressedThumb: Int?
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
                            rowFrame = frame
                        }
                        .task { rowFrame = proxy.frame(in: .global) }
                }
            }
            .onAppear { dragOffset = 0 } // row identity survives tab switches
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
        .background(rowBackground)
        .photosPicker(isPresented: $showPhotoPicker, selection: $pickedItem, matching: .images)
        .onChange(of: pickedItem) { _, item in
            guard let item else { return }
            Task { @MainActor in
                if let data = try? await item.loadTransferable(type: Data.self) {
                    store.addPhoto(task, data: TaskStore.downscaledJPEG(from: data))
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
               let image = UIImage(data: task.allPhotos[index]) {
                PhotoViewer(title: task.title, image: image) {
                    // Closing stays instant (locked Q16).
                    var t = Transaction(); t.disablesAnimations = true
                    withTransaction(t) { viewerIndex = nil }
                }
                .presentationBackground(Color.black.opacity(0.55))
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
        .padding(.trailing, Win95.Px.grid * pixel)
        .frame(maxWidth: .infinity, minHeight: Win95.rowHeight(pixel))
    }

    private var title: some View {
        Text(task.title)
            .font(W95Font.standard(pixel))
            .strikethrough(task.isCompleted)
            // Colour carries one meaning: red = Important. Completed is grey.
            .foregroundStyle(task.isCompleted ? Win95.shadow
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
            .foregroundStyle(Win95.text)
            .lineLimit(1...6)
            .focused($editFocused)
            .submitLabel(.done)
            .onChange(of: editFocused) { _, focused in
                if !focused { commitEdit() }
            }
            .padding(.vertical, firstLineInset)
    }

    private var trailingColumn: some View {
        Group {
            if isEditing && !addedPhotoThisEdit {
                // Add-photo plus: a bare glyph in the theme colour, not a
                // button. One photo per edit session — the plus retires after
                // a pick and returns on the next edit.
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
        // Pinned to the first line's band, however tall the row grows.
        .frame(width: Win95.Px.grid * 8 * pixel,
               height: Win95.rowHeight(pixel), alignment: .trailing)
    }

    /// Thumbnails accumulate LEFT TO RIGHT in the order added. Tapping one
    /// presses it in briefly — you see the press — then the viewer opens
    /// (founder request 2026-08-04). Closing stays instant.
    private var photoStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Win95.Px.grid * pixel) {
                ForEach(Array(task.allPhotos.enumerated()), id: \.offset) { index, data in
                    if let image = UIImage(data: data) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: Win95.Px.thumbnail * 2 * pixel,
                                   height: Win95.Px.thumbnail * pixel)
                            .clipped()
                            .bevelSunken(pixel)
                            .scaleEffect(pressedThumb == index ? 0.92 : 1)
                            .animation(.easeOut(duration: 0.1), value: pressedThumb)
                            .contentShape(Rectangle())
                            .onTapGesture { openViewer(index) }
                            .accessibilityLabel("Photo \(index + 1), opens in a window")
                    }
                }
            }
            .padding(.leading, Win95.rowHeight(pixel) + Win95.Px.grid * pixel)
            .padding(.trailing, Win95.Px.grid * pixel)
            .padding(.bottom, Win95.Px.grid * pixel)
        }
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

    /// Tap → inline edit. Blocked on completed rows.
    private func handleTap() {
        guard !task.isCompleted, !isEditing else { return }
        draft = task.title
        isEditing = true
        addedPhotoThisEdit = false // fresh session, the plus returns
        editing.begin(task.id.uuidString, bottom: rowFrame.maxY)
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
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        menu.show(task: task, at: CGPoint(x: rowFrame.minX + Win95.Px.grid * pixel,
                                          y: rowFrame.maxY + Win95.Px.grid * pixel))
    }

    /// Swipe left = pull forward (toward Today), right = defer (toward
    /// General) — content follows the finger, matching the taskbar's order.
    private func swipeChanged(_ dx: CGFloat) {
        guard !task.isCompleted else { return }
        let direction: StepDirection = dx < 0 ? .pullOne : .deferOne
        if currentBucket.steppedOnce(direction) == nil {
            // Dead end: rubber-band + one light haptic.
            dragOffset = snapped(dx * Self.rubberResistance)
            if abs(dx) > 20, !rubberBandBuzzed {
                rubberBandBuzzed = true
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        } else {
            dragOffset = snapped(dx)
        }
    }

    private func swipeEnded(_ dx: CGFloat, velocity: CGFloat, startX: CGFloat) {
        rubberBandBuzzed = false
        guard !task.isCompleted else { return }

        let direction: StepDirection = dx < 0 ? .pullOne : .deferOne
        let runway = dx > 0 ? max(1, rowWidth - startX) : max(1, startX)
        let bar = min(rowWidth * Self.commitFraction, runway * Self.runwayFraction)
        let overThreshold = abs(dx) > bar || abs(velocity) > Self.commitVelocity
        let sameSign = (dx < 0) == (velocity < 0) || abs(velocity) < 50

        guard currentBucket.steppedOnce(direction) != nil, overThreshold, sameSign else {
            withAnimation(.spring(duration: 0.3)) { dragOffset = 0 }
            return
        }

        // Commit: slide off the edge, then the model moves and the list
        // closes the gap.
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.easeOut(duration: 0.15)) {
            dragOffset = dx < 0 ? -rowWidth * 1.2 : rowWidth * 1.2
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))
            withAnimation(.spring(duration: 0.25)) {
                store.step(task, direction: direction)
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

    private func commitEdit() {
        guard isEditing else { return }
        isEditing = false
        editing.end(task.id.uuidString)
        store.editTitle(task, to: draft) // empty draft → store reverts
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

/// Photo viewer, redesigned 2026-08-04: a floating Win95 window at ~3/4 of
/// the screen that HUGS the image — title bar with ✕ on top, image inside a
/// bevelled frame. The app stays visible behind, dimmed. Only the ✕ or the
/// dimmed background closes it; the image itself is inert. Opens after the
/// thumbnail's press-in; closes instantly.
private struct PhotoViewer: View {
    @Environment(\.pixel) private var pixel
    let title: String
    let image: UIImage
    var onClose: () -> Void

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // The dimmed background IS the close control (besides the ✕).
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onClose)

                window(maxWidth: geo.size.width * 0.75,
                       maxHeight: geo.size.height * 0.75)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .preferredColorScheme(.light)
    }

    private func window(maxWidth: CGFloat, maxHeight: CGFloat) -> some View {
        // The window wraps the image: scale to fit 3/4 of the screen, then
        // size the chrome to the image — the frame hugs, never letterboxes.
        let scale = min(maxWidth / image.size.width,
                        (maxHeight - Win95.Px.titleBar * pixel) / image.size.height)
        let fitted = CGSize(width: image.size.width * scale,
                            height: image.size.height * scale)

        return VStack(spacing: 0) {
            TitleBar(title: title, isClose: true, onSettings: onClose)
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
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
