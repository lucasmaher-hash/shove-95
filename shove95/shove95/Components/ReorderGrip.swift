//
//  ReorderGrip.swift
//  shove95
//
//  Three lines at the right of a task: the handle you drag it by.
//
//  It is QUIET at rest and full strength under the finger (founder direction
//  2026-08-23). The resting strength is the day chip's, so the two things at
//  the right of a row are one weight rather than two — the chip lost a quarter
//  of its own opacity in the same pass, and this followed it down.
//
//  Pinned to the FIRST LINE, not centred on the row. A task that runs to five
//  lines is still one task, and a handle floating at its middle reads as
//  belonging to the words beside it rather than to the row.
//

import SwiftUI

struct ReorderGrip: View {
    @Environment(\.skeu) private var skeu
    /// True while this row is the one being dragged.
    let isActive: Bool
    /// The glyph's own size, and the height of the first line's band.
    let size: CGFloat
    let bandHeight: CGFloat

    /// What "quiet" is worth, for a CONTROL — WCAG 1.4.11 asks 3:1 of a
    /// control's visual affordance, and this glyph is the only thing saying a
    /// row can be dragged.
    ///
    /// The quiet now comes from opacity over `ink` rather than over
    /// `inkMuted`. Dimming the muted token was compounding two reductions:
    /// at 0.75 it measured 3.16:1 and at the 0.45 asked for on 2026-08-25 it
    /// reached 1.90:1, roughly half the floor and effectively invisible in
    /// daylight (measured in review 2026-08-26). Starting from the strong
    /// token buys the same restraint at a legible strength.
    static let restingOpacity: Double = 0.58

    /// The day chip's share of the same idea. Higher because the chip is
    /// TEXT — "3 Days" is the only place the list says when a task is due —
    /// and text answers to 4.5:1, not 3:1.
    static let labelOpacity: Double = 0.72

    var body: some View {
        // Apple's own mark for this, and the one every reader already knows
        // from a list they can rearrange.
        Image(systemName: "line.3.horizontal")
            .font(SkeuFont.at(size, weight: .medium))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(skeu.ink)
            .opacity(isActive ? 1 : Self.restingOpacity)
            // A 44pt target around a small glyph: this is the one control on
            // the row you have to find without looking, because your eye is on
            // where the task is going.
            .frame(width: SkeuControl.minTouch, height: bandHeight)
            .contentShape(Rectangle())
            .accessibilityLabel("Reorder")
            .accessibilityHint("Drag to move this task up or down")
    }
}
