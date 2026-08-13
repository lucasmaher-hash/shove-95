//
//  SkeuRootView.swift
//  shove95
//
//  The main screen in the skeu look, rebuilt from the founder's frame (shove95
//  file, node 2:609) in light brown.
//
//  That frame is 1495 × 3250 — an iPhone layout drawn at 3.72×. Every number
//  in `F` is its value times 402/1495, with the source value alongside so any
//  of them can be checked against the file.
//
//  STEP 3: the list between the bars is live — real tasks from the store,
//  completion toggles, and an add row. Swipes, the row menu, photos and date
//  chips are still Win95-only and follow in later steps.
//
//  Row construction follows the founder's established language rather than the
//  design-system §9.6 slat: a task is a TROUGH cut into the ground (the same
//  channel the bars use), its checkbox a glass circle lying in it — subdued
//  while open, prominent once done. One vocabulary for the whole screen.
//

import SwiftUI
import PhotosUI
import Shove95Kit

private enum F {
    /// 402pt of phone over 1495pt of frame.
    static let s: CGFloat = 402.0 / 1495.0

    /// Founder direction (2026-08-14): the menu/settings gear read too small
    /// next to the close ✕ used everywhere else in this look (a flat 37pt in
    /// SkeuSettingsView and SkeuSecondaryScreens). Rather than bump `plus`
    /// alone and leave it looking oversized against its neighbours, every
    /// button/toggle/row token below scales by the same ratio — including
    /// font sizes and the glass "bloom" shading, both of which are already
    /// parametrized off these values, so they grow in proportion for free.
    static let scaleUp: CGFloat = 37 / (107.444 * s)

    /// ONE margin on every side. The frame itself is uneven — 28.0 leading,
    /// 46.2 trailing, 21.5 below — which reads as a bar pushed off-centre
    /// rather than as a deliberate inset. The smallest of the three wins.
    /// Page-edge inset, not a button/toggle — left out of the scale-up.
    static let margin = 21.5

    /// The workspace/tab bars sit INSIDE the safe area, so the old code's
    /// `.padding(.vertical, margin)` stacked a full second margin on top of
    /// whatever the Dynamic Island and home indicator already reserve — far
    /// more room above the workspace bar and below the tab bar than beside
    /// them (founder bug report 2026-08-14). This is the smaller, VERTICAL-
    /// ONLY margin that replaces it: just the breathing room beyond the
    /// mandatory safe-area clearance, pushing both bars toward their
    /// physical top/bottom edges, on device — to about where Apple Notes
    /// sits its own toolbars.
    ///
    /// Horizontal stays on `margin` for every bar, workspace included — an
    /// earlier pass here also swapped the workspace bar's LEFT/RIGHT inset
    /// to this smaller value, which reads fine on the simulator but jams the
    /// pill into the corner on a real device's rounded edge (founder bug
    /// report 2026-08-14, second round). Vertical and horizontal insets
    /// answer different physical constraints — a notch and a corner radius —
    /// and conflating them was the bug.
    ///
    /// ZERO is deliberate, measured off Apple Notes at the founder's request
    /// (2026-08-14, third round): Notes puts its top toolbar's upper edge at
    /// ~55pt against a ~59pt top inset, and its bottom toolbar's lower edge
    /// at ~836pt against an ~840pt bottom boundary. In other words it adds no
    /// margin of its own — the safe area IS the margin, and the toolbars ride
    /// right on it. Anything above zero here reads as the bars floating short
    /// of the edge, which is exactly what kept getting flagged.
    static let marginNotch = 0.0

    /// The TOP needs to go slightly negative to land where Notes lands, and
    /// the bottom does not — hence a second constant rather than one shared
    /// value. At `marginNotch = 0` the bottom bar already sits ~842pt against
    /// an ~840pt boundary (matched), but the top bar can only reach ~66pt,
    /// because the top safe-area inset is ~59pt and the bar's own glass bloom
    /// eats the rest. Notes clears ~55pt by drawing INTO that inset, so this
    /// lifts by the difference. Small on purpose: the status bar's own glyphs
    /// sit above this line, and a larger lift would run the pill into them.
    static let marginTopLift = -8.0

    // Workspace bar — node 2:655, positioned by 2:654
    static let topHeight = 145.8 * s * scaleUp        // 39.2 → 50.2
    static let gapTop = 54 * s * scaleUp              // 14.5 → 18.5

    // Tab bar — node 2:639
    static let bottomHeight = 148.2 * s * scaleUp     // 39.9 → 51.1

    // Shared trough padding — nodes 2:639 / 2:655
    static let padLead = 71.313 * s * scaleUp         // 19.2 → 24.6
    static let padTrail = 20.617 * s * scaleUp        // 5.5 → 7.1

    // Glass pill — node 2:657
    static let glassPadH = 35.656 * s * scaleUp       // 9.6 → 12.3
    static let glassPadV = 23.771 * s * scaleUp       // 6.4 → 8.2
    static let glassGap = 29.714 * s * scaleUp        // 8.0 → 10.2
    static let icon = 59.427 * s * scaleUp            // 16.0 → 20.5
    static let label = 47.542 * s * scaleUp           // 12.8 → 16.4

