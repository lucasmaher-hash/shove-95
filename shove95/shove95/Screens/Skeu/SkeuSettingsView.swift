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

    /// NOT the transcribed 123.077 × q (56.9). That figure is proportional to
    /// the reference card's 800pt width, but these panels are squat — at their
    /// height the same radius reads as a capsule, which the founder rejected
    /// against the reference's clearly squarer corners (2026-08-13).
    static let cardRadius: CGFloat = 30
    /// The stroke width of the TROUGHS at their on-screen size — the founder
    /// wants one identical contour on both, so this is the trough formula
    /// (7 × height/148.2) evaluated at the trough height used below.
    static let cardRim = 7 * (66.4 / 148.2) // 3.1
    static let cardPad = 46.154 * q         // 21.3
    static let sectionGap = 46.154 * q      // 21.3

    static let troughPad = 30.769 * q       // 14.2
    static let pillPadH = 36.923 * q        // 17.1
    static let pillPadV = 24.615 * q        // 11.4
    static let pillHeight: CGFloat = 38     // 12.8 text + 2 × 11.4, rounded
    static let label: CGFloat = 12.8
    static let icon = 30.769 * q            // 14.2

    /// Input rows: a trough one notch shorter than an option trough, so a
    /// stack of fields doesn't out-weigh the choices above it.
    static let fieldHeight: CGFloat = 46
    static let pillSmall: CGFloat = 30
    static let circle = 80 * q              // 37 — the round corner button
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
    private var pillSmallH: CGFloat { G.pillSmall * chromeScale }
    private var circleSize: CGFloat { G.circle * chromeScale }
    @Environment(\.skeu) private var skeu
    @Environment(AppSettings.self) private var settings
    @Environment(TaskStore.self) private var store
    @Environment(SyncStatus.self) private var sync
    @State private var showArchive = false
    @State private var showAbout = false
    @State private var newWorkspace = ""
    @FocusState private var addWorkspaceFocused: Bool
    var onClose: () -> Void

    var body: some View {
        ZStack {
            skeu.canvas.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: G.sectionGap) {
                    header

                    panel("Design") {
                        ForEach(DesignMode.allCases, id: \.self) { mode in
                            option(mode.label,
                                   selected: settings.design == mode) {
                                settings.design = mode
                            }
                        }
                    }

                    panel("Light & dark") {
                        ForEach(AppearanceMode.allCases, id: \.self) { mode in
                            option(mode.label,
                                   selected: settings.appearance == mode) {
                                settings.appearance = mode
                            }
                        }
                    }

                    panel("Theme") {
                        ForEach(SkeuTheme.all) { theme in
                            swatchOption(theme,
                                         selected: settings.skeuTheme.id == theme.id) {
                                settings.skeuTheme = theme
                            }
                        }
                    }

                    panel("Typeface") {
                        ForEach(AppFace.allCases, id: \.self) { face in
                            option(face.label,
                                   selected: settings.skeuFace == face) {
                                settings.skeuFace = face
                            }
                        }
                    }

                    tabNamesPanel
                    workspacesPanel
                    dataPanel
                }
                .padding(.horizontal, 21.5) // the screen margin of the root
                .padding(.vertical, SkeuSpace.md)
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

                field(text: $newWorkspace, prompt: "New workspace",
                      focused: $addWorkspaceFocused) {
                    trailingPill("Add") { addWorkspace() }
                }
            }
        }
    }

    private func addWorkspace() {
        store.addWorkspace(named: newWorkspace)
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
                    .font(.system(size: labelSize))
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
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(skeu.ink)
                    .frame(width: circleSize, height: circleSize)
                    .skeuGlass(Circle(), height: circleSize)
            }
            .buttonStyle(.plain)
            .frame(minWidth: SkeuControl.minTouch, minHeight: SkeuControl.minTouch)
            .accessibilityLabel("Close settings")
        }
    }

    // MARK: Panels

    /// One setting = one CARD, carrying its label and a trough with every
    /// option. The card is the reference's sheet construction at panel size.
    private func panel<C: View>(_ title: String,
                                @ViewBuilder options: () -> C) -> some View {
        // Concrete rather than skeuShape(): that helper erases to AnyShape,
        // which cannot strokeBorder, and the rim needs its inset stroke.
        let shape = RoundedRectangle(cornerRadius: G.cardRadius, style: .continuous)

        return VStack(alignment: .leading, spacing: SkeuSpace.sm) {
            Text(title)
                .font(SkeuFont.eyebrow)
                .textCase(.uppercase)
                .tracking(0.8)
                .foregroundStyle(skeu.inkFaint)

            HStack(spacing: SkeuSpace.sm) {
                options()
            }
            .padding(G.troughPad)
            .frame(maxWidth: .infinity)
            .skeuTrough(Capsule(),
                        height: pillH + G.troughPad * 2)
        }
        .padding(G.cardPad)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            // The frame lights its card with two soft glow blobs; a diagonal
            // gradient carries the same top-left-lit read without an asset.
            shape.fill(
                LinearGradient(colors: [skeu.materialTop, skeu.material, skeu.materialBottom],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            )
        }
        // The SAME contour the troughs wear — identical thickness, colours and
        // ramp (founder direction 2026-08-13: one stroke construction for the
        // outer frames and the inner ones). The white rim of the Figma card is
        // superseded.
        //
        // MIRRORED, though: the trough is carved in, so its lip is dark on top
        // and lit at the bottom. The card is raised — the same edge catches
        // the light on top and falls into shade below. Copying the trough's
        // orientation verbatim put the light on the wrong side (founder catch,
        // 2026-08-13).
        .overlay {
            shape.strokeBorder(
                LinearGradient(
                    stops: [.init(color: skeu.outlineBottom, location: 0.0),
                            .init(color: skeu.outline, location: 0.55),
                            .init(color: skeu.outline, location: 1.0)],
                    startPoint: .top, endPoint: .bottom),
                lineWidth: G.cardRim)
        }
        .shadow(color: drop(0.19), radius: 26.8, x: -6.5, y: 10.6)
        .shadow(color: drop(0.16), radius: 49, x: -25.4, y: 42)
    }

    /// A labelled option pill. Options share the trough's width evenly, as the
    /// reference pill fills its trough.
    private func option(_ title: String,
                        selected: Bool,
                        action: @escaping () -> Void) -> some View {
        Button {
            SkeuHaptic.selection()
            action()
        } label: {
            Text(title)
                .font(.system(size: labelSize))
                .tracking(-0.02 * G.label)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .foregroundStyle(selected ? skeu.ink : skeu.inkMuted)
                .padding(.horizontal, G.pillPadH * 0.6)
                .frame(maxWidth: .infinity)
                .frame(height: pillH)
                .skeuGlass(Capsule(), height: pillH, prominent: selected)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    /// A colour-swatch pill for the theme row — five must share one trough, so
    /// they carry a dot instead of a name.
    private func swatchOption(_ theme: SkeuTheme,
                              selected: Bool,
                              action: @escaping () -> Void) -> some View {
        Button {
            SkeuHaptic.selection()
            action()
        } label: {
            Circle()
                .fill(theme.light.material)
                .overlay { Circle().strokeBorder(.white.opacity(0.5), lineWidth: 1) }
                .frame(width: G.icon, height: G.icon)
                .frame(maxWidth: .infinity)
                .frame(height: pillH)
                .skeuGlass(Capsule(), height: pillH, prominent: selected)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(theme.name) theme")
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    /// A panel whose content is NOT a single option trough — used where the
    /// setting is a list of fields rather than a choice. Same card, same
    /// contour; only the inside differs.
    private func card<C: View>(_ title: String,
                               @ViewBuilder content: () -> C) -> some View {
        let shape = RoundedRectangle(cornerRadius: G.cardRadius, style: .continuous)

        return VStack(alignment: .leading, spacing: SkeuSpace.sm) {
            Text(title)
                .font(SkeuFont.eyebrow)
                .textCase(.uppercase)
                .tracking(0.8)
                .foregroundStyle(skeu.inkFaint)

            content()
        }
        .padding(G.cardPad)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            shape.fill(
                LinearGradient(colors: [skeu.materialTop, skeu.material, skeu.materialBottom],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            )
        }
        .overlay {
            shape.strokeBorder(
                LinearGradient(
                    stops: [.init(color: skeu.outlineBottom, location: 0.0),
                            .init(color: skeu.outline, location: 0.55),
                            .init(color: skeu.outline, location: 1.0)],
                    startPoint: .top, endPoint: .bottom),
                lineWidth: G.cardRim)
        }
        .shadow(color: drop(0.19), radius: 26.8, x: -6.5, y: 10.6)
        .shadow(color: drop(0.16), radius: 49, x: -25.4, y: 42)
    }

    /// A text field in a trough, with an optional control at its trailing end.
    /// §9.7: inputs are recessed — the same channel everything else uses.
    @ViewBuilder
    private func field<T: View>(text: Binding<String>,
                                prompt: String,
                                focused: FocusState<Bool>.Binding,
                                @ViewBuilder trailing: () -> T) -> some View {
        HStack(spacing: SkeuSpace.sm) {
            TextField("", text: text,
                      prompt: Text(prompt).foregroundStyle(skeu.inkFaint))
                .font(.system(size: labelSize))
                .foregroundStyle(skeu.ink)
                .focused(focused)
                .submitLabel(.done)

            trailing()
        }
        .padding(.leading, SkeuSpace.lg)
        .padding(.trailing, SkeuSpace.sm)
        .frame(height: fieldH)
        .skeuTrough(Capsule(), height: fieldH)
    }

    /// A small glass pill sitting inside a field's trough.
    private func trailingPill(_ title: String, action: @escaping () -> Void) -> some View {
        Text(title)
            .font(.system(size: labelSize * 0.9, weight: .medium))
            .foregroundStyle(skeu.ink)
            .lineLimit(1)
            .padding(.horizontal, SkeuSpace.md)
            .frame(height: pillSmallH)
            .skeuGlass(Capsule(), height: pillSmallH)
            .contentShape(Capsule())
            .onTapGesture {
                SkeuHaptic.press()
                action()
            }
            .accessibilityAddTraits(.isButton)
    }

    /// A standalone action pill — no trough behind it, it IS the control.
    private func actionPill(_ title: String, action: @escaping () -> Void) -> some View {
        Text(title)
            .font(.system(size: labelSize, weight: .medium))
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

    private func drop(_ alpha: Double) -> Color {
        skeu.shadow.opacity(alpha * skeu.shadowIntensity)
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
    private var pillH: CGFloat { G.pillHeight * chromeScale }
    private var pillSmallH: CGFloat { G.pillSmall * chromeScale }
    private var circleSize: CGFloat { G.circle * chromeScale }
    @Environment(\.skeu) private var skeu
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
                .font(.system(size: labelSize))
                .foregroundStyle(skeu.ink)
                .focused($focused)
                .submitLabel(.done)
                .onSubmit(commit)
                .onChange(of: focused) { _, isFocused in
                    if !isFocused { commit() }
                }

            Text("Default")
                .font(.system(size: labelSize * 0.9, weight: .medium))
                .foregroundStyle(skeu.ink)
                .lineLimit(1)
                .padding(.horizontal, SkeuSpace.md)
                .frame(height: pillSmallH)
                .skeuGlass(Capsule(), height: pillSmallH, prominent: !isDefault)
                .contentShape(Capsule())
                .onTapGesture {
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
        .padding(.leading, SkeuSpace.lg)
        .padding(.trailing, SkeuSpace.sm)
        .frame(height: fieldH)
        .skeuTrough(Capsule(), height: fieldH)
        .task { draft = settings.name(for: bucket) }
    }

    private func commit() {
        settings.setName(draft == bucket.displayName ? "" : draft, for: bucket)
        draft = settings.name(for: bucket)
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
    private var pillH: CGFloat { G.pillHeight * chromeScale }
    private var pillSmallH: CGFloat { G.pillSmall * chromeScale }
    private var circleSize: CGFloat { G.circle * chromeScale }
    @Environment(\.skeu) private var skeu
    @Environment(TaskStore.self) private var store
    let workspace: Workspace
    var onDelete: () -> Void

    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: SkeuSpace.sm) {
            TextField("", text: $draft,
                      prompt: Text(workspace.name).foregroundStyle(skeu.inkFaint))
                .font(.system(size: labelSize))
                .foregroundStyle(skeu.ink)
                .focused($focused)
                .submitLabel(.done)
                .onSubmit(commit)
                .onChange(of: focused) { _, isFocused in
                    if !isFocused { commit() }
                }

            // The default workspace can't be deleted — there must always be
            // somewhere for tasks to live.
            if !workspace.isDefault {
                Text("Delete")
                    .font(.system(size: labelSize * 0.9, weight: .medium))
                    .foregroundStyle(skeu.critical)
                    .lineLimit(1)
                    .padding(.horizontal, SkeuSpace.md)
                    .frame(height: pillSmallH)
                    .skeuGlass(Capsule(), height: pillSmallH)
                    .contentShape(Capsule())
                    .onTapGesture {
                        SkeuHaptic.warning()
                        onDelete()
                    }
                    .accessibilityLabel("Delete workspace \(workspace.name)")
            }
        }
        .padding(.leading, SkeuSpace.lg)
        .padding(.trailing, SkeuSpace.sm)
        .frame(height: fieldH)
        .skeuTrough(Capsule(), height: fieldH)
        .task { draft = workspace.name }
    }

    private func commit() {
        store.renameWorkspace(workspace, to: draft)
        draft = workspace.name
    }
}
