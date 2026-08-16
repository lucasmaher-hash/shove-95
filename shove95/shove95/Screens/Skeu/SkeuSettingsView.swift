//
//  SkeuSettingsView.swift
//  shove95
//
//  Settings in the skeu look — a ROUGH first pass, built to nail the
//  construction before the content is complete. Tab names, workspaces, archive
//  and about still live in the Win95 settings and arrive here in step 4 proper.
//
//  Construction transcribed from the founder's menu study (shove95 file, node
//  2:182, the "Dashboard / Projects 10 / Account / Support" card):
//
//    CARD    a raised sheet: material fill, white rim (7.69 at frame scale),
//            soft shadows falling down-left. ONE CARD PER SETTING — the founder
//            was explicit (2026-08-13) that each setting is its own panel, not
//            sections sharing a sheet. The frame also carries a leather texture
//            and two glow blobs — the texture is out (hard rule: no texture
//            assets; depth from light only), the glows are approximated by a
//            diagonal gradient on the fill.
//    TROUGH  inside each card, the same channel the bars use — gradient,
//            contour, four inner shadows — holding that setting's options.
//    OPTION  a glass pill. Selected = prominent (bright rim, glow, ink label).
//            Resting = subdued (half rim, no glow, muted label) — nodes 1:87
//            vs 1:101.
//
//  Scale: the frame draws its pill text at 27.692 where the phone wants 12.8,
//  so every transcribed value is × 0.4622.
//

import SwiftUI
import Shove95Kit

private enum G {
    static let q: CGFloat = 12.8 / 27.692   // 0.4622 — the frame-to-phone scale

    /// Between one setting and the next — i.e. the air ABOVE each heading.
    /// Raised from the transcribed 21.3 (founder direction 2026-08-16): with
    /// the outer cards gone, that figure was doing two jobs it used to share
    /// with a card edge, and seven settings ran together as one column.
    static let sectionGap: CGFloat = 44

    static let pillPadH = 36.923 * q        // 17.1
    static let pillHeight: CGFloat = 38     // 12.8 text + 2 × 11.4, rounded
    static let label: CGFloat = 12.8

    /// Input rows are the TOGGLE, taken apart: the field is the toggle's
    /// trough and the button beside it is the toggle's inner pill (founder
    /// direction 2026-08-16). Read from `SkeuToggle` rather than copied, so
    /// the two families cannot drift apart the way they already did once.
    static let fieldHeight = SkeuToggle.height
    static let rowButtonH = SkeuToggle.height - SkeuToggle.padV * 2

    /// The width of a button standing BESIDE a field. Fixed, not intrinsic:
    /// Default, Delete and Add stack in one column down the sheet, and three
    /// different widths there read as three different kinds of control.
    /// Sized for "Default", the longest of the three.
    static let rowButtonW: CGFloat = 88

    /// How far a panel dissolves as it passes under the docked header. Matches
    /// the home screen's bars — see `F.edgeFade` there.
    static let edgeFade: CGFloat = 28

    /// Room under the last panel for the home indicator, now that the scroll
    /// view runs past the safe area to the physical bottom edge.
    static let bottomClearance: CGFloat = 34

    /// The open language list. Tall enough to show several choices at once,
    /// short enough that the sheet underneath is still reachable — an
    /// unbounded list would push Data off the bottom and eat the outer scroll.
    static let languageListHeight: CGFloat = 232
}

struct SkeuSettingsView: View {
    @Environment(\.skeuTextScale) private var textScale
    @Environment(\.skeuChromeScale) private var chromeScale

    // Dynamic Type (FR-015): text on the full curve, chrome at half. Without
    // this the eyebrow headings scaled (they use SkeuFont tokens) while every
    // field label stayed fixed — giant titles over tiny controls.
    private var labelSize: CGFloat { G.label * textScale }
    private var fieldH: CGFloat { G.fieldHeight * chromeScale }
    private var pillH: CGFloat { G.pillHeight * chromeScale }
    // No `\.skeuFace` here: this view observes AppSettings, so a face change
    // already re-runs its body. Only the leaf views below, which don't, need
    // to declare that dependency.
    @Environment(\.skeu) private var skeu
    @Environment(AppSettings.self) private var settings
    @Environment(TaskStore.self) private var store
    @Environment(SyncStatus.self) private var sync
    @State private var showArchive = false
    @State private var showAbout = false
    @State private var newWorkspace = ""
    @FocusState private var addWorkspaceFocused: Bool
    // One namespace per toggle row: the gliding pill must travel WITHIN its
    // own row, and a shared namespace would let it fly between panels.
    @Namespace private var themeNS
    @Namespace private var faceNS
    @Namespace private var designNS
    @Namespace private var appearanceNS
    var onClose: () -> Void

