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
enum SkeuHaptic {
    @MainActor static func press() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    @MainActor static func toggle() {
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
    }

    @MainActor static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    @MainActor static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    @MainActor static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
