//
//  SkeuTheme.swift
//  shove95
//
//  A named light/dark PAIR of palettes — the unit the theme picker deals in:
//  an id for persistence, a display name, and the colours.
//
//  Cream is spelled out by hand (§2.4 ships exact hexes); the rest are derived
//  from one seed each (§2.5), which is the point — theming has to be provably
//  real, not a set of hand-tuned specials.
//
//  FOUR of them, chosen by the founder from the six that were here
//  (2026-08-22): Cream, Moss, Slate and a rose that is new. Clay and Ember
//  both sat in the warm half beside Cream, and Silver needed machinery of its
//  own to stop reading as Slate.
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

    static let moss = SkeuTheme(
        id: "moss", name: "Moss",
        light: .derived(from: Color(hex: 0xA8B79A), accent: Color(hex: 0x4E6B45)),
        dark: .derived(from: Color(hex: 0xA8B79A), accent: Color(hex: 0x4E6B45), dark: true))

    static let slate = SkeuTheme(
        id: "slate", name: "Slate",
        light: .derived(from: Color(hex: 0xB4BAC4), accent: Color(hex: 0x3F5670)),
        dark: .derived(from: Color(hex: 0xB4BAC4), accent: Color(hex: 0x3F5670), dark: true))

    /// Rose, added when the palette was cut to four (founder direction
    /// 2026-08-22). The seed is held at Moss's saturation and Slate's
    /// brightness rather than at a fuller pink: these are SURFACES, and the
    /// picker shows the seed at more than double strength anyway, so a theme
    /// that looks quiet in the app still announces itself in the swatch.
    static let rose = SkeuTheme(
        id: "rose", name: "Rose",
        light: .derived(from: Color(hex: 0xC9A6AE), accent: Color(hex: 0x8E4257)),
        dark: .derived(from: Color(hex: 0xC9A6AE), accent: Color(hex: 0x8E4257), dark: true))

    /// The colour this theme shows in the PICKER.
    ///
    /// Not `light.material` — that is the surface the app is painted in, and
    /// at 0.62 of the seed's saturation it is deliberately quiet. Quiet
    /// surfaces side by side read as greys with a hint of something
    /// (founder direction 2026-08-17). The swatch says what the theme IS, so
    /// it takes the seed at full strength; nothing the app paints changes.
    var swatch: Color {
        let s = light.material.hsb
        return Color(h: s.h, s: min(s.s * 2.1, 0.82), b: min(s.b * 1.02, 0.94))
    }

    /// What the picker actually paints. Flat, and it stays a style rather
    /// than a `Color` because the segment takes one: Silver painted a raked
    /// gradient here until it was cut (2026-08-22), a single tone at a neutral
    /// hue being grey no matter how it is tuned.
    var swatchStyle: AnyShapeStyle { AnyShapeStyle(swatch) }

    static let all: [SkeuTheme] = [cream, moss, slate, rose]

    static func named(_ id: String) -> SkeuTheme {
        all.first { $0.id == id } ?? cream
    }
}