    var body: some View {
        ZStack {
            skeu.canvas.ignoresSafeArea()

            // The header is a SIBLING of the scroll view, not its first row —
            // the Win95 window's arrangement, where the title bar stays put
            // and only the well's contents travel (founder direction
            // 2026-08-16). Scrolled inside, the title and the ✕ rode up under
            // the status bar and the first panel collided with the clock.
            VStack(alignment: .leading, spacing: 0) {
                header
                    // Lands the ✕ on exactly the gear's y — see SkeuTopBar.
                    .padding(.top, SkeuTopBar.inset)
                    .padding(.horizontal, SkeuTopBar.margin)
                    // A band of its own. The Win95 window gets this for free
                    // from the title bar's height; here the panels would
                    // otherwise travel a few points under the word "Settings"
                    // and read as a collision rather than a dock.
                    .padding(.bottom, SkeuSpace.md)

                ScrollView {
                // LAZY, not a plain VStack. Seven cards, each carrying a
                // trough (four inner shadows apiece) and the selected option's
                // glass (five blurred lens layers, two additive gradients,
                // three shadows) — all of it was being rasterised on the first
                // frame, while the sheet was still sliding up. That is what
                // made the presentation stutter (founder bug report
                // 2026-08-14). Only the cards actually on screen now render.
                LazyVStack(alignment: .leading, spacing: G.sectionGap) {
                    // Section order MATCHES the Win95 settings exactly — the
                    // two are the same screen in two looks, and a reader who
                    // switches design should find the same control in the same
                    // place (founder bug report 2026-08-14). Win95's
                    // "Appearance" swatch row is this "Theme" row.
                    panel("Theme") {
                        ForEach(SkeuTheme.all) { theme in
                            swatchOption(theme,
                                         selected: settings.skeuTheme.id == theme.id,
                                         in: themeNS) {
                                settings.skeuTheme = theme
                            }
                        }
                    }

                    panel("Typeface") {
                        ForEach(AppFace.allCases, id: \.self) { face in
                            option(face.label,
                                   selected: settings.skeuFace == face,
                                   in: faceNS) {
                                settings.skeuFace = face
                            }
                        }
                    }

                    panel("Design") {
                        ForEach(DesignMode.allCases, id: \.self) { mode in
                            option(mode.label,
                                   selected: settings.design == mode,
                                   in: designNS) {
                                // The two looks cross-fade — see DesignSwitch.
                                withAnimation(DesignSwitch.animation) {
                                    settings.design = mode
                                }
                            }
                        }
                    }

                    panel("Light & dark") {
                        ForEach(AppearanceMode.allCases, id: \.self) { mode in
                            option(mode.label,
                                   selected: settings.appearance == mode,
                                   in: appearanceNS) {
                                settings.appearance = mode
                            }
                        }
                    }

                    tabNamesPanel
                    workspacesPanel
                    languagePanel
                    dataPanel
                }
                .padding(.horizontal, SkeuTopBar.margin) // the root's screen margin
                .padding(.top, SkeuSpace.md)
                // Clears the home indicator by PADDING rather than by stopping
                // the scroll view short — see the `ignoresSafeArea` below.
                .padding(.bottom, SkeuSpace.md + G.bottomClearance)
                }
                .scrollIndicators(.hidden)
                // The header is docked and the panels run under it, so they
                // dissolve on the way rather than being cut — and only once
                // something has scrolled past. See SkeuEdgeFade.
                .skeuScrollEdgeFade(G.edgeFade * chromeScale, edges: .top)
                // Runs to the BOTTOM OF THE SCREEN. Stopping at the safe area
                // left a dead band under the last panel that read as a bar —
                // the same thing the Win95 well was fixed for on 2026-08-04.
                // Content travels through it; the padding above is what keeps
                // the last row reachable above the home indicator.
                .ignoresSafeArea(.container, edges: .bottom)
            }
        }
        .fullScreenCover(isPresented: $showArchive) {
            SkeuArchiveView { showArchive = false }
        }
        .fullScreenCover(isPresented: $showAbout) {
            SkeuAboutView { showAbout = false }
        }
    }

    // MARK: Tab names

