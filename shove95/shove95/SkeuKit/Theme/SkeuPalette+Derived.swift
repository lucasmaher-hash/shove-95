//
//  SkeuPalette+Derived.swift
//  shove95
//
//  Derivation (§2.3): any single seed colour generates a compliant palette.
//  This is the interchange mechanism — a designer hands over ONE colour and the
//  system computes the other twenty-odd roles, so no palette can drift out of
//  contract by hand-picking a stop.
//

import SwiftUI

extension SkeuPalette {

    /// Builds a full palette from one material seed.
    /// - Parameters:
    ///   - seed: the body colour of raised surfaces
    ///   - accentSeed: optional action colour; defaults to a deepened, more
    ///     saturated seed
    ///   - dark: build the dark-mode variant
    static func derived(from seed: Color,
                        accent accentSeed: Color? = nil,
                        dark: Bool = false) -> SkeuPalette {

        let s = seed.hsb
        let acc = (accentSeed ?? seed.shifted(sat: +0.22, bri: -0.24)).hsb

        // Light ladder. ONE BASE: canvas, material and recess are all the seed
        // itself — see `SkeuPalette.cream` for why. Only the gradient stops and
        // the shadows move, so every object IS the page, lit differently.
        if !dark {
            return SkeuPalette(
                canvas:         seed,
                canvasAlt:      seed,

                material:       seed,
                materialTop:    Color(h: s.h, s: s.s * 0.78, b: min(s.b * 1.10, 1.0)),
                materialBottom: Color(h: s.h, s: min(s.s * 1.18, 1), b: s.b * 0.86),

                // Trough BRIGHTNESS ratios come from the reference: near wall at
                // 0.76× the base, floor at 0.955×, contour at 0.59×.
                //
                // The saturation multipliers do NOT — the reference's 1.18× is
                // tuned for a red already at 0.73 saturation. Applied to a pale
                // seed it yields grey, so they are pushed much harder here and
                // scale with how unsaturated the seed is.
                recess:         Color(h: s.h, s: min(s.s * 1.75, 1), b: s.b * 0.76),
                recessBottom:   Color(h: s.h, s: min(s.s * 1.25, 1), b: min(s.b * 0.955, 1.0)),

                edgeLight:      .white,
                edgeShade:      Color(h: s.h, s: min(s.s * 1.8, 1), b: s.b * 0.42),
                seam:           Color(h: s.h, s: s.s * 0.35, b: min(s.b * 1.14, 1)),
                // The contour is a gradient: dark near lip, LIT far lip. The
                // far one goes brighter than the material itself — it is a
                // highlight, not just a paler edge.
                outline:        Color(h: s.h, s: min(s.s * 1.9, 1), b: s.b * 0.60),
                outlineBottom:  Color(h: s.h, s: s.s * 0.68, b: min(s.b * 1.02, 1.0)),

                ink:            Color(h: s.h, s: min(s.s * 1.35, 1), b: s.b * 0.26),
                inkMuted:       Color(h: s.h, s: min(s.s * 1.15, 1), b: s.b * 0.46),
                inkFaint:       Color(h: s.h, s: s.s * 0.9,          b: s.b * 0.62),
                inkOnAccent:    Color(h: acc.h, s: acc.s * 0.10, b: 0.99),

                accent:         Color(h: acc.h, s: acc.s, b: acc.b),
                accentTop:      Color(h: acc.h, s: acc.s * 0.88, b: min(acc.b * 1.14, 1)),
                accentBottom:   Color(h: acc.h, s: min(acc.s * 1.10, 1), b: acc.b * 0.84),

                positive:       Color(h: 0.35, s: 0.45, b: 0.55),
                caution:        Color(h: 0.10, s: 0.62, b: 0.72),
                critical:       Color(h: 0.02, s: 0.58, b: 0.62),

                shadow:         Color(h: s.h, s: min(s.s * 1.5, 1), b: s.b * 0.22),
                shadowIntensity: 1.0,
                isDark:         false
            )
        }

        // Dark ladder: material sits ABOVE canvas in brightness, shadows soften,
        // rim light weakens, rim shade strengthens. A bright rim on dark
        // material reads as chrome, which this system does not want.
        //
        // Saturation is pushed UP rather than down as the doc's draft had it.
        // Cutting it while also dropping brightness to 0.20 produced a neutral
        // grey for any lightly-saturated seed — the app has to stay the same
        // MATERIAL in the dark, merely unlit, so the hue survives the fall.
        return SkeuPalette(
            canvas:         Color(h: s.h, s: min(s.s * 1.25, 1), b: 0.19),
            canvasAlt:      Color(h: s.h, s: min(s.s * 1.25, 1), b: 0.19),

            material:       Color(h: s.h, s: min(s.s * 1.25, 1), b: 0.19),
            materialTop:    Color(h: s.h, s: min(s.s * 1.10, 1), b: 0.26),
            materialBottom: Color(h: s.h, s: min(s.s * 1.35, 1), b: 0.14),

            recess:         Color(h: s.h, s: min(s.s * 1.40, 1), b: 0.11),
            recessBottom:   Color(h: s.h, s: min(s.s * 1.15, 1), b: 0.23),

            edgeLight:      Color(h: s.h, s: 0.16, b: 1.0),
            // §5.4 holds in the dark too: a neutral black edge against warm
            // material reads as soot.
            edgeShade:      Color(h: s.h, s: min(s.s * 1.5, 1), b: 0.03),
            seam:           Color(h: s.h, s: s.s * 0.7, b: 0.36),
            outline:        Color(h: s.h, s: min(s.s * 1.5, 1), b: 0.09),
            outlineBottom:  Color(h: s.h, s: s.s * 0.9, b: 0.34),

            ink:            Color(h: s.h, s: 0.10, b: 0.96),
            inkMuted:       Color(h: s.h, s: 0.16, b: 0.74),
            inkFaint:       Color(h: s.h, s: 0.20, b: 0.55),
            inkOnAccent:    Color(h: acc.h, s: 0.08, b: 0.99),

            accent:         Color(h: acc.h, s: acc.s * 0.95, b: min(acc.b * 1.25, 0.86)),
            accentTop:      Color(h: acc.h, s: acc.s * 0.85, b: min(acc.b * 1.45, 0.95)),
            accentBottom:   Color(h: acc.h, s: acc.s,        b: min(acc.b * 1.05, 0.70)),

            positive:       Color(h: 0.35, s: 0.42, b: 0.72),
            caution:        Color(h: 0.10, s: 0.60, b: 0.86),
            critical:       Color(h: 0.02, s: 0.55, b: 0.80),

            shadow:         Color(h: s.h, s: min(s.s * 1.5, 1), b: 0.04),
            shadowIntensity: 0.9,
            isDark:         true
        )
    }
}
