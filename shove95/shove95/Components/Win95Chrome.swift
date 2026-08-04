//
//  Win95Chrome.swift
//  shove95
//
//  Window furniture: title bar, status bar, taskbar (design.md §5).
//  The phone is treated as a maximized Win95 window — title bar on top,
//  status bar at the bottom, taskbar below that.
//

import SwiftUI
import Shove95Kit

// MARK: - Title bar

/// 18px navy gradient bar. Title reads `{Tab} - shove.95`; one raised control
/// button at the trailing edge opens Settings. The gear is drawn from scratch —
/// Microsoft's own glyphs are not used (and SF Symbols are prohibited).
struct TitleBar: View {
    @Environment(\.pixel) private var pixel
    // Painted from the scheme rather than the statics: the title bar's own
    // inputs never change when the palette does, so without this dependency
    // SwiftUI has no reason to redraw it (see EnvironmentValues.win95Scheme).
    @Environment(\.win95Scheme) private var scheme
    let title: String
    /// `true` renders a close ✕ instead of the settings gear.
    var isClose: Bool = false
    var onSettings: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Text(title)
                .font(W95Font.standard(pixel))
                .foregroundStyle(Color(hex: scheme.highlight))
                .padding(.leading, Win95.Px.grid * pixel)
                .lineLimit(1)

            Spacer(minLength: 0)

            Button(action: onSettings) {
                Group {
                    if isClose { CloseGlyph().fill(Color(hex: scheme.text)) }
                    else { GearGlyph().fill(Color(hex: scheme.text)) }
                }
                    .frame(width: Win95.Px.titleBarControlW * pixel * 0.6,
                           height: Win95.Px.titleBarControlW * pixel * 0.6)
                    .frame(width: Win95.Px.titleBarControlW * pixel,
                           height: Win95.Px.titleBarControlH * pixel)
                    .background(Color(hex: scheme.surface))
                    .bevelRaised(pixel)
            }
            .buttonStyle(.plain)
            .padding(.trailing, pixel * 2)
            .accessibilityLabel(isClose ? "Close" : "Settings")
        }
        .frame(height: Win95.Px.titleBar * pixel)
        .background(
            LinearGradient(colors: [Color(hex: scheme.titleA), Color(hex: scheme.titleB)],
                           startPoint: .leading, endPoint: .trailing)
        )
    }
}

/// Pixel cog on a 12×12 grid: a hollow two-unit ring, four square teeth and
/// four corner nubs. Solid bodies turn to mush at 24pt — the hole is what makes
/// it read as a gear.
private struct GearGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        let u = rect.width / 12
        func block(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
            CGRect(x: x * u, y: y * u, width: w * u, height: h * u)
        }
        var path = Path()
        // Ring — two units thick, hollow centre at cols/rows 4...7.
        path.addRect(block(2, 2, 8, 2)) // top
        path.addRect(block(2, 8, 8, 2)) // bottom
        path.addRect(block(2, 2, 2, 8)) // left
        path.addRect(block(8, 2, 2, 8)) // right
        // Teeth
        path.addRect(block(5, 0, 2, 2))  // N
        path.addRect(block(5, 10, 2, 2)) // S
        path.addRect(block(0, 5, 2, 2))  // W
        path.addRect(block(10, 5, 2, 2)) // E
        // Corner nubs
        path.addRect(block(1, 1, 1, 1))
        path.addRect(block(10, 1, 1, 1))
        path.addRect(block(1, 10, 1, 1))
        path.addRect(block(10, 10, 1, 1))
        return path
    }
}

/// Pixel ✕ for window close controls.
struct CloseGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        let u = rect.width / 8
        var path = Path()
        for i in 0..<6 {
            path.addRect(CGRect(x: CGFloat(i + 1) * u, y: CGFloat(i + 1) * u, width: u, height: u))
            path.addRect(CGRect(x: CGFloat(6 - i) * u, y: CGFloat(i + 1) * u, width: u, height: u))
        }
        return path
    }
}

// MARK: - Status panel

