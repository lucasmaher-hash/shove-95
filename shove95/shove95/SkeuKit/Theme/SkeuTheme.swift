//
//  SkeuTheme.swift
//  shove95
//
//  A named light/dark PAIR of palettes — the unit the theme picker deals in.
//  The app-level shape deliberately mirrors `Win95Scheme`: an id for
//  persistence, a display name, and the colours. Same picker idiom, two design
//  languages.
//
//  Cream is spelled out by hand (§2.4 ships exact hexes); the rest are derived
//  from one seed each (§2.5), which is the point — theming has to be provably
//  real, not five hand-tuned specials.
//

import SwiftUI

struct SkeuTheme: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let light: SkeuPalette
    let dark: SkeuPalette

    func palette(dark isDark: Bool) -> SkeuPalette { isDark ? dark : light }

    // MARK: Presets

    /// Both halves are written out by hand — see `SkeuPalette.creamDark` for
    /// why the derived dark came out grey.
    static let cream = SkeuTheme(
        id: "cream", name: "Cream",
        light: .cream,
        dark: .creamDark)

    static let clay = SkeuTheme(
        id: "clay", name: "Clay",
        light: .derived(from: Color(hex: 0xC98B6E)),
        dark: .derived(from: Color(hex: 0xC98B6E), dark: true))

    static let moss = SkeuTheme(
        id: "moss", name: "Moss",
        light: .derived(from: Color(hex: 0xA8B79A), accent: Color(hex: 0x4E6B45)),
        dark: .derived(from: Color(hex: 0xA8B79A), accent: Color(hex: 0x4E6B45), dark: true))

    static let slate = SkeuTheme(
        id: "slate", name: "Slate",
        light: .derived(from: Color(hex: 0xB4BAC4), accent: Color(hex: 0x3F5670)),
        dark: .derived(from: Color(hex: 0xB4BAC4), accent: Color(hex: 0x3F5670), dark: true))

    static let ember = SkeuTheme(
        id: "ember", name: "Ember",
        light: .derived(from: Color(hex: 0xC96F60), accent: Color(hex: 0x8E3324)),
        dark: .derived(from: Color(hex: 0xC96F60), accent: Color(hex: 0x8E3324), dark: true))

    /// The colour this theme shows in the PICKER.
    ///
    /// Not `light.material` — that is the surface the app is painted in, and
    /// at 0.62 of the seed's saturation it is deliberately quiet. Five quiet
    /// surfaces side by side read as five greys with a hint of something
    /// (founder direction 2026-08-17). The swatch says what the theme IS, so
    /// it takes the seed at full strength; nothing the app paints changes.
    var swatch: Color {
        let s = light.material.hsb
        return Color(h: s.h, s: min(s.s * 2.1, 0.82), b: min(s.b * 1.02, 0.94))
    }

    static let all: [SkeuTheme] = [cream, clay, moss, slate, ember]

    static func named(_ id: String) -> SkeuTheme {
        all.first { $0.id == id } ?? cream
    }
}
