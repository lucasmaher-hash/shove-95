//
//  Win95Theme.swift
//  shove95
//
//  Design tokens transcribed from docs/design.md §§1–4.
//  RULE (design.md §1): nothing in the app hard-codes a point value that the
//  spec expresses in 1995 pixels — everything multiplies the `pixel` unit.
//

import SwiftUI

// MARK: - The pixel unit (design.md §1)

extension EnvironmentValues {
    /// One 1995 pixel in points. 2 = default scale; 3/4 = stepped Dynamic Type.
    @Entry var pixel: CGFloat = 2
}

// MARK: - Palette (design.md §2 — six colors carry the whole interface)

enum Win95 {
    // Chrome
    static let surface     = Color(hex: 0xC0C0C0) // every chrome surface
    static let highlight   = Color(hex: 0xFFFFFF) // bevel outer top-left (raised); list well bg
    static let light       = Color(hex: 0xDFDFDF) // bevel inner top-left (raised)
    static let shadow      = Color(hex: 0x808080) // bevel inner bottom-right (raised); secondary text
    static let darkShadow  = Color(hex: 0x0A0A0A) // bevel outer bottom-right (raised)
    static let text        = Color(hex: 0x222222) // all primary text

    // Accents — one meaning each (design.md §2)
    static let important        = Color(hex: 0xFF0000) // Important tasks. Nothing else is red.
    static let titleActiveA     = Color(hex: 0x000080) // title bar gradient start (the app's only gradient)
    static let titleActiveB     = Color(hex: 0x1084D0) // title bar gradient end
    static let titleInactiveA   = Color(hex: 0x808080) // macOS only
    static let titleInactiveB   = Color(hex: 0xB5B5B5) // macOS only
    static let selectionBG      = Color(hex: 0x000080) // row being dragged/swiped
    static let selectionText    = Color(hex: 0xFFFFFF)
    static let desktop          = Color(hex: 0x008080) // teal — macOS only, unused on iOS

    static let titleBarGradient = LinearGradient(
        colors: [titleActiveA, titleActiveB],
        startPoint: .leading,
        endPoint: .trailing
    )
}

// MARK: - Metrics (design.md §4 — spec px → pt = value × pixel)

extension Win95 {
    /// All values in 1995 pixels; multiply by the environment `pixel` to get points.
    enum Px {
        static let bevel: CGFloat           = 2   // two nested 1px frames
        static let grid: CGFloat            = 4   // spacing grid: 2/4/8/16/24
        static let buttonMinWidth: CGFloat  = 75
        static let buttonMinHeight: CGFloat = 23
        static let checkbox: CGFloat        = 12
        static let titleBar: CGFloat        = 18
        static let titleBarControlW: CGFloat = 16
        static let titleBarControlH: CGFloat = 14
        static let taskbar: CGFloat         = 28
        static let statusBar: CGFloat       = 12
        static let scrollbar: CGFloat       = 16  // macOS-relevant
        static let thumbnail: CGFloat       = 32  // photo thumbnail (64pt @2×)
        static let fontStandard: CGFloat    = 11  // W95FA standard size
        static let fontSmall: CGFloat       = 8   // taskbar clock well
    }

    /// Deliberate deviation from the 1995 spec (design.md §4): minimum touch
    /// row height is a fixed 44pt at every pixel scale — Apple's tap minimum
    /// overrides authenticity.
    static let rowMinHeight: CGFloat = 44
}

// MARK: - Hex helper

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