    /// One trough per tab, each holding its field and a Default pill. The
    /// pill fades out when the name already IS the default — a control that
    /// would do nothing shouldn't invite a press.
    private var tabNamesPanel: some View {
        card("Tab names") {
            VStack(spacing: SkeuSpace.sm) {
                ForEach(Bucket.line, id: \.self) { bucket in
                    SkeuNameField(bucket: bucket)
                }
            }
        }
    }

    // MARK: Language

    /// Below Workspaces and above Data — the last thing you SET, before the
    /// section that only shows you things.
    private var languagePanel: some View {
        card("Language") { SkeuLanguageRow() }
    }

    // MARK: Workspaces

    private var workspacesPanel: some View {
        card("Workspaces") {
            VStack(spacing: SkeuSpace.sm) {
                ForEach(store.workspaces(), id: \.id) { workspace in
                    SkeuWorkspaceRow(workspace: workspace) {
                        if settings.currentWorkspaceID == workspace.id {
                            settings.currentWorkspaceID = Workspace.defaultID
                        }
                        store.deleteWorkspace(workspace) // tasks fold into default
                    }
                }

                HStack(spacing: SkeuSpace.sm) {
                    field(text: $newWorkspace, prompt: "New workspace",
                          focused: $addWorkspaceFocused)

                    SkeuRowButton(title: "Add") {
                        SkeuHaptic.press()
                        addWorkspace()
                    }
                }
            }
        }
    }

    private func addWorkspace() {
        // See SettingsView.add(): a refused name keeps its text and its
        // focus rather than being silently swallowed.
        guard store.addWorkspace(named: newWorkspace) != nil else { return }
        newWorkspace = ""
        addWorkspaceFocused = false
    }

    // MARK: Data

