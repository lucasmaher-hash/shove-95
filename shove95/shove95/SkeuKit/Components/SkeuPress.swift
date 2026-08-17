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
    static let pressGrow: CGFloat = 1.055
    /// Out and back. Short enough to finish before the finger lifts on a
    /// normal tap, so the swell reads as the press itself rather than as an
    /// animation that follows it.
    static let pressSwell = Animation.spring(response: 0.18, dampingFraction: 0.55)
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
            // One frame at full size, then release. Long enough to be seen,
            // short enough that a fast tapper never sees two swells overlap.
            try? await Task.sleep(for: .milliseconds(110))
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
                    try? await Task.sleep(for: .milliseconds(150))
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
