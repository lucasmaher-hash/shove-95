//
//  LaunchCover.swift
//  shove95
//
//  The wordmark, held still, while the store opens.
//
//  A STILL CARD, not a journey (founder direction 2026-08-17, fifth pass).
//  The chevron used to fly off the right edge, growing as it went, with the
//  ground thinning around it — four passes of choreography, all of it now
//  gone. What is left is exactly the frame that animation began on: both
//  parts, at rest, left of centre. Held for `duration`, then lifted.
//
//  It plays on every COLD launch. Returning from the background does not
//  re-run the process, so a warm return still goes straight to the list.
//
//  ONE drawing, two grounds. The mark is the icon and the icon has a single
//  drawing, so there is no Win95 variant of it missing here — but the ground
//  it sits on now follows the app's theme rather than the icon's fixed blue
//  (founder direction, same pass). Win95 takes its title-bar colour, skeu its
//  accent: in both looks those are the tone that look already carries white
//  lettering on, so the wordmark stays legible in every palette.
//

import SwiftUI

struct LaunchCover: View {
    @Environment(\.pixel) private var pixel
    @Environment(AppSettings.self) private var settings
    @Environment(\.colorScheme) private var systemScheme

    /// How long the card is held. It was the budget for a two-second
    /// animation; with the animation gone it is simply the hold.
    static let duration: TimeInterval = 2.0

    /// The ground: this look's own strong tone, resolved for light or dark.
    ///
    /// Win95 takes the title bar's colour and skeu the accent, because those
    /// are the two the looks already set white lettering on — the wordmark is
    /// white in both, so the ground has to be a tone that carries it. It was
    /// the icon's fixed blue, which sat outside every palette the app can be
    /// wearing (founder direction 2026-08-17).
    private var ground: Color {
        let dark = settings.appearance.isDark(system: systemScheme)
        switch settings.design {
        case .win95:
            return Color(hex: settings.scheme.resolved(dark: dark).titleA)
        case .skeu:
            return settings.skeuTheme.palette(dark: dark).accent
        }
    }

    /// How far left the mark sits. Kept from the animated version: this is
    /// the frame that one began on, and the founder asked for that frame.
    private var lead: CGFloat { Win95.Px.grid * 11 * pixel }

    var body: some View {
        ZStack {
            ground.ignoresSafeArea()

            HStack(spacing: 5 * pixel) {
                Text("sho")
                    .font(.system(size: Win95.Px.fontStandard * 2.6 * pixel,
                                  weight: .regular, design: .monospaced))
                    .foregroundStyle(.white)

                ChevronGlyph()
                    .fill(.white)
                    // MEASURED off icon-1024 (founder direction 2026-08-17):
                    // there the chevron is 0.62 of the word's width and the
                    // gap between them 0.10 of it. 8 and 12 grid units give
                    // the 6:9 drawing its icon size; the spacing above is the
                    // icon's gap.
                    .frame(width: Win95.Px.grid * 8 * pixel,
                           height: Win95.Px.grid * 12 * pixel)
            }
            .offset(x: -lead)
        }
        // The app lifts it after `duration` with its own fade — there is
        // nothing here that has to finish first any more.
        .transition(.opacity)
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
