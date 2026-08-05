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
                    VStack(alignment: .leading, spacing: Win95.Px.grid * 2 * pixel) {
                        header("Appearance")
                        schemeRow

                        header("Typeface").padding(.top, Win95.Px.grid * 2 * pixel)
                        faceRow

                        header("Tab names").padding(.top, Win95.Px.grid * 2 * pixel)
                        ForEach(Bucket.line, id: \.self) { bucket in
                            NameField(bucket: bucket)
                        }

                        header("Workspaces").padding(.top, Win95.Px.grid * 2 * pixel)
                        WorkspacesSection()

                        header("Data").padding(.top, Win95.Px.grid * 2 * pixel)
                        dataSection
                    }
                    .padding(Win95.Px.grid * 2 * pixel)
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
        .preferredColorScheme(.light)
        .fullScreenCover(isPresented: $showArchive) {
            ArchiveView { showArchive = false }
                .environment(\.pixel, pixel)
                .environment(\.win95Scheme, settings.scheme)
        }
        .fullScreenCover(isPresented: $showAbout) {
            AboutView { showAbout = false }
                .environment(\.pixel, pixel)
                .environment(\.win95Scheme, settings.scheme)
        }
    }

    /// Archive, one line of iCloud status, About. The status is a LINE, not a
    /// control: sync is silent (FR-013), so there is nothing here to press and
    /// nothing to retry.
    private var dataSection: some View {
        VStack(alignment: .leading, spacing: Win95.Px.grid * pixel) {
            Win95Button(action: { showArchive = true }, compact: true) {
                Text("Archive")
                    .font(W95Font.small(pixel))
                    .foregroundStyle(Win95.text)
            }
            .fixedSize()

            Text(sync.summary)
                .font(W95Font.small(pixel))
                .foregroundStyle(sync.isDegraded ? Win95.important : Win95.shadow)
                .fixedSize(horizontal: false, vertical: true)

            Win95Button(action: { showAbout = true }, compact: true) {
                Text("About")
                    .font(W95Font.small(pixel))
                    .foregroundStyle(Win95.text)
            }
            .fixedSize()
            .padding(.top, Win95.Px.grid * pixel)
        }
    }

    /// Two pressed-in choices, same idiom as the scheme swatches. The Win95
    /// face is the app; the system face is here because a bitmap-derived font
    /// is hard for some people to read, and legibility outranks costume.
    private var faceRow: some View {
        HStack(spacing: Win95.Px.grid * pixel) {
            ForEach(AppFace.allCases, id: \.self) { face in
                let isSelected = settings.face == face
                Text(face.label)
                    .font(face == .w95 ? W95Font.standard(pixel)
                                       : .system(size: Win95.Px.fontStandard * pixel * 0.82))
                    .foregroundStyle(Win95.text)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: Win95.rowHeight(pixel))
                    .background(Win95.surface)
                    .modifier(SwatchBevel(isSelected: isSelected, pixel: pixel))
                    .offset(x: isSelected ? pixel : 0, y: isSelected ? pixel : 0)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        var t = Transaction(); t.disablesAnimations = true
                        withTransaction(t) { settings.face = face }
                    }
                    .accessibilityLabel("\(face.label) typeface")
                    .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            }
        }
    }

    private func header(_ title: String) -> some View {
        Text(title)
            .font(W95Font.standard(pixel))
            .foregroundStyle(Win95.text)
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
/// name already is the default: a button that would do nothing shouldn't
/// invite a press.
private struct NameField: View {
    @Environment(\.pixel) private var pixel
    @Environment(AppSettings.self) private var settings
    let bucket: Bucket

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
            }, compact: true) {
                Text("Default")
                    .font(W95Font.small(pixel))
                    .foregroundStyle(Win95.text)
            }
            .fixedSize()
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

    @State private var newName = ""
    @FocusState private var addFocused: Bool

    /// One trailing column for the whole section: Delete, Add, and the empty
    /// slot on the undeletable default workspace all reserve this width, so
    /// every name field ends at the same x (founder request 2026-08-04).
    /// Sized to the longest label at any pixel scale.
    private var buttonColumn: CGFloat { Win95.Px.grid * 12 * pixel }

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
        store.addWorkspace(named: newName)
        newName = ""
        addFocused = false
    }
}

private struct WorkspaceRow: View {
    @Environment(\.pixel) private var pixel
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
