//
//  LiveActivityController.swift
//  shove95
//
//  Keeps the Lock Screen showing whatever the store says is pinned.
//
//  RECONCILIATION, not commands. The obvious shape is `pin() { start() }` and
//  `unpin() { end() }`, and it is wrong: a pin can also disappear because the
//  task was completed, deleted, archived, rolled over at midnight, or
//  un-pinned on another device and synced here. Each of those would need its
//  own call, and the first one anyone forgot would leave a ghost card on the
//  Lock Screen with no way to dismiss it.
//
//  So nothing calls "start" or "stop". `reconcile()` looks at the store and
//  makes ActivityKit match, and every mutation path already bumps
//  `TaskStore.revision`, which is what triggers it. One code path, and no way
//  to add a sixth way of losing a pin without it being handled.
//
//  THE 8-HOUR CEILING. iOS ends every Live Activity after at most eight
//  hours. The founder's answer (2026-08-16) is that the pin belongs to the
//  TASK, not to the activity: if the store says something is pinned and no
//  activity is running, this starts a fresh one. Since reconcile runs on
//  foreground, the pin feels open-ended as long as the app is opened now and
//  then — which is the honest version of "it stays until you turn it off".
//

import SwiftUI
import ActivityKit
import Shove95Kit

@MainActor
@Observable
final class LiveActivityController {

    /// True when iOS has Live Activities switched off for shove.95. The pin
    /// still works — it is app state — but nothing reaches the Lock Screen,
    /// and the user is told once (founder direction 2026-08-16).
    var activitiesDisabled: Bool {
        !ActivityAuthorizationInfo().areActivitiesEnabled
    }

    private var current: Activity<PinnedTaskAttributes>?

    /// Makes the Lock Screen match the store. Safe to call as often as you
    /// like — it is a no-op when nothing has changed.
    func reconcile(store: TaskStore, settings: AppSettings, isDark: Bool) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            // Permission can be revoked while an activity is up; drop the
            // handle so a later grant starts cleanly rather than trying to
            // update a card iOS has already taken away.
            Task { await endAll() }
            current = nil
            return
        }

        // Adopt anything already running — after a cold launch this process
        // has no handle on the activity from the last one, and requesting a
        // second would leave two cards on the Lock Screen.
        if current == nil {
            current = Activity<PinnedTaskAttributes>.activities.first
        }

        guard let task = store.pinnedTask(), !task.isCompleted else {
            let running = current
            current = nil
            Task { await running?.end(nil, dismissalPolicy: .immediate) }
            return
        }

        let state = contentState(for: task, store: store, settings: settings, isDark: isDark)

        if let running = current, running.attributes.taskID == task.id {
            Task { await running.update(ActivityContent(state: state, staleDate: nil)) }
            return
        }

        // A DIFFERENT task holds the pin. taskID is immutable for an
        // activity's lifetime, so the old card is retired and a new one
        // requested rather than mutated.
        let outgoing = current
        current = nil
        Task {
            await outgoing?.end(nil, dismissalPolicy: .immediate)
            current = try? Activity.request(
                attributes: PinnedTaskAttributes(taskID: task.id),
                content: ActivityContent(state: state, staleDate: nil))
        }
    }

    private func endAll() async {
        for activity in Activity<PinnedTaskAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    // MARK: Resolving the look

    /// The app is the only place allowed to know colours, so it resolves them
    /// here and the widget draws what it is handed — see PinnedTaskActivity.
    private func contentState(for task: TaskItem,
                              store: TaskStore,
                              settings: AppSettings,
                              isDark: Bool) -> PinnedTaskAttributes.ContentState {
        let chip = ChipFormat.label(dueDate: task.dueDate,
                                    isCompleted: task.isCompleted,
                                    now: store.now(),
                                    calendar: store.calendar)

        switch settings.design {
        case .win95:
            let scheme = settings.scheme.resolved(dark: isDark)
            return .init(
                title: task.title,
                chip: chip,
                look: .win95,
                palette: ActivityPalette(
                    surface: .init(hex: scheme.surface),
                    ink: .init(hex: scheme.text),
                    inkMuted: .init(hex: scheme.shadow),
                    accent: .init(hex: scheme.titleA),
                    light: .init(hex: scheme.highlight),
                    dark: .init(hex: scheme.darkShadow)),
                fontName: settings.face == .w95 ? W95Font.postScriptName : nil)

        case .skeu:
            let palette = settings.skeuTheme.palette(dark: isDark)
            return .init(
                title: task.title,
                chip: chip,
                look: .skeu,
                palette: ActivityPalette(
                    surface: .init(palette.material),
                    ink: .init(palette.ink),
                    inkMuted: .init(palette.inkMuted),
                    accent: .init(palette.accent),
                    light: .init(palette.edgeLight),
                    dark: .init(palette.shadow)),
                fontName: settings.skeuFace == .w95 ? W95Font.postScriptName : nil)
        }
    }
}

// MARK: - Colour bridging

extension ActivityColor {
    /// From the 24-bit literals the Win95 schemes are written in.
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }

    /// From a SwiftKit `Color`, which is how the skeu palettes are written.
    ///
    /// Resolved against the LIGHT trait deliberately: the palette handed in
    /// is already the dark one when dark is what the user picked, so
    /// resolving it again against the device trait would darken it twice.
    init(_ color: Color) {
        let resolved = UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        resolved.getRed(&r, green: &g, blue: &b, alpha: &a)
        self.init(red: Double(r), green: Double(g), blue: Double(b), alpha: Double(a))
    }
}
