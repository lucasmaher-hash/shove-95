//
//  Win95Scheme.swift
//  shove95
//
//  Colour schemes. Windows 95 shipped a set of named Appearance schemes, and
//  swapping between them was one of the era's small joys — so the theme picker
//  is period-correct rather than a modern bolt-on. Every scheme keeps the same
//  bevel STRUCTURE (design.md §3); only the palette changes.
//
//  `important` stays red in every scheme: colour carries exactly one meaning
//  (design.md §2), and remapping it would break that rule.
//

import SwiftUI

struct Win95Scheme: Identifiable, Equatable, Sendable {
    let id: String
    let name: String

    let surface: UInt32
    let highlight: UInt32
    let light: UInt32
    let shadow: UInt32
    let darkShadow: UInt32
    let text: UInt32
    let titleA: UInt32
    let titleB: UInt32
    let selectionBG: UInt32
    let selectionText: UInt32
    /// The list well behind the tasks (white in Classic, tinted elsewhere).
    let well: UInt32
    /// The floating status panel and its Undo tint (founder request 2026-08-04:
    /// a light panel docked above the taskbar, not silver window furniture).
    let statusBG: UInt32
    let statusAccent: UInt32
    /// True for the `*Dark` variants below. `titleA` (the accent source) is
    /// deliberately darkened for dark-mode title bars, which makes it too low
    /// contrast for small accents like the add-row plus — this flag lets
    /// `Win95.accent` pick the brighter `titleB` stop instead when dark.
    var isDark: Bool = false

    // MARK: Authentic Windows 95 Appearance schemes

    static let classic = Win95Scheme(
        id: "classic", name: "Windows Standard",
        surface: 0xC0C0C0, highlight: 0xFFFFFF, light: 0xDFDFDF,
        shadow: 0x808080, darkShadow: 0x0A0A0A, text: 0x222222,
        titleA: 0x000080, titleB: 0x1084D0,
        selectionBG: 0x000080, selectionText: 0xFFFFFF, well: 0xFFFFFF, statusBG: 0xCFE4F7, statusAccent: 0x7FB2DD)

    static let desert = Win95Scheme(
        id: "desert", name: "Desert",
        surface: 0xD5CCBB, highlight: 0xFFFFFF, light: 0xE8E1D4,
        shadow: 0x9A9081, darkShadow: 0x2B2620, text: 0x2B2620,
        titleA: 0x80471C, titleB: 0xC08A5A,
        selectionBG: 0x80471C, selectionText: 0xFFF8EC, well: 0xFFFBF2, statusBG: 0xF0DEC4, statusAccent: 0xC79A63)

    static let eggplant = Win95Scheme(
        id: "eggplant", name: "Eggplant",
        surface: 0x8E8E9E, highlight: 0xE6E6F0, light: 0xB4B4C4,
        shadow: 0x5C5C70, darkShadow: 0x141420, text: 0x14141E,
        titleA: 0x40284C, titleB: 0x6E4A80,
        selectionBG: 0x40284C, selectionText: 0xF2ECF6, well: 0xF3F1F7, statusBG: 0xD6CCE4, statusAccent: 0x9A7FB8)

    static let rose = Win95Scheme(
        id: "rose", name: "Rose",
        surface: 0xD0B0B8, highlight: 0xFFF2F5, light: 0xE4CBD2,
        shadow: 0x94707A, darkShadow: 0x2A1A1E, text: 0x2A1A1E,
        titleA: 0x80304C, titleB: 0xB56A86,
        selectionBG: 0x80304C, selectionText: 0xFFF2F5, well: 0xFFF7F9, statusBG: 0xF3D3DE, statusAccent: 0xC98BA3)

    static let slate = Win95Scheme(
        id: "slate", name: "Slate",
        surface: 0xA8B0B8, highlight: 0xEAEEF2, light: 0xC6CDD4,
        shadow: 0x6C767F, darkShadow: 0x141A1F, text: 0x141A1F,
        titleA: 0x1F3A4C, titleB: 0x4C7C99,
        selectionBG: 0x1F3A4C, selectionText: 0xEAEEF2, well: 0xF4F7FA, statusBG: 0xD3E2EE, statusAccent: 0x7FA6C2)

