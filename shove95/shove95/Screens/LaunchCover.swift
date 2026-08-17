//
//  LaunchCover.swift
//  shove95
//
//  The wordmark assembling itself on the app's blue, while the store opens.
//
//  It used to be deliberately LATE — shown only if the first frame hadn't
//  arrived within 220ms, so that on a warm launch nobody ever saw it. That
//  reticence and a two-second animation cannot both be true, and the founder
//  chose the animation: it now plays on every COLD launch (2026-08-17).
//  Returning from the background does not re-run the process, so a warm
//  return still goes straight to the list.
//
//  ONE design, not two. Everything else in this app exists twice, but this is
//  the icon, and the icon has one drawing. There is no Win95 variant missing
//  here.
//
//  The choreography (founder direction 2026-08-17, second pass): BOTH parts
//  are there from the first frame, sitting left of centre. Nothing fades in.
//  Then the chevron alone leaves — travelling right and growing hard as it
//  goes, out of a mark the size of a letter into the size of the screen.
//
//  The word does not move. It is the fixed point the chevron departs from,
//  and that is what makes the growth read as distance rather than as a zoom.
//
//  The chevron does not STOP (founder direction 2026-08-17, third pass). It
//  keeps going past the edge, and the blue thins out around it while it is
//  still travelling, so the list is already there by the time the mark has
//  gone. Nothing waits for anything: the cover doesn't finish and then leave,
//  it leaves as part of finishing.
//

import SwiftUI

struct LaunchCover: View {
    @Environment(\.pixel) private var pixel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// How long the app holds the cover.
    ///
    /// It WAS 3.0, and speeding the flight up by 30% and the fade by 40%
    /// cannot leave it there: everything visible is over at 1.8s, and the
    /// remaining 1.2 would be a fully transparent cover sitting on a live app
    /// that cannot be touched yet. Trimmed to just past the fade — the three
    /// seconds were the budget for the motion, and the motion is now quicker
    /// than the budget.
    static let duration: TimeInterval = 2.0

    /// The icon's blue, so the cover and the icon are the same object.
    private static let blue = Color(hex: 0x0C2EBE)

    /// False for one frame, then true — the whole choreography hangs off it.
    @State private var arrived = false

    /// How far right the chevron goes — off the edge, not up to it.
    private var travel: CGFloat { Win95.Px.grid * 58 * pixel }
    /// How far left the whole mark starts, so the chevron has room to run.
    private var lead: CGFloat { Win95.Px.grid * 11 * pixel }
    /// At rest the chevron IS the icon — the frame above now carries the
    /// icon's proportions, so there is nothing left to scale away.
    private var startScale: CGFloat { 1.0 }
    /// 6, not 8: the frame it multiplies grew by a third when it took the
    /// icon's size, so this drops by the same third and the chevron reaches
    /// the edge at the width it already had.
    private var endScale: CGFloat { 6.0 }

    var body: some View {
        ZStack {
            Self.blue.ignoresSafeArea()

            HStack(spacing: 5 * pixel) {
                Text("sho")
                    .font(.system(size: Win95.Px.fontStandard * 2.6 * pixel,
                                  weight: .regular, design: .monospaced))
                    .foregroundStyle(.white)
                    // FIXED. The word is the point the chevron leaves from,
                    // and a departure needs something to be measured against.

                ChevronGlyph()
                    .fill(.white)
                    // MEASURED off icon-1024 (founder direction 2026-08-17):
                    // there the chevron is 0.62 of the word's width and the
                    // gap between them 0.10 of it. The cover had 0.47 and
                    // 0.23 — a chevron too small beside a word held too far
                    // away, which is why the two did not read as one mark.
                    // 8 and 12 grid units give the 6:9 drawing its icon size;
                    // the spacing above is the icon's gap.
                    .frame(width: Win95.Px.grid * 8 * pixel,
                           height: Win95.Px.grid * 12 * pixel)
                    // Grows from its LEADING edge while travelling right, so
                    // the near side stays with the word and the far side runs
                    // away from it.
                    .scaleEffect(arrived && !reduceMotion ? endScale : startScale,
                                 anchor: .leading)
                    .offset(x: arrived && !reduceMotion ? travel : 0)
                    .animation(chevron, value: arrived)
            }
            // Both parts start left of centre — the chevron needs somewhere
            // to run to, and a mark that begins centred would end off-screen.
            .offset(x: -lead)
        }
        // The blue thins WHILE the chevron is still running, not after it has
        // landed. A cover that completes its animation and only then fades is
        // two events; this is one.
        .opacity(arrived || reduceMotion ? 0 : 1)
        .animation(veil, value: arrived)
        // Once it is on its way out it stops taking touches. The app removes
        // it a moment later, and a transparent sheet swallowing taps in
        // between would read as the app being frozen.
        .allowsHitTesting(!arrived)
        // A beat before it moves, so the mark is READ standing still first.
        // Straight into the travel and there is nothing to have departed
        // from. See `chevron` for how this 0.3 fits the three-second budget.
        .task {
            try? await Task.sleep(for: .milliseconds(300))
            arrived = true
        }
        .transition(.opacity)
    }

    /// §8.5: Reduce Motion holds the mark still. There is nothing to fade
    /// here — both parts are on screen from the first frame either way, so
    /// the accessible version is simply the title card without the journey.
    /// SLOW, and easing IN rather than out — a spring arrives, and this one
    /// is not arriving anywhere. It leans into the journey instead, so the
    /// chevron is still gathering speed at the point it leaves the screen
    /// (founder direction 2026-08-17, fourth pass).
    ///
    /// The numbers are a budget, not taste. `arrived` fires at 0.3s and the
    /// app lifts the cover at `duration` (3.0s); everything below has to fit
    /// between those two, which is why they are stated together.
    private var chevron: Animation {
        reduceMotion
            ? .easeOut(duration: 0.01)
            : .easeIn(duration: 1.77)   // 2.3 ÷ 1.3 — 30% quicker
    }

    /// Finishes as the chevron reaches the right edge, which is where the
    /// founder asked the two to meet. The delay is what holds that meeting:
    /// 0.3 still + 0.43 + 1.07 = 1.8s, the same fraction of the flight it
    /// was before both were sped up.
    private var veil: Animation {
        reduceMotion
            ? .easeOut(duration: 0.5).delay(0.6)
            : .easeIn(duration: 1.07).delay(0.43)   // 1.5 ÷ 1.4 — 40% quicker
    }
}

/// The icon's chevron, drawn from the same grid so the cover and the home
/// screen show one mark rather than two similar ones.
private struct ChevronGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        let u = rect.width / 6
        let v = rect.height / 9
        // (first column, last column) per row — two blocks thick, one step
        // per row, tip at the middle.
        let rows = [(0, 1), (1, 2), (2, 3), (3, 4), (4, 5), (3, 4), (2, 3), (1, 2), (0, 1)]
        var path = Path()
        for (row, span) in rows.enumerated() {
            for column in span.0...span.1 {
                path.addRect(CGRect(x: CGFloat(column) * u, y: CGFloat(row) * v,
                                    width: u, height: v))
            }
        }
        return path
    }
}
