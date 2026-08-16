//
//  SkeuMotion.swift
//  shove95
//
//  Motion physics (§8). Motion communicates MASS: these objects are light but
//  not weightless, so they settle quickly with a small overshoot. Nothing
//  linear, nothing bouncy.
//
//  This is the exact opposite of the Win95 rule, where appearance changes are
//  instant and the press IS the animation. Same app, two physics.
//

import SwiftUI

enum SkeuMotion {
    /// Press / release. The most-used curve in the system.
    static let press = Animation.spring(response: 0.26, dampingFraction: 0.68)
    /// Layout shifts, appearance of inline content.
    static let layout = Animation.spring(response: 0.40, dampingFraction: 0.86)
    /// Sheets and large overlays.
    static let present = Animation.spring(response: 0.52, dampingFraction: 0.84)
    /// State cross-fades where nothing actually moves.
    static let tint = Animation.easeOut(duration: 0.16)
}

// MARK: - Haptics (§8.4)

/// Touch-DOWN rather than release is deliberate: it reinforces that the object
/// physically moved under the finger.
/// The app's haptics — BOTH looks. Named for the skeu kit because that is
/// where it started, but the Win95 rows call it too: a swipe should feel the
/// same whichever costume it is wearing (founder bug report 2026-08-17, that
/// the slide buzzes in skeu and not in Windows).
///
/// The generators are HELD and PREPARED rather than built at the call site.
/// A generator constructed and fired in the same breath frequently drops its
/// first impulse — the engine has not spun up — which is exactly how one look
/// ends up feeling dead while the other, warmed by some earlier tap, does not.
enum SkeuHaptic {
    @MainActor private static let light = UIImpactFeedbackGenerator(style: .light)
    @MainActor private static let rigid = UIImpactFeedbackGenerator(style: .rigid)
    @MainActor private static let soft = UIImpactFeedbackGenerator(style: .soft)
    @MainActor private static let selector = UISelectionFeedbackGenerator()
    @MainActor private static let notifier = UINotificationFeedbackGenerator()

    /// Call before a gesture that will buzz — on touch-down, not on commit.
    @MainActor static func prepare() {
        light.prepare()
        rigid.prepare()
        soft.prepare()
    }

    @MainActor static func press() {
        light.impactOccurred()
    }

    /// The moment a swipe passes the point where letting go would commit.
    /// Softer than the commit itself, so the two read as a pair rather than a
    /// double tap.
    @MainActor static func threshold() {
        soft.impactOccurred(intensity: 0.7)
    }

    @MainActor static func toggle() {
        rigid.impactOccurred()
    }

    @MainActor static func selection() {
        selector.selectionChanged()
    }

    @MainActor static func warning() {
        notifier.notificationOccurred(.warning)
    }

    @MainActor static func success() {
        notifier.notificationOccurred(.success)
    }
}
