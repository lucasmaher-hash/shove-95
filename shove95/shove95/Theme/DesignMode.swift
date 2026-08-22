//
//  DesignMode.swift
//  shove95
//
//  Which visual language the app speaks, and whether it speaks it light or dark.
//
//  These two are deliberately independent. `DesignMode` picks the grammar —
//  hard 2px bevels on a pixel grid, or soft material on a depth ladder.
//  `AppearanceMode` picks the lighting, and it is GLOBAL: the Windows look gets
//  its own dark palettes later, and this same switch will drive both.
//

import SwiftUI

/// The app speaks one visual language now.
///
/// It shipped with two — soft skeuomorphism and a pixel-faithful Windows 95
/// interface, built side by side, every change made twice. The founder settled
/// on skeuomorphism and the other was removed root and branch (founder
/// direction 2026-08-22), along with the rule that made every feature cost
/// double.
///
/// The type survives as a single case rather than being deleted outright: it
/// is what the stored preference decodes into, and a one-case enum reads as a
/// decision rather than as an oversight.
enum DesignMode: String, CaseIterable, Sendable {
    case skeu

    var label: String { "Skeuomorph" }
}

enum AppearanceMode: String, CaseIterable, Sendable {
    case system, light, dark

    var label: String {
        switch self {
        case .system: "System"
        case .light:  "Light"
        case .dark:   "Dark"
        }
    }

    /// What to hand `preferredColorScheme`. `.system` returns nil so the app
    /// keeps following the device — pinning it would break the very thing the
    /// option promises, and would make the resolved palette self-referential.
    var preferred: ColorScheme? {
        switch self {
        case .system: nil
        case .light:  .light
        case .dark:   .dark
        }
    }

    /// Resolves against the device setting, which only matters for `.system`.
    func isDark(system: ColorScheme) -> Bool {
        switch self {
        case .system: system == .dark
        case .light:  false
        case .dark:   true
        }
    }
}
