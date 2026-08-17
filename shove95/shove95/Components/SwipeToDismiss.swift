//
//  SwipeToDismiss.swift
//  shove95
//
//  Two ways out of a full-screen sheet: in from the left edge, or down from
//  the header.
//
//  Settings, About, How to use and Archive all cover the whole screen, and a
//  full-screen cover has no system dismiss gesture of its own — the ✕ was the
//  only exit. Both looks now take the two gestures people already have in
//  their hands (founder direction 2026-08-17).
//
//  THE LEFT EDGE, not anywhere. A horizontal drag in the middle of a settings
//  screen is a swipe on a task row everywhere else in this app; only a drag
//  that BEGINS at the screen's edge means "back", which is also what iOS
//  itself has taught.
//
//  THE HEADER, not the whole page. A downward drag lower down is a scroll, and
//  a sheet that closes when you try to scroll it is worse than one with no
//  gesture at all. Confined to the header band, it also stays clear of the
//  system's own pull-down from the very top of the display.
//

import SwiftUI

struct SwipeToDismiss: ViewModifier {
    /// Height of the band, measured from the top, in which a downward drag
    /// dismisses. The header's own height — below it, dragging scrolls.
    let headerHeight: CGFloat
    let onDismiss: () -> Void

    /// How far a drag has to travel before it counts. Generous: this competes
    /// with scrolling and with the row gestures, so a hesitant drag should do
    /// nothing rather than something surprising.
    private static let distance: CGFloat = 70
    /// A flick counts sooner than a drag.
    private static let velocity: CGFloat = 320
    /// How near the leading edge a horizontal drag must start.
    private static let edge: CGFloat = 24

    @State private var offset: CGSize = .zero

    func body(content: Content) -> some View {
        content
            .offset(x: offset.width, y: offset.height)
            .simultaneousGesture(
                DragGesture(minimumDistance: 12, coordinateSpace: .global)
                    .onChanged { value in
                        switch mode(for: value) {
                        case .horizontal: offset = CGSize(width: max(0, value.translation.width), height: 0)
                        case .vertical:   offset = CGSize(width: 0, height: max(0, value.translation.height))
                        case .none:       offset = .zero
                        }
                    }
                    .onEnded { value in
                        let mode = mode(for: value)
                        let travelled = mode == .horizontal ? value.translation.width : value.translation.height
                        let speed = mode == .horizontal
                            ? value.predictedEndTranslation.width - value.translation.width
                            : value.predictedEndTranslation.height - value.translation.height
                        let committed = mode != .none
                            && (travelled > Self.distance || speed > Self.velocity)

                        if committed {
                            SkeuHaptic.press()
                            onDismiss()
                        }
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            offset = .zero
                        }
                    }
            )
    }

    private enum Mode { case horizontal, vertical, none }

    private func mode(for value: DragGesture.Value) -> Mode {
        let dx = value.translation.width, dy = value.translation.height
        // Started at the leading edge and travelling right — "back".
        if value.startLocation.x <= Self.edge, dx > abs(dy) { return .horizontal }
        // Started in the header band and travelling down — "put it away".
        if value.startLocation.y <= headerHeight, dy > abs(dx) { return .vertical }
        return .none
    }
}

extension View {
    /// Closes this full-screen sheet on a drag in from the left edge, or down
    /// from its header. See `SwipeToDismiss`.
    func swipeToDismiss(headerHeight: CGFloat, _ onDismiss: @escaping () -> Void) -> some View {
        modifier(SwipeToDismiss(headerHeight: headerHeight, onDismiss: onDismiss))
    }
}