    // Round glass button — node 2:665
    static let plus = 107.444 * s * scaleUp           // 28.9 → 37 (matches the ✕)
    static let plusIcon = 53.722 * s * scaleUp        // 14.4 → 18.5

    /// The workspace pill and the settings gear ONLY: +20%, font included
    /// (founder direction 2026-08-14). Applied at those two call sites rather
    /// than folded into the tokens above, because `plus`/`plusIcon` are also
    /// worn by the camera glyphs and `label`/`glassPad*` by the tab bar —
    /// none of which are meant to grow with the top bar.
    static let topControlScale: CGFloat = 1.2

    // Bloom behind each trough — nodes 2:653 / 2:610
    static let bloomBlur = 5.381 * s * scaleUp        // 1.45 → 1.85
    /// ONE overhang, not the frame's two (40 wide / 15.4 tall): the uneven
    /// halo pooled at the ends and pinched at the edges. The vertical wins.
    static let bloomOverhang = 15.4 * s * scaleUp     // 4.1 → 5.3

    // Task rows — no frame reference yet; sized against the bars.
    static let rowHeight: CGFloat = 44 * scaleUp      // 56.3
    static let rowGap: CGFloat = 2 * scaleUp          // 2.6
    static let check: CGFloat = 26 * scaleUp          // 33.3
    /// Photo thumbnail — the Win95 side's 64pt spec size (TASK-045), scaled
    /// up with everything else so it doesn't read small next to a bigger row.
    static let thumb: CGFloat = 64 * scaleUp          // 82.0
}

struct SkeuRootView: View {
    @Environment(\.skeu) private var skeu
    @Environment(\.pixel) private var pixel
    @Environment(AppSettings.self) private var settings
    @Environment(SyncStatus.self) private var sync
    @Environment(TaskStore.self) private var store

    @State private var showSettings = false
    @State private var bucket: Bucket = .today
    @State private var draft = ""
    @FocusState private var addFocused: Bool
    @State private var menu = MenuCoordinator()
    /// How much of the list the keyboard is covering, in points.
    @State private var keyboardOverlap: CGFloat = 0

    /// The tab bar's glass pill glides from the old selection to the new one
    /// instead of popping in fresh each time (founder direction 2026-08-14).
    @Namespace private var tabPillNS

    // The workspace pill's open/closed flag deliberately does NOT live here —
    // see SkeuWorkspacePill for why keeping it out of the root's state is
    // what makes opening the menu cheap.

    // Photo attach from the add row. NOT the Win95 AddRowView flow — that one
    // commits the draft the moment ✚ is pressed and then targets the fresh
    // task, which reads as "my editing just ended and a photo menu opened for
    // something else" (founder bug report 2026-08-13). Here the picked photos
    // are BUFFERED alongside the draft and attach when the task is actually
    // committed, so taking a photo is part of composing, not the end of it.
    @State private var showPhotoPicker = false
    @State private var showCamera = false
    @State private var showSourceChoice = false
    @State private var pickedItem: PhotosPickerItem?
    @State private var pendingPhotos: [Data] = []

    var body: some View {
        ZStack {
            skeu.canvas.ignoresSafeArea()

            VStack(spacing: 0) {
                workspaceBar
                    .padding(.horizontal, F.margin)
                    .padding(.top, F.marginTopLift)
                taskList
                    .padding(.horizontal, F.margin)
                    // The undo panel FLOATS over the list rather than taking
                    // layout space, so it can come and go without shifting the
                    // rows — and it sits above the tab bar, not inside it.
                    .overlay(alignment: .bottom) { undoPanel }
                tabBar
                    .padding(.horizontal, F.margin)
                    .padding(.bottom, F.marginNotch)
            }
        }
        // The bars are furniture: they stay put while the keyboard is up, the
        // same rule the Win95 root follows for its taskbar.
        .ignoresSafeArea(.keyboard, edges: .bottom)
        // The row menu draws above everything, unclipped by the scroll view.
        .overlay { SkeuMenuOverlay() }
        .environment(menu)
        // The store's queries are scoped to the active workspace. The Win95
        // root does this sync when IT is mounted; in skeu mode this view is
        // the one that has to keep the scope pointed at the user's pick.
        .onAppear {
            store.seedWorkspacesIfNeeded(legacy: settings.legacyWorkspaces)
            syncWorkspaceScope()
        }
        .onChange(of: settings.currentWorkspaceID) { syncWorkspaceScope() }
        .onChange(of: store.revision) { syncWorkspaceScope() }
        .fullScreenCover(isPresented: $showSettings) {
            // Wrapped in the magnifier so the panels can be inspected like the
            // rest of the look. Switching design to Windows 95 in there removes
            // THIS view from AppShell, which tears the cover down and lands on
            // the Win95 root — exactly the right behaviour, free of charge.
            ZoomInspector {
                SkeuSettingsView { showSettings = false }
            }
        }
    }

