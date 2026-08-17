//
//  Win95Controls.swift
//  shove95
//
//  Primitive controls (design.md §4–5). Every dimension is a multiple of the
//  `pixel` environment unit — no hard-coded point values.
//

import SwiftUI

// MARK: - Button

/// Surface fill + raised bevel. Pressed = sunken bevel with the label offset
/// one pixel down-right — every control that opens or does something presses
/// in first (founder direction 2026-08-04). Built on Button so the press state
/// rides UIKit's touch pipeline: the old zero-distance DragGesture version
/// violated design.md §13 and froze any ScrollView it sat in.
struct Win95Button<Label: View>: View {
    @Environment(\.pixel) private var pixel
    var action: () -> Void
    /// Vertically slimmer variant for dense settings rows.
    var compact: Bool = false
    /// Fixed width, so a column of buttons with different labels lines up.
    /// Applied INSIDE the button: the bevel and fill have to grow with it,
    /// and a `.frame` on the outside would leave them at the label's size.
    var width: CGFloat? = nil
    @ViewBuilder var label: Label

    var body: some View {
        // The haptic lives HERE, not at every call site — this is what
        // `.skeuPress` does for the other look, and copying the behaviour
        // means copying where it lives (founder direction 2026-08-17).
        Button(action: { SkeuHaptic.press(); action() }) {
            label
                .padding(.horizontal, Win95.Px.grid * 2 * pixel)
                .frame(width: width)
                .frame(minHeight: (compact ? Win95.Px.buttonCompact
                                           : Win95.Px.buttonMinHeight) * pixel)
        }
        .buttonStyle(Win95ButtonStyle(pixel: pixel))
    }
}

/// The press-in: bevel inverts and the label nudges one pixel down-right.
/// The flip itself is instant (design.md §8) — the press IS the animation.
struct Win95ButtonStyle: ButtonStyle {
    let pixel: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .offset(x: configuration.isPressed ? pixel : 0,
                    y: configuration.isPressed ? pixel : 0)
            .background(Win95.surface)
            .modifier(BevelSwitch(isPressed: configuration.isPressed, pixel: pixel))
            .contentShape(Rectangle())
    }
}

/// Swaps bevel direction with no implicit animation.
private struct BevelSwitch: ViewModifier {
    let isPressed: Bool
    let pixel: CGFloat

    func body(content: Content) -> some View {
        if isPressed {
            content.bevelSunken(pixel)
        } else {
            content.bevelRaised(pixel)
        }
    }
}

// MARK: - Checkbox

/// The real Win95 control: a 12px sunken white box with a black pixel
/// checkmark. Visual size stays authentic; the tap target is expanded to 44pt
/// (design.md §4 — the one deliberate deviation).
struct Win95Checkbox: View {
    @Environment(\.pixel) private var pixel
    let isChecked: Bool
    var action: () -> Void

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Win95.well)
                .frame(width: Win95.Px.checkbox * pixel, height: Win95.Px.checkbox * pixel)
                .bevelSunken(pixel)

            if isChecked {
                CheckmarkGlyph()
                    .fill(Win95.text)
                    .frame(width: Win95.Px.checkbox * pixel, height: Win95.Px.checkbox * pixel)
            }
        }
        .frame(width: Win95.rowHeight(pixel), height: Win95.rowHeight(pixel)) // ≥44pt tap target
        .contentShape(Rectangle())
        // `toggle`, matching the skeu tick — a box that fills is a different
        // event from a button that is pressed.
        .onTapGesture { SkeuHaptic.toggle(); action() }
        .accessibilityHidden(true) // the row carries the label + actions
    }
}

/// The checkmark drawn as pixel blocks on a 12×12 grid — no SF Symbols
/// (design.md §9 prohibits them).
///
/// Shared with the skeu look: under Retro or Blend its tick takes this shape
/// instead of the system symbol, so a ticked task matches the type beside it.
struct CheckmarkGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        let u = rect.width / 12 // one 1995 pixel
        // (column, row) blocks, each 1×2 pixels, forming the classic tick.
        let blocks: [(CGFloat, CGFloat)] = [
            (2, 5), (2, 6),
            (3, 6), (3, 7),
            (4, 7), (4, 8),
            (5, 6), (5, 7),
            (6, 5), (6, 6),
            (7, 4), (7, 5),
            (8, 3), (8, 4),
        ]
        var path = Path()
        for (col, row) in blocks {
            path.addRect(CGRect(x: col * u, y: row * u, width: u, height: u))
        }
        return path
    }
}

// MARK: - Sunken well

/// The white list box the tasks live in (design.md §5). Its border is EVEN,
/// not bevelled: at this size the lit bottom-right of a true bevel stopped
/// reading as depth and just looked like an uneven frame (founder request
/// 2026-08-04). Small controls keep the real bevel.
struct SunkenWell<Content: View>: View {
    @Environment(\.pixel) private var pixel
    @ViewBuilder var content: Content

