//
//  TypedText.swift
//  shove95
//
//  Text that types itself out when the typeface under it changes.
//
//  Swapping a face is the one setting whose effect is the TEXT ITSELF, and it
//  used to happen between two frames — every label on the screen was suddenly
//  a different shape and nothing said why. Typing it out makes the change the
//  subject rather than a side effect: you see the words being set again in the
//  face you just chose (founder direction 2026-08-16).
//
//  Belongs to BOTH looks. The trigger is passed in rather than read here, so a
//  Win95 label reacts to `AppFace` and a skeu one to the skeu face, and
//  neither has to know about the other's setting.
//
//  Style rides the OUTSIDE: `.font`, `.foregroundStyle`, `.tracking` and the
//  rest are ordinary View modifiers and reach the Text inside, so a call site
//  keeps the styling it already had and only changes what it wraps.
//
//  The first appearance never types. A row scrolling into a lazy list has not
//  changed face; it was simply not on screen yet, and typing it out there
//  would make the list look like it was loading.
//

import SwiftUI

struct TypedText: View {
    let text: String
    /// Anything that changes when the face does. Character count is not
    /// enough — "Today" set in two faces is the same length.
    let trigger: AnyHashable

    /// The whole run, not per character: a long label would otherwise take
    /// noticeably longer than a short one sitting beside it, and the two are
    /// meant to finish together.
    private static let duration: Double = 0.42

    @State private var revealed: Int?
    @State private var seen: AnyHashable?

    var body: some View {
        // nil means "show everything" — the state before any face change and
        // the state after the run finishes.
        Text(revealed.map { String(text.prefix($0)) } ?? text)
            // The caret keeps the line from collapsing while it is short, so
            // neighbours do not shuffle sideways as it grows.
            .fixedSize(horizontal: false, vertical: true)
            .task(id: trigger) {
                guard let previous = seen else {
                    seen = trigger          // first appearance: no animation
                    return
                }
                guard previous != trigger else { return }
                seen = trigger
                await type()
            }
            // A half-typed label must never be what survives. The run is
            // async, so anything that interrupts it — the sheet being
            // dismissed, the view scrolling away, another face change landing
            // mid-run — can strand `revealed` partway, and a heading reading
            // "TYPEF" is worse than one that never animated at all (caught in
            // the simulator 2026-08-16, on the ✕ tap that closed the sheet).
            .onDisappear { revealed = nil }
    }

    private func type() async {
        let count = text.count
        guard count > 0 else { return }
        // Whatever happens below — return, cancellation, the task being torn
        // down — the text ends up whole.
        defer { revealed = nil }
        let step = UInt64(Self.duration / Double(count) * 1_000_000_000)
        revealed = 0
        for n in 1...count {
            try? await Task.sleep(nanoseconds: step)
            if Task.isCancelled { return }
            revealed = n
        }
    }
}
