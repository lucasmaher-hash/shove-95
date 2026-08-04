//
//  RowInteraction.swift
//  shove95
//
//  The task row's ENTIRE touch layer — press, tap, hold, swipe, reorder — as
//  one UIKit state machine. The row attaches no SwiftUI gesture of any kind;
//  design.md §16 records why (every SwiftUI construct broke scrolling on
//  device) and the five standing traps this file must respect.
//
//  Phases:
//
//      idle ──touch──▶ pending ──0.4s still──▶ held ──drag──▶ reordering
//                        │  │
//                        │  ├─▶ horizontal > slop ──▶ swiping
//                        │  └─▶ vertical   > slop ──▶ surrendered (scroll's)
//                        └─▶ lift ──▶ tap
//
//  The scroll view is the other player: with the row surrendered it scrolls
//  and then CANCELS our touches; while a row is armed (held) the list sets
//  `.scrollDisabled`, so the vertical axis belongs to the reorder.
//

import SwiftUI
import UIKit

/// Everything the row wants to know, in one bundle. All callbacks are
/// MainActor — UIKit touch delivery is main-thread.
struct RowGestureHandlers {
    /// Touch-down (after the 0.12s intent delay) and touch-up/cancel.
    var onPressChanged: (Bool) -> Void
    /// A clean tap: no hold fired, no movement past slop.
    var onTap: () -> Void
    /// 0.4s stationary. The row responds by arming + showing the menu.
    var onHold: () -> Void
    /// Live horizontal drag, window-space dx from touch-down.
    var onSwipeChanged: (CGFloat) -> Void
    /// Fingers up after a swipe: final dx, signed velocity (pt/s), and the
    /// touch's starting x in window space — the row scales its commit
    /// threshold to the runway the finger actually had before the screen edge.
    var onSwipeEnded: (CGFloat, CGFloat, CGFloat) -> Void
    /// The system or scroll view took the touch mid-swipe.
    var onSwipeCancelled: () -> Void
    /// Live vertical drag while armed, window-space dy from touch-down.
    var onReorderChanged: (CGFloat) -> Void
    /// Fingers up (or cancelled) after a reorder — commit what we have.
    var onReorderEnded: () -> Void
    /// Whether a hold has armed this row (menu up) — drag becomes reorder.
    var isArmed: () -> Bool
}

/// SwiftUI wrapper. Sits in the row's `.background`, above the colour fill and
/// below the content, so nested controls (checkbox, TextField) win their own
/// touches and everything else lands here.
struct RowGestureView: UIViewRepresentable {
    let handlers: RowGestureHandlers

    func makeUIView(context: Context) -> RowGestureCatcher {
        let view = RowGestureCatcher()
        view.backgroundColor = .clear
        view.isMultipleTouchEnabled = false
        view.handlers = handlers
        return view
    }

    func updateUIView(_ view: RowGestureCatcher, context: Context) {
        view.handlers = handlers // closures capture the task — rebind on update
    }
}

final class RowGestureCatcher: UIView {
    var handlers: RowGestureHandlers?

    private enum Phase {
        case idle        // no touch
        case pending     // finger down, nothing decided
        case held        // hold fired; menu up; vertical drag = reorder
        case swiping     // horizontal drag owns the touch
        case reordering  // vertical drag while armed
        case surrendered // vertical drag, not armed — the scroll view's touch
    }

    private var phase: Phase = .idle

    // Window-space tracking (trap 2: the row MOVES with the drag, so
    // self-relative coordinates read half the real distance).
    private var startPoint: CGPoint = .zero
    private var startTime: TimeInterval = 0
    private var lastPoint: CGPoint = .zero
    private var lastTime: TimeInterval = 0
    private var segmentVelocityX: CGFloat = 0

    private var tintWork: DispatchWorkItem?
    private var holdWork: DispatchWorkItem?

    /// Movement before a touch stops being a tap/hold candidate.
    private static let slop: CGFloat = 10
    /// How much more horizontal than vertical a drag must be to be a swipe.
    private static let axisBias: CGFloat = 1.2
    /// Stationary time before the hold (menu) fires.
    private static let holdDelay: TimeInterval = 0.4
    /// Stationary time before the press tint shows. This is what keeps every
    /// scroll that happens to start on a row from flashing it grey: a moving
    /// finger passes slop well inside 0.12s and the tint never fires.
    private static let tintDelay: TimeInterval = 0.12

    private func point(_ touch: UITouch) -> CGPoint {
        touch.location(in: window ?? self)
    }

