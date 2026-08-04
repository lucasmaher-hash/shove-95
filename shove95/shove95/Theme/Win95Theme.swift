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

    /// The active scheme, carried through the environment so SwiftUI can SEE it.
    ///
    /// The palette itself is served by `Win95`'s static accessors, which SwiftUI
    /// cannot track: a view whose inputs are unchanged is never re-rendered, so
    /// it keeps painting the old colours. `TitleBar` hit this exactly — its
    /// inputs (title, isClose, closure) don't move when the scheme does, so the
    /// Settings window's own title bar stayed on the previous palette while
    /// everything around it repainted. Views that must repaint on a scheme
    /// change read this value and paint from it.
    @Entry var win95Scheme: Win95Scheme = .classic
}

// MARK: - Stepped Dynamic Type (design.md §7, FR-015)

/// The pixel unit is the accessibility mechanism: the whole interface scales in
/// WHOLE-pixel steps, exactly like changing display resolution on a CRT. Whole
/// multiples keep the bitmap-derived font crisp — continuous scaling would land
/// it on fractional sizes and turn it to mush.
struct PixelScale: ViewModifier {
    @Environment(\.dynamicTypeSize) private var typeSize

    private var pixel: CGFloat {
        switch typeSize {
        case .xSmall, .small, .medium, .large, .xLarge: 2
        case .xxLarge, .xxxLarge, .accessibility1, .accessibility2: 3
        default: 4 // accessibility3 and above
        }
    }

    func body(content: Content) -> some View {
        content.environment(\.pixel, pixel)
    }
}

// MARK: - Palette (design.md §2 — six colors carry the whole interface)

enum Win95 {
    /// The active colour scheme. Set by AppSettings; RootView rebuilds its
    /// subtree when it changes (see `.id(settings.scheme.id)`), which is what
    /// makes these computed properties re-read.
    nonisolated(unsafe) static var scheme: Win95Scheme = .classic

    // Chrome
    static var surface: Color     { Color(hex: scheme.surface) }
    static var highlight: Color   { Color(hex: scheme.highlight) }
    static var light: Color       { Color(hex: scheme.light) }
    static var shadow: Color      { Color(hex: scheme.shadow) }
    static var darkShadow: Color  { Color(hex: scheme.darkShadow) }
    static var text: Color        { Color(hex: scheme.text) }
    /// The list well behind the tasks.
    static var well: Color        { Color(hex: scheme.well) }

    // Accents — one meaning each (design.md §2)
    /// Important tasks. Red in EVERY scheme: colour carries exactly one
    /// meaning, so this is deliberately not themeable.
    static let important = Color(hex: 0xFF0000)
    static var titleActiveA: Color   { Color(hex: scheme.titleA) }
    static var titleActiveB: Color   { Color(hex: scheme.titleB) }
    static var selectionBG: Color    { Color(hex: scheme.selectionBG) }
    static var selectionText: Color  { Color(hex: scheme.selectionText) }
    static var statusBG: Color     { Color(hex: scheme.statusBG) }
    /// The theme's signature colour (the title bar's dark stop) — used for
    /// small accents like the add-photo plus.
    static var accent: Color       { Color(hex: scheme.titleA) }
    static var statusAccent: Color { Color(hex: scheme.statusAccent) }
    static let desktop = Color(hex: 0x008080) // teal — macOS only

    static var titleBarGradient: LinearGradient {
        LinearGradient(colors: [titleActiveA, titleActiveB],
                       startPoint: .leading, endPoint: .trailing)
    }
}

// MARK: - Metrics (design.md §4 — spec px → pt = value × pixel)

extension Win95 {
    /// All values in 1995 pixels; multiply by the environment `pixel` to get points.
    enum Px {
        static let bevel: CGFloat           = 2   // two nested 1px frames
        static let grid: CGFloat            = 4   // spacing grid: 2/4/8/16/24
        static let buttonMinWidth: CGFloat  = 75
        static let buttonMinHeight: CGFloat = 23
        static let buttonCompact: CGFloat   = 16  // Default/Delete in Settings
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

    /// Deliberate deviation from the 1995 spec (design.md §4): Apple's 44pt tap
    /// minimum overrides authenticity. It is a FLOOR, not a fixed value — at 3×
    /// and 4× the scaled checkbox is taller than 44pt, so the row must grow with
    /// it or the control overflows its row (caught at 4× on 2026-08-04).
    static let rowMinTouch: CGFloat = 44

    static func rowHeight(_ pixel: CGFloat) -> CGFloat {
        max(rowMinTouch, (Px.checkbox + Px.grid * 2) * pixel)
    }
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
