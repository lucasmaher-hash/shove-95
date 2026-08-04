//
//  shove95App.swift
//  shove95
//
//  Created by Lucas Maher on 03.08.26.
//

import SwiftUI
import SwiftData
import Shove95Kit

@main
struct shove95App: App {
    private let container: ModelContainer
    @State private var store: TaskStore
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Local-only for now; the model is CloudKit-compatible by construction
        // and Phase 5 flips this to .private("iCloud.com.lucasmaher.shove95").
        let configuration = ModelConfiguration(cloudKitDatabase: .none)
        let container = try! ModelContainer(for: TaskItem.self, configurations: configuration)
        self.container = container
        _store = State(initialValue: TaskStore(context: container.mainContext))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .modifier(PixelScale()) // stepped 2×/3×/4× (FR-015)
        }
        .modelContainer(container)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                // Day-rollover placement pass — cheap and idempotent (PRD §2).
                store.runDayRolloverPassIfNeeded()
            }
        }
    }
}
