//
//  W95Font.swift
//  shove95
//
//  W95FA — OpenType recreation of the Windows 95 MS Sans Serif bitmap.
//  Bundled at Resources/W95FA.otf (SIL OFL, see W95FA-LICENSE.txt).
//  One typeface, one size, one weight everywhere (design.md §6); it renders
//  crisp only at whole multiples of 11px — which the stepped `pixel` unit
//  guarantees (22/33/44pt).
//

import SwiftUI

/// Which typeface the whole interface uses. The Win95 face is the default and
/// the point of the app; the system face exists because a bitmap-derived font
/// is genuinely hard to read for some people, and legibility outranks costume.
enum AppFace: String, CaseIterable, Sendable {
    case w95, system

    var label: String { self == .w95 ? "W95FA" : "System" }
}

enum W95Font {
    /// Set from the synced preference before any view renders. A static
    /// because the fonts are read from every view in the app, exactly like
    /// `Win95.scheme` — and rebuilt the same way when it changes.
    nonisolated(unsafe) static var face: AppFace = .w95

    /// PostScript name, verified via CoreText: family "W95FA", one Regular face.
    static let postScriptName = "W95FARegular"

    /// Standard text: 11px × pixel scale (22pt at 2×).
    static func standard(_ pixel: CGFloat) -> Font {
        sized(Win95.Px.fontStandard * pixel)
    }

    /// Small text (chips, status panel, buttons): 8px × pixel scale.
    static func small(_ pixel: CGFloat) -> Font {
        sized(Win95.Px.fontSmall * pixel)
    }

    /// The system face is set a touch smaller: W95FA is a bitmap recreation
    /// whose glyphs fill their em box, so matching the raw point size makes
    /// the system face look oversized next to the same layout.
    private static func sized(_ size: CGFloat) -> Font {
        switch face {
        case .w95:    return .custom(postScriptName, fixedSize: size)
        case .system: return .system(size: size * 0.82, weight: .regular)
        }
    }
}
