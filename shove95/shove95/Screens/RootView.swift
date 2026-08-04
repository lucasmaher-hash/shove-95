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
    @State private var menu = MenuCoordinator()

    var body: some View {
        VStack(spacing: 0) {
            TitleBar(title: "\(selected.displayName) - shove.95") {
                showSettings = true
            }

            TaskListView(bucket: selected)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            #if DEBUG
            debugBar
            #endif

            Win95StatusBar(
                text: store.lastAction?.statusText ?? "",
                onUndo: store.lastAction == nil ? nil : {
                    withAnimation(.spring(duration: 0.25)) { store.undoLastAction() }
                }
            )

            Taskbar(selected: $selected)
        }
        .background(Win95.surface)
        .environment(menu)
        .overlay { MenuOverlay().environment(menu) }
        .preferredColorScheme(.light) // Win95 has no dark mode (design.md §1)
        .onReceive(NotificationCenter.default.publisher(
            for: UIApplication.significantTimeChangeNotification)) { _ in
            // Fires at midnight, timezone changes, clock changes (PRD §2).
            store.runDayRolloverPassIfNeeded()
        }
        .sheet(isPresented: $showSettings) {
            // Placeholder until Phase 5 builds the real Settings window.
            VStack(spacing: 16) {
                Text("Settings")
                    .font(W95Font.standard(pixel))
                    .foregroundStyle(Win95.text)
                Text("Archive · iCloud · About arrive in Phase 5.")
                    .font(W95Font.small(pixel))
                    .foregroundStyle(Win95.shadow)
                Win95Button(action: { showSettings = false }) {
                    Text("Close")
                        .font(W95Font.small(pixel))
                        .foregroundStyle(Win95.text)
                }
                .fixedSize()
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Win95.surface)
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
