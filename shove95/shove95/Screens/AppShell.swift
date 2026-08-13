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

import SwiftUI

struct AppShell: View {
    @Environment(AppSettings.self) private var settings
    /// The DEVICE setting. Only consulted when the user picked "System" — in
    /// the other two cases the palette is pinned, so reading this would make
    /// the resolution circular once `preferredColorScheme` takes effect.
    @Environment(\.colorScheme) private var systemScheme

    var body: some View {
        switch settings.design {
        case .win95:
            // The palette is read through statics (`Win95.scheme`), which
            // SwiftUI cannot observe, so the dark variant is pushed there and
            // the subtree rebuilt on the flip — the same mechanism the scheme
            // picker itself uses.
            //
            // This assignment must happen HERE, synchronously, not in
            // `.onAppear` — `.onAppear` fires after RootView's first body
            // evaluation, so every descendant that reads `Win95.*` directly
            // (not through `\.win95Scheme`) painted once with the stale
            // light-mode value and then never repainted, because nothing
            // about their own state changed to make SwiftUI re-run their
            // body. Task rows stayed white in dark mode forever unless
            // something unrelated (a press, a menu) forced a redraw (founder
            // bug report 2026-08-14).
            let resolved = settings.scheme.resolved(dark: isDark)
            let _ = { Win95.scheme = resolved }()
            RootView()
                .id(isDark ? "dark" : "light")
                // The reactive counterpart to the static assignment above:
                // anything reading `\.win95Scheme` (TitleBar, Taskbar) repaints
                // the instant this changes, no `.id()` rebuild required.
                .environment(\.win95Scheme, resolved)
                .preferredColorScheme(settings.appearance.preferred)
                .onChange(of: isDark) { _, dark in
                    Win95.scheme = settings.scheme.resolved(dark: dark)
                }
                .onChange(of: settings.scheme.id) { _, _ in
                    Win95.scheme = settings.scheme.resolved(dark: isDark)
                }
        case .skeu:
            // TEMPORARY: the magnifier is scaffolding for tuning the surface
            // work. Unwrap this once the skeu look is signed off — see
            // ZoomInspector.swift.
            ZoomInspector { SkeuRootView() }
                // The palette rides the environment, so it needs no help. The
                // TYPEFACE does: SkeuFont reads a static, which SwiftUI cannot
                // see, so the subtree has to be rebuilt when it changes.
                .id(settings.skeuFace.rawValue)
                .skeuTheme(settings.skeuTheme.palette(dark: isDark))
                .preferredColorScheme(settings.appearance.preferred)
        }
    }

    private var isDark: Bool {
        settings.appearance.isDark(system: systemScheme)
    }
}
