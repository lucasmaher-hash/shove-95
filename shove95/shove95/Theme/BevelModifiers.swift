//
//  BevelModifiers.swift
//  shove95
//
//  The bevel is the entire visual language (design.md §3). Always exactly two
//  nested 1-pixel frames — never a corner radius, never a shadow.
//
//  Raised:  outer top-left #FFFFFF · inner top-left #DFDFDF
//           inner bottom-right #808080 · outer bottom-right #0A0A0A
//  Sunken:  the exact inversion.
//
//  Drawn as filled rects on the pixel grid rather than strokes, so edges land
//  on whole pixels at every scale (2×/3×/4×) and stay crisp.
//

import SwiftUI

struct BevelBorder: View {
    enum Style { case raised, sunken }

    let style: Style
    let pixel: CGFloat

    /// (outer top-left, inner top-left, inner bottom-right, outer bottom-right)
    private var colors: (Color, Color, Color, Color) {
        switch style {
        case .raised: (Win95.highlight, Win95.light, Win95.shadow, Win95.darkShadow)
        case .sunken: (Win95.shadow, Win95.darkShadow, Win95.light, Win95.highlight)
        }
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let p = pixel
            let (outerTL, innerTL, innerBR, outerBR) = colors

            ZStack(alignment: .topLeading) {
                // Outer frame — top-left edges, then bottom-right over them.
                Path { path in
                    path.addRect(CGRect(x: 0, y: 0, width: w, height: p))
                    path.addRect(CGRect(x: 0, y: 0, width: p, height: h))
                }
                .fill(outerTL)

                Path { path in
                    path.addRect(CGRect(x: 0, y: h - p, width: w, height: p))
                    path.addRect(CGRect(x: w - p, y: 0, width: p, height: h))
                }
                .fill(outerBR)

                // Inner frame, inset by one pixel.
                Path { path in
                    path.addRect(CGRect(x: p, y: p, width: w - 2 * p, height: p))
                    path.addRect(CGRect(x: p, y: p, width: p, height: h - 2 * p))
                }
                .fill(innerTL)

                Path { path in
                    path.addRect(CGRect(x: p, y: h - 2 * p, width: w - 2 * p, height: p))
                    path.addRect(CGRect(x: w - 2 * p, y: p, width: p, height: h - 2 * p))
                }
                .fill(innerBR)
            }
        }
        .allowsHitTesting(false)
    }
}

/// The same two nested frames, but the SAME pair of colours on all four sides:
/// no light source, so no lit edge. Used for the big list well, where the lit
/// bottom-right of a true bevel read as an uneven border rather than as depth
/// (founder request 2026-08-04). Small controls keep the real bevel — at chip
/// and button size the lighting is what makes them look pressable.
struct EvenBorder: View {
    let pixel: CGFloat

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let p = pixel

            ZStack(alignment: .topLeading) {
                frame(width: w, height: h, inset: 0, thickness: p).fill(Win95.shadow)
                frame(width: w, height: h, inset: p, thickness: p).fill(Win95.darkShadow)
            }
        }
        .allowsHitTesting(false)
    }

    /// One closed rectangular ring, drawn as four filled rects on the pixel
    /// grid so every edge lands on a whole pixel at 2×/3×/4×.
    private func frame(width w: CGFloat, height h: CGFloat,
                       inset: CGFloat, thickness t: CGFloat) -> Path {
        var path = Path()
        path.addRect(CGRect(x: inset, y: inset, width: w - inset * 2, height: t))
        path.addRect(CGRect(x: inset, y: h - inset - t, width: w - inset * 2, height: t))
        path.addRect(CGRect(x: inset, y: inset, width: t, height: h - inset * 2))
        path.addRect(CGRect(x: w - inset - t, y: inset, width: t, height: h - inset * 2))
        return path
    }
}

extension View {
    /// Raised bevel — buttons, taskbar, window body, thumbnail frames.
    func bevelRaised(_ pixel: CGFloat) -> some View {
        overlay(BevelBorder(style: .raised, pixel: pixel))
    }

    /// Sunken bevel — text fields, status-bar panels, chips.
    func bevelSunken(_ pixel: CGFloat) -> some View {
        overlay(BevelBorder(style: .sunken, pixel: pixel))
    }

    /// Even border — the list well only. See `EvenBorder`.
    func bevelEven(_ pixel: CGFloat) -> some View {
        overlay(EvenBorder(pixel: pixel))
    }
}
