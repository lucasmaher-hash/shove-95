import Foundation
import SwiftData

/// A named container for tasks — Personal, Work, Design…
///
/// A SYNCED RECORD, not a device preference (changed 2026-08-04). It began as
/// a UserDefaults entry with a random id, which broke the moment a second
/// device appeared: tasks reference a workspace BY id, so every task arriving
/// from another device carried an id this one had never seen and fell into the
/// default workspace. Which workspace you are *currently looking at* remains
/// local — that genuinely is per-device view state.
///
/// CloudKit-compatible by construction: every property defaulted, no `#Unique`.
/// Uniqueness is therefore not enforced by the store, so `id` is DETERMINISTIC
/// for the seeded pair and readers dedupe — see `TaskStore.workspaces()`.
@Model
public final class Workspace {
    /// Stable across devices. The seeded pair use fixed ids so two devices
    /// seeding independently converge instead of doubling up.
    public var id: String = Workspace.defaultID
    public var name: String = ""
    public var createdAt: Date = Date.now

    public init() {}

    public init(id: String, name: String, createdAt: Date = .now) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
    }

    /// The undeletable workspace every task falls back to.
    public static let defaultID = "default"
    public static let workID = "work"

    public var isDefault: Bool { id == Self.defaultID }

    /// What gets stamped on `TaskItem.workspaceID`: nil for the default, so
    /// tasks written before workspaces existed belong to it automatically.
    public var taskStampID: String? { isDefault ? nil : id }
}
