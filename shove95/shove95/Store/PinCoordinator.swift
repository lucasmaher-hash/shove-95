//
//  PinCoordinator.swift
//  shove95
//
//  The one pinned task, and the question that guards it.
//
//  Borrowed from Mononote: an app holds ONE note, and its whole point is that
//  the note leaves the app — it sits on the Lock Screen and in the Dynamic
//  Island until you are done with it. The transferable idea is not "only one
//  item"; shove.95 is a list and stays a list. It is that exactly one thing
//  may follow you around, and you have to decide which.
//
//  That decision is the reason this type exists. Pinning a second task
//  silently would make the limit feel like a bug — you pin something, and the
//  thing you pinned this morning is gone without a word. So the swap is a
//  question, asked once, in whichever look is running.
//
//  The coordinator owns the QUESTION, not the pin: `TaskStore.pin(_:)` is
//  still the only writer. Both roots present their own dialog against this
//  state, so the two looks cannot drift on what pinning means — only on how
//  the dialog is drawn.
//

import SwiftUI
import Shove95Kit

@MainActor
@Observable
final class PinCoordinator {

    /// A pin held back until the user answers. `outgoing` is the title of the
    /// task that currently holds the pin — the dialog needs it to name what
    /// is about to be let go.
    struct Replacement: Equatable {
        let incoming: UUID
        let incomingTitle: String
        let outgoingTitle: String
    }

    private(set) var replacement: Replacement?

    /// True once the user has been told that Live Activities are switched off
    /// for shove.95 in iOS Settings. Told once, never again — see
    /// `LiveActivityController`.
    var didWarnAboutDisabledActivities = false

    /// The single entry point for the pin control in both looks.
    ///
    /// Unpinning never asks: taking something off the Lock Screen is what the
    /// user just said they wanted, and it is one tap to undo. Only REPLACING
    /// asks, because that quietly discards a decision made earlier.
    func toggle(_ task: TaskItem, store: TaskStore) {
        if task.isPinned {
            store.unpin(task)
            return
        }
        if let held = store.pinnedTask(), held.id != task.id {
            replacement = Replacement(incoming: task.id,
                                      incomingTitle: task.title,
                                      outgoingTitle: held.title)
            return
        }
        store.pin(task)
    }

    func confirm(store: TaskStore) {
        defer { replacement = nil }
        guard let pending = replacement,
              let task = store.task(withID: pending.incoming) else { return }
        store.pin(task)
    }

    func cancel() {
        replacement = nil
    }
}
