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

/// 18px navy gradient bar. Two forms (founder redesign 2026-08-04):
///   · main screen — `{Workspace} ▼` at the leading edge (tappable, switches
///     workspace), the day name at the trailing edge before the gear
///   · plain windows (Settings) — a single title, close ✕ at the trailing edge
/// The gear/✕/▼ are drawn from scratch — Microsoft's own glyphs are not used
/// (and SF Symbols are prohibited).
struct TitleBar: View {
    @Environment(\.pixel) private var pixel
    // Painted from the scheme rather than the statics: the title bar's own
    // inputs never change when the palette does, so without this dependency
    // SwiftUI has no reason to redraw it (see EnvironmentValues.win95Scheme).
    @Environment(\.win95Scheme) private var scheme
    let title: String
    /// Workspace form: the leading `{workspace} ▼` label and its tap action.
    var workspace: String? = nil
    /// True while the workspace dropdown is open — the label shrinks slightly
    /// for the duration, like a held control (founder direction 2026-08-04).
    var workspaceMenuOpen: Bool = false
    var onWorkspace: (() -> Void)? = nil
    /// `true` renders a close ✕ instead of the settings gear.
    var isClose: Bool = false
    var onSettings: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            if let workspace {
                // The workspace is the window's identity, so it sits where a
                // Win95 title sits; the ▼ marks it as a menu, not a label.
                HStack(spacing: Win95.Px.grid * pixel) {
                    Text(workspace)
                        .font(W95Font.standard(pixel))
                        .foregroundStyle(Color(hex: scheme.selectionText))
                        .lineLimit(1)
                    DownArrowGlyph()
                        .fill(Color(hex: scheme.selectionText))
                        .frame(width: 7 * pixel, height: 4 * pixel)
                }
                .scaleEffect(workspaceMenuOpen ? 0.92 : 1, anchor: .leading)
                .animation(.spring(duration: 0.22), value: workspaceMenuOpen)
                .padding(.leading, Win95.Px.grid * pixel)
                .padding(.trailing, Win95.Px.grid * 2 * pixel)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture { onWorkspace?() }
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel("Workspace: \(workspace)")
                .accessibilityHint("Switches workspace")

                Spacer(minLength: 0)

                Text(title)
                    .font(W95Font.standard(pixel))
                    .foregroundStyle(Color(hex: scheme.selectionText))
                    .lineLimit(1)
                    .padding(.trailing, Win95.Px.grid * 2 * pixel)
            } else {
                Text(title)
                    .font(W95Font.standard(pixel))
                    .foregroundStyle(Color(hex: scheme.selectionText))
                    .padding(.leading, Win95.Px.grid * pixel)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }

            Button(action: onSettings) {
                Group {
                    if isClose { CloseGlyph().fill(Color(hex: scheme.text)) }
                    else { GearGlyph().fill(Color(hex: scheme.text)) }
                }
                    .frame(width: Win95.Px.titleBarControlW * pixel * 0.6,
                           height: Win95.Px.titleBarControlW * pixel * 0.6)
                    .frame(width: Win95.Px.titleBarControlW * pixel,
                           height: Win95.Px.titleBarControlH * pixel)
            }
            .buttonStyle(TitleBarControlStyle(pixel: pixel, surface: Color(hex: scheme.surface)))
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

/// Title-bar control press-in: bevel inverts and the glyph nudges one pixel,
/// exactly like a real Win95 caption button (founder direction 2026-08-04:
/// every control that opens something presses in first).
private struct TitleBarControlStyle: ButtonStyle {
    let pixel: CGFloat
    let surface: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .offset(x: configuration.isPressed ? pixel : 0,
                    y: configuration.isPressed ? pixel : 0)
            .background(surface)
            .modifier(TitleControlBevel(isPressed: configuration.isPressed, pixel: pixel))
    }
}

private struct TitleControlBevel: ViewModifier {
    let isPressed: Bool
    let pixel: CGFloat

    func body(content: Content) -> some View {
        if isPressed { content.bevelSunken(pixel) } else { content.bevelRaised(pixel) }
    }
}

/// Pixel ▼ for the workspace menu: stepped rows on a 7×4 grid.
struct DownArrowGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        let u = rect.width / 7
        var path = Path()
        for row in 0..<4 {
            path.addRect(CGRect(x: CGFloat(row) * u, y: CGFloat(row) * rect.height / 4,
                                width: CGFloat(7 - row * 2) * u, height: rect.height / 4))
        }
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
    // Painted from the scheme rather than the statics, same reasoning as
    // TitleBar: nothing else about this view's inputs changes when the
    // palette does, so without this dependency SwiftUI has no reason to
    // redraw it (see EnvironmentValues.win95Scheme) — it sat one tap stale
    // after every scheme/appearance change (founder bug report 2026-08-14).
    @Environment(\.win95Scheme) private var scheme
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
        // Asymmetric: the extra room goes ABOVE the buttons, so the panel is
        // taller without the buttons changing size.
        .padding(.top, Win95.Px.taskbarTopInset * pixel + pixel)
        .padding(.bottom, pixel)
        .frame(height: (Win95.Px.taskbar + Win95.Px.taskbarTopInset) * pixel)
        // ONE slab, not two: the surface extends through the home-indicator
        // area to the physical bottom, and the bevel is a top edge only — a
        // docked Win95 taskbar has no bottom bevel, and the full raised frame
        // drew a line that read as a second bar (founder bug report
        // 2026-08-04).
        .background(Color(hex: scheme.surface).ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) {
            VStack(spacing: 0) {
                Rectangle().fill(Color(hex: scheme.highlight)).frame(height: pixel)
                Rectangle().fill(Color(hex: scheme.light)).frame(height: pixel)
            }
        }
    }
}

private struct TaskbarButton: View {
    @Environment(\.pixel) private var pixel
    @Environment(AppSettings.self) private var settings
    @Environment(\.win95Scheme) private var scheme
    let bucket: Bucket
    let isActive: Bool
    var action: () -> Void

    /// Labels abbreviate from 3× so four buttons still fit (FR-015). It was
    /// 4× until the stepped-type audit: at 3× "Tomorrow" was clipped at both
    /// ends, and `minimumScaleFactor` can't save a label that long in a
    /// quarter of the bar.
    private var label: String {
        pixel >= 3 ? settings.shortName(for: bucket) : settings.name(for: bucket)
    }

    var body: some View {
        Text(label)
            .font(W95Font.small(pixel))
            .foregroundStyle(Color(hex: scheme.text))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .offset(x: isActive ? pixel : 0, y: isActive ? pixel : 0)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Pressed tab: a lighter grey, flat — the authentic dotted hatch
            // read as noise at phone size (founder restyle 2026-08-04).
            .background(Color(hex: isActive ? scheme.light : scheme.surface))
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
