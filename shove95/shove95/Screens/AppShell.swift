//
//  AppShell.swift
//  shove95
//
//  Picks the visual language and hands the chosen tree its lighting.
//
//  The two designs are siblings, not layers: neither wraps the other, and
//  nothing below this point has to ask which look is active. Everything they
//  share — the store, the settings object, sync — is injected above.
//
//  The SETTINGS SHEET is owned here rather than by either root, because the
//  Design switch lives inside that sheet. Owned by a root, flipping the switch
//  swapped the root out from under its own presentation and the sheet vanished
//  mid-interaction (founder bug report 2026-08-14). Held above the switch, the
//  sheet survives the swap and simply re-skins — which is what you want when
//  the control you just used is the one changing the look.
//

import SwiftUI

/// The dissolve between the two looks.
///
/// Driven from the CONTROL, with `withAnimation`, not from a container
/// watching `settings.design`. Watching it animated one direction and not the
/// other — the value changes identically both ways, but the container only
/// reliably picked it up when the tree it was animating was the one being
/// inserted (founder bug report 2026-08-16). An explicit transaction at the
/// switch itself has no such asymmetry: both looks fade, both ways.
///
/// Slow enough to read as a change of clothes rather than a flicker, short
/// enough that the control you just pressed is still under your finger when it
/// settles.
enum DesignSwitch {
    static let animation: Animation = .easeInOut(duration: 0.34)
}

struct AppShell: View {
    @Environment(AppSettings.self) private var settings
    /// The DEVICE setting. Only consulted when the user picked "System" — in
    /// the other two cases the palette is pinned, so reading this would make
    /// the resolution circular once `preferredColorScheme` takes effect.
    @Environment(\.colorScheme) private var systemScheme

    @State private var showSettings = false
    /// Owned HERE, above the design switch, for the same reason the settings
    /// sheet is: the pinned task is app-wide, and a coordinator per look
    /// would mean the replace question could be asked twice, or lost when
    /// the switch is flipped mid-question.
    @State private var activity = LiveActivityController()
    @Environment(TaskStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        // The two looks CROSS-FADE into each other. They are different view
        // trees, not one tree re-skinned, so there is nothing to interpolate
        // — but a hard cut between two complete design languages reads as a
        // glitch, and the reader is usually looking at the very control that
        // caused it. A dissolve says "this is the same screen, dressed
        // differently", which is exactly what it is (founder direction
        // 2026-08-16; possible at all only since the transitions ban came off
        // §9 the same day).
        //
        // Held in a ZStack so both trees occupy the same space while they
        // trade places. They line up section for section now, so the fade
        // lands on itself instead of sliding.
        ZStack { root }
            // ONE presentation for both looks. `isPresented` is untouched by
            // the design switch, so the sheet stays up; only its content and
            // the palette underneath change.
            .fullScreenCover(isPresented: $showSettings) {
                settingsSheet
            }
            // Reconciliation, not commands — see LiveActivityController. Every
            // way a pin can appear or vanish (pinned, replaced, completed,
            // deleted, rolled over, synced from another device) bumps
            // `revision`, so this one hook covers all of them.
            .task(id: store.revision) { reconcile() }
            // The look travels INSIDE the activity's content, so a theme,
            // typeface or design change has to be pushed out to the Lock
            // Screen the same as a title change.
            .onChange(of: lookSignature) { reconcile() }
            // Restarts anything iOS retired at its eight-hour ceiling.
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { reconcile() }
            }
    }

    private func reconcile() {
        activity.reconcile(store: store, settings: settings, isDark: isDark)
    }

    /// Everything the Lock Screen card's appearance depends on, in one value
    /// so a single `onChange` catches all of it.
    private var lookSignature: String {
        [settings.skeuTheme.id,
         settings.skeuFace.rawValue,
         isDark ? "d" : "l"].joined(separator: "|")
    }

    /// One look, so no switch. The Windows 95 interface used to live beside
    /// this one and every change had to be made twice; the founder settled on
    /// skeuomorphism and it was removed root and branch (founder direction
    /// 2026-08-22).
    @ViewBuilder
    private var root: some View {
        SkeuRootView(showSettings: $showSettings)
            // The palette rides the environment, so it needs no help. The
            // TYPEFACE does: SkeuFont reads a static, which SwiftUI cannot
            // see, so the subtree has to be rebuilt when it changes.
            .id(settings.skeuFace.rawValue)
            // Dynamic Type (FR-015). This look has no stepped pixel unit, so
            // it resolves the setting into two multipliers here.
            .skeuTypeScaling()
            .skeuTheme(settings.skeuTheme.palette(dark: isDark))
            .preferredColorScheme(settings.appearance.preferred)
            .transition(.opacity)
    }

    /// The settings screen in whichever look is active. Both variants need the
    /// same `.id` treatment their roots get, for the same reason: the typeface
    /// and palette are read through statics the sheet cannot observe.
    private var settingsSheet: some View {
        // Same dissolve as the roots, and it matters MORE here: the Design
        // switch is on this screen, so this is the surface the reader is
        // looking at when it changes. The two sheets are aligned section for
        // section, so the fade happens in place rather than under a jump.
        ZStack { settingsSheetContent }
    }

    /// One look, so no switch — see `root`.
    @ViewBuilder
    private var settingsSheetContent: some View {
        // NO `.id(face)` here, unlike the root above. Rebuilding this
        // sheet on a typeface change tore down the toggle mid-glide, so
        // the Typeface switch was the one switch on the screen that
        // snapped instead of sliding. The face rides the environment
        // instead; the few leaf views that don't otherwise observe
        // AppSettings read it to declare the dependency.
        SkeuSettingsView { showSettings = false }
            .environment(\.skeuFace, settings.skeuFace)
            .skeuTypeScaling()
            .skeuTheme(settings.skeuTheme.palette(dark: isDark))
            .preferredColorScheme(settings.appearance.preferred)
            .transition(.opacity)
    }

    private var isDark: Bool {
        settings.appearance.isDark(system: systemScheme)
    }
}
