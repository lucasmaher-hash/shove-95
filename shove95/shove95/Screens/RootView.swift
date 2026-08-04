//
//  RootView.swift
//  shove95
//
//  The phone as a maximized Win95 window (design.md §5):
//    title bar · sunken list well · taskbar
//  The frame is fixed; only content moves through it. Tab changes slide the
//  list contents in from the side the tab lives on, while the title bar, well
//  and taskbar hold still (design.md §8, amended 2026-08-04).
//

import SwiftUI
import Shove95Kit

struct RootView: View {
    @State private var selected: Bucket = .today
    @State private var showSettings = false
    @State private var showWorkspaceMenu = false
    @Environment(\.pixel) private var pixel
    @Environment(TaskStore.self) private var store
    @Environment(AppSettings.self) private var settings
    @State private var menu = MenuCoordinator()
    @State private var reorder = ReorderCoordinator()
    @State private var editing = EditingCoordinator()

    /// Which way the last tab change travelled — decided before `selected`
    /// moves, so both halves of the transition agree on a direction.
    @State private var goingRight = true

    /// Wraps the taskbar's binding so a tap resolves direction and animates.
    private var tabSelection: Binding<Bucket> {
        Binding(
            get: { selected },
            set: { newValue in
                guard newValue != selected,
                      let from = Bucket.line.firstIndex(of: selected),
                      let to = Bucket.line.firstIndex(of: newValue) else { return }
                goingRight = to > from
                // Fast and flat: this is a pane sliding across, not a bounce.
                withAnimation(.easeOut(duration: 0.22)) { selected = newValue }
            }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            TitleBar(
                title: settings.name(for: selected),
                workspace: settings.currentWorkspace.name,
                workspaceMenuOpen: showWorkspaceMenu,
                onWorkspace: {
                    withAnimation(.spring(duration: 0.26, bounce: 0.38)) {
                        showWorkspaceMenu.toggle()
                    }
                }
            ) {
                showSettings = true
            }
            // The tab slide must not drag the title along with it: text swaps
            // are appearance, and appearance is instant (design.md §8).
            // Without this the two titles crossfade through each other.
            .transaction { $0.animation = nil }

            // Tabs slide in from the side they live on: tapping a tab to the
            // right brings its list in from the right. Only the list travels —
            // the title bar and taskbar are window furniture and stay put, so
            // the frame reads as fixed and the content as moving through it.
            SunkenWell {
                ZStack {
                    TaskListView(bucket: selected)
                        .id(selected)
                        .transition(.asymmetric(
                            insertion: .move(edge: goingRight ? .trailing : .leading),
                            removal: .move(edge: goingRight ? .leading : .trailing)
                        ))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped() // contents travel; the well never does
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // The status panel floats over the list rather than taking layout
            // space, so it can appear and vanish without shifting the rows —
            // and it sits outside the slide, so it doesn't ride along.
            .overlay(alignment: .bottom) {
                if let action = store.lastAction {
                    Win95StatusPanel(text: action.statusText(name: settings.name)) {
                        withAnimation(.spring(duration: 0.25)) { store.undoLastAction() }
                    }
                    // Retires itself; any further mutation restarts the clock.
                    .task(id: store.revision) {
                        try? await Task.sleep(for: .seconds(6))
                        if !Task.isCancelled { store.dismissLastAction() }
                    }
                }
            }

            Taskbar(selected: tabSelection)
        }
        // Win95 palettes are read through static accessors, so the chrome is
        // rebuilt wholesale when the scheme changes. The .id sits INSIDE the
        // presentation modifiers — rebuilding above them would tear down
        // `showSettings` and slam the Settings window shut on every pick.
        .id(settings.scheme.id)
        .background(Win95.surface)
        // The taskbar is window furniture — it stays docked at the bottom
        // instead of riding up with the keyboard.
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .environment(menu)
        .environment(reorder)
        .environment(editing)
        // Workspace dropdown — drops from the title bar's leading edge, the
        // way a Win95 menu drops from a menu-bar title. Same spring as the
        // row menu; same flat, fast exit.
        .overlay(alignment: .topLeading) {
            if showWorkspaceMenu {
                ZStack(alignment: .topLeading) {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { closeWorkspaceMenu() }

                    WorkspaceMenu(onPick: { id in
                        closeWorkspaceMenu()
                        settings.currentWorkspaceID = id
                    })
                    .offset(x: Win95.Px.grid * pixel, y: Win95.Px.titleBar * pixel)
                    .transition(.scale(scale: 0.86, anchor: .topLeading)
                        .combined(with: .opacity))
                }
            }
        }
        // The store's queries are all scoped to the active workspace; keep it
        // pointed at the one the user picked, including across relaunches.
        .onAppear {
            store.reclaimOrphanedTasks(knownIDs: settings.knownWorkspaceStampIDs)
            store.workspaceID = settings.currentWorkspace.taskStampID
        }
        .onChange(of: settings.currentWorkspaceID) {
            store.workspaceID = settings.currentWorkspace.taskStampID
        }
        // Closing the menu also disarms, restoring scrolling. A live drag keeps
        // its armed state — it dismisses the menu the moment it starts moving.
        .onChange(of: menu.request?.taskID) { _, id in
            if id == nil { reorder.disarm() }
        }
        .overlay { MenuOverlay().environment(menu) }
        .preferredColorScheme(.light) // Win95 has no dark mode (design.md §1)
        .onReceive(NotificationCenter.default.publisher(
            for: UIApplication.significantTimeChangeNotification)) { _ in
            // Fires at midnight, timezone changes, clock changes (PRD §2).
            store.runDayRolloverPassIfNeeded()
        }
        .onChange(of: showSettings) { _, open in
            if open { closeWorkspaceMenu() }
        }
        // Full-screen, not a sheet: sheets bring rounded corners and a drag
        // indicator, both prohibited (design.md §9).
        .fullScreenCover(isPresented: $showSettings) {
            SettingsView { showSettings = false }
                .environment(settings)
                .environment(\.pixel, pixel)
                // Presented content doesn't sit under RootView's `.id` rebuild,
                // so the scheme has to reach it explicitly.
                .environment(\.win95Scheme, settings.scheme)
        }
    }

    private func closeWorkspaceMenu() {
        guard showWorkspaceMenu else { return }
        withAnimation(.easeOut(duration: 0.11)) { showWorkspaceMenu = false }
    }
}

// MARK: - Workspace dropdown

/// The list of workspaces as a Win95 menu panel. The active one renders as a
/// pressed row (selection colours), matching the taskbar's pressed-tab idiom.
private struct WorkspaceMenu: View {
    @Environment(\.pixel) private var pixel
    @Environment(AppSettings.self) private var settings
    var onPick: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(settings.workspaces) { workspace in
                let isCurrent = workspace.id == settings.currentWorkspaceID
                Text(workspace.name)
                    .font(W95Font.standard(pixel))
                    .foregroundStyle(isCurrent ? Win95.selectionText : Win95.text)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Win95.Px.grid * pixel)
                    .frame(minHeight: Win95.rowHeight(pixel))
                    .background(isCurrent ? Win95.selectionBG : Win95.surface)
                    .contentShape(Rectangle())
                    .onTapGesture { onPick(workspace.id) }
                    .accessibilityAddTraits(isCurrent ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(pixel * 2)
        .frame(minWidth: Win95.Px.buttonMinWidth * pixel * 1.6, alignment: .leading)
        .fixedSize()
        .background(Win95.surface)
        .bevelRaised(pixel)
    }
}