    var body: some View {
        content
            .background(Win95.well)
            .bevelEven(pixel)
    }
}

// MARK: - Date chip

/// A miniature sunken status-bar panel holding the overdue date (design.md §5).
/// Overdue chip: a solid rectangle in the theme's status tint with the date in
/// black — no bevel, no outline (founder restyle 2026-08-04, filled rather than
/// framed; the sunken mini-well and then the outline both read as clutter).
struct DateChip: View {
    @Environment(\.pixel) private var pixel
    let label: String

    var body: some View {
        Text(label)
            .font(W95Font.small(pixel))
            .foregroundStyle(Win95.text)
            .padding(.horizontal, Win95.Px.grid * pixel)
            .padding(.vertical, pixel)
            .background(Win95.statusAccent)
    }
}

// MARK: - Plus glyph

/// Bare pixel plus on a 12×12 grid — an affordance, not a button (no bevel).
struct PlusGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        let u = rect.width / 12
        var path = Path()
        path.addRect(CGRect(x: 5 * u, y: 1 * u, width: 2 * u, height: 10 * u))
        path.addRect(CGRect(x: 1 * u, y: 5 * u, width: 10 * u, height: 2 * u))
        return path
    }
}

// MARK: - Camera glyph

/// The photo control's mark: the founder's camera, transcribed.
///
/// From `pixel-camera-icon-6766180-512.png` (2026-08-17), read off the file
/// rather than eyeballed — the drawing sits on a 12×10 grid of 32.8px cells,
/// and this is that grid cell for cell.
///
/// TRANSCRIBED, not embedded. A PNG would not take the scheme's colour, and
/// it would resample at every Dynamic Type step onto fractional pixels; as
/// cells it stays crisp at 2×, 3× and 4× and re-tints with everything else.
struct CameraGlyph: Shape {
    /// `#` is ink. Ten rows of twelve, exactly as the file draws them.
    private static let rows = [
        "....####....",
        ".###....###.",
        "#.#........#",
        "#....##....#",
        "#...#..#...#",
        "#...#..#...#",
        "#...#..#...#",
        "#....##....#",
        "#..........#",
        ".##########.",
    ]

    func path(in rect: CGRect) -> Path {
        let u = rect.width / CGFloat(Self.rows[0].count)
        var path = Path()
        for (r, row) in Self.rows.enumerated() {
            for (c, mark) in row.enumerated() where mark == "#" {
                path.addRect(CGRect(x: CGFloat(c) * u, y: CGFloat(r) * u,
                                    width: u, height: u))
            }
        }
        return path
    }
}

// MARK: - Pin glyph

/// The pin control's mark: a ring, holding a solid core when the task is
/// pinned and struck through when it is not.
///
/// The skeu look draws this with two SF Symbols (`record.circle.fill` and
/// `circle.slash`), which is exactly the founder's reference art. A hairline
/// vector circle is an anti-pattern here though — nothing in 1995 had one —
/// so this is the same mark rasterised onto the pixel grid, the way the
/// checkbox and the plus already are.
///
/// The cells are computed rather than hand-listed: a 13-unit grid is too
/// large to transcribe by hand without an error, and the radii are the real
/// design decision. Odd grid so the circle has a true centre cell.
struct PinGlyph: Shape {
    var isPinned: Bool

    /// Grid units from centre. The ring is ~1.5 cells thick, which is the
    /// thinnest that still reads as a ring rather than a dotted outline once
    /// quantised.
    private static let outer: CGFloat = 6.1
    private static let inner: CGFloat = 4.5
    /// The core leaves a clear gap inside the ring — touching, it would read
    /// as one fat blob at small pixel scales.
    private static let core: CGFloat = 3.0

    func path(in rect: CGRect) -> Path {
        let n = 13
        let u = rect.width / CGFloat(n)
        let centre = CGFloat(n) / 2
        var path = Path()

        for row in 0..<n {
            for column in 0..<n {
                let dx = CGFloat(column) + 0.5 - centre
                let dy = CGFloat(row) + 0.5 - centre
                let distance = (dx * dx + dy * dy).squareRoot()

                let onRing = distance <= Self.outer && distance >= Self.inner
                let inCore = isPinned && distance <= Self.core
                // The strike runs corner to corner and overshoots the ring on
                // both ends, as in the reference. Top-left to bottom-right,
                // so it never reads as a checkmark.
                let onStrike = !isPinned && abs(dx - dy) < 0.95

                guard onRing || inCore || onStrike else { continue }
                path.addRect(CGRect(x: CGFloat(column) * u, y: CGFloat(row) * u,
                                    width: u, height: u))
            }
        }
        return path
    }
}

