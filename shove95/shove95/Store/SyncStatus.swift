//
//  SyncStatus.swift
//  shove95
//
//  What Settings tells you about iCloud, and nothing more (TASK-052, FR-013).
//
//  The rule from the PRD: sync is SILENT. No alerts, no spinners, no "syncing…"
//  banners, no retry buttons. A signed-out account is not an error state — the
//  app is fully usable locally and always has been. The only thing the user is
//  ever offered is one line of text in Settings, and only if they go looking.
//

import SwiftUI
import CloudKit

@Observable @MainActor
final class SyncStatus {
    enum Mode: Equatable {
        /// The CloudKit-backed store opened.
        case syncing
        /// The store opened locally; sync is off for the reason given.
        case localOnly(reason: String)
        /// Nothing on disk would open — running from memory this launch.
        case unavailable(reason: String)
    }

    private(set) var mode: Mode
    private(set) var accountStatus: CKAccountStatus?

    init(mode: Mode = .localOnly(reason: "not configured")) {
        self.mode = mode
        refreshAccountStatus()
    }

    /// Re-checked whenever the app becomes active, because the answer changes
    /// outside the app: the user signs in, or switches iCloud Drive off.
    ///
    /// Guarded by the same entitlement flag as the store: constructing a
    /// CKContainer the app isn't entitled to raises an Objective-C exception
    /// that Swift cannot catch.
    func refreshAccountStatus() {
        guard case .syncing = mode else { return }
        Task { @MainActor in
            accountStatus = try? await CKContainer(
                identifier: "iCloud.com.lucasmaher.shove95"
            ).accountStatus()
        }
    }

    /// One line, lower case, no punctuation drama — the app's voice.
    var summary: String {
        switch mode {
        case .unavailable:
            return "storage unavailable — this session only"
        case .localOnly:
            return "this device only"
        case .syncing:
            switch accountStatus {
            case .available: return "iCloud: on"
            case .noAccount: return "iCloud: not signed in"
            case .restricted: return "iCloud: restricted"
            case .couldNotDetermine, .temporarilyUnavailable: return "iCloud: unavailable"
            case .none: return "iCloud: checking"
            @unknown default: return "iCloud: unavailable"
            }
        }
    }

    /// True when something is genuinely wrong rather than merely off — the
    /// only case worth colouring.
    var isDegraded: Bool {
        if case .unavailable = mode { return true }
        return false
    }
}
