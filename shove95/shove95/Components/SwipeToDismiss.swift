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
//  gesture at all.
//
//  Two things the first version got wrong, both worth keeping written down:
//
//  1. It compared the drag's start against a header height measured from the
//     sheet's own top, while `startLocation` is in GLOBAL space and counts the
//     status bar. The band therefore sat above the title rather than on it,
//     and dragging the header did nothing. The safe-area inset is added now,
//     and the band is measured to include the title AND its button.
//
//  2. Offsetting the sheet revealed BLACK. Nothing is behind a full-screen
//     cover — the screen it came from is not rendered underneath — so moving
//     it exposes the void. A backdrop in the sheet's own ground colour sits
//     behind it and stays put while it travels, so what appears is the app
//     rather than a hole.
//

import SwiftUI

struct SwipeToDismiss: ViewModifier {
    /// Height of the band, measured from below the safe area, in which a
    /// downward drag dismisses — the header and its button, nothing lower.
    let headerHeight: CGFloat
    /// What shows through while the sheet travels. The sheet's own ground.
    let backdrop: Color
    let onDismiss: () -> Void

    /// How far a drag has to travel before it counts. Generous: it competes
    /// with scrolling and with the row gestures, so a hesitant drag should do
    /// nothing rather than something surprising.
    private static let distance: CGFloat = 70
    /// A flick counts sooner than a drag.
    private static let velocity: CGFloat = 320
    /// How near the leading edge a horizontal drag must start.
    private static let edge: CGFloat = 24

    @State private var offset: CGSize = .zero
    /// The status-bar inset, measured rather than assumed. `startLocation` is
    /// global and counts it; the header band is stated from below it.
    @State private var topInset: CGFloat = 0

    func body(content: Content) -> some View {
        ZStack {
            backdrop.ignoresSafeArea()
            content.offset(x: offset.width, y: offset.height)
        }
        // The measurement lives in a BACKGROUND, not around the content.
        // Wrapping the content in an ignoresSafeArea GeometryReader pulled
        // every sheet up under the status bar — the header slid off the top on
        // all four screens in both looks (founder bug report 2026-08-17).
        // A background reader takes no layout part and reports the real inset.
        .background {
            GeometryReader { proxy in
                Color.clear
                    .onAppear { topInset = proxy.safeAreaInsets.top }
                    .onChange(of: proxy.safeAreaInsets.top) { _, new in topInset = new }
            }
            .ignoresSafeArea()
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 12, coordinateSpace: .global)
                .onChanged { value in
                    switch mode(for: value) {
                    case .horizontal:
                        offset = CGSize(width: max(0, value.translation.width), height: 0)
                    case .vertical:
                        offset = CGSize(width: 0, height: max(0, value.translation.height))
                    case .none:
                        offset = .zero
                    }
                }
                .onEnded { value in
                    let mode = mode(for: value)
                    let travelled = mode == .horizontal
                        ? value.translation.width : value.translation.height
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
        let band = topInset + headerHeight
        let dx = value.translation.width, dy = value.translation.height
        // Started at the leading edge and travelling right — "back".
        if value.startLocation.x <= Self.edge, dx > abs(dy) { return .horizontal }
        // Started anywhere in the header band and travelling down.
        if value.startLocation.y <= band, dy > abs(dx) { return .vertical }
        return .none
    }
}

extension View {
    /// Closes this full-screen sheet on a drag in from the left edge, or down
    /// from its header. See `SwipeToDismiss`.
    func swipeToDismiss(headerHeight: CGFloat,
                        backdrop: Color,
                        _ onDismiss: @escaping () -> Void) -> some View {
        modifier(SwipeToDismiss(headerHeight: headerHeight,
                                backdrop: backdrop,
                                onDismiss: onDismiss))
    }
}
