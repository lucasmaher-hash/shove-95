//
//  SkeuFont.swift
//  shove95
//
//  Typography (§6). SF Pro for UI, New York for the wordmark, rounded numerals
//  for counters.
//
//  Two deliberate departures from the doc's literal code:
//
//  1. Tokens map to system TEXT STYLES rather than fixed point sizes, so
//     Dynamic Type works natively. §6.3 sanctions this explicitly — the fixed
//     sizes in §6.2 are the design reference, not the shipping values. The
//     mapping is chosen so the default (Large) size matches the reference: e.g.
//     `title1` → `.title` is 28pt on the nose.
//
//  2. The tokens honour a typeface switch, because the founder kept that choice
//     in the menu — the bitmap face stays reachable from the skeu look too.
//     W95FA is set ~1.22× the system size: the inverse of the 0.82 factor
//     W95Font already uses to keep the two faces optically level.
//
//     The selection is SEPARATE from `W95Font.face`. The two looks default
//     differently — SF Pro here, W95FA there — and sharing one value would mean
//     the skeu screens silently inheriting a bitmap face they were not drawn
//     for, which is exactly what the first build did.
//

import SwiftUI

enum SkeuFont {

    /// Set from `AppSettings` before any view renders — a static for the same
    /// reason `W95Font.face` is one: every view in the tree reads it.
    nonisolated(unsafe) static var face: AppFace = .system

    // MARK: Display

    /// The wordmark. New York, italic — the reference uses a high-contrast
    /// serif here, and New York is the system serif, so nothing gets bundled.
    static var display: Font {
        // Asked by ROLE, not by case, so Blend resolves like every other
        // token instead of needing its own branch here.
        SkeuFont.face.isPixel(.content)
            ? .custom(W95Font.postScriptName, size: 40, relativeTo: .largeTitle)
            : .system(.largeTitle, design: .serif).italic()
    }

    // MARK: Titles

    static var title1: Font { styled(.title, weight: .semibold, w95: 34) }
    static var title2: Font { styled(.title2, weight: .semibold, w95: 27) }
    static var title3: Font { styled(.title3, weight: .semibold, w95: 24) }

    // MARK: Body

    static var body: Font { styled(.body, weight: .regular, w95: 20) }
    static var bodyEmph: Font { styled(.body, weight: .medium, w95: 20) }
    static var callout: Font { styled(.subheadline, weight: .regular, w95: 18) }
    static var caption: Font { styled(.footnote, weight: .regular, w95: 16) }

    /// Section eyebrows. Pair with `.textCase(.uppercase)`, `.tracking(0.8)`
    /// and `inkFaint` — always as the top line of a two-line stack.
    /// CHROME: a settings heading is the app labelling itself, and the founder
    /// names it as one of the parts that stays pixel under Blend.
    static var eyebrow: Font { styled(.caption2, weight: .semibold, w95: 13, role: .chrome) }

    // MARK: Numerals

    /// Counters and balances. Monospaced digits so a changing number does not
    /// shuffle the layout around it.
    static var numeral: Font {
        SkeuFont.face.isPixel(.content)
            ? .custom(W95Font.postScriptName, size: 40, relativeTo: .largeTitle)
            : .system(.largeTitle, design: .rounded).weight(.semibold).monospacedDigit()
    }

    /// A RAW point size in the active face.
    ///
    /// The skeu screens size their text from transcribed Figma values, not
    /// from text styles, so they cannot use the tokens above — but they still
    /// have to honour the typeface switch. Every `.font(.system(size:))` in
    /// those screens went through SF Pro regardless of the setting, which is
    /// why picking W95FA did nothing there (founder bug report 2026-08-14).
    ///
    /// W95FA is set 1.22× the system size: the inverse of the 0.82 factor
    /// `W95Font` uses to keep the two faces optically level.
    /// `role` is what lets the Blend face tell furniture from the user's own
    /// words — see `TextRole`. It defaults to `.content`, so a site that says
    /// nothing gets the readable face and only the marked ones stay pixel.
    static func at(_ size: CGFloat,
                   weight: Font.Weight = .regular,
                   role: TextRole = .content) -> Font {
        face.isPixel(role)
            ? .custom(W95Font.postScriptName, fixedSize: size * 1.22)
            : .system(size: size, weight: weight)
    }

    /// Maps a token onto a system text style, or onto W95FA at the equivalent
    /// optical size when the bitmap face is selected.
    private static func styled(_ style: Font.TextStyle,
                               weight: Font.Weight,
                               w95 size: CGFloat,
                               role: TextRole = .content) -> Font {
        SkeuFont.face.isPixel(role)
            ? .custom(W95Font.postScriptName, size: size, relativeTo: style)
            : .system(style).weight(weight)
    }
}
