//
//  EditingCoordinator.swift
//  shove95
//
//  Which field currently holds the keyboard, hoisted out of the rows so the
//  LIST can react to it. A row knows it is being edited; only the list can
//  scroll it clear of the keyboard.
//

import SwiftUI
import Shove95Kit

@Observable @MainActor
final class EditingCoordinator {
    /// The task being edited, the add row (`addRowID`), or nil.
    var focused: String?

    /// The focused field's bottom edge in global coordinates. The list needs
    /// it to answer the only question that matters: is this field actually
    /// under the keyboard? A field already in the clear must not be yanked.
    var focusedBottom: CGFloat = 0

    /// Scroll identity for the permanent capture row at the bottom of a list.
    static let addRowID = "add-row"

    func begin(_ id: String, bottom: CGFloat) {
        focused = id
        focusedBottom = bottom
    }

    /// Only the field that claimed focus may release it — a stale row losing
    /// focus after another has taken it must not clear the new one.
    func end(_ id: String) {
        if focused == id {
            focused = nil
            focusedBottom = 0
        }
    }
}