    // MARK: Dark variants (2026-08-14)
    //
    // Windows 95 had no dark mode; these are an invention, and they are built
    // to the same STRUCTURE rather than to authenticity — the bevel is
    // untouched, only the six colours fall. The rules that survive:
    //
    //   · highlight/light/shadow/darkShadow keep their ORDER, so a raised
    //     bevel still reads raised. Inverting the ramp would flip every
    //     control in the app into looking pressed.
    //   · `well` stays the LIGHTEST-relative surface of its scheme, because
    //     it is the paper the list is written on.
    //   · `important` is untouched (it is not part of the scheme at all) —
    //     red carries exactly one meaning in every palette and every mode.
    //   · title bars keep their hue and lose brightness, so a scheme is still
    //     recognisably itself in the dark.

    static let classicDark = Win95Scheme(
        id: "classic", name: "Windows Standard",
        surface: 0x3A3A3A, highlight: 0x5E5E5E, light: 0x4A4A4A,
        shadow: 0x1E1E1E, darkShadow: 0x000000, text: 0xE8E8E8,
        titleA: 0x000050, titleB: 0x0A5A8E,
        selectionBG: 0x1084D0, selectionText: 0xFFFFFF, well: 0x252525,
        statusBG: 0x2C3A47, statusAccent: 0x40658A, isDark: true)

    static let desertDark = Win95Scheme(
        id: "desert", name: "Desert",
        surface: 0x3D372E, highlight: 0x655D4E, light: 0x4E4739,
        shadow: 0x201C16, darkShadow: 0x000000, text: 0xEDE4D4,
        titleA: 0x502D12, titleB: 0x8A6340,
        selectionBG: 0x8A6340, selectionText: 0xFFF8EC, well: 0x282219,
        statusBG: 0x3E3324, statusAccent: 0x7A5D3B, isDark: true)

    static let eggplantDark = Win95Scheme(
        id: "eggplant", name: "Eggplant",
        surface: 0x35353F, highlight: 0x5A5A6C, light: 0x45454F,
        shadow: 0x1C1C24, darkShadow: 0x000000, text: 0xE6E6F0,
        titleA: 0x2A1A32, titleB: 0x513760,
        selectionBG: 0x6E4A80, selectionText: 0xF2ECF6, well: 0x222229,
        statusBG: 0x33283E, statusAccent: 0x66528A, isDark: true)

    static let roseDark = Win95Scheme(
        id: "rose", name: "Rose",
        surface: 0x3E3134, highlight: 0x6A565B, light: 0x4F4044,
        shadow: 0x211A1C, darkShadow: 0x000000, text: 0xF5E6EA,
        titleA: 0x521F31, titleB: 0x86475B,
        selectionBG: 0x86475B, selectionText: 0xFFF2F5, well: 0x291F22,
        statusBG: 0x3D2A31, statusAccent: 0x7A4E5F, isDark: true)

    static let slateDark = Win95Scheme(
        id: "slate", name: "Slate",
        surface: 0x333A40, highlight: 0x586570, light: 0x424B53,
        shadow: 0x1A1F23, darkShadow: 0x000000, text: 0xE4EAF0,
        titleA: 0x14252F, titleB: 0x33556B,
        selectionBG: 0x4C7C99, selectionText: 0xEAEEF2, well: 0x21272B,
        statusBG: 0x28353F, statusAccent: 0x4E7A99, isDark: true)

    static let all: [Win95Scheme] = [classic, desert, eggplant, rose, slate]
    static let allDark: [Win95Scheme] = [classicDark, desertDark, eggplantDark, roseDark, slateDark]

    static func named(_ id: String, dark: Bool = false) -> Win95Scheme {
        let set = dark ? allDark : all
        return set.first { $0.id == id } ?? (dark ? classicDark : classic)
    }

    /// This scheme in the requested lighting. `AppSettings.scheme` always holds
    /// the LIGHT instance — it is what the picker shows and what syncs — and
    /// the dark twin is looked up by id at paint time.
    func resolved(dark: Bool) -> Win95Scheme {
        dark ? Win95Scheme.named(id, dark: true) : self
    }
}
