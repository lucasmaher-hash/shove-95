//
//  RootView.swift
//  shove95
//
//  The phone as a maximized Win95 window (design.md §5):
//    title bar · sunken list well · status bar · taskbar
//  Tab switching is INSTANT — motion describes position only (design.md §8).
//

import SwiftUI
import Shove95Kit

struct RootView: View {
    @State private var selected: Bucket = .today
    @State private var showSettings = false
    @Environment(\.pixel) private var pixel
    @Environment(TaskStore.self) private var store
    @Environment(AppSettings.self) private var settings
    @State private var menu = MenuCoordinator()

    var body: some View {
        VStack(spacing: 0) {
            TitleBar(title: "\(settings.name(for: selected)) - shove.95") {
                showSettings = true
            }

            // The status panel floats over the list rather than taking layout
            // space, so it can appear and vanish without shifting the rows.
            TaskListView(bucket: selected)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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

            #if DEBUG
            debugBar
            #endif

            Taskbar(selected: $selected)
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
        .overlay { MenuOverlay().environment(menu) }
        .preferredColorScheme(.light) // Win95 has no dark mode (design.md §1)
        .onReceive(NotificationCenter.default.publisher(
            for: UIApplication.significantTimeChangeNotification)) { _ in
            // Fires at midnight, timezone changes, clock changes (PRD §2).
            store.runDayRolloverPassIfNeeded()
        }
        // Full-screen, not a sheet: sheets bring rounded corners and a drag
        // indicator, both prohibited (design.md §9).
        .fullScreenCover(isPresented: $showSettings) {
            SettingsView { showSettings = false }
                .environment(settings)
                .environment(\.pixel, pixel)
        }
    }

    #if DEBUG
    private var debugBar: some View {
        HStack(spacing: 12) {
            Button("Seed") { store.seedDebugData() }
            Button("Fillers") { store.seedScrollFillers() }
            Button("Defer 1st") {
                if let first = store.tasks(in: .today).active.first {
                    store.step(first, direction: .deferOne)
                }
            }
            Spacer()
        }
        .font(.caption2)
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(Win95.surface)
    }
    #endif
}
