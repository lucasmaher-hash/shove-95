//
//  HowToContent.swift
//  shove95
//
//  What the app expects you to do, written once.
//
//  Nearly every gesture here is CUSTOM — the swipe, the hold, the hold-drag,
//  Return-as-commit — and none of them announce themselves. What stands in
//  until the interface explains itself is this: a picture of the gesture, its
//  name, and one line saying what happens. Not a paragraph. A reader looking
//  something up scans the pictures first and only reads the line under the one
//  that matches (founder direction 2026-08-16).
//
//  ONE source for both looks. The two screens that render this have already
//  drifted once elsewhere in the app — the VoiceOver row logic is written
//  twice and no longer agrees with itself — and help that disagrees with
//  itself is worse than none.
//

import Foundation

enum HowTo {
    /// The pictogram beside an item. Drawn, not lettered: these have to read
    /// in the Win95 look too, where SF Symbols are prohibited (design.md §9).
    enum Glyph: String {
        case line           // the three dated tabs, as a row of steps
        case swipeRight
        case swipeLeft
        case clock
        case tick
        case caret          // tap to edit
        case hold
        case drag
        case plus
        case camera
        case pin
        case lockScreen
        case workspace
        case undo
        case photo
    }

    struct Item: Identifiable {
        let glyph: Glyph
        let action: String
        let result: String
        var id: String { action }
    }

    struct Section: Identifiable {
        let title: String
        let items: [Item]
        var id: String { title }
    }

    static let sections: [Section] = [
        Section(title: "The three tabs", items: [
            Item(glyph: .line, action: "Today · Tomorrow · General",
                 result: "One line. A task moves along it one step at a time."),
            Item(glyph: .swipeRight, action: "Swipe right",
                 result: "One step later. From General it springs back."),
            Item(glyph: .swipeLeft, action: "Swipe left",
                 result: "One step earlier. From Today it springs back."),
            Item(glyph: .clock, action: "Overdue",
                 result: "Rolls into Today by itself, and says how long it waited."),
        ]),

        Section(title: "A task", items: [
            Item(glyph: .tick, action: "Tap the circle",
                 result: "Ticks it off. It sinks to the bottom."),
            Item(glyph: .caret, action: "Tap the text",
                 result: "Edits in place. Return commits."),
            Item(glyph: .hold, action: "Press and hold",
                 result: "The row menu: move, flag, delete."),
            Item(glyph: .drag, action: "Hold, then drag",
                 result: "Reorders by hand, and it stays where you put it."),
        ]),

        Section(title: "Adding", items: [
            Item(glyph: .plus, action: "The bottom row",
                 result: "Type, press Return."),
            Item(glyph: .camera, action: "The camera",
                 result: "Attaches photos while you write."),
        ]),

        Section(title: "Live", items: [
            Item(glyph: .pin, action: "The ring, bottom left",
                 result: "Its own tab, for the one thing you are doing now."),
            Item(glyph: .plus, action: "Go Live",
                 result: "Type it, and it goes straight to the Lock Screen."),
            Item(glyph: .lockScreen, action: "There it has a tick",
                 result: "So it finishes without opening the app."),
            Item(glyph: .caret, action: "The Live switch",
                 result: "Takes it off the Lock Screen. The text stays put."),
        ]),

        Section(title: "Elsewhere", items: [
            Item(glyph: .workspace, action: "The name, top left",
                 result: "Switches workspace. The live note is shared across all."),
            Item(glyph: .undo, action: "After a move",
                 result: "A bar offers to undo it, then retires."),
            Item(glyph: .photo, action: "A thumbnail",
                 result: "Opens the photo. It can be removed there."),
        ]),
    ]
}
