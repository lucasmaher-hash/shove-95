//
//  HowToContent.swift
//  shove95
//
//  What the app expects you to do, written once.
//
//  Nearly every gesture here is CUSTOM — the swipe, the hold, the hold-drag,
//  Return-as-commit — and none of them announce themselves. A list is not a
//  substitute for an interface that explains itself, but it is what stands in
//  until one does, and it costs nothing to be honest about the ones that are
//  genuinely undiscoverable (the pin, the reorder, the rubber-band at the ends
//  of the chain).
//
//  ONE source for both looks. The two screens that render this have already
//  drifted once elsewhere in the app — the VoiceOver row logic is written
//  twice and no longer agrees with itself — and a help text that disagrees
//  with itself is worse than none.
//

import Foundation

enum HowTo {
    struct Item: Identifiable {
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
        Section(title: "The four tabs", items: [
            Item(action: "Today · Tomorrow · Week · General",
                 result: "One line, in that order. A task moves along it one step at a time — never two."),
            Item(action: "Swipe a task right",
                 result: "Pushes it one step later. From General it springs back: there is nowhere further."),
            Item(action: "Swipe a task left",
                 result: "Pulls it one step earlier. From Today it springs back the same way."),
            Item(action: "Anything overdue",
                 result: "Rolls into Today by itself and keeps a chip saying how long it has been waiting."),
        ]),

        Section(title: "A task", items: [
            Item(action: "Tap the circle",
                 result: "Ticks it off. It drops to the bottom of the list, struck through, and leaves for the archive later."),
            Item(action: "Tap the text",
                 result: "Edits it in place. Return commits, and so does tapping another row. Clearing it entirely leaves the old title alone."),
            Item(action: "Press and hold",
                 result: "Opens the row menu: move it anywhere on the line, flag it as important, or delete it."),
            Item(action: "Hold, then drag",
                 result: "Reorders the list by hand. A task you have placed yourself is left where you put it."),
        ]),

        Section(title: "Adding", items: [
            Item(action: "The bottom row",
                 result: "Type and press Return. The new task lands where the add row was standing."),
            Item(action: "The camera, while typing",
                 result: "Attaches a photo. Several are fine — they wait until the task exists."),
            Item(action: "The circle beside it",
                 result: "Pins the task to the Lock Screen as you write it."),
        ]),

        Section(title: "The pinned task", items: [
            Item(action: "Exactly one, app-wide",
                 result: "Across every workspace. Pinning a second one asks before it lets the first go."),
            Item(action: "On the Lock Screen",
                 result: "It carries a tick button, so it can be finished without opening the app."),
            Item(action: "It releases itself",
                 result: "Completing, deleting or archiving the task takes it off the Lock Screen."),
        ]),

        Section(title: "Elsewhere", items: [
            Item(action: "The name at the top left",
                 result: "Switches workspace. Each keeps its own list; the pin is shared across all of them."),
            Item(action: "After a move",
                 result: "A bar names what happened and offers to undo it. It retires itself after a few seconds."),
            Item(action: "A photo thumbnail",
                 result: "Opens it. It can be removed from there."),
        ]),
    ]
}
