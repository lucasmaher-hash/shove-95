//
//  LaunchCover.swift
//  shove95
//
//  The wordmark on the app's blue while the store opens.
//
//  It is deliberately LATE, not early: shown only if the first frame hasn't
//  arrived within a beat. A splash that always appears makes a fast launch
//  feel slower, because it puts a screen between the tap and the app that
//  wasn't there before. On a warm launch nobody should ever see this.
//
//  Once shown it stays for a minimum duration — a cover that flickers for
//  80ms reads as a glitch, which is worse than either extreme.
//

import SwiftUI

struct LaunchCover: View {
    @Environment(\.pixel) private var pixel

    /// The icon's blue, so the cover and the icon are the same object.
    private static let blue = Color(hex: 0x0C2EBE)

    var body: some View {
        ZStack {
            Self.blue.ignoresSafeArea()

            HStack(spacing: Win95.Px.grid * 3 * pixel) {
                Text("sho")
                    .font(.system(size: Win95.Px.fontStandard * 2.6 * pixel,
                                  weight: .regular, design: .monospaced))
                    .foregroundStyle(.white)
                ChevronGlyph()
                    .fill(.white)
                    .frame(width: Win95.Px.grid * 6 * pixel,
                           height: Win95.Px.grid * 9 * pixel)
            }
        }
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