    // MARK: Workspace bar — node 2:654

    private var workspaceBar: some View {
        HStack(alignment: .top, spacing: 0) {
            SkeuWorkspacePill()

            Spacer(minLength: SkeuSpace.sm)

            // The gear stands in for the frame's ✚ — this screen still has to
            // reach Settings, and there is nowhere else yet.
            Button { showSettings = true } label: {
                let size = F.plus * F.topControlScale
                Image(systemName: "gearshape")
                    .font(.system(size: F.plusIcon * F.topControlScale, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(skeu.ink)
                    .frame(width: size, height: size)
                    .skeuGlass(Circle(), height: size)
            }
            .buttonStyle(.plain)
            .frame(minWidth: SkeuControl.minTouch, minHeight: SkeuControl.minTouch)
            .accessibilityLabel("Settings")
        }
    }

    // MARK: Task list

    private var taskList: some View {
        let (active, completed) = store.tasks(in: bucket)

        // ScrollView, not List — List eats the horizontal pans the app's core
        // swipe will need (the TASK-019 spike finding; same reason as Win95).
        return ScrollView {
            LazyVStack(spacing: F.rowGap) {
                // No empty-state text: the add row's own "add" placeholder
                // already says the list is empty and where to start.
                ForEach(active, id: \.id) { task in
                    taskRow(task)
                }

                if !completed.isEmpty {
                    Color.clear.frame(height: F.rowGap)
                    ForEach(completed, id: \.id) { task in
                        taskRow(task)
                    }
                }

                addRow
            }
            .padding(.vertical, SkeuSpace.lg)
        }
        .scrollDismissesKeyboard(.interactively)
        // The give at the limit is what tells you the list ended.
        .scrollBounceBehavior(.always, axes: .vertical)
        // The list carries its own bottom inset so the keyboard has somewhere
        // to sit. `.ignoresSafeArea(.keyboard)` above keeps the BARS docked,
        // and that same modifier is why automatic field-avoidance never fires
        // here — this inset replaces it.
        .contentMargins(.bottom, keyboardOverlap, for: .scrollContent)
        .onReceive(NotificationCenter.default.publisher(
            for: UIResponder.keyboardWillChangeFrameNotification)) { note in
            guard let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey]
                as? CGRect else { return }
            let screenHeight = (note.object as? UIScreen)?.bounds.height
                ?? UIApplication.shared.connectedScenes
                    .compactMap { ($0 as? UIWindowScene)?.screen.bounds.height }
                    .first ?? frame.maxY
            // What the keyboard covers, minus the chrome already parked down
            // there: only the part that eats into the list matters.
            let covered = max(0, screenHeight - frame.origin.y)
            let chrome = F.bottomHeight + F.margin * 2
            withAnimation(.easeOut(duration: 0.25)) {
                keyboardOverlap = max(0, covered - chrome)
            }
        }
    }

    /// One task row. A separate STRUCT, not a helper function, and that is
    /// load-bearing: inside a LazyVStack the model reads must happen in the
    /// row's own body, or the row belongs to the parent's observation scope
    /// and keeps its stale look after a toggle — the task moved to the
    /// completed section but kept rendering unchecked (caught on device
    /// 2026-08-13). Same reason the Win95 side has TaskRowView.
    private func taskRow(_ task: TaskItem) -> some View {
        SkeuTaskRow(task: task)
    }

    /// The add row: a plain row like the tasks themselves — an unchecked
    /// circle and a faded "add" beside it, no frame (founder direction
    /// 2026-08-13). The commit ＋ only exists while the field is being edited,
    /// the same way the existing rows grow their controls in edit mode.
    private var addRow: some View {
        HStack(spacing: F.glassGap) {
            ZStack {}
                .frame(width: F.check, height: F.check)
                .skeuGlass(Circle(), height: F.check, prominent: false)
                .frame(width: SkeuControl.minTouch, height: SkeuControl.minTouch)
                .contentShape(Rectangle())
                .onTapGesture { addFocused = true }

            TextField("", text: $draft,
                      prompt: Text("add").foregroundStyle(skeu.inkFaint))
                .font(.system(size: F.label))
                .foregroundStyle(skeu.ink)
                .focused($addFocused)
                .submitLabel(.done)
                .onSubmit(commitAdd)

            // Photos picked mid-composition wait here, visibly, until commit.
            ForEach(Array(pendingPhotos.enumerated()), id: \.offset) { _, data in
                if let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: F.check, height: F.check)
                        .clipShape(RoundedRectangle(cornerRadius: SkeuRadius.xs,
                                                    style: .continuous))
                }
            }

            if addFocused {
                Button {
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        showSourceChoice = true
                    } else {
                        showPhotoPicker = true
                    }
                } label: {
                    // A BARE glyph — no glass circle behind it (founder
                    // direction 2026-08-14). It keeps the full-size frame so
                    // the tap target stays honest; only the surface is gone.
                    Image(systemName: "camera")
                        .font(.system(size: F.plusIcon, weight: .medium))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(skeu.ink)
                        .frame(width: F.plus, height: F.plus)
                }
                .buttonStyle(.plain)
                .transition(.scale(scale: 0.6).combined(with: .opacity))
                .accessibilityLabel("Add photo to new task")
            }
        }
        .padding(.leading, SkeuSpace.xs)
        .padding(.trailing, F.padTrail)
        .frame(minHeight: F.rowHeight)
        .animation(SkeuMotion.press, value: addFocused)
        .photosPicker(isPresented: $showPhotoPicker, selection: $pickedItem, matching: .images)
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { data in
                showCamera = false
                guard let data, let prepared = ImageImport.prepare(data) else { return }
                pendingPhotos.append(prepared)
            }
            .ignoresSafeArea()
        }
        // The one system sheet worth keeping — same reasoning as the Win95 row.
        .confirmationDialog("Add photo", isPresented: $showSourceChoice) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Camera") { showCamera = true }
            }
            Button("Photo Library") { showPhotoPicker = true }
            Button("Cancel", role: .cancel) {}
        }
        .onChange(of: pickedItem) { _, item in
            guard let item else { return }
            Task { @MainActor in
                if let data = try? await item.loadTransferable(type: Data.self),
                   let prepared = ImageImport.prepare(data) {
                    pendingPhotos.append(prepared)
                }
                pickedItem = nil
            }
        }
    }

    private func commitAdd() {
        // Buffered photos attach HERE, to the task the user was composing —
        // not to some fresh context the moment the camera was pressed.
        if let task = store.addTask(title: draft, in: bucket) {
            for data in pendingPhotos {
                store.addPhoto(task, data: data)
            }
            pendingPhotos = []
        }
        draft = ""
        // Keyboard dismisses on commit: a field that stays open reads as
        // "still typing" and hides the list you just added to.
        addFocused = false
    }

    // MARK: Undo

    /// Appears only when there is a last action to report, and retires itself
    /// after six seconds — any further mutation restarts the clock. Built as a
    /// trough with a glass Undo pill, the same vocabulary as the bars.
    @ViewBuilder
    private var undoPanel: some View {
        if let action = store.lastAction {
            HStack(spacing: F.glassGap) {
                Text(action.statusText(name: settings.name))
                    .font(.system(size: F.label))
                    .foregroundStyle(skeu.ink)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("Undo")
                    .font(.system(size: F.label, weight: .medium))
                    .foregroundStyle(skeu.ink)
                    .lineLimit(1)
                    .padding(.horizontal, F.glassPadH)
                    .frame(height: 30)
                    .skeuGlass(Capsule(), height: 30)
                    .contentShape(Capsule())
                    .onTapGesture {
                        SkeuHaptic.press()
                        withAnimation(SkeuMotion.layout) { store.undoLastAction() }
                    }
                    .accessibilityLabel("Undo last action")
                    .accessibilityAddTraits(.isButton)
            }
            .padding(.leading, F.padLead)
            .padding(.trailing, SkeuSpace.sm)
            .frame(height: 46)
            .skeuTrough(Capsule(), height: 46)
            .padding(.bottom, SkeuSpace.sm)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            // Retires itself; any further mutation restarts the clock.
            .task(id: store.revision) {
                try? await Task.sleep(for: .seconds(6))
                if !Task.isCancelled {
                    withAnimation(SkeuMotion.layout) { store.dismissLastAction() }
                }
            }
        }
    }

    // MARK: Tab bar — node 2:639

    private var tabBar: some View {
        // `symmetric: true`: the frame's own trough padding is uneven (19.2
        // leading / 5.5 trailing), which read as the whole row sitting closer
        // to General than to Today (founder bug report 2026-08-14). The tab
        // bar is a fully centred four-up toggle, not a positioned frame
        // element, so it gets equal breathing room on both sides instead.
        trough(height: F.bottomHeight, spacing: 0, symmetric: true) {
            // Equal-width columns, not the frame's fixed 122.79 gap or a
            // Spacer-packed row: either of those lets the group drift off
            // whichever side has the bigger neighbour, and the label inside
            // a variable-width slot never sits dead-centre. A fixed column
            // per tab centres every label in its own quarter of the bar
            // (founder direction 2026-08-14) — the ✕-matching icon that used
            // to ride along with the selected label is gone for the same
            // reason: text is the whole tab now, so it can own the centre.
            //
            // Every label is laid out IDENTICALLY whether or not it is the
            // selected one — same font, same padding, same centred column —
            // so no text can shift when the selection moves. The glass is a
            // BACKGROUND that only the selected column carries, and the
            // matched-geometry id rides on that background alone. Putting the
            // effect on the whole label instead (the first attempt) animated
            // the text across with the pill; the founder's note was that the
            // words should hold still and only the lens should travel
            // (2026-08-14).
            let pillHeight = F.bottomHeight - F.glassPadV * 2
            ForEach(Bucket.line, id: \.self) { line in
                Text(settings.name(for: line))
                    .font(.system(size: F.label))
                    .tracking(-0.02 * F.label)
                    .foregroundStyle(skeu.ink)
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.horizontal, F.glassPadH)
                    .padding(.vertical, F.glassPadV)
                    .background {
                        if bucket == line {
                            Color.clear
                                .skeuGlass(Capsule(), height: pillHeight)
                                .matchedGeometryEffect(id: "tabPill", in: tabPillNS)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        SkeuHaptic.selection()
                        withAnimation(SkeuMotion.layout) { bucket = line }
                    }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Pieces

    /// The channel both bars are cut into, with the soft bloom that seats it
    /// in the ground: light over dark, opposite the trough's own fill, so the
    /// bar sits in a shallow dish rather than on flat paint.
    private func trough<C: View>(height: CGFloat,
                                 spacing: CGFloat,
                                 symmetric: Bool = false,
                                 @ViewBuilder content: () -> C) -> some View {
        HStack(spacing: spacing) {
            content()
        }
        .padding(.leading, symmetric ? (F.padLead + F.padTrail) / 2 : F.padLead)
        .padding(.trailing, symmetric ? (F.padLead + F.padTrail) / 2 : F.padTrail)
        .frame(height: height)
        .skeuTrough(Capsule(), height: height)
        .background {
            Capsule()
                .fill(LinearGradient(colors: [skeu.recessBottom, skeu.recess],
                                     startPoint: .top, endPoint: .bottom))
                .padding(-F.bloomOverhang)
                .blur(radius: F.bloomBlur)
                .allowsHitTesting(false)
        }
    }

    // `plainLabel` / `glassLabel` lived here until 2026-08-14. The workspace
    // bar stopped using them when it became a dropdown, and the tab bar
    // stopped when its glass moved into a background layer so the text could
    // hold still — at which point a "selected" and an "unselected" spelling
    // of the same label were the very thing causing the drift.

    /// Points the store's queries at the selected workspace — the same logic
    /// the Win95 root runs, minus its scheme adoption (skeu themes are local).
    private func syncWorkspaceScope() {
        let all = store.workspaces()
        let ids = Set(all.compactMap(\.taskStampID))
        if store.knownWorkspaceIDs != ids { store.knownWorkspaceIDs = ids }
        if !all.contains(where: { $0.id == settings.currentWorkspaceID }) {
            settings.currentWorkspaceID = Workspace.defaultID
        }
        let stamp = all.first { $0.id == settings.currentWorkspaceID }?.taskStampID
        if store.workspaceID != stamp { store.workspaceID = stamp }
    }
}

// MARK: - Workspace switcher

/// The workspace switcher: the Win95 mechanism (a title, a ▼, a mini menu)
/// translated into this look's own vocabulary instead of copying its floating
/// panel — the CURRENT workspace stays living in the glass pill, and tapping
/// it or the chevron grows that same pill straight down into a short list of
/// the others (founder direction 2026-08-14). Nothing detaches from the
/// control the way the Win95 dropdown detaches from the title bar; the pill
/// itself is the menu.
///
/// A separate STRUCT, not a helper property on SkeuRootView, and that is
/// load-bearing — the same lesson SkeuTaskRow records. The open/closed flag
/// used to be `@State` on the ROOT, so every toggle invalidated the root's
/// whole body: `store.tasks(in:)` re-ran (a fetch, a sort, three filters),
/// `store.workspaces()` re-ran (a fetch, a dedup, a sort), and every task row
/// was rebuilt — all to expand one pill. That is what made opening the menu
/// crawl (founder bug report 2026-08-14). Owning the flag here keeps the
/// invalidation inside this small subtree.
private struct SkeuWorkspacePill: View {
    @Environment(AppSettings.self) private var settings
    @Environment(TaskStore.self) private var store

    @State private var isOpen = false

    var body: some View {
        let workspaces = store.workspaces()
        let current = workspaces.first { $0.id == settings.currentWorkspaceID }
        let others = workspaces.filter { $0.id != settings.currentWorkspaceID }
        // Everything in here rides the same +20% as the gear, font included,
        // so the pill grows as one piece instead of a bigger box around
        // unchanged text.
        let scale = F.topControlScale
        let label = F.label * scale
        let rowHeight = (F.topHeight - F.glassPadV * 2) * scale

        return VStack(alignment: .leading, spacing: 0) {
            Button {
                SkeuHaptic.selection()
                withAnimation(SkeuMotion.layout) { isOpen.toggle() }
            } label: {
                HStack(spacing: F.glassGap * scale) {
                    Text(current?.name ?? "")
                        .font(.system(size: label))
                        .tracking(-0.02 * label)
                        .lineLimit(1)
                        .fixedSize()

                    // Two strokes, nothing else — no circle, no glass of its
                    // own. It rides inside the pill it controls, the same way
                    // the Win95 ▼ rides inside the title bar it controls.
                    ChevronGlyph()
                        .stroke(Color.white,
                                style: StrokeStyle(lineWidth: 1.6 * scale, lineCap: .round))
                        .frame(width: label * 0.55, height: label * 0.32)
                        .rotationEffect(.degrees(isOpen ? 180 : 0))
                }
                .foregroundStyle(.white)
                .frame(height: rowHeight)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Workspace: \(current?.name ?? "")")
            .accessibilityHint("Opens the workspace list")

            if isOpen {
                ForEach(others, id: \.id) { workspace in
                    Text(workspace.name)
                        .font(.system(size: label))
                        .tracking(-0.02 * label)
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(1)
                        // Full pill width, not `.fixedSize()` — the row has to
                        // be tappable across the whole pill, not just where
                        // the glyphs happen to fall.
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(height: rowHeight)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            SkeuHaptic.selection()
                            withAnimation(SkeuMotion.layout) {
                                settings.currentWorkspaceID = workspace.id
                                isOpen = false
                            }
                        }
                        .accessibilityAddTraits(.isButton)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .padding(.horizontal, F.glassPadH * scale)
        .frame(minWidth: SkeuControl.minTouch * 1.6, alignment: .leading)
        .fixedSize(horizontal: true, vertical: false)
        .skeuGlass(RoundedRectangle(cornerRadius: rowHeight / 2, style: .continuous),
                   height: rowHeight)
    }
}

/// A bare ⌄ — two strokes meeting at a point, drawn rather than pulled from
/// SF Symbols so it reads as exactly two lines and nothing rounder.
private struct ChevronGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return path
    }
}

// MARK: - Task row

/// See the comment at `taskRow(_:)` for why this is its own view.
///
/// The touch layer is the SAME state machine the Win95 row uses —
/// RowGestureView, with the swipe physics transcribed from TaskRowView. The
/// machine is UIKit and look-agnostic; only two things differ here: no
/// pixel-grid snapping of the drag (the skeu look has no pixel grid), and the
/// press reads as the skeu scale-down rather than a tint.
private struct SkeuTaskRow: View {
    @Environment(\.skeu) private var skeu
    @Environment(TaskStore.self) private var store
    @Environment(MenuCoordinator.self) private var menu
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let task: TaskItem

    @State private var isPressing = false
    @State private var dragOffset: CGFloat = 0
    @State private var rubberBandBuzzed = false
    @State private var rowFrame: CGRect = .zero
    @State private var rowWidth: CGFloat = 390

    // Inline edit
    @State private var isEditing = false
    @State private var draft = ""
    @FocusState private var editFocused: Bool

    // Photos
    @State private var showPhotoPicker = false
    @State private var showCamera = false
    @State private var showSourceChoice = false
    @State private var pickedItem: PhotosPickerItem?
    /// Index into task.allPhotos of the photo open in the viewer.
    @State private var viewerIndex: Int?
    /// Which thumbnail is mid press-in (the tiny open animation).
    @State private var pressedThumb: Int?
    /// One photo per edit session: the camera retires after a pick and returns
    /// the next time the row enters edit mode.
    @State private var addedPhotoThisEdit = false

    // Swipe commit thresholds — TaskRowView's values verbatim; they are
    // interaction physics, not styling, and the two looks must FEEL identical.
    private static let commitFraction: CGFloat = 0.22
    private static let runwayFraction: CGFloat = 0.5
    private static let commitVelocity: CGFloat = 300
    private static let rubberResistance: CGFloat = 0.3

    var body: some View {
        row
            .offset(x: dragOffset)
            // §8.5: Reduce Motion drops the SCALE but keeps the depth cue —
            // the depth change is the affordance, not decoration. The swipe's
            // own translation is the gesture itself and always follows.
            .scaleEffect(reduceMotion ? 1 : (isPressing ? 0.97 : 1), anchor: .center)
            .animation(reduceMotion ? SkeuMotion.tint : SkeuMotion.press, value: isPressing)
            // Touch sandwich: the catcher sits below the content, so the
            // checkbox's own tap gesture wins its touches and everything else
            // lands in the state machine.
            .background(RowGestureView(handlers: handlers))
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
            .photosPicker(isPresented: $showPhotoPicker, selection: $pickedItem, matching: .images)
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker { data in
                    showCamera = false
                    guard let data, let prepared = ImageImport.prepare(data) else { return }
                    store.addPhoto(task, data: prepared)
                    addedPhotoThisEdit = true
                }
                .ignoresSafeArea()
            }
            .confirmationDialog("Add photo", isPresented: $showSourceChoice) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button("Camera") { showCamera = true }
                }
                Button("Photo Library") { showPhotoPicker = true }
                Button("Cancel", role: .cancel) {}
            }
            .onChange(of: pickedItem) { _, item in
                guard let item else { return }
                Task { @MainActor in
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let prepared = ImageImport.prepare(data) {
                        store.addPhoto(task, data: prepared)
                        addedPhotoThisEdit = true // the camera retires this session
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
                    SkeuPhotoViewer(image: image) { viewerIndex = nil }
                }
            }
    }

    private var currentBucket: Bucket {
        task.bucket(now: store.now(), calendar: store.calendar)
    }

    private var handlers: RowGestureHandlers {
        RowGestureHandlers(
            onPressChanged: { isPressing = $0 },
            onTap: handleTap,
            onHold: {
                guard !isEditing else { return }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                menu.show(task: task, rowFrame: rowFrame)
            },
            onSwipeChanged: swipeChanged,
            onSwipeEnded: swipeEnded,
            onSwipeCancelled: swipeCancelled
        )
    }

    /// Routes a tap by WHERE it landed: a thumbnail opens the viewer, anything
    /// else starts an edit. Geometry rather than gestures — the thumbnails are
    /// hit-transparent on purpose, because a photo with its own tap gesture
    /// swallows the whole touch and swiping across it moves nothing.
    private func handleTap(at point: CGPoint) {
        let local = CGPoint(x: point.x - rowFrame.minX, y: point.y - rowFrame.minY)
        if let index = photoIndex(at: local) {
            openViewer(index)
            return
        }
        guard !task.isCompleted, !isEditing else { return }
        draft = task.title
        isEditing = true
        addedPhotoThisEdit = false // fresh session, the camera returns
        // Focus must land AFTER the TextField exists — setting it in the same
        // pass that creates the field is a race.
        Task { @MainActor in editFocused = true }
    }

    private func commitEdit() {
        guard isEditing else { return }
        isEditing = false
        store.editTitle(task, to: draft) // empty draft → store reverts
    }

    /// Return commits instead of adding a line: a vertical-axis TextField
    /// inserts a newline rather than firing onSubmit, so it is intercepted in
    /// the binding — before it lands — and the focus change is deferred a
    /// runloop turn (inline it runs mid-update and SwiftUI drops it).
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
        let stripHeight = F.thumb + SkeuSpace.sm
        // The strip is always the bottom band, whatever height the title grew to.
        guard local.y > rowFrame.height - stripHeight else { return nil }

        let leading = SkeuControl.minTouch + F.glassGap
        guard local.x >= leading else { return nil }
        let index = Int((local.x - leading) / (F.thumb + SkeuSpace.sm))
        // Reject the gaps between thumbnails.
        let withinThumb = (local.x - leading)
            .truncatingRemainder(dividingBy: F.thumb + SkeuSpace.sm) <= F.thumb
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

    /// Swipe left = pull forward (toward Today), right = defer (toward
    /// General) — content follows the finger, matching the tab bar's order.
    private func swipeChanged(_ dx: CGFloat) {
        guard !task.isCompleted else { return }
        let direction: StepDirection = dx < 0 ? .pullOne : .deferOne
        if currentBucket.steppedOnce(direction) == nil {
            // Dead end: rubber-band + one light haptic.
            dragOffset = dx * Self.rubberResistance
            if abs(dx) > 20, !rubberBandBuzzed {
                rubberBandBuzzed = true
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        } else {
            dragOffset = dx
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
                _ = store.step(task, direction: direction) // destination unused here
            }
            dragOffset = 0 // row identity survives the move
        }
    }

    private func swipeCancelled() {
        rubberBandBuzzed = false
        guard dragOffset != 0 else { return }
        withAnimation(.spring(duration: 0.3)) { dragOffset = 0 }
    }

    private var row: some View {
        VStack(alignment: .leading, spacing: 0) {
            mainLine
            if !task.allPhotos.isEmpty {
                photoStrip
            }
        }
    }

    private var mainLine: some View {
        // .top: the checkbox belongs on the FIRST line of a wrapped task.
        HStack(alignment: .top, spacing: F.glassGap) {
            // onTapGesture rather than Button, deliberately: an UNCHECKED box
            // is an empty ZStack whose glass layers all carry
            // .allowsHitTesting(false), and a Button over that content never
            // fired on device even with an explicit contentShape (2026-08-13).
            // The tap gesture with its own contentShape is the pattern every
            // other tappable in this screen already uses.
            ZStack {
                if task.isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(skeu.ink)
                }
            }
            .frame(width: F.check, height: F.check)
            .skeuGlass(Circle(), height: F.check, prominent: task.isCompleted)
            // §3.3 minimum target: the gesture owns the full 44pt square.
            .frame(width: SkeuControl.minTouch, height: SkeuControl.minTouch)
            .contentShape(Rectangle())
            .onTapGesture {
                SkeuHaptic.toggle()
                withAnimation(SkeuMotion.press) { store.toggleCompleted(task) }
            }
            .accessibilityLabel(task.isCompleted ? "Completed" : "Not completed")
            .accessibilityAddTraits(.isButton)

            if isEditing {
                // Wraps by itself as the text grows — the only way a task
                // gains a line. Return commits (intercepted in the binding).
                TextField("", text: returnCommitting, axis: .vertical)
                    .font(.system(size: F.label))
                    .tracking(-0.02 * F.label)
                    // Important stays red while you edit it — the flag doesn't
                    // pause because the caret is in the field.
                    .foregroundStyle(task.isImportant ? skeu.critical : skeu.ink)
                    .lineLimit(1...6)
                    .focused($editFocused)
                    .submitLabel(.done)
                    .onChange(of: editFocused) { _, focused in
                        if !focused { commitEdit() }
                    }
                    .frame(minHeight: F.rowHeight)
            } else {
                Text(task.title)
                    .font(.system(size: F.label))
                    .tracking(-0.02 * F.label)
                    // Important stays red in EVERY look — colour carries
                    // exactly one meaning, the rule the Win95 side enforces.
                    .foregroundStyle(task.isImportant && !task.isCompleted
                                     ? skeu.critical
                                     : (task.isCompleted ? skeu.inkMuted : skeu.ink))
                    .strikethrough(task.isCompleted, color: skeu.inkMuted)
                    .fixedSize(horizontal: false, vertical: true) // wraps, never truncates
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(minHeight: F.rowHeight)
                    .allowsHitTesting(false) // the ROW owns tap-to-edit
            }

            // Trailing column: the camera while editing, otherwise the overdue
            // chip. Pinned to the first line's band however tall the row grows.
            if isEditing && !addedPhotoThisEdit {
                // One photo per session, matching the Win95 row.
                // Bare glyph, no glass circle — see the add row's camera.
                Image(systemName: "camera")
                    .font(.system(size: F.plusIcon, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(skeu.ink)
                    .frame(width: F.plus, height: F.plus)
                    .frame(width: SkeuControl.minTouch, height: F.rowHeight)
                    .contentShape(Rectangle())
                    .onTapGesture { chooseSource() }
                    .accessibilityLabel("Add photo")
            } else if let chip = ChipFormat.label(dueDate: task.dueDate,
                                                  isCompleted: task.isCompleted,
                                                  now: store.now(),
                                                  calendar: store.calendar) {
                // A glass lozenge, not a flat tinted block: in this look every
                // object earns its presence from light. Hit-transparent, like
                // the title and the thumbnails — the row owns the touch.
                Text(chip)
                    .font(.system(size: F.label * 0.85, weight: .medium))
                    .foregroundStyle(skeu.ink)
                    .padding(.horizontal, SkeuSpace.sm)
                    .frame(height: 24)
                    .skeuGlass(Capsule(), height: 24)
                    .frame(height: F.rowHeight)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true) // the row's label already says it
            }
        }
        // NO surface. A task is plain text on the ground, exactly as in the
        // Win95 look (founder direction 2026-08-13) — only the checkbox is an
        // object. The troughs are reserved for chrome: bars, inputs, panels.
        .padding(.leading, SkeuSpace.xs)
        .padding(.trailing, F.padTrail)
        .frame(minHeight: F.rowHeight)
    }

    /// Thumbnails accumulate left to right in the order added. Tapping one
    /// presses it in briefly — you see the press — then the viewer opens.
    ///
    /// A plain HStack, NOT a horizontal ScrollView: a nested scroll view owns
    /// horizontal pans, so swiping across a photo would move nothing while
    /// swiping across the text moved the task.
    private var photoStrip: some View {
        HStack(spacing: SkeuSpace.sm) {
            ForEach(Array(task.allPhotos.enumerated()), id: \.offset) { index, data in
                if let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: F.thumb, height: F.thumb)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: SkeuRadius.sm,
                                                    style: .continuous))
                        .overlay {
                            // The photo is a carved-in inlay: the same inverted
                            // lighting the troughs use, so it reads as set into
                            // the ground rather than laid on it.
                            RoundedRectangle(cornerRadius: SkeuRadius.sm, style: .continuous)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [skeu.outline, skeu.outlineBottom],
                                        startPoint: .top, endPoint: .bottom),
                                    lineWidth: 1.5)
                        }
                        .scaleEffect(pressedThumb == index ? 0.92 : 1)
                        .animation(.easeOut(duration: 0.1), value: pressedThumb)
                        // Hit-transparent, exactly like the title: a foreground
                        // view with its own tap gesture takes the whole touch,
                        // and swiping across a photo would move nothing. The
                        // catcher behind owns every touch; taps route by region.
                        .allowsHitTesting(false)
                        .accessibilityLabel("Photo \(index + 1), opens full screen")
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.leading, SkeuControl.minTouch + F.glassGap)
        .padding(.trailing, F.padTrail)
        .padding(.bottom, SkeuSpace.sm)
    }
}

// MARK: - Photo viewer

/// Full-screen photo. The Win95 side wraps its viewer in window furniture;
/// here the photo simply sits on the canvas with one glass ✕ — there is no
/// window metaphor in this look to honour.
private struct SkeuPhotoViewer: View {
    @Environment(\.skeu) private var skeu
    let image: UIImage
    var onClose: () -> Void

    var body: some View {
        ZStack {
            skeu.canvas.ignoresSafeArea()

            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .padding(SkeuSpace.lg)

            Button {
                SkeuHaptic.press()
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(skeu.ink)
                    .frame(width: 37, height: 37)
                    .skeuGlass(Circle(), height: 37)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(SkeuSpace.xl)
            .accessibilityLabel("Close photo")
        }
    }
}
