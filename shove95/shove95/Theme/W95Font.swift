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

enum W95Font {
    /// PostScript name, verified via CoreText: family "W95FA", one Regular face.
    static let postScriptName = "W95FARegular"

    /// Standard text: 11px × pixel scale (22pt at 2×).
    static func standard(_ pixel: CGFloat) -> Font {
        .custom(postScriptName, fixedSize: Win95.Px.fontStandard * pixel)
    }

    /// Small text (taskbar clock well): 8px × pixel scale.
    static func small(_ pixel: CGFloat) -> Font {
        .custom(postScriptName, fixedSize: Win95.Px.fontSmall * pixel)
    }
}
