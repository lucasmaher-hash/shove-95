//
//  ReorderCoordinator.swift
//  shove95
//
//  Drag-to-reorder state, hoisted OUT of the row and into the list.
//
//  It lives here for two reasons the row can't solve alone:
//
//  1. `.zIndex` only orders siblings when it's applied to the stack's own
//     child. Applied inside the row's body it was ignored, so the lifted row
//     drew in natural order — fine dragging up (later siblings draw on top),
//     but dragging DOWN it slid underneath every row it passed.
//
//  2. The rows it passes have to part to make space, and no row can know that
//     from its own state. The list reads the drag from here and displaces the
//     span between the origin and the target by one row height.
//
//  3. The enclosing ScrollView wins every vertical pan, so a row's own drag
//     gesture never sees one — the reorder simply never fired. The list
//     switches scrolling OFF while a row is armed, which is why "armed" has to
//     be visible outside the row.
//

import SwiftUI
import Shove95Kit

@Observable @MainActor
final class ReorderCoordinator {
    /// Set when a long press succeeds, before any movement. While this is on,
    /// the list stops scrolling so the row's pan can claim the vertical drag.
    private(set) var isArmed = false
    private(set) var armedTaskID: UUID?

    /// The lifted task, or nil when nothing is being dragged.
    private(set) var taskID: UUID?
    /// Its index in the active list when the lift began.
    private(set) var fromIndex = 0
    /// Signed whole-row steps travelled so far — what the other rows react to.
    private(set) var steps = 0

    func arm(taskID: UUID) {
        isArmed = true
        armedTaskID = taskID
    }

    func disarm() {
        guard taskID == nil else { return } // a live drag stays armed
        isArmed = false
        armedTaskID = nil
    }

    func isArmed(_ id: UUID) -> Bool { isArmed && armedTaskID == id }

    func begin(taskID: UUID, at index: Int) {
        self.taskID = taskID
        fromIndex = index
        steps = 0
    }

    func update(steps newSteps: Int) {
        guard taskID != nil, newSteps != steps else { return }
        steps = newSteps
    }

    func end() {
        taskID = nil
        steps = 0
        isArmed = false
        armedTaskID = nil
    }

    func isDragging(_ id: UUID) -> Bool { taskID == id }

    /// How far a row that is NOT being dragged should slide to open a gap.
    /// Rows in the swept span move one height against the drag direction.
    func displacement(for index: Int, rowHeight: CGFloat) -> CGFloat {
        guard taskID != nil, steps != 0 else { return 0 }
        let target = fromIndex + steps
        if steps > 0, index > fromIndex, index <= target { return -rowHeight }
        if steps < 0, index < fromIndex, index >= target { return rowHeight }
        return 0
    }
}
