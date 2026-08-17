//
//  KeyboardDock.swift
//  shove95
//
//  Reading the keyboard's OWN animation off its notification, so a list
//  getting out of its way travels WITH it rather than beside it.
//
//  Both looks dock a focused field the same way and were doing the same
//  arithmetic twice, each animating on a hand-picked `easeOut(0.25)` that had
//  nothing to do with what the keyboard was actually doing. UIKit posts both a
//  duration and a curve; matched, the inset, the lift and the keyboard are one
//  movement instead of three that happen to overlap (founder bug report
//  2026-08-17).
//

import SwiftUI

enum KeyboardDock {
    struct Change {
        /// The keyboard's top edge in global coordinates; `.infinity` when it
        /// is not on screen, so a "is this field covered" test is just a
        /// comparison and needs no special case.
        let top: CGFloat
        /// How far the keyboard eats into the LIST, once the chrome already
        /// parked at the bottom is discounted — the keyboard covers that
        /// first, and the list must not inset itself for it twice.
        let overlap: CGFloat
        /// The keyboard's own animation, for everything that moves with it.
        let animation: Animation
    }

    /// `chrome` is whatever this look keeps docked at the bottom: the Win95
    /// taskbar, the skeu tab bar.
    static func read(_ note: Notification, chrome: CGFloat) -> Change? {
        guard let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey]
                as? CGRect else { return nil }

        let screenHeight = (note.object as? UIScreen)?.bounds.height
            ?? UIApplication.shared.connectedScenes
                .compactMap { ($0 as? UIWindowScene)?.screen.bounds.height }
                .first ?? frame.maxY

        let covered = max(0, screenHeight - frame.origin.y)
        return Change(top: covered > 0 ? frame.origin.y : .infinity,
                      overlap: max(0, covered - chrome),
                      animation: animation(from: note))
    }

    /// The curve arrives as a RAW `UIView.AnimationCurve` value, and for
    /// keyboards it is almost always 7 — a private ease with no public case
    /// and no SwiftUI equivalent. `easeInOut` is its closest relative and is
    /// what the default branch is for; the named curves are handled anyway
    /// because a hardware keyboard attaching does send them.
    private static func animation(from note: Notification) -> Animation {
        let duration = note.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey]
            as? Double ?? 0.25
        // Zero means "do not animate": a hardware keyboard connecting, or a
        // frame change with nothing to show for it.
        guard duration > 0 else { return .linear(duration: 0) }

        let raw = note.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? Int
        switch raw.flatMap(UIView.AnimationCurve.init(rawValue:)) {
        case .easeIn:  return .easeIn(duration: duration)
        case .easeOut: return .easeOut(duration: duration)
        case .linear:  return .linear(duration: duration)
        default:       return .easeInOut(duration: duration)
        }
    }
}
