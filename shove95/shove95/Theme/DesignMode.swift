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

enum DesignMode: String, CaseIterable, Sendable {
    /// The pixel-faithful Windows 95 interface the app is named after.
    case win95
    /// Soft skeuomorphism — see docs/SKEUOMORPHIC_DESIGN_SYSTEM.md.
    case skeu

    var label: String {
        switch self {
        case .win95: "Windows 95"
        case .skeu:  "Skeuomorph"
        }
    }
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
