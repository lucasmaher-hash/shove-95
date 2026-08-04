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

    static let all: [Win95Scheme] = [classic, desert, eggplant, rose, slate]

    static func named(_ id: String) -> Win95Scheme {
        all.first { $0.id == id } ?? classic
    }
}
