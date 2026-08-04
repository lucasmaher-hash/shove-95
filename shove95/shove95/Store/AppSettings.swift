//
//  AppSettings.swift
//  shove95
//
//  User preferences: colour scheme and custom tab names. Persisted in
//  UserDefaults — these are device preferences, not task data, so they
//  deliberately stay out of the synced SwiftData store.
//

import SwiftUI
import Shove95Kit

@Observable @MainActor
final class AppSettings {
    private enum Key {
        static let scheme = "settings.scheme"
        static func name(_ bucket: Bucket) -> String { "settings.name.\(bucket.rawValue)" }
    }

    var scheme: Win95Scheme {
        didSet {
            UserDefaults.standard.set(scheme.id, forKey: Key.scheme)
            Win95.scheme = scheme
        }
    }

    /// Custom tab labels. Empty string = use the built-in name.
    private var customNames: [Bucket: String]

    init() {
        let stored = UserDefaults.standard.string(forKey: Key.scheme) ?? Win95Scheme.classic.id
        scheme = Win95Scheme.named(stored)
        Win95.scheme = Win95Scheme.named(stored)

        var names: [Bucket: String] = [:]
        for bucket in Bucket.line {
            if let value = UserDefaults.standard.string(forKey: Key.name(bucket)), !value.isEmpty {
                names[bucket] = value
            }
        }
        customNames = names
    }

    /// The label to show for a bucket — the user's name if set, else the default.
    /// Bucket semantics never change; only the label does.
    func name(for bucket: Bucket) -> String {
        customNames[bucket] ?? bucket.displayName
    }

    /// Abbreviated label for the 4× taskbar.
    func shortName(for bucket: Bucket) -> String {
        if let custom = customNames[bucket] {
            return String(custom.prefix(3))
        }
        return bucket.shortName
    }

    func setName(_ raw: String, for bucket: Bucket) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            customNames.removeValue(forKey: bucket)
            UserDefaults.standard.removeObject(forKey: Key.name(bucket))
        } else {
            customNames[bucket] = trimmed
            UserDefaults.standard.set(trimmed, forKey: Key.name(bucket))
        }
    }

    func resetName(for bucket: Bucket) {
        setName("", for: bucket)
    }
}
