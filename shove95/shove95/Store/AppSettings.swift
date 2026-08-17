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
        static let design = "settings.design"
        static let appearance = "settings.appearance"
        static let skeuTheme = "settings.skeu.theme"
        static let skeuFace = "settings.skeu.face"
        // v2: the founder settled the default set at Personal + Work
        // (2026-08-04); the bump orphans pre-release test data.
        static let workspaces = "settings.workspaces.v2"
        static let currentWorkspace = "settings.workspace.current"
        static let language = "settings.language"
        static let colorSlot = "settings.color.slot"
        static let sharedSlot = "settings.color.shared"
        static func name(_ bucket: Bucket) -> String { "settings.name.\(bucket.rawValue)" }
    }

    /// The chosen interface language, as a BCP-47 code.
    ///
    /// Stored and shown, and read by nothing else yet — the option ships
    /// before the translations do (founder direction 2026-08-16). When strings
    /// arrive, this is the value that selects them; until then choosing
    /// Français changes what the picker says and nothing more, which
    /// `Language.isTranslated` lets the picker admit.
    var languageCode: String = Language.english_.code {
        didSet { UserDefaults.standard.set(languageCode, forKey: Key.language) }
    }

    var language: Language { Language.named(languageCode) }

    /// Always the LIGHT instance — it is what the picker shows and what syncs.
    /// The dark twin is resolved by id at paint time, in AppShell, which is
    /// the only place that knows the current lighting. Assigning `Win95.scheme`
    /// here as well would race that: this setter runs first with the light
    /// palette and the screen flashes it before AppShell corrects the value.
    /// The chosen colour, as a POSITION rather than a name (founder decision
    /// 2026-08-17). Slot 0 is Windows Standard and Cream, 1 is Desert and
    /// Clay, and so on: one setting, and the two looks cannot drift apart
    /// because neither owns it.
    ///
    /// Slot 5 is Silver, which only the skeu look has. While it is chosen the
    /// Windows look shows `sharedSlot` — the last colour that existed in both
    /// — rather than an invented sixth scheme.
    var colorSlot: Int = 0 {
        didSet {
            UserDefaults.standard.set(colorSlot, forKey: Key.colorSlot)
            if colorSlot < Win95Scheme.all.count {
                sharedSlot = colorSlot
            }
            Win95.scheme = scheme
        }
    }

    /// The last slot both looks could show. Only moves when a shared colour is
    /// picked, so choosing Silver and coming back lands where you left.
    private(set) var sharedSlot: Int = 0 {
        didSet { UserDefaults.standard.set(sharedSlot, forKey: Key.sharedSlot) }
    }

    /// Always a real Win95 scheme: silver falls back to the last shared slot.
    var scheme: Win95Scheme {
        Win95Scheme.all[min(sharedSlot, Win95Scheme.all.count - 1)]
    }

    /// The typeface, mirrored from the synced record. Assigning it updates the
    /// static W95Font reads from, exactly as `scheme` does for the palette.
    var face: AppFace = .w95 {
        didSet { W95Font.face = face }
    }

    /// Which visual language the app speaks. Local to the device for now: the
    /// scheme and typeface ride the synced `AppPreferences` record, and adding
    /// a field there is a CloudKit schema change worth making on its own rather
    /// than folding into the look.
    var design: DesignMode {
        didSet { UserDefaults.standard.set(design.rawValue, forKey: Key.design) }
    }

    /// Light / dark / follow-the-device. Global by design — the Windows look
    /// gains dark palettes later and will read the same value.
    var appearance: AppearanceMode {
        didSet { UserDefaults.standard.set(appearance.rawValue, forKey: Key.appearance) }
    }

    /// The typeface for the skeu look. Separate from `face`, and defaulting the
    /// other way: that design is drawn for SF Pro, the Windows one for W95FA.
    /// One shared value would mean each look inheriting the other's face.
    var skeuFace: AppFace {
        didSet {
            UserDefaults.standard.set(skeuFace.rawValue, forKey: Key.skeuFace)
            SkeuFont.face = skeuFace
        }
    }

    /// The typeface of whichever look is on screen. The settings row binds here,
    /// so there is one visible switch rather than two that look identical.
    var activeFace: AppFace {
        get { design == .skeu ? skeuFace : face }
        set { if design == .skeu { skeuFace = newValue } else { face = newValue } }
    }

    /// The skeuomorphic palette. Kept separate from `scheme` rather than mapped
    /// onto it: the five Windows schemes and the five skeu themes are different
    /// sets, and collapsing them would mean one look silently repicking the
    /// other's colours.
    var skeuTheme: SkeuTheme {
        SkeuTheme.all[min(colorSlot, SkeuTheme.all.count - 1)]
    }

    /// Custom tab labels. Empty string = use the built-in name.
    private var customNames: [Bucket: String]

    /// Which workspace this DEVICE is looking at. Deliberately not synced —
    /// the workspaces themselves are records now, but where you happen to be
    /// looking is local, like a scroll position.
    var currentWorkspaceID: String {
        didSet { UserDefaults.standard.set(currentWorkspaceID, forKey: Key.currentWorkspace) }
    }

    /// Workspaces this device held in preferences before they became synced
    /// records. Read once, to seed the records with the SAME ids so tasks
    /// already stamped with them keep their home.
    var legacyWorkspaces: [(id: String, name: String)] {
        struct Legacy: Codable { let id: String; let name: String }
        guard let data = UserDefaults.standard.data(forKey: Key.workspaces),
              let decoded = try? JSONDecoder().decode([Legacy].self, from: data)
        else { return [] }
        return decoded.map { ($0.id, $0.name) }
    }

    init() {

        // Skeu on a fresh install (founder direction 2026-08-17). Anyone who
        // has already chosen keeps their choice — this is the fallback, not an
        // override.
        design = DesignMode(rawValue: UserDefaults.standard.string(forKey: Key.design) ?? "")
            ?? .skeu
        appearance = AppearanceMode(rawValue: UserDefaults.standard.string(forKey: Key.appearance) ?? "")
            ?? .system
        let storedFace = AppFace(rawValue: UserDefaults.standard.string(forKey: Key.skeuFace) ?? "")
            ?? .system
        skeuFace = storedFace
        SkeuFont.face = storedFace

        var names: [Bucket: String] = [:]
        for bucket in Bucket.line {
            if let value = UserDefaults.standard.string(forKey: Key.name(bucket)), !value.isEmpty {
                names[bucket] = value
            }
        }
        customNames = names

        currentWorkspaceID = UserDefaults.standard.string(forKey: Key.currentWorkspace)
            ?? Workspace.defaultID

        languageCode = UserDefaults.standard.string(forKey: Key.language)
            ?? Language.english_.code

        // LAST, because assigning `colorSlot` runs its observer, and that
        // observer reads `scheme` — which means every stored property has to
        // exist first.
        //
        // Migrated from the two old name-keyed settings on first run:
        // whichever look the reader last touched decides the slot, and the
        // Win95 name wins the tie because it existed first.
        let legacyScheme = UserDefaults.standard.string(forKey: Key.scheme)
        let legacySkeu = UserDefaults.standard.string(forKey: Key.skeuTheme)
        let migrated = Win95Scheme.all.firstIndex { $0.id == legacyScheme }
            ?? SkeuTheme.all.firstIndex { $0.id == legacySkeu }
            ?? 0
        sharedSlot = UserDefaults.standard.object(forKey: Key.sharedSlot) as? Int ?? migrated
        colorSlot = UserDefaults.standard.object(forKey: Key.colorSlot) as? Int ?? migrated
        Win95.scheme = scheme
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