    /// Archive, one line of sync status, About. The status is a LINE, not a
    /// control: sync is silent, so there is nothing here to press or retry.
    private var dataPanel: some View {
        card("Data") {
            VStack(alignment: .leading, spacing: SkeuSpace.md) {
                HStack(spacing: SkeuSpace.sm) {
                    actionPill("Archive") { showArchive = true }
                    actionPill("About") { showAbout = true }
                    Spacer(minLength: 0)
                }

                Text(sync.summary)
                    .font(SkeuFont.at(labelSize))
                    .foregroundStyle(sync.isDegraded ? skeu.critical : skeu.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var header: some View {
        HStack {
            Text("Settings")
                .font(SkeuFont.title3)
                .foregroundStyle(skeu.ink)

            Spacer(minLength: SkeuSpace.sm)

            Button {
                SkeuHaptic.press()
                onClose()
            } label: {
                // Same size, same glyph weight and same corner as the gear
                // this sheet opened from — see SkeuTopBar.
                let size = SkeuTopBar.control * chromeScale
                Image(systemName: "xmark")
                    .font(SkeuFont.at(SkeuTopBar.icon * chromeScale, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(skeu.ink)
                    .frame(width: size, height: size)
                    .skeuGlass(Circle(), height: size)
            }
            .buttonStyle(.plain)
            .frame(minWidth: SkeuControl.minTouch, minHeight: SkeuControl.minTouch)
            .accessibilityLabel("Close settings")
        }
    }

    // MARK: Panels

    /// One setting = a heading and a trough of options. NO outer card.
    ///
    /// The card was the Figma menu study's construction, but stacking seven of
    /// them put a frame inside a frame on every row (founder direction
    /// 2026-08-14): the home screen does not wrap its four tabs in a card, and
    /// these are the same control. The eyebrow now labels the trough directly,
    /// and the trough is the only surface — which also removes seven raised
    /// cards' worth of gradients and shadows from the sheet's first frame.
    private func panel<C: View>(_ title: String,
                                @ViewBuilder options: () -> C) -> some View {
        VStack(alignment: .leading, spacing: SkeuSpace.sm) {
            Text(title)
                .font(SkeuFont.eyebrow)
                .textCase(.uppercase)
                .tracking(0.8)
                .foregroundStyle(skeu.inkFaint)

            SkeuSegmentedTrough { options() }
        }
    }

    /// One option — the SAME segment the home screen's tab bar is built from.
    ///
    /// `group` is the matched-geometry namespace: each settings row is its own
    /// toggle, so its pill must glide within that row and not toward some
    /// other panel's selection.
    private func option(_ title: String,
                        selected: Bool,
                        in group: Namespace.ID,
                        action: @escaping () -> Void) -> some View {
        SkeuSegment(isSelected: selected, namespace: group, geometryID: "pill") {
            Text(title)
                .skeuSegmentLabel(textScale)
                .foregroundStyle(selected ? skeu.ink : skeu.inkMuted)
        }
        .onTapGesture {
            SkeuHaptic.selection()
            withAnimation(SkeuMotion.layout) { action() }
        }
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    /// The theme row's segment. The colour FILLS the pill (founder direction
    /// 2026-08-16) — a dot floating in a segment made the choice look like an
    /// icon beside an absent label, when the colour is the whole answer.
    ///
    /// The content is a blank line of the same type the other rows set, so a
    /// colour pill comes out exactly the size of a label pill and the theme
    /// row lines up with Typeface, Design and Light & dark above it.
    private func swatchOption(_ theme: SkeuTheme,
                              selected: Bool,
                              in group: Namespace.ID,
                              action: @escaping () -> Void) -> some View {
        SkeuSegment(isSelected: selected, namespace: group, geometryID: "pill",
                    fill: theme.light.material) {
            Text(" ").skeuSegmentLabel(textScale)
        }
        .onTapGesture {
            SkeuHaptic.selection()
            withAnimation(SkeuMotion.layout) { action() }
        }
        .accessibilityLabel("\(theme.name) theme")
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    /// A heading over free-form content — the field stacks and the Data row.
    /// Card-less for the same reason `panel` is: those fields already sit in
    /// troughs of their own, so an outer frame was a frame inside a frame.
    private func card<C: View>(_ title: String,
                               @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: SkeuSpace.sm) {
            Text(title)
                .font(SkeuFont.eyebrow)
                .textCase(.uppercase)
                .tracking(0.8)
                .foregroundStyle(skeu.inkFaint)

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// A text field in a trough. §9.7: inputs are recessed — the same channel
    /// everything else uses.
    ///
    /// Nothing else goes in here. The Default / Delete / Add buttons used to
    /// sit inside this trough, which made a control live in a container that
    /// is meant to read as a hole in the surface; they stand beside it now
    /// (founder direction 2026-08-16) — see `SkeuRowButton`.
    private func field(text: Binding<String>,
                       prompt: String,
                       focused: FocusState<Bool>.Binding) -> some View {
        TextField("", text: text,
                  prompt: Text(prompt).foregroundStyle(skeu.inkFaint))
            .font(SkeuFont.at(labelSize))
            .foregroundStyle(skeu.ink)
            .focused(focused)
            .submitLabel(.done)
            .padding(.horizontal, SkeuSpace.lg)
            .frame(height: fieldH)
            .skeuTrough(Capsule(), height: fieldH)
    }

    /// A standalone action pill — no trough behind it, it IS the control.
    private func actionPill(_ title: String, action: @escaping () -> Void) -> some View {
        Text(title)
            .font(SkeuFont.at(labelSize, weight: .medium))
            .foregroundStyle(skeu.ink)
            .padding(.horizontal, G.pillPadH)
            .frame(height: pillH)
            .skeuGlass(Capsule(), height: pillH)
            .contentShape(Capsule())
            .onTapGesture {
                SkeuHaptic.press()
                action()
            }
            .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Row button

/// The button that stands BESIDE a field: Default, Delete, Add.
///
/// It is the toggle's inner pill, standing outside a trough instead of in
/// one: same height, same glass, so a field row and an option row are visibly
/// the same construction (founder direction 2026-08-16). One fixed width
/// across all three so they line up down the sheet.
private struct SkeuRowButton: View {
    @Environment(\.skeu) private var skeu
    @Environment(\.skeuTextScale) private var textScale
    @Environment(\.skeuChromeScale) private var chromeScale
    /// Read only to re-render on a typeface change — see `\.skeuFace`.
    @Environment(\.skeuFace) private var face
    let title: String
    /// Colour comes from the caller — Delete is the one destructive word on
    /// this screen and says so.
    var tint: Color?
    var prominent = true
    var action: () -> Void

    var body: some View {
        let height = G.rowButtonH * chromeScale

        Text(title)
            .font(SkeuFont.at(G.label * textScale, weight: .medium))
            .foregroundStyle(tint ?? skeu.ink)
            .lineLimit(1)
            // The width is fixed, so an accessibility size has to shrink the
            // word rather than push the field off the screen.
            .minimumScaleFactor(0.6)
            .frame(width: G.rowButtonW * chromeScale, height: height)
            .skeuGlass(Capsule(), height: height, prominent: prominent)
            .contentShape(Capsule())
            .onTapGesture(perform: action)
            .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Tab name field

/// Its own view so the draft state belongs to the row, not the whole screen.
private struct SkeuNameField: View {
    @Environment(\.skeuTextScale) private var textScale
    @Environment(\.skeuChromeScale) private var chromeScale

    // Dynamic Type (FR-015): text on the full curve, chrome at half. Without
    // this the eyebrow headings scaled (they use SkeuFont tokens) while every
    // field label stayed fixed — giant titles over tiny controls.
    private var labelSize: CGFloat { G.label * textScale }
    private var fieldH: CGFloat { G.fieldHeight * chromeScale }
    @Environment(\.skeu) private var skeu
    /// Read only to re-render on a typeface change — see `\.skeuFace`.
    @Environment(\.skeuFace) private var face
    @Environment(AppSettings.self) private var settings
    let bucket: Bucket

    @State private var draft = ""
    @FocusState private var focused: Bool

    private var isDefault: Bool {
        settings.name(for: bucket) == bucket.displayName
    }

    var body: some View {
        HStack(spacing: SkeuSpace.sm) {
            // The field always holds the REAL current name at full strength —
            // a greyed placeholder reads as empty.
            TextField("", text: $draft,
                      prompt: Text(bucket.displayName).foregroundStyle(skeu.inkFaint))
                .font(SkeuFont.at(labelSize))
                .foregroundStyle(skeu.ink)
                .focused($focused)
                .submitLabel(.done)
                .onSubmit(commit)
                .onChange(of: focused) { _, isFocused in
                    if !isFocused { commit() }
                }
                .padding(.horizontal, SkeuSpace.lg)
                .frame(height: fieldH)
                .skeuTrough(Capsule(), height: fieldH)

            // Fades when the name already IS the default — a control that
            // would do nothing shouldn't invite a press.
            SkeuRowButton(title: "Default", prominent: !isDefault) {
                guard !isDefault else { return }
                SkeuHaptic.press()
                focused = false
                draft = bucket.displayName
                settings.resetName(for: bucket)
            }
            .opacity(isDefault ? 0.35 : 1)
            .animation(SkeuMotion.tint, value: isDefault)
            .accessibilityLabel("Restore default name for \(bucket.displayName)")
        }
        .task { draft = settings.name(for: bucket) }
    }

    private func commit() {
        settings.setName(draft == bucket.displayName ? "" : draft, for: bucket)
        draft = settings.name(for: bucket)
    }
}

// MARK: - Language row

/// The language picker: the workspace row's exact construction — a trough
/// holding a field, a row button beside it — with a list that drops out
/// underneath when the button is pressed.
///
/// The FIELD is the search box. Thirty languages is too long to scroll past
/// politely, and a separate search box above a list is two controls where one
/// will do: the row already has a field, so typing in it opens the list and
/// filters it. Pressing Edit on an empty field opens the whole list to scroll.
private struct SkeuLanguageRow: View {
    @Environment(\.skeu) private var skeu
    @Environment(\.skeuTextScale) private var textScale
    @Environment(\.skeuChromeScale) private var chromeScale
    /// Read only to re-render on a typeface change — see `\.skeuFace`.
    @Environment(\.skeuFace) private var face
    @Environment(AppSettings.self) private var settings

    @State private var query = ""
    @State private var isOpen = false
    @FocusState private var focused: Bool

    private var labelSize: CGFloat { G.label * textScale }
    private var fieldH: CGFloat { G.fieldHeight * chromeScale }
    private var matches: [Language] { Language.all.filter { $0.matches(query) } }

    var body: some View {
        VStack(spacing: SkeuSpace.sm) {
            HStack(spacing: SkeuSpace.sm) {
                TextField("", text: $query,
                          prompt: Text(settings.language.endonym)
                            .foregroundStyle(skeu.inkFaint))
                    .font(SkeuFont.at(labelSize))
                    .foregroundStyle(skeu.ink)
                    .focused($focused)
                    .submitLabel(.done)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .padding(.horizontal, SkeuSpace.lg)
                    .frame(height: fieldH)
                    .skeuTrough(Capsule(), height: fieldH)
                    // Typing IS the search — the list opens itself rather than
                    // asking you to press Edit first and then type.
                    .onChange(of: query) { _, new in
                        guard !new.isEmpty, !isOpen else { return }
                        withAnimation(SkeuMotion.layout) { isOpen = true }
                    }

                SkeuRowButton(title: isOpen ? "Done" : "Edit") {
                    SkeuHaptic.press()
                    withAnimation(SkeuMotion.layout) { isOpen.toggle() }
                    if isOpen {
                        focused = true
                    } else {
                        query = ""
                        focused = false
                    }
                }
                .accessibilityLabel(isOpen ? "Close language list" : "Choose language")
            }

            if isOpen { list }
        }
    }

    /// Sits in a trough like every other well on this screen, and is bounded
    /// so the sheet stays scrollable — a list grown to thirty rows would push
    /// Data off the bottom and swallow the outer scroll.
    private var list: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(matches) { language in
                    row(language)
                }
                if matches.isEmpty {
                    Text("No match")
                        .font(SkeuFont.at(labelSize))
                        .foregroundStyle(skeu.inkFaint)
                        .frame(maxWidth: .infinity, minHeight: fieldH)
                }
            }
            .padding(.vertical, SkeuSpace.xs)
        }
        .frame(maxHeight: G.languageListHeight * chromeScale)
        .skeuTrough(RoundedRectangle(cornerRadius: SkeuRadius.lg, style: .continuous),
                    height: fieldH)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func row(_ language: Language) -> some View {
        let selected = language.code == settings.languageCode
        return HStack(spacing: SkeuSpace.sm) {
            Text(language.endonym)
                .font(SkeuFont.at(labelSize))
                .foregroundStyle(skeu.ink)
                .lineLimit(1)

            // Honest about what the option currently does. The founder chose
            // to ship the picker before the strings (2026-08-16); a language
            // that changes nothing yet should say so rather than look broken.
            if !language.isTranslated {
                Text("soon")
                    .font(SkeuFont.at(labelSize * 0.8))
                    .foregroundStyle(skeu.inkFaint)
            }

            Spacer(minLength: 0)

            // A SHAPE, not a tint — the selected row has to be identifiable
            // without colour (N2).
            if selected {
                Image(systemName: "checkmark")
                    .font(SkeuFont.at(labelSize))
                    .foregroundStyle(skeu.accent)
            }
        }
        .padding(.horizontal, SkeuSpace.lg)
        .frame(minHeight: G.rowButtonH * chromeScale)
        .contentShape(Rectangle())
        .onTapGesture {
            SkeuHaptic.selection()
            settings.languageCode = language.code
            withAnimation(SkeuMotion.layout) { isOpen = false }
            query = ""
            focused = false
        }
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
        .accessibilityLabel(language.isTranslated
                            ? language.endonym
                            : "\(language.endonym), not translated yet")
    }
}

// MARK: - Workspace row

private struct SkeuWorkspaceRow: View {
    @Environment(\.skeuTextScale) private var textScale
    @Environment(\.skeuChromeScale) private var chromeScale

    // Dynamic Type (FR-015): text on the full curve, chrome at half. Without
    // this the eyebrow headings scaled (they use SkeuFont tokens) while every
    // field label stayed fixed — giant titles over tiny controls.
    private var labelSize: CGFloat { G.label * textScale }
    private var fieldH: CGFloat { G.fieldHeight * chromeScale }
    @Environment(\.skeu) private var skeu
    /// Read only to re-render on a typeface change — see `\.skeuFace`.
    @Environment(\.skeuFace) private var face
    @Environment(TaskStore.self) private var store
    let workspace: Workspace
    var onDelete: () -> Void

    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: SkeuSpace.sm) {
            TextField("", text: $draft,
                      prompt: Text(workspace.name).foregroundStyle(skeu.inkFaint))
                .font(SkeuFont.at(labelSize))
                .foregroundStyle(skeu.ink)
                .focused($focused)
                .submitLabel(.done)
                .onSubmit(commit)
                .onChange(of: focused) { _, isFocused in
                    if !isFocused { commit() }
                }
                .padding(.horizontal, SkeuSpace.lg)
                .frame(height: fieldH)
                .skeuTrough(Capsule(), height: fieldH)

            // The default workspace can't be deleted — there must always be
            // somewhere for tasks to live. Its slot is HELD rather than
            // collapsed, so that one row's field isn't wider than the rest.
            if workspace.isDefault {
                Color.clear
                    .frame(width: G.rowButtonW * chromeScale,
                           height: G.rowButtonH * chromeScale)
            } else {
                SkeuRowButton(title: "Delete", tint: skeu.critical) {
                    SkeuHaptic.warning()
                    onDelete()
                }
                .accessibilityLabel("Delete workspace \(workspace.name)")
            }
        }
        .task { draft = workspace.name }
    }

    private func commit() {
        store.renameWorkspace(workspace, to: draft)
        draft = workspace.name
    }
}
