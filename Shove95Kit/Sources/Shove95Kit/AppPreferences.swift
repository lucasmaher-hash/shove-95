import Foundation
import SwiftData

/// Preferences that follow the ACCOUNT rather than the device.
///
/// Most settings are deliberately local — text size, and which workspace you
/// happen to be looking at, belong to the device you're holding. The colour
/// scheme is different: it's the app's identity, and the founder wants the
/// same one everywhere (2026-08-04).
///
/// A singleton record with a fixed id. CloudKit forbids unique constraints, so
/// two devices can both create one before they've seen each other; readers
/// dedupe by id, oldest wins — the same rule as `Workspace`.
@Model
public final class AppPreferences {
    public var id: String = AppPreferences.singletonID
    public var schemeID: String = "classic"
    public var createdAt: Date = Date.now

    public init() {}

    public static let singletonID = "app"
}
