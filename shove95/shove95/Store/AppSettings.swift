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

/// A named container for tasks — work, private, design… The DEFAULT workspace
/// has `id == nil` semantics on TaskItem but is represented here with a fixed
/// sentinel id so it can sit in the same list; it is renamable, not deletable.
struct Workspace: Identifiable, Codable, Equatable {
    let id: String
    var name: String

    static let defaultID = "default"
    static let fallback = Workspace(id: defaultID, name: "Personal")

    /// What gets stamped on TaskItem.workspaceID: nil for the default
    /// workspace, so pre-workspace tasks belong to it automatically.
    var taskStampID: String? { id == Self.defaultID ? nil : id }
}

@Observable @MainActor
final class AppSettings {
    private enum Key {
        static let scheme = "settings.scheme"
        // v2: the founder settled the default set at Personal + Work
        // (2026-08-04); the bump orphans pre-release test data.
        static let workspaces = "settings.workspaces.v2"
        static let currentWorkspace = "settings.workspace.current"
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

    /// All workspaces, default first. Always contains at least the default.
    private(set) var workspaces: [Workspace] {
        didSet { persistWorkspaces() }
    }

    /// Called explicitly from `init` as well as from `didSet`: property
    /// observers do NOT fire during initialization, so the first-run list was
    /// built, used, and never written. Every relaunch then minted a fresh
    /// "Work" with a fresh UUID, orphaning the tasks stamped with the old one.
    private func persistWorkspaces() {
        if let data = try? JSONEncoder().encode(workspaces) {
            UserDefaults.standard.set(data, forKey: Key.workspaces)
        }
    }

    /// Every workspace id a task may legitimately carry. Anything else is a
    /// leftover from a deleted or lost workspace.
    var knownWorkspaceStampIDs: Set<String> {
        Set(workspaces.compactMap(\.taskStampID))
    }

    var currentWorkspaceID: String {
        didSet { UserDefaults.standard.set(currentWorkspaceID, forKey: Key.currentWorkspace) }
    }

    var currentWorkspace: Workspace {
        workspaces.first { $0.id == currentWorkspaceID } ?? .fallback
    }

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

        var loaded: [Workspace] = []
        if let data = UserDefaults.standard.data(forKey: Key.workspaces),
           let decoded = try? JSONDecoder().decode([Workspace].self, from: data) {
            loaded = decoded
        }
        if loaded.isEmpty {
            // First run ships two workspaces: Personal (the undeletable
            // default) and Work.
            loaded = [.fallback, Workspace(id: UUID().uuidString, name: "Work")]
        } else if !loaded.contains(where: { $0.id == Workspace.defaultID }) {
            loaded.insert(.fallback, at: 0) // the default always exists
        }
        workspaces = loaded

        let current = UserDefaults.standard.string(forKey: Key.currentWorkspace)
        currentWorkspaceID = loaded.contains { $0.id == current } ? current! : Workspace.defaultID

        persistWorkspaces() // didSet doesn't fire in init — see above
    }

    // MARK: Workspaces

    func addWorkspace(named raw: String) {
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        workspaces.append(Workspace(id: UUID().uuidString, name: name))
    }

    func renameWorkspace(_ id: String, to raw: String) {
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let index = workspaces.firstIndex(where: { $0.id == id }) else { return }
        workspaces[index].name = name
    }

    /// The caller is responsible for reassigning the workspace's tasks first
    /// (TaskStore.reassignTasksToDefaultWorkspace). The default is undeletable.
    func removeWorkspace(_ id: String) {
        guard id != Workspace.defaultID else { return }
        workspaces.removeAll { $0.id == id }
        if currentWorkspaceID == id { currentWorkspaceID = Workspace.defaultID }
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
