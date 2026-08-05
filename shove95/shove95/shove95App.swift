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
    @State private var settings = AppSettings()
    @State private var sync = SyncStatus()
    /// Late splash: shown only if the first frame is slow, and then held long
    /// enough not to flicker. See LaunchCover.
    @State private var showLaunchCover = false
    @State private var launchSettled = false
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let (container, mode) = Self.makeContainer()
        self.container = container
        _store = State(initialValue: TaskStore(context: container.mainContext))
        _sync = State(initialValue: SyncStatus(mode: mode))
    }

    /// Sync when it's provisioned, local otherwise — and NEVER a crash.
    ///
    /// The gate is a real one, not caution: with `cloudKitDatabase: .private`
    /// and no iCloud entitlement, CoreData's mirroring delegate calls
    /// `CKContainer(identifier:)`, which raises an OBJECTIVE-C exception on a
    /// background queue. Swift `try/catch` cannot see it and the app dies on
    /// launch (verified 2026-08-04). So the CloudKit path is only taken when
    /// the entitlement actually exists, which the Info.plist flag records —
    /// see docs/cloudkit-setup.md for the two-minute Xcode step that sets it.
    static var cloudKitEnabled: Bool {
        Bundle.main.object(forInfoDictionaryKey: "ShoveCloudKitEnabled") as? Bool ?? false
    }

    private static func makeContainer() -> (ModelContainer, SyncStatus.Mode) {
        let models: [any PersistentModel.Type] = [TaskItem.self, TaskPhoto.self, Workspace.self, AppPreferences.self]
        let schema = Schema(models)

        do {
            guard cloudKitEnabled else {
                let local = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
                return (try ModelContainer(for: schema, configurations: local),
                        .localOnly(reason: "iCloud not enabled for this build"))
            }
            let cloud = ModelConfiguration(
                schema: schema,
                cloudKitDatabase: .private("iCloud.com.lucasmaher.shove95")
            )
            return (try ModelContainer(for: schema, configurations: cloud), .syncing)
        } catch {
            // Local store, same schema — the data is identical, only the
            // mirroring is absent.
            let local = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
            if let container = try? ModelContainer(for: schema, configurations: local) {
                return (container, .localOnly(reason: error.localizedDescription))
            }
            // Nothing on disk works: an in-memory store still lets the app run
            // rather than crash on launch. Nothing written here survives.
            let memory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            let container = try! ModelContainer(for: schema, configurations: memory)
            return (container, .unavailable(reason: error.localizedDescription))
        }
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootView()
                .environment(store)
                .environment(settings)
                .environment(sync)
                .environment(\.win95Scheme, settings.scheme)
                .modifier(PixelScale()) // stepped 2×/3×/4× (FR-015)
                .task {
                    // Photos moved into their own records for CloudKit; this
                    // lifts anything still in the old fields. Idempotent.
                    store.migrateLegacyPhotos()
                }
                #if DEBUG
                // Seeding by launch argument keeps the debug controls off the
                // screen: `simctl launch … -seedFillers YES`.
                .task {
                    if UserDefaults.standard.bool(forKey: "seedFillers") {
                        store.seedScrollFillers()
                    }
                }
                #endif

                if showLaunchCover { LaunchCover() }
            }
            .task {
                // If the app is ready inside this window, no cover at all.
                try? await Task.sleep(for: .milliseconds(220))
                guard !launchSettled else { return }
                withAnimation(.easeOut(duration: 0.15)) { showLaunchCover = true }
                // Held so a brief appearance doesn't read as a flicker.
                try? await Task.sleep(for: .milliseconds(600))
                withAnimation(.easeOut(duration: 0.25)) { showLaunchCover = false }
            }
            .task {
                // "Ready" = the first query has returned. Cheap, and it is the
                // thing that actually takes time on a cold CloudKit launch.
                _ = store.tasks(in: .today)
                launchSettled = true
                if showLaunchCover {
                    try? await Task.sleep(for: .milliseconds(400))
                    withAnimation(.easeOut(duration: 0.25)) { showLaunchCover = false }
                }
            }
        }
        .modelContainer(container)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                // Day-rollover placement pass — cheap and idempotent (PRD §2).
                store.runDayRolloverPassIfNeeded()
                sync.refreshAccountStatus()
            }
        }
    }
}
