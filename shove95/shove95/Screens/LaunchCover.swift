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
//  The choreography: the word lands first, from slightly left, and the
//  chevron follows it in and grows into place — so the mark assembles rather
//  than fading up whole. The chevron is deliberately last and deliberately
//  late; it is the part of the wordmark that carries the app's name.
//

import SwiftUI

struct LaunchCover: View {
    @Environment(\.pixel) private var pixel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// How long the whole thing takes, and therefore how long the app holds
    /// the cover before it is allowed to leave. The founder asked for about
    /// two seconds; the motion below fills 1.5 of them and the rest is the
    /// mark simply standing there, which is the part that makes it read as a
    /// title card rather than a transition.
    static let duration: TimeInterval = 2.0

    /// The icon's blue, so the cover and the icon are the same object.
    private static let blue = Color(hex: 0x0C2EBE)

    /// False for one frame, then true — the whole choreography hangs off it.
    @State private var arrived = false

    private var travel: CGFloat { Win95.Px.grid * 8 * pixel }

    var body: some View {
        ZStack {
            Self.blue.ignoresSafeArea()

            HStack(spacing: Win95.Px.grid * 3 * pixel) {
                Text("sho")
                    .font(.system(size: Win95.Px.fontStandard * 2.6 * pixel,
                                  weight: .regular, design: .monospaced))
                    .foregroundStyle(.white)
                    // In from the left, which is also where it ends up
                    // relative to the chevron — the word arrives at its own
                    // place rather than sliding through it.
                    .offset(x: arrived || reduceMotion ? 0 : -travel)
                    .opacity(arrived ? 1 : 0)
                    .animation(word, value: arrived)

                ChevronGlyph()
                    .fill(.white)
                    .frame(width: Win95.Px.grid * 6 * pixel,
                           height: Win95.Px.grid * 9 * pixel)
                    // GROWS from its leading edge, so it opens out of the
                    // word rather than swelling around a point of its own.
                    .scaleEffect(arrived || reduceMotion ? 1 : 0.25,
                                 anchor: .leading)
                    .offset(x: arrived || reduceMotion ? 0 : -travel * 0.5)
                    .opacity(arrived ? 1 : 0)
                    .animation(chevron, value: arrived)
            }
        }
        // A frame's delay, because a view that is already in its end state on
        // the first render has nothing to animate from.
        .task {
            try? await Task.sleep(for: .milliseconds(60))
            arrived = true
        }
        .transition(.opacity)
    }

    // §8.5: Reduce Motion drops the TRAVEL and the growth, keeps the fade.
    // The mark still arrives; it just doesn't cross the screen to do it.
    private var word: Animation {
        reduceMotion
            ? .easeOut(duration: 0.35)
            : .spring(response: 0.62, dampingFraction: 0.78)
    }

    private var chevron: Animation {
        reduceMotion
            ? .easeOut(duration: 0.35).delay(0.15)
            : .spring(response: 0.72, dampingFraction: 0.66).delay(0.34)
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
