//
//  HowToContent.swift
//  shove95
//
//  What the app expects you to do, written once.
//
//  THREE BLOCKS, and that is the whole screen (founder direction 2026-09-01).
//  It used to be thirteen items — three essentials plus three sections of
//  lookup — each a glyph, a named control and a five-word result. True, and
//  far too much: the app is simple, and a screen listing every gesture in it
//  made it look like it was not.
//
//  What survives is the three things you cannot work out by looking: going
//  live, the swipe, and workspaces. Everything cut is discoverable by using
//  the app — tapping a circle ticks a task off, the camera adds a photo, a
//  heading folds. Those never needed a manual entry; they needed one try.
//
//  Each block is now a heading, one picture, and a short paragraph under it,
//  rather than a column of terse rows. With only three of them there is room
//  to say a whole sentence, and a sentence explains where five words could
//  only label.
//
import Foundation

enum HowTo {
    /// The pictogram beside an item. Drawn, not lettered: they had to read in
    /// a look where SF Symbols are prohibited (design.md §9).
    ///
    /// A VOCABULARY, not a list of what is currently used — a case with no
    /// block pointing at it costs nothing and lets the content above change
    /// without anyone opening the drawing code. Most of these are unused
    /// since the screen came down to three; they stay for exactly that
    /// reason.
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

    /// One explained thing: a heading that sits above its frame, a single
    /// picture at the top inside it, and the words underneath.
    struct Block: Identifiable {
        let title: String
        let glyph: Glyph
        let body: String
        var id: String { title }
    }

    /// In the order someone meets them: the feature that has no visible
    /// explanation at all, then the gesture the whole app is built on, then
    /// the thing that quietly changes what the list contains.
    static let blocks: [Block] = [
        Block(title: "Go live",
              glyph: .pin,
              body: "One task at a time can be live. Tap the ring at the "
                  + "bottom left, and it sits on your Lock Screen until you "
                  + "tick it off."),

        Block(title: "Swiping",
              glyph: .swipeRight,
              body: "Swipe a task right to push it later — Today to Tomorrow, "
                  + "Tomorrow to Soon. Swipe left to bring it back."),

        Block(title: "Workspaces",
              glyph: .workspace,
              body: "The name at the top left switches between separate "
                  + "lists, so work and home never share one. The live task "
                  + "is shared between them."),
    ]
}
