//
//  SkeuChromeGlyph.swift
//  shove95
//
//  The skeu top bar's gear and ✕, drawn to match the chosen typeface.
//
//  An SF Symbol beside pixel text is the same mismatch the Blend face exists
//  to avoid: under Retro the whole of the app's furniture is set in the bitmap
//  face and then two vector glyphs sit in the middle of it, rounded and
//  antialiased (founder direction 2026-08-16). So these follow `TextRole`
//  `.chrome` exactly as a heading does — pixel under Retro and Blend, the
//  system symbol under System.
//
//  The pixel shapes are the Win95 look's own `GearGlyph` and `CloseGlyph`,
//  used rather than redrawn. They are a grid of rectangles, so they take the
//  skeu palette's tint like anything else and stay crisp at any size.
//

import SwiftUI

struct SkeuChromeGlyph: View {
    enum Kind {
        case gear, close

        var symbol: String {
            switch self {
            case .gear:  "gearshape"
            case .close: "xmark"
            }
        }
    }

    let kind: Kind
    let face: AppFace
    /// Point size of the SF Symbol. The pixel shape is drawn a touch smaller —
    /// a bitmap glyph fills its box where a symbol leaves optical margin, so
    /// matching the raw figure makes it read as the larger of the two.
    let size: CGFloat
    let tint: Color

    var body: some View {
        if face.isPixel(.chrome) {
            shape
                .fill(tint)
                .frame(width: size * 0.82, height: size * 0.82)
        } else {
            Image(systemName: kind.symbol)
                .font(SkeuFont.at(size, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint)
        }
    }

    /// `AnyShape` rather than a ViewBuilder: a builder returns
    /// `_ConditionalContent`, which is a View and not a Shape, and `.fill`
    /// needs the Shape.
    private var shape: AnyShape {
        switch kind {
        case .gear:  AnyShape(GearGlyph())
        case .close: AnyShape(CloseGlyph())
        }
    }
}
