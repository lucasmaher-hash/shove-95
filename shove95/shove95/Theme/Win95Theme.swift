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
    /// Text that has been set aside — a completed task's title.
    ///
    /// It used to reach for `shadow`, which is right by accident in the light
    /// schemes (0x808080 grey on a pale surface) and wrong in every dark one:
    /// `shadow` is a BEVEL tone, darker than its surface, so a completed
    /// title came out near-black on a dark well and could not be read at all
    /// (founder bug report 2026-08-16). Muted toward the SURFACE instead,
    /// which is the same gesture in both directions — and in the classic
    /// scheme it lands on 0x808080, exactly the grey this replaces, so no
    /// light theme changes appearance.
    static var textMuted: Color {
        Color(hex: scheme.text.blended(toward: scheme.surface, by: 0.55))
    }
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
    /// The theme's signature colour — used for small accents like the
    /// add-photo plus. In dark schemes `titleA` is deliberately darkened for
    /// title-bar contrast, which reads as nearly invisible on a small glyph,
    /// so dark mode reaches for the brighter `titleB` stop lightened further
    /// still — title-bar brightness alone isn't enough against a dark surface.
    static var accent: Color {
        Color(hex: scheme.isDark ? scheme.titleB.lightened(by: 0.4) : scheme.titleA)
    }
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
        /// The window's one side margin, measured off the TO-DOS: the list
        /// well is full-bleed and its bevel is an OVERLAY, which paints over
        /// the first two pixels rather than pushing content in, so a task row
        /// stands exactly one grid unit from the screen.
        ///
        /// The title bar and the taskbar are bands of that same window and
        /// take the same margin. Before this the title sat at 4, its button at
        /// 2 and the taskbar buttons at 8 — three bands of one window, each
        /// beginning somewhere else (founder direction 2026-08-17). Named
        /// rather than written as `grid` at each site so the three cannot
        /// drift apart again.
        static let windowMargin: CGFloat    = grid
        static let buttonMinWidth: CGFloat  = 75
        static let buttonMinHeight: CGFloat = 23
        static let buttonCompact: CGFloat   = 16  // Default/Delete in Settings
        static let checkbox: CGFloat        = 12
        /// Raised from 18 (founder direction 2026-08-17). The controls are
        /// 14 spec px tall, so at 18 there were two left over — a hairline
        /// above and below, which reads as the ✕ touching the roof rather
        /// than sitting in the bar. At 24 there are five either side — 22 was
        /// still a shade tight over the ✕ and the bin (founder, same day).
        ///
        /// 28 is where the two looks AGREE. The skeu sheets put their ✕ at
        /// `SkeuTopBar.inset` (6) + half of `SkeuTopBar.control` (22.2) =
        /// 28.2pt below the safe area; a bar of 28 spec px centres its own
        /// controls at 28pt. Flipping Design now leaves the close button
        /// where the thumb already is instead of moving it four points
        /// (founder direction 2026-08-17, item 38).
        ///
        /// HORIZONTALLY the two stay apart on purpose: the skeu ✕ floats on a
        /// canvas and needs a margin, this one belongs to a full-bleed title
        /// bar and would look adrift inside one.
        ///
        /// This is also the top-section growth the founder asked for across
        /// every screen: one figure drives all of them.
        static let titleBar: CGFloat        = 28
        static let titleBarControlW: CGFloat = 16
        static let titleBarControlH: CGFloat = 14
        static let taskbar: CGFloat         = 28
        /// Extra breathing room above the taskbar buttons — the panel grows by
        /// this, the buttons don't (founder request 2026-08-04).
        static let taskbarTopInset: CGFloat = 4
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

extension UInt32 {
    /// Blends this hex colour toward white by `amount` (0...1). Used to lift
    /// a dark-scheme accent (already the brighter `titleB` stop) further
    /// above the surrounding dark surface — title-bar colours alone aren't
    /// bright enough for a small standalone glyph.
    func lightened(by amount: Double) -> UInt32 {
        let r = Double((self >> 16) & 0xFF), g = Double((self >> 8) & 0xFF), b = Double(self & 0xFF)
        func mix(_ c: Double) -> UInt32 { UInt32(Swift.min(255, c + (255 - c) * amount)) }
        return (mix(r) << 16) | (mix(g) << 8) | mix(b)
    }

    /// Blends this hex colour toward `other` by `amount` (0...1).
    ///
    /// Muting a foreground has to be done RELATIVE to its ground, not by
    /// darkening: a light scheme mutes toward its pale surface, a dark one
    /// mutes toward its dark surface, and the same call gives the right
    /// direction in both. Reaching for a fixed grey is what put black text
    /// on a dark well.
    func blended(toward other: UInt32, by amount: Double) -> UInt32 {
        func channel(_ shift: UInt32) -> UInt32 {
            let a = Double((self >> shift) & 0xFF)
            let b = Double((other >> shift) & 0xFF)
            return UInt32(Swift.max(0, Swift.min(255, a + (b - a) * amount)))
        }
        return (channel(16) << 16) | (channel(8) << 8) | channel(0)
    }
}

extension Color {
    /// The alpha parameter is SkeuKit's requirement (design system §2.7); Win95
    /// never passes it, since a 1995 palette has no translucency.
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}
