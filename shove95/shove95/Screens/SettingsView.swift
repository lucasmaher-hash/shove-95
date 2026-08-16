//
//  SettingsView.swift
//  shove95
//
//  A maximized Win95 settings window. Presented full-screen rather than as a
//  sheet — sheets carry rounded corners and a drag indicator, both prohibited
//  (design.md §9).
//
//  Layout revised 2026-08-04 on founder feedback: no grey group boxes around
//  the controls — plain headers on the window surface, controls directly
//  beneath. The scheme picker is one row of solid swatches with no caption;
//  tab renaming is field-left / Default-button-right. Workspaces live here too.
//
//  Archive, iCloud status and About arrive in Phase 5.
//

import SwiftUI
import Shove95Kit

struct SettingsView: View {
    @Environment(\.pixel) private var pixel
    @Environment(AppSettings.self) private var settings
    @Environment(SyncStatus.self) private var sync
    @State private var showArchive = false
    @State private var showAbout = false
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            TitleBar(title: "Settings - shove.95", isClose: true, onSettings: onClose)

            SunkenWell {
                ScrollView {
                    // Same sections in the same order and the same rhythm as
                    // the skeu sheet — this is one settings screen in two
                    // looks, and a reader who flips Design should find every
                    // control where they left it (founder direction
                    // 2026-08-16).
                    VStack(alignment: .leading, spacing: sectionGap) {
                        section("Appearance") { schemeRow }
                        section("Typeface") { faceRow }
                        section("Design") { designRow }
                        section("Light & dark") { appearanceRow }

                        section("Tab names") {
                            VStack(alignment: .leading, spacing: rowGap) {
                                ForEach(Bucket.line, id: \.self) { bucket in
                                    NameField(bucket: bucket,
                                              buttonColumn: buttonColumn)
                                }
                            }
                        }

                        section("Workspaces") {
                            WorkspacesSection(buttonColumn: buttonColumn)
                        }

                        section("Language") {
                            LanguageSection(buttonColumn: buttonColumn)
                        }

                        section("Data") { dataSection }
                    }
                    .padding(.horizontal, Win95.Px.grid * 2 * pixel)
                    // TOP is matched to the skeu sheet's, not to `sectionGap`:
                    // over there the first heading sits 32pt below the docked
                    // header (its own 16 plus the scroll's 16), and the whole
                    // point is that the first heading lands on the same y in
                    // both looks. `contentTopInset` carries the difference in
                    // chrome height between a title bar and a text header.
                    .padding(.top, contentTopInset)
                    // Clears the home indicator, since the well itself now
                    // runs to the physical bottom edge.
                    .padding(.bottom, Win95.Px.grid * 8 * pixel)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .background(Win95.surface)
        // The well runs to the bottom of the SCREEN. Stopping at the safe area
        // drew its bottom border partway up, which read as a stray horizontal
        // rule under the content (founder bug report 2026-08-04).
        .ignoresSafeArea(.container, edges: .bottom)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .fullScreenCover(isPresented: $showArchive) {
            ArchiveView { showArchive = false }
                .environment(\.pixel, pixel)
                .environment(\.win95Scheme, settings.scheme)
                .id(settings.face.rawValue + settings.scheme.id)
        }
        .fullScreenCover(isPresented: $showAbout) {
            AboutView { showAbout = false }
                .environment(\.pixel, pixel)
                .environment(\.win95Scheme, settings.scheme)
                .id(settings.face.rawValue + settings.scheme.id)
        }
    }

    /// Archive, one line of iCloud status, About. The status is a LINE, not a
    /// control: sync is silent (FR-013), so there is nothing here to press and
    /// nothing to retry.
    private var dataSection: some View {
        VStack(alignment: .leading, spacing: Win95.Px.grid * 2 * pixel) {
            // The two buttons sit side by side, with the status line beneath
            // both — the skeu sheet's arrangement. Stacked, with the status
            // wedged between them, the line read as a caption for Archive.
            HStack(spacing: rowGap) {
                Win95Button(action: { showArchive = true },
                            compact: true, width: buttonColumn) {
                    Text("Archive")
                        .font(W95Font.small(pixel))
                        .foregroundStyle(Win95.text)
                }

                Win95Button(action: { showAbout = true },
                            compact: true, width: buttonColumn) {
                    Text("About")
                        .font(W95Font.small(pixel))
                        .foregroundStyle(Win95.text)
                }

                Spacer(minLength: 0)
            }

            Text(sync.summary)
                .font(W95Font.small(pixel))
                .foregroundStyle(sync.isDegraded ? Win95.important : Win95.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Two pressed-in choices, same idiom as the scheme swatches. The Win95
    /// face is the app; the system face is here because a bitmap-derived font
    /// is hard for some people to read, and legibility outranks costume.
    private var faceRow: some View {
        HStack(spacing: Win95.Px.grid * pixel) {
            ForEach(AppFace.allCases, id: \.self) { face in
                // Each option is set in the face it selects — the label is the
                // preview. Asked as "how would this face set a CHROME label",
                // which is what these are, so Blend previews itself as pixel
                // rather than looking identical to System.
                SegmentedChoice(
                    label: face.label,
                    font: face.isPixel(.chrome) ? W95Font.standard(pixel, role: .chrome)
                                                : .system(size: Win95.Px.fontStandard * pixel * 0.82),
                    // Binds to whichever look is active — each keeps its own
                    // choice, so switching design doesn't drag a face along.
                    isSelected: settings.activeFace == face,
                    accessibilityLabel: "\(face.label) typeface"
                ) { settings.activeFace = face }
            }
        }
    }

    /// The whole point of this phase: one tap swaps the app's visual language.
    private var designRow: some View {
        HStack(spacing: Win95.Px.grid * pixel) {
            ForEach(DesignMode.allCases, id: \.self) { mode in
                SegmentedChoice(
                    label: mode.label,
                    font: W95Font.small(pixel),
                    isSelected: settings.design == mode,
                    accessibilityLabel: "\(mode.label) design"
                ) {
                    // The two looks cross-fade — see DesignSwitch.
                    withAnimation(DesignSwitch.animation) { settings.design = mode }
                }
            }
        }
    }

    /// Global, not skeu-only — the Windows look gains dark palettes later and
    /// will read this same value.
    private var appearanceRow: some View {
        HStack(spacing: Win95.Px.grid * pixel) {
            ForEach(AppearanceMode.allCases, id: \.self) { mode in
                SegmentedChoice(
                    label: mode.label,
                    font: W95Font.small(pixel),
                    isSelected: settings.appearance == mode,
                    accessibilityLabel: "\(mode.label) appearance"
                ) { settings.appearance = mode }
            }
        }
    }

    // MARK: Rhythm
    //
    // The three gaps that give this screen its shape, matched to the skeu
    // sheet's. Before this the heading sat 16pt from its own controls and 32
    // from the previous section — near enough to the middle that it read as
    // belonging to neither (founder direction 2026-08-16). A heading hugs
    // what it labels; the air goes BETWEEN settings.
    //
    // The values are now the SKEU sheet's, exactly: 12 and 44 at the design
    // step. They were approximated on the 2/4/8/16/24 spec grid before, which
    // put every heading 4pt out and every control up to 20pt out from its twin
    // — visible the moment you flip Design, which is the one moment C4 exists
    // for (founder direction 2026-08-16). Half-grid units still land on whole
    // pixels at every step, so nothing is lost by leaving the grid here.
    //
    // What CANNOT be matched is the curve. This look steps its unit in whole
    // pixels (FR-015) while the skeu look scales continuously, so the two
    // agree exactly at the design step and drift apart above it. Holding them
    // together everywhere would mean giving one of them the other's scaling
    // rule, and both rules are load-bearing.

    /// Distance from the title bar to the first heading. Chosen so that
    /// heading lands on the same y as the skeu sheet's, which measures 32pt
    /// below its header — the remainder is the title bar being taller than a
    /// line of text. Verified by comparing both looks at the same scroll
    /// position; adjust by measuring, not by reasoning about it.
    private var contentTopInset: CGFloat { Win95.Px.grid * 4 * pixel }

    /// Heading → its controls. 6 × 2 = 12pt, the skeu `SkeuSpace.sm`.
    private var headingGap: CGFloat { Win95.Px.grid * 1.5 * pixel }
    /// One setting → the next. 22 × 2 = 44pt, the skeu `G.sectionGap`.
    private var sectionGap: CGFloat { Win95.Px.grid * 5.5 * pixel }
    /// Between field rows inside one section.
    private var rowGap: CGFloat { Win95.Px.grid * pixel }

    /// One trailing column for EVERY field row on the screen — Default,
    /// Delete, Add, and the empty slot on the undeletable default workspace
    /// all reserve it. Tab names used an intrinsic width before, so its
    /// fields ended at a different x than the Workspaces fields directly
    /// below them. Sized to the longest label at any pixel scale.
    private var buttonColumn: CGFloat { Win95.Px.grid * 12 * pixel }

    /// A heading and the controls it labels, as one block.
    ///
    /// The heading is an EYEBROW, matching the skeu sheet's: small, upper
    /// case, tracked, in the muted ink. It was set at standard body size,
    /// which stood about 9pt taller than its twin — and since a settings
    /// screen is a column of these, that difference accumulated all the way
    /// down until the last section sat 37pt lower than the same section in
    /// the other look. The gaps were already identical by then; the type was
    /// what was left (founder decision 2026-08-16: shrink this one rather
    /// than add air to the skeu rhythm).
    ///
    /// `fontSmall` at the same tracking is the closest this look's own scale
    /// gets to `SkeuFont.eyebrow`, and it stays on the pixel unit, so the
    /// heading still lands on whole pixels at every Dynamic Type step.
    private func section<C: View>(_ title: String,
                                  @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: headingGap) {
            // Types itself out on a face change, exactly as the skeu heading
            // does — this look had the same setting and none of the animation
            // (founder bug report 2026-08-16). `.uppercased()` rather than
            // `.textCase`, since TypedText slices the string itself and has to
            // slice the string that is actually shown.
            TypedText(text: title.uppercased(), face: settings.face, role: .chrome)
                .font(W95Font.small(pixel, role: .chrome))
                .tracking(0.8)
                .foregroundStyle(Win95.textMuted)

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // One bare row of swatches — no box, no caption. The pressed bevel on the
    // selected swatch is the whole answer to "which one is on".
    private var schemeRow: some View {
        HStack(spacing: Win95.Px.grid * pixel) {
            ForEach(Win95Scheme.all) { scheme in
                SchemeSwatch(
                    scheme: scheme,
                    isSelected: scheme.id == settings.scheme.id
                ) {
                    var t = Transaction()
                    t.disablesAnimations = true // appearance never animates
                    withTransaction(t) { settings.scheme = scheme }
                }
            }
        }
    }
}

// MARK: - Scheme swatch

/// A solid block of the scheme's title-bar gradient — its most recognisable
/// colour. Selected reads as a pressed toolbar button: sunken bevel, nudged
/// down and right one pixel.
private struct SchemeSwatch: View {
    @Environment(\.pixel) private var pixel
    /// Read only to re-render on a typeface change — the face is a
    /// static this view cannot otherwise see. See `\.appFace`.
    @Environment(\.appFace) private var face
    let scheme: Win95Scheme
    let isSelected: Bool
    var action: () -> Void

    var body: some View {
        LinearGradient(colors: [Color(hex: scheme.titleA), Color(hex: scheme.titleB)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
            .frame(maxWidth: .infinity)
            .frame(height: Win95.rowHeight(pixel))
            .padding(pixel * 2)
            .background(Win95.surface)
            .modifier(SwatchBevel(isSelected: isSelected, pixel: pixel))
            .offset(x: isSelected ? pixel : 0, y: isSelected ? pixel : 0)
            .contentShape(Rectangle())
            .onTapGesture(perform: action)
            .accessibilityLabel(scheme.name)
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Segmented choice

/// One option in a row of mutually exclusive choices. Selected renders as a
/// pressed toolbar button — sunken bevel, nudged a pixel down and right — the
/// same idiom the scheme swatches use, so the three switches read as one family.
private struct SegmentedChoice: View {
    @Environment(\.pixel) private var pixel
    /// Read only to re-render on a typeface change — the face is a
    /// static this view cannot otherwise see. See `\.appFace`.
    @Environment(\.appFace) private var face
    let label: String
    let font: Font
    let isSelected: Bool
    let accessibilityLabel: String
    var action: () -> Void

    var body: some View {
        Text(label)
            .font(font)
            .foregroundStyle(Win95.text)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, Win95.Px.grid * pixel)
            .frame(maxWidth: .infinity)
            .frame(minHeight: Win95.rowHeight(pixel))
            .background(Win95.surface)
            .modifier(SwatchBevel(isSelected: isSelected, pixel: pixel))
            .offset(x: isSelected ? pixel : 0, y: isSelected ? pixel : 0)
            .contentShape(Rectangle())
            .onTapGesture {
                // Appearance never animates (design.md §8).
                var t = Transaction()
                t.disablesAnimations = true
                withTransaction(t, action)
            }
            .accessibilityLabel(accessibilityLabel)
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

private struct SwatchBevel: ViewModifier {
    let isSelected: Bool
    let pixel: CGFloat

    func body(content: Content) -> some View {
        if isSelected { content.bevelSunken(pixel) } else { content.bevelRaised(pixel) }
    }
}

// MARK: - Name field

/// Field on the left, `Default` on the right. The field always holds the REAL
/// current name in full-strength text — the greyed placeholder read as empty
/// (founder feedback 2026-08-04). Default is compact, and fades out when the
/// The language picker, in this look's own parts: a sunken field, a button
/// beside it, and a sunken well of choices that drops out underneath.
///
/// Same behaviour as the skeu row (see `SkeuLanguageRow`) — the field IS the
/// search box, so typing opens the list and filters it, and Edit with an
/// empty field opens the whole list to scroll. The two looks have to agree on
/// what a control DOES; only how it is drawn differs (C4).
private struct LanguageSection: View {
    @Environment(\.pixel) private var pixel
    @Environment(AppSettings.self) private var settings
    let buttonColumn: CGFloat

    @State private var query = ""
    @State private var isOpen = false
    @FocusState private var focused: Bool

    private var matches: [Language] { Language.all.filter { $0.matches(query) } }

    var body: some View {
        VStack(alignment: .leading, spacing: Win95.Px.grid * pixel) {
            HStack(spacing: Win95.Px.grid * pixel) {
                TextField(settings.language.endonym, text: $query)
                    .font(W95Font.standard(pixel))
                    .foregroundStyle(Win95.text)
                    .focused($focused)
                    .submitLabel(.done)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .padding(.horizontal, Win95.Px.grid * pixel)
                    .frame(minHeight: Win95.rowHeight(pixel))
                    .background(Win95.well)
                    .bevelSunken(pixel)
                    .onChange(of: query) { _, new in
                        guard !new.isEmpty, !isOpen else { return }
                        isOpen = true
                    }

                Win95Button(action: toggle, compact: true, width: buttonColumn) {
                    Text(isOpen ? "Done" : "Edit")
                        .font(W95Font.small(pixel))
                        .foregroundStyle(Win95.text)
                }
                .accessibilityLabel(isOpen ? "Close language list" : "Choose language")
            }

            if isOpen { list }
        }
    }

    private var list: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(matches) { language in
                    row(language)
                }
                if matches.isEmpty {
                    Text("(no match)")
                        .font(W95Font.standard(pixel))
                        .foregroundStyle(Win95.textMuted)
                        .padding(.horizontal, Win95.Px.grid * pixel)
                        .frame(minHeight: Win95.rowHeight(pixel))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: Win95.rowHeight(pixel) * 6)
        .background(Win95.well)
        .bevelSunken(pixel)
    }

    private func row(_ language: Language) -> some View {
        let selected = language.code == settings.languageCode
        return HStack(spacing: Win95.Px.grid * pixel) {
            Text(language.endonym)
                .font(W95Font.standard(pixel))
                // Selection is the SELECTION BAR, this look's own idiom for it
                // — the navy fill and its light text, exactly as the workspace
                // menu marks the current one.
                .foregroundStyle(selected ? Win95.selectionText : Win95.text)
                .lineLimit(1)

            if !language.isTranslated {
                Text("soon")
                    .font(W95Font.small(pixel))
                    .foregroundStyle(selected ? Win95.selectionText : Win95.textMuted)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Win95.Px.grid * pixel)
        .frame(maxWidth: .infinity, minHeight: Win95.rowHeight(pixel), alignment: .leading)
        .background(selected ? Win95.selectionBG : Win95.well)
        .contentShape(Rectangle())
        .onTapGesture {
            settings.languageCode = language.code
            isOpen = false
            query = ""
            focused = false
        }
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
        .accessibilityLabel(language.isTranslated
                            ? language.endonym
                            : "\(language.endonym), not translated yet")
    }

    private func toggle() {
        isOpen.toggle()
        if isOpen {
            focused = true
        } else {
            query = ""
            focused = false
        }
    }
}

/// name already is the default: a button that would do nothing shouldn't
/// invite a press.
private struct NameField: View {
    @Environment(\.pixel) private var pixel
    @Environment(AppSettings.self) private var settings
    let bucket: Bucket
    /// Shared with Workspaces, so every field on the screen ends at the same x.
    let buttonColumn: CGFloat

    @State private var draft = ""
    @FocusState private var focused: Bool

    private var isDefault: Bool {
        settings.name(for: bucket) == bucket.displayName
    }

    var body: some View {
        HStack(spacing: Win95.Px.grid * pixel) {
            TextField(bucket.displayName, text: $draft)
                .font(W95Font.standard(pixel))
                .foregroundStyle(Win95.text)
                .focused($focused)
                .submitLabel(.done)
                .onSubmit { commit() }
                .onChange(of: focused) { _, isFocused in
                    if !isFocused { commit() }
                }
                .padding(.horizontal, Win95.Px.grid * pixel)
                .frame(minHeight: Win95.rowHeight(pixel))
                .background(Win95.well)
                .bevelSunken(pixel)

            Win95Button(action: {
                focused = false
                draft = bucket.displayName
                settings.resetName(for: bucket)
            }, compact: true, width: buttonColumn) {
                Text("Default")
                    .font(W95Font.small(pixel))
                    .foregroundStyle(Win95.text)
            }
            .opacity(isDefault ? 0.35 : 1)
            .disabled(isDefault)
            .animation(.easeOut(duration: 0.15), value: isDefault)
            .accessibilityLabel("Restore default name for \(bucket.displayName)")
        }
        .task { draft = settings.name(for: bucket) }
    }

    private func commit() {
        settings.setName(draft == bucket.displayName ? "" : draft, for: bucket)
        draft = settings.name(for: bucket)
    }
}

// MARK: - Workspaces

/// One row per workspace (rename inline; Delete folds its tasks back into the
/// default workspace), plus an add row. The default workspace is renamable but
/// not deletable — there must always be somewhere for tasks to live.
private struct WorkspacesSection: View {
    @Environment(\.pixel) private var pixel
    @Environment(AppSettings.self) private var settings
    @Environment(TaskStore.self) private var store

    /// Owned by the screen now, not this section — Tab names shares it.
    let buttonColumn: CGFloat

    @State private var newName = ""
    @FocusState private var addFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Win95.Px.grid * pixel) {
            ForEach(store.workspaces(), id: \.id) { workspace in
                WorkspaceRow(workspace: workspace, buttonColumn: buttonColumn) {
                    if settings.currentWorkspaceID == workspace.id {
                        settings.currentWorkspaceID = Workspace.defaultID
                    }
                    store.deleteWorkspace(workspace) // its tasks fold into the default
                }
            }

            HStack(spacing: Win95.Px.grid * pixel) {
                TextField("New workspace", text: $newName)
                    .font(W95Font.standard(pixel))
                    .foregroundStyle(Win95.text)
                    .focused($addFocused)
                    .submitLabel(.done)
                    .onSubmit { add() }
                    .padding(.horizontal, Win95.Px.grid * pixel)
                    .frame(minHeight: Win95.rowHeight(pixel))
                    .background(Win95.well)
                    .bevelSunken(pixel)

                Win95Button(action: add, compact: true, width: buttonColumn) {
                    Text("Add")
                        .font(W95Font.small(pixel))
                        .foregroundStyle(Win95.text)
                }
                .accessibilityLabel("Add workspace")
            }
        }
    }

    private func add() {
        // Refused (empty, or the name is already taken): the typed text and
        // the focus STAY, so the field visibly did not accept it. Clearing
        // both is what made a duplicate name look like a dead button.
        guard store.addWorkspace(named: newName) != nil else { return }
        newName = ""
        addFocused = false
    }
}

private struct WorkspaceRow: View {
    @Environment(\.pixel) private var pixel
    /// Read only to re-render on a typeface change — the face is a
    /// static this view cannot otherwise see. See `\.appFace`.
    @Environment(\.appFace) private var face
    @Environment(TaskStore.self) private var store
    let workspace: Workspace
    let buttonColumn: CGFloat
    var onDelete: () -> Void

    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: Win95.Px.grid * pixel) {
            TextField(workspace.name, text: $draft)
                .font(W95Font.standard(pixel))
                .foregroundStyle(Win95.text)
                .focused($focused)
                .submitLabel(.done)
                .onSubmit { commit() }
                .onChange(of: focused) { _, isFocused in
                    if !isFocused { commit() }
                }
                .padding(.horizontal, Win95.Px.grid * pixel)
                .frame(minHeight: Win95.rowHeight(pixel))
                .background(Win95.well)
                .bevelSunken(pixel)

            if workspace.isDefault {
                // The default workspace can't be deleted, but it still holds
                // the column open so its name field matches every other row.
                Color.clear.frame(width: buttonColumn, height: 1)
            } else {
                Win95Button(action: onDelete, compact: true, width: buttonColumn) {
                    Text("Delete")
                        .font(W95Font.small(pixel))
                        .foregroundStyle(Win95.important)
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