/// Appears ONLY when there is a last action to report (founder request
/// 2026-08-04 — it used to be permanent window furniture). A light panel that
/// floats above the taskbar rather than sitting inside the grey chrome, with a
/// flat tinted Undo block instead of a raised button.
struct Win95StatusPanel: View {
    @Environment(\.pixel) private var pixel
    let text: String
    var onUndo: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Text(text)
                .font(W95Font.small(pixel))
                .foregroundStyle(Win95.text)
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.horizontal, Win95.Px.grid * 2 * pixel)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("Undo")
                .font(W95Font.small(pixel))
                .foregroundStyle(Win95.text)
                .padding(.horizontal, Win95.Px.grid * 2 * pixel)
                .frame(maxHeight: .infinity)
                .background(Win95.statusAccent) // flat tint, no bevel
                .contentShape(Rectangle())
                .onTapGesture(perform: onUndo)
                .accessibilityLabel("Undo last action")
        }
        .frame(height: Win95.Px.statusBar * pixel + Win95.Px.grid * 2 * pixel)
        .background(Win95.statusBG)
        .bevelRaised(pixel)
        .padding(.horizontal, Win95.Px.grid * pixel)
        .padding(.bottom, Win95.Px.grid * pixel)
    }
}

// MARK: - Taskbar

/// The bottom bar IS the Win95 taskbar (locked Q21). Four text buttons share
/// the full width; the active tab renders pressed. Silver fills into the
/// home-indicator safe area. (The clock well was removed 2026-08-04 at the
/// founder's request — the tabs get the whole bar.)
struct Taskbar: View {
    @Environment(\.pixel) private var pixel
    @Environment(AppSettings.self) private var settings
    @Binding var selected: Bucket

    var body: some View {
        HStack(spacing: pixel) {
            ForEach(Bucket.line, id: \.self) { bucket in
                TaskbarButton(bucket: bucket, isActive: bucket == selected) {
                    // Instant switch — appearance never animates (design.md §8).
                    var t = Transaction()
                    t.disablesAnimations = true
                    withTransaction(t) { selected = bucket }
                }
            }
        }
        // The bar itself still spans edge to edge — it is the taskbar — but the
        // buttons are inset so they don't run into the bezel.
        .padding(.horizontal, Win95.Px.grid * pixel)
        .padding(.vertical, pixel)
        .frame(height: Win95.Px.taskbar * pixel)
        .background(Win95.surface)
        .bevelRaised(pixel)
    }
}

private struct TaskbarButton: View {
    @Environment(\.pixel) private var pixel
    @Environment(AppSettings.self) private var settings
    let bucket: Bucket
    let isActive: Bool
    var action: () -> Void

    /// Labels abbreviate at the largest scale so four buttons still fit (FR-015).
    private var label: String {
        pixel >= 4 ? settings.shortName(for: bucket) : settings.name(for: bucket)
    }

    var body: some View {
        Text(label)
            .font(W95Font.small(pixel))
            .foregroundStyle(Win95.text)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .offset(x: isActive ? pixel : 0, y: isActive ? pixel : 0)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                if isActive {
                    // Pressed taskbar buttons carry Win95's dotted hatch.
                    HatchPattern(pixel: pixel)
                } else {
                    Win95.surface
                }
            }
            .modifier(TaskbarBevel(isActive: isActive, pixel: pixel))
            .contentShape(Rectangle())
            .onTapGesture(perform: action)
            .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
            .accessibilityLabel(settings.name(for: bucket))
    }
}

private struct TaskbarBevel: ViewModifier {
    let isActive: Bool
    let pixel: CGFloat

    func body(content: Content) -> some View {
        if isActive {
            content.bevelSunken(pixel)
        } else {
            content.bevelRaised(pixel)
        }
    }
}

/// The 50% checkerboard Win95 used inside depressed taskbar buttons.
private struct HatchPattern: View {
    let pixel: CGFloat

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Win95.surface))
            var path = Path()
            var y: CGFloat = 0
            var row = 0
            while y < size.height {
                var x: CGFloat = (row % 2 == 0) ? 0 : pixel
                while x < size.width {
                    path.addRect(CGRect(x: x, y: y, width: pixel, height: pixel))
                    x += pixel * 2
                }
                y += pixel
                row += 1
            }
            context.fill(path, with: .color(Win95.highlight))
        }
    }
}
