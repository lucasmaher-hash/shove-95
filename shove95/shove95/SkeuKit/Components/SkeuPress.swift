//
//  SkeuPress.swift
//  shove95
//
//  The app's press: a control swells briefly when it is pressed, then settles.
//
//  THE standard from here on (founder direction 2026-08-17). Every control in
//  the skeu look wears it — pills, row buttons, the workspace name, the
//  circular chrome, the dialog buttons — and anything added later should reach
//  for `.skeuPress` rather than inventing its own reaction. That is the whole
//  point of it living in one file.
//
//  A SWELL, not a shrink. The design system's `SkeuPressStyle` presses objects
//  INTO the page, which suits a button you hold; this is for a tap, where the
//  object is answering rather than being held down. The two coexist: press
//  style for anything with a hold state, this for everything else.
//
//  It also fires where nothing changes. Pressing the toggle option that is
//  already chosen swells it and does nothing else — the control acknowledges
//  the touch instead of ignoring it, which is the difference between "that did
//  nothing" and "that is already the answer".
//

import SwiftUI

extension SkeuMotion {
    /// How far a pressed control swells. Small on purpose: it has to read at a
    /// glance without moving neighbours or looking like a bounce.
    static let pressGrow: CGFloat = 1.115
    /// Out and back. Short enough to finish before the finger lifts on a
    /// normal tap, so the swell reads as the press itself rather than as an
    /// animation that follows it.
    static let pressSwell = Animation.spring(response: 0.36, dampingFraction: 0.60)
}

private struct SkeuPress: ViewModifier {
    /// Nil leaves the tap to whatever the caller already wired — used where a
    /// Button or an existing gesture owns the action and this only supplies
    /// the swell.
    let action: (() -> Void)?
    let haptic: Bool

    @State private var swollen = false

    func body(content: Content) -> some View {
        let shape = content
            .scaleEffect(swollen ? SkeuMotion.pressGrow : 1)
            .animation(SkeuMotion.pressSwell, value: swollen)

        if let action {
            shape
                .contentShape(Rectangle())
                .onTapGesture {
                    swell()
                    if haptic { SkeuHaptic.press() }
                    action()
                }
        } else {
            shape
                .onTapGesture { swell() }   // decoration only
        }
    }

    private func swell() {
        swollen = true
        Task { @MainActor in
            // Held at full size, then released. Lengthened on founder
            // direction (2026-08-17) — at 110ms the swell was over before the
            // eye had finished arriving at it.
            try? await Task.sleep(for: .milliseconds(260))
            swollen = false
        }
    }
}

extension View {
    /// The app's press. See `SkeuPress` — this is the standard reaction for
    /// every tappable in the skeu look.
    func skeuPress(haptic: Bool = true, _ action: @escaping () -> Void) -> some View {
        modifier(SkeuPress(action: action, haptic: haptic))
    }
}

// MARK: - Landing

/// The swell a toggle's glass makes when it ARRIVES.
///
/// The pill already glides to the chosen option; without this it simply stops,
/// and the gliding read as the whole event. Swelling on arrival gives the
/// journey an end, and matches what every other control in the app does when
/// it is pressed (founder direction 2026-08-17).
struct SkeuLanding: ViewModifier {
    /// Anything that changes when the selection moves — the selected option's
    /// own identity is enough.
    let token: AnyHashable
    /// False on the row that is merely losing the selection: only the arriving
    /// one should swell.
    let active: Bool

    @State private var swollen = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(swollen ? SkeuMotion.pressGrow : 1)
            .animation(SkeuMotion.pressSwell, value: swollen)
            .onChange(of: token) {
                guard active else { return }
                swollen = true
                Task { @MainActor in
                    // Held until the glide is most of the way there, so the
                    // swell lands with the pill rather than ahead of it.
                    try? await Task.sleep(for: .milliseconds(300))
                    swollen = false
                }
            }
    }
}

extension View {
    func skeuLanding(_ token: AnyHashable, active: Bool) -> some View {
        modifier(SkeuLanding(token: token, active: active))
    }
}

// MARK: - Pulse

/// A slow, shallow breath. Used by the one pinned task, in both looks.
///
/// The pin is the app's only piece of state that lives OUTSIDE the app — on
/// the Lock Screen, in the Dynamic Island. A static dot says "this is marked";
/// a breathing one says "this is live somewhere else", which is what it
/// actually means (founder direction 2026-08-17).
///
/// Deliberately slow and shallow. A list is somewhere people read, and a fast
/// or wide pulse in the corner of the eye is the kind of motion you end up
/// covering with a thumb.
struct SkeuPulse: ViewModifier {
    let active: Bool
    /// Whether the page behind this mark is dark, when the system's answer is
    /// the wrong one to ask.
    ///
    /// The skeu look and `\.colorScheme` always agree. Win95 does NOT: its
    /// palette is chosen separately, so a dark scheme can sit under a light
    /// appearance and the pulse would then swing the wrong way — which is why
    /// this look kept coming back wrong after the direction had been fixed
    /// (founder bug report 2026-08-17, third pass). Win95 states its own
    /// scheme's darkness; everything else leaves this nil.
    var darkOverride: Bool? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Read rather than passed: the pulse is used by both looks, and this is
    /// the one signal both of them already carry.
    @Environment(\.colorScheme) private var colorScheme
    @State private var up = false

    private var dimmed: Bool { active && up && !reduceMotion }

    /// Which way "more visible" points.
    ///
    /// On a dark page the mark stands out by getting BRIGHTER; on a light one
    /// the same move washes it into the paper, and it has to get DARKER
    /// instead (founder direction 2026-08-17). Contrast is the goal, and
    /// contrast has no fixed direction — only a fixed distance from whatever
    /// is behind it.
    private var isDark: Bool { darkOverride ?? (colorScheme == .dark) }

    /// On a DARK page the mark stands out by getting brighter, and fading it
    /// back is the low half of the breath. On a LIGHT one both of those read
    /// the same way — washing out against paper IS brightening, which is why
    /// the light mode still looked wrong after the direction of `brightness`
    /// had already been flipped (founder bug report 2026-08-17, second pass).
    ///
    /// So light mode does not fade at all. It keeps the mark solid and swings
    /// it through brightness alone: up toward the paper at the quiet end of
    /// the breath, down away from it at the loud end. Contrast is the signal
    /// in both schemes; only on a dark page can opacity help carry it.
    /// ONE set of numbers for both looks (founder direction 2026-08-17).
    /// The skeu behaviour was the one that read correctly, so Win95 takes it
    /// verbatim rather than keeping a variant of its own.
    private var lowOpacity: Double { isDark ? 0.28 : 1 }
    private var lowBrightness: Double { isDark ? 0 : 0.16 }
    private var highBrightness: Double { isDark ? 0.32 : -0.34 }

    func body(content: Content) -> some View {
        content
            // Swings BOTH ways from rest: further from the page at the top of
            // the breath than the mark ever normally is, and clearly closer
            // to it at the bottom (founder direction 2026-08-17 — the first
            // pass only dimmed, which reads as a fault rather than a signal).
            .opacity(dimmed ? lowOpacity : 1)
            .brightness(dimmed ? lowBrightness : highBrightness)
            .scaleEffect(dimmed ? 0.88 : 1.08)
            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                       value: up)
            .onChange(of: active, initial: true) { up = active }
    }
}

extension View {
    func skeuPulse(_ active: Bool, dark: Bool? = nil) -> some View {
        modifier(SkeuPulse(active: active, darkOverride: dark))
    }
}
