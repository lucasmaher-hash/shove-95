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

/// What a piece of text IS — the distinction the Blend face is built on.
///
/// `content` is the DEFAULT, deliberately. Blend is defined by what stays
/// pixel, not by what escapes it (founder direction 2026-08-16: "only the
/// important parts"), so a call site that says nothing gets the readable face.
/// Forgetting to mark a label then costs legibility for one line; the opposite
/// default would quietly costume the user's own words.
enum TextRole {
    /// The app's own furniture: the workspace name, the tab bar, a settings
    /// heading, the toggle you just pressed. Things the app says about itself,
    /// where the pixel face IS the product.
    case chrome
    /// The user's own words — a task's title, a name they typed. Never
    /// sacrificed to costume.
    case content
}

/// Which typeface the interface uses. The Win95 face is the default and the
/// point of the app; the system face exists because a bitmap-derived font is
/// genuinely hard to read for some people, and legibility outranks costume.
///
/// `blend` is the middle: the furniture keeps the pixel face, the words you
/// wrote do not. It is the setting for people who want the app to look like
/// itself and still want to read their own list (founder direction
/// 2026-08-16).
enum AppFace: String, CaseIterable, Sendable {
    /// TWO faces, not three. There was an all-pixel option; the founder cut
    /// it as too much, on the reasoning that a blend is what almost everyone
    /// actually wants and the third choice only made the decision harder
    /// (founder direction 2026-08-22).
    ///
    /// `blend` inherits the name "Retro" now that nothing retro-er exists to
    /// claim it — the label describes what a reader gets, not how the
    /// implementation mixes two faces.
    case blend, system

    var label: String {
        switch self {
        // Never "W95FA" (founder direction 2026-08-16): the file name of a
        // typeface is not what the setting is offering. The credit for the
        // face itself stays in About, where it belongs.
        case .blend:  "Retro"
        case .system: "Modern"
        }
    }

    /// Whether text in `role` is set in the pixel face.
    func isPixel(_ role: TextRole) -> Bool {
        switch self {
        case .blend:  role == .chrome
        case .system: false
        }
    }
}

enum W95Font {
    /// Set from the synced preference before any view renders. A static
    /// because the fonts are read from every view in the app, exactly like
    /// `Win95.scheme` — and rebuilt the same way when it changes.
    nonisolated(unsafe) static var face: AppFace = .blend

    /// PostScript name, verified via CoreText: family "W95FA", one Regular face.
    static let postScriptName = "W95FARegular"

    /// Standard text: 11px × pixel scale (22pt at 2×).
    static func standard(_ pixel: CGFloat, role: TextRole = .content) -> Font {
        sized(Win95.Px.fontStandard * pixel, role: role)
    }

    /// Small text (chips, status panel, buttons): 8px × pixel scale.
    static func small(_ pixel: CGFloat, role: TextRole = .content) -> Font {
        sized(Win95.Px.fontSmall * pixel, role: role)
    }

    /// Section headings: 15px × pixel scale, ABOVE standard rather than below
    /// it. A heading that names a run of tasks has to outrank them, and this
    /// one was set in `small` — the quietest size in the app — which left the
    /// day a task belonged to harder to read than the task (founder direction
    /// 2026-08-17).
    static func heading(_ pixel: CGFloat, role: TextRole = .chrome) -> Font {
        sized(Win95.Px.fontHeading * pixel, role: role)
    }

    /// The system face is set a touch smaller: W95FA is a bitmap recreation
    /// whose glyphs fill their em box, so matching the raw point size makes
    /// the system face look oversized next to the same layout.
    private static func sized(_ size: CGFloat, role: TextRole) -> Font {
        face.isPixel(role)
            ? .custom(postScriptName, fixedSize: size)
            : .system(size: size * 0.82, weight: .regular)
    }
}

// MARK: - Environment

extension EnvironmentValues {
    /// The active Win95-side face, as an OBSERVABLE value.
    ///
    /// `W95Font.face` is a static, which SwiftUI cannot watch, so the settings
    /// sheet used to be rebuilt wholesale on every face change via `.id`. That
    /// worked and cost the typewriter: a rebuilt view is a brand-new one, and
    /// `TypedText` deliberately never animates its first appearance, so the
    /// Win95 headings switched between two frames while the skeu ones typed.
    ///
    /// Reading this instead declares the dependency without destroying the
    /// tree — the same move the skeu sheet already makes with `\.skeuFace`.
    @Entry var appFace: AppFace = .blend
}
