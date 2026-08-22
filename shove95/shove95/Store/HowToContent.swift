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
//  TWO PARTS, and the split is the point (founder direction 2026-08-17).
//  `essentials` is the shape of the app: the line tasks travel along, the one
//  live thing, and the workspaces holding it all. Someone who reads only that
//  can use shove95. Everything else is lookup — real, but nothing you need
//  before you start — and sits below a clear gap so it reads as reference
//  rather than as more of the same.
//
//  The result lines were roughly twice this long and the screen read as a
//  manual. Every one of them is now the shortest true sentence: five words is
//  a glance, twelve is reading (founder direction, same day).
//
//  ONE source for both looks. The two screens that render this have already
//  drifted once elsewhere in the app — the VoiceOver row logic is written
//  twice and no longer agrees with itself — and help that disagrees with
//  itself is worse than none.
//

import Foundation

enum HowTo {
    /// The pictogram beside an item. Drawn, not lettered: they had to read in
    /// a look where SF Symbols are prohibited (design.md §9).
    ///
    /// A VOCABULARY, not a list of what is currently used — a case with no
    /// item pointing at it costs nothing and lets the content above change
    /// without anyone opening the drawing code.
    enum Glyph: String {
        case line           // the dated tabs, as a row of steps
        case swipeRight
        case swipeLeft
        case clock
        case tick
        case caret          // tap to edit
        case hold
        case drag
        case plus
        case camera
        case calendar
        case fold           // a section heading that opens and shuts
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

    /// The top of the screen, above the gap. No heading: these are not a
    /// category, they are the app.
    static let essentials: [Item] = [
        Item(glyph: .line, action: "Today · Tomorrow · Soon",
             result: "Swipe a task right for later, left for earlier."),
        Item(glyph: .pin, action: "The ring, bottom left",
             result: "One live thing, on your Lock Screen."),
        Item(glyph: .workspace, action: "The name, top left",
             result: "Separate lists. Live is shared."),
    ]

    /// Everything below the gap: true, and lookup.
    static let sections: [Section] = [
        Section(title: "A task", items: [
            Item(glyph: .tick, action: "Tap the circle", result: "Ticks it off."),
            Item(glyph: .caret, action: "Tap the text", result: "Return commits."),
            Item(glyph: .hold, action: "Press and hold", result: "Move, flag, delete."),
            Item(glyph: .drag, action: "Hold, then drag", result: "Reorder by hand."),
            Item(glyph: .photo, action: "A thumbnail", result: "Opens it. Remove it there."),
        ]),

        Section(title: "Adding", items: [
            Item(glyph: .plus, action: "The add row", result: "Type, press Return."),
            Item(glyph: .camera, action: "The camera", result: "Attach a photo."),
            Item(glyph: .calendar, action: "The calendar", result: "Give it a day."),
        ]),

        Section(title: "In Soon", items: [
            Item(glyph: .fold, action: "Tap a heading", result: "Folds that day away."),
            Item(glyph: .clock, action: "Overdue", result: "Rolls into Today by itself."),
        ]),
    ]
}
