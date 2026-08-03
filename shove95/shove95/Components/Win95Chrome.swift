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
    let title: String
    var onSettings: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Text(title)
                .font(W95Font.standard(pixel))
                .foregroundStyle(Win95.highlight)
                .padding(.leading, Win95.Px.grid * pixel)
                .lineLimit(1)

            Spacer(minLength: 0)

            Button(action: onSettings) {
                GearGlyph()
                    .fill(Win95.text)
                    .frame(width: Win95.Px.titleBarControlW * pixel * 0.6,
                           height: Win95.Px.titleBarControlW * pixel * 0.6)
                    .frame(width: Win95.Px.titleBarControlW * pixel,
                           height: Win95.Px.titleBarControlH * pixel)
                    .background(Win95.surface)
                    .bevelRaised(pixel)
            }
            .buttonStyle(.plain)
            .padding(.trailing, pixel * 2)
            .accessibilityLabel("Settings")
        }
        .frame(height: Win95.Px.titleBar * pixel)
        .background(Win95.titleBarGradient)
    }
}

/// Pixel gear: a square body with four nubs and a punched-out centre.
private struct GearGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        let u = rect.width / 8
        var path = Path()
        // Body
        path.addRect(CGRect(x: u * 1, y: u * 1, width: u * 6, height: u * 6))
        // Nubs
        path.addRect(CGRect(x: u * 3, y: 0, width: u * 2, height: u))
        path.addRect(CGRect(x: u * 3, y: u * 7, width: u * 2, height: u))
        path.addRect(CGRect(x: 0, y: u * 3, width: u, height: u * 2))
        path.addRect(CGRect(x: u * 7, y: u * 3, width: u, height: u * 2))
        // Punch the centre out
        path.addRect(CGRect(x: u * 3, y: u * 3, width: u * 2, height: u * 2))
        return path
    }
}

// MARK: - Status bar

/// 12px sunken panel carrying the last action and its Undo (FR-009).
/// Always present — window furniture — and empty when idle.
struct Win95StatusBar: View {
    @Environment(\.pixel) private var pixel
    let text: String
    var onUndo: (() -> Void)?

    var body: some View {
        HStack(spacing: Win95.Px.grid * pixel) {
            Text(text)
                .font(W95Font.small(pixel))
                .foregroundStyle(Win95.text)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Win95.Px.grid * pixel)
                .frame(maxHeight: .infinity)
                .background(Win95.surface)
                .bevelSunken(pixel)

            if let onUndo {
                // Compact button: a standard 23px Win95 button would force the
                // whole bar to double height, and design.md §4 fixes the status
                // bar at 12px. Same bevel, smaller box.
                Text("Undo")
                    .font(W95Font.small(pixel))
                    .foregroundStyle(Win95.text)
                    .padding(.horizontal, Win95.Px.grid * pixel)
                    .frame(maxHeight: .infinity)
                    .background(Win95.surface)
                    .bevelRaised(pixel)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onUndo)
                    .accessibilityLabel("Undo last action")
            }
        }
        .padding(.horizontal, pixel)
        .padding(.vertical, pixel)
        .frame(height: Win95.Px.statusBar * pixel + Win95.Px.grid * pixel)
        .background(Win95.surface)
    }
}

// MARK: - Taskbar

/// The bottom bar IS the Win95 taskbar (locked Q21). Four text buttons share
/// the width; the active tab renders pressed. A sunken clock well sits at the
/// trailing edge. Silver fills into the home-indicator safe area.
struct Taskbar: View {
    @Environment(\.pixel) private var pixel
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

            // At 4× the four buttons need the full width; the clock is the
            // first thing to go (it is decoration, the tabs are not).
            if pixel < 4 {
                ClockWell()
            }
        }
        .padding(.horizontal, pixel)
        .padding(.vertical, pixel)
        .frame(height: Win95.Px.taskbar * pixel)
        .background(Win95.surface)
        .bevelRaised(pixel)
    }
}

private struct TaskbarButton: View {
    @Environment(\.pixel) private var pixel
    @Environment(\.dynamicTypeSize) private var typeSize
    let bucket: Bucket
    let isActive: Bool
    var action: () -> Void

    /// Labels abbreviate at the largest scale so four buttons still fit (FR-015).
    private var label: String {
        pixel >= 4 ? bucket.shortName : bucket.displayName
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
            .accessibilityLabel(bucket.displayName)
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

/// Sunken clock well — date over time, updating every minute.
private struct ClockWell: View {
    @Environment(\.pixel) private var pixel

    var body: some View {
        TimelineView(.everyMinute) { context in
            VStack(spacing: 0) {
                Text(context.date, format: .dateTime.weekday(.abbreviated).day().month(.twoDigits))
                Text(context.date, format: .dateTime.hour().minute())
            }
            .font(W95Font.small(pixel))
            .foregroundStyle(Win95.text)
            .lineLimit(1)
            .padding(.horizontal, Win95.Px.grid * pixel)
            .frame(maxHeight: .infinity)
            .background(Win95.surface)
            .bevelSunken(pixel)
        }
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityHidden(true)
    }
}
