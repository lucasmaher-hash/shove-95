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
/// one pixel down-right. The flip is INSTANT — appearance never animates
/// (design.md §8).
struct Win95Button<Label: View>: View {
    @Environment(\.pixel) private var pixel
    var action: () -> Void
    @ViewBuilder var label: Label

    @State private var isPressed = false

    var body: some View {
        label
            .padding(.horizontal, Win95.Px.grid * 2 * pixel)
            .frame(minHeight: Win95.Px.buttonMinHeight * pixel)
            .offset(x: isPressed ? pixel : 0, y: isPressed ? pixel : 0)
            .background(Win95.surface)
            .modifier(BevelSwitch(isPressed: isPressed, pixel: pixel))
            .contentShape(Rectangle())
            .onTapGesture { action() }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )
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
                .fill(Win95.highlight)
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
        .onTapGesture(perform: action)
        .accessibilityHidden(true) // the row carries the label + actions
    }
}

/// The checkmark drawn as pixel blocks on a 12×12 grid — no SF Symbols
/// (design.md §9 prohibits them).
private struct CheckmarkGlyph: Shape {
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

/// The white list box the tasks live in (design.md §5).
struct SunkenWell<Content: View>: View {
    @Environment(\.pixel) private var pixel
    @ViewBuilder var content: Content

    var body: some View {
        content
            .background(Win95.highlight)
            .bevelSunken(pixel)
    }
}

// MARK: - Date chip

/// A miniature sunken status-bar panel holding the overdue date (design.md §5).
struct DateChip: View {
    @Environment(\.pixel) private var pixel
    let label: String

    var body: some View {
        Text(label)
            .font(W95Font.small(pixel))
            .foregroundStyle(Win95.shadow)
            .padding(.horizontal, Win95.Px.grid * pixel)
            .padding(.vertical, pixel)
            .background(Win95.surface)
            .bevelSunken(pixel)
    }
}
