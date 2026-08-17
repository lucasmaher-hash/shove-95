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

    /// What the picker actually paints. Every theme but one is its `swatch`
    /// flat; silver is a raked gradient, because a single tone at a neutral
    /// hue IS grey no matter how it is tuned. Metal reads as metal only when
    /// the light travels across it.
    var swatchStyle: AnyShapeStyle {
        guard id == "silver" else { return AnyShapeStyle(swatch) }
        return AnyShapeStyle(LinearGradient(
            stops: [.init(color: Color(hex: 0x8F949C), location: 0.00),
                    .init(color: Color(hex: 0xE8ECF2), location: 0.30),
                    .init(color: Color(hex: 0xA8AEB8), location: 0.52),
                    .init(color: Color(hex: 0xF4F7FA), location: 0.72),
                    .init(color: Color(hex: 0x9AA0A9), location: 1.00)],
            startPoint: .topLeading, endPoint: .bottomTrailing))
    }

    /// Silver. Skeu only — there is no Win95 twin, and the founder's rule is
    /// that Windows falls back to the last shared colour while this is chosen
    /// (2026-08-17). Inventing a sixth Win95 scheme nobody designed would have
    /// been the worse answer.
    ///
    /// A near-neutral base at a hint of blue: metal is not grey, it is a grey
    /// that remembers the sky. The metallic read comes from the SWATCH's
    /// gradient and from the look's own rim and glass — a flat fill at this
    /// hue would be exactly the "just grey" the founder rejected.
    static let silver = SkeuTheme(
        id: "silver", name: "Silver",
        light: .derived(from: Color(hex: 0xDCDEE1), accent: Color(hex: 0x555B63),
                        metallic: true),
        dark: .derived(from: Color(hex: 0xDCDEE1), accent: Color(hex: 0x9AA3AE),
                       dark: true, metallic: true))

    static let all: [SkeuTheme] = [cream, clay, moss, slate, ember, silver]

    static func named(_ id: String) -> SkeuTheme {
        all.first { $0.id == id } ?? cream
    }
}