    // Trap 1: delaysContentTouches swallows the first ~150ms of a quick swipe.
    // Configure from touchesBegan too — at didMoveToWindow the SwiftUI scroll
    // view is not always in the ancestor chain yet.
    override func didMoveToWindow() {
        super.didMoveToWindow()
        configureEnclosingScrollView()
    }

    private func configureEnclosingScrollView() {
        var ancestor: UIView? = superview
        while let view = ancestor {
            if let scrollView = view as? UIScrollView {
                scrollView.delaysContentTouches = false
                scrollView.canCancelContentTouches = true
                return
            }
            ancestor = view.superview
        }
    }

    // MARK: Touches

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        guard phase == .idle, let touch = touches.first else { return }
        configureEnclosingScrollView()

        phase = .pending
        startPoint = point(touch)
        startTime = touch.timestamp
        lastPoint = startPoint
        lastTime = touch.timestamp
        segmentVelocityX = 0

        let tint = DispatchWorkItem { [weak self] in
            guard let self, self.phase == .pending || self.phase == .held else { return }
            self.handlers?.onPressChanged(true)
        }
        tintWork?.cancel()
        tintWork = tint
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.tintDelay, execute: tint)

        let hold = DispatchWorkItem { [weak self] in
            guard let self, self.phase == .pending else { return }
            self.phase = .held
            self.handlers?.onHold()
        }
        holdWork?.cancel()
        holdWork = hold
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.holdDelay, execute: hold)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        guard let touch = touches.first else { return }
        let p = point(touch)
        let dx = p.x - startPoint.x
        let dy = p.y - startPoint.y

        let dt = touch.timestamp - lastTime
        if dt > 0 { segmentVelocityX = (p.x - lastPoint.x) / CGFloat(dt) }
        lastPoint = p
        lastTime = touch.timestamp

        switch phase {
        case .pending:
            guard hypot(dx, dy) > Self.slop else { return }
            tintWork?.cancel()
            holdWork?.cancel()
            if abs(dx) > abs(dy) * Self.axisBias {
                phase = .swiping
                handlers?.onPressChanged(false) // a swiping row isn't "pressed"
                handlers?.onSwipeChanged(dx)
            } else {
                // Vertical, not armed: the scroll view's touch. It will cancel
                // us the moment it starts scrolling; never look again.
                phase = .surrendered
                handlers?.onPressChanged(false)
            }

        case .held:
            // Menu is up. Movement past slop turns the hold into a reorder
            // (the row-side handler dismisses the menu on first change).
            if handlers?.isArmed() == true, hypot(dx, dy) > Self.slop {
                phase = .reordering
                handlers?.onPressChanged(false)
                handlers?.onReorderChanged(dy)
            }

        case .swiping:
            handlers?.onSwipeChanged(dx)

        case .reordering:
            handlers?.onReorderChanged(dy)

        case .idle, .surrendered:
            break
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        tintWork?.cancel()
        holdWork?.cancel()
        let dx = (touches.first.map { point($0).x } ?? lastPoint.x) - startPoint.x

        switch phase {
        case .pending:
            handlers?.onPressChanged(false)
            handlers?.onTap()
        case .held:
            // Lift after the menu opened: the menu stays, the row-side tint
            // persists via isMenuOpen — just clear the physical press.
            handlers?.onPressChanged(false)
        case .swiping:
            handlers?.onPressChanged(false)
            handlers?.onSwipeEnded(dx, endVelocity(touches, dx: dx), startPoint.x)
        case .reordering:
            handlers?.onPressChanged(false)
            handlers?.onReorderEnded()
        case .idle, .surrendered:
            handlers?.onPressChanged(false)
        }
        phase = .idle
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        tintWork?.cancel()
        holdWork?.cancel()
        handlers?.onPressChanged(false)

        switch phase {
        case .swiping: handlers?.onSwipeCancelled()
        case .reordering: handlers?.onReorderEnded() // commit what we have
        case .idle, .pending, .held, .surrendered: break
        }
        phase = .idle
    }

    /// Trap 3: synthesised touches can share timestamps, zeroing the
    /// per-segment velocity — fall back to the whole gesture's average.
    private func endVelocity(_ touches: Set<UITouch>, dx: CGFloat) -> CGFloat {
        if segmentVelocityX != 0 { return segmentVelocityX }
        let elapsed = (touches.first?.timestamp ?? lastTime) - startTime
        return elapsed > 0 ? dx / CGFloat(elapsed) : 0
    }
}
