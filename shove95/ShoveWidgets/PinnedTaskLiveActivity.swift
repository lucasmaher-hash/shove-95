//
//  PinnedTaskLiveActivity.swift
//  ShoveWidgets
//
//  The pinned task, on the Lock Screen and in the Dynamic Island.
//
//  This file knows NOTHING about themes. Every colour arrives resolved in the
//  content state, because the app is the only place allowed to know colours
//  (CLAUDE.md rule 2) and duplicating the palettes here would have meant two
//  places to change when a theme changes. What lives here is GEOMETRY, which
//  the app cannot send: a 2px Win95 bevel and a soft skeu slab are drawings,
//  not values.
//
//  The two looks share no layout on purpose. A Windows 95 dialog and a
//  skeuomorphic slab are different objects that happen to carry the same
//  sentence; expressing them as one view with a style flag would have forced
//  a compromise geometry that is neither.
//

import SwiftUI
import WidgetKit
import ActivityKit
import Shove95Kit

// MARK: - Colour bridging

private extension Color {
    init(_ c: ActivityColor) {
        self.init(.sRGB, red: c.red, green: c.green, blue: c.blue, opacity: c.alpha)
    }
}

private extension PinnedTaskAttributes.ContentState {
    /// The typeface setting, honoured on the Lock Screen too. W95FA is set
    /// 1.22× the system size — the inverse of the 0.82 factor the app uses to
    /// keep the two faces optically level.
    func font(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        if let name = fontName {
            return .custom(name, fixedSize: size * 1.22)
        }
        return .system(size: size, weight: weight)
    }
}

// MARK: - The configuration

struct PinnedTaskLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PinnedTaskAttributes.self) { context in
            LockScreenCard(state: context.state, taskID: context.attributes.taskID)
                // The card paints its own surface edge to edge; without this
                // iOS puts its default material behind it and the Win95 grey
                // floats on a translucent slab.
                .activityBackgroundTint(Color(context.state.palette.surface))
                .activitySystemActionForegroundColor(Color(context.state.palette.ink))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    ExpandedIsland(state: context.state, taskID: context.attributes.taskID)
                }
            } compactLeading: {
                Image(systemName: "record.circle.fill")
                    .foregroundStyle(Color(context.state.palette.accent))
            } compactTrailing: {
                // Truncated hard: the compact slot is a few characters wide,
                // and a title that elides to "sort out th…" is still a better
                // reminder than an icon alone.
                Text(context.state.title)
                    .font(context.state.font(13))
                    .foregroundStyle(Color(context.state.palette.ink))
                    .lineLimit(1)
                    .frame(maxWidth: 90, alignment: .leading)
            } minimal: {
                Image(systemName: "record.circle.fill")
                    .foregroundStyle(Color(context.state.palette.accent))
            }
            // Tapping anywhere that is not the button opens the app.
            .widgetURL(URL(string: "shove95://task/\(context.attributes.taskID.uuidString)"))
        }
    }
}

// MARK: - Lock Screen

private struct LockScreenCard: View {
    let state: PinnedTaskAttributes.ContentState
    let taskID: UUID

    var body: some View {
        switch state.look {
        case .win95: Win95Card(state: state, taskID: taskID)
        case .skeu:  SkeuCardView(state: state, taskID: taskID)
        }
    }
}

// MARK: Windows 95

/// A dialog box, because that is what 1995 put on screen when it had one
/// thing to tell you. Title bar, message, one button.
private struct Win95Card: View {
    let state: PinnedTaskAttributes.ContentState
    let taskID: UUID

    /// The Lock Screen is not the app, so there is no `\.pixel` environment
    /// here. Two is the app's default scale and the one the bevel geometry
    /// was drawn for.
    private let pixel: CGFloat = 2

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // `light` is the bevel highlight, which in every Win95 scheme
                // is white — the same colour the title bar has always used for
                // its text. `surface` was the grey of the dialog face and
                // vanished against the blue.
                Text("shove.95")
                    .font(state.font(11))
                    .foregroundStyle(Color(state.palette.light))
                Spacer(minLength: 0)
                if let chip = state.chip {
                    Text(chip)
                        .font(state.font(11))
                        .foregroundStyle(Color(state.palette.light))
                }
            }
            .padding(.horizontal, 4 * pixel)
            .frame(height: 18 * pixel)
            .background(Color(state.palette.accent))

            HStack(alignment: .top, spacing: 4 * pixel) {
                Text(state.title)
                    .font(state.font(11))
                    .foregroundStyle(Color(state.palette.ink))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button(intent: CompletePinnedTaskIntent(taskID: taskID)) {
                    Text("Done")
                        .font(state.font(11))
                        .foregroundStyle(Color(state.palette.ink))
                        .padding(.horizontal, 4 * pixel)
                        .frame(minHeight: 16 * pixel)
                        .background(Color(state.palette.surface))
                        .bevel(raised: true, pixel: pixel, state: state)
                }
                .buttonStyle(.plain)
            }
            .padding(4 * pixel)
        }
        .background(Color(state.palette.surface))
        .bevel(raised: true, pixel: pixel, state: state)
        .padding(8)
    }
}

private extension View {
    /// The 2px Win95 bevel — two nested 1px frames, light above and left,
    /// dark below and right. Reimplemented rather than shared: the app's
    /// modifier reads `Win95.*` statics that do not exist in this process.
    func bevel(raised: Bool, pixel: CGFloat,
               state: PinnedTaskAttributes.ContentState) -> some View {
        let light = Color(raised ? state.palette.light : state.palette.dark)
        let dark = Color(raised ? state.palette.dark : state.palette.light)
        return overlay {
            ZStack {
                Path { p in p.addRect(.infinite) }
                    .stroke(lineWidth: 0) // keeps the ZStack laid out
                GeometryReader { proxy in
                    let w = proxy.size.width, h = proxy.size.height
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: h))
                        p.addLine(to: CGPoint(x: 0, y: 0))
                        p.addLine(to: CGPoint(x: w, y: 0))
                    }
                    .stroke(light, lineWidth: pixel)
                    Path { p in
                        p.move(to: CGPoint(x: w, y: 0))
                        p.addLine(to: CGPoint(x: w, y: h))
                        p.addLine(to: CGPoint(x: 0, y: h))
                    }
                    .stroke(dark, lineWidth: pixel)
                }
            }
        }
    }
}

// MARK: Skeu

/// A slab lying on the Lock Screen: soft material, a rim light along the top
/// edge, one light source from above — the same physics contract the app's
/// surfaces follow, drawn with what arrives in the state.
private struct SkeuCardView: View {
    let state: PinnedTaskAttributes.ContentState
    let taskID: UUID

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(state.title)
                    .font(state.font(16, weight: .medium))
                    .foregroundStyle(Color(state.palette.ink))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                if let chip = state.chip {
                    Text(chip)
                        .font(state.font(13))
                        .foregroundStyle(Color(state.palette.inkMuted))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(intent: CompletePinnedTaskIntent(taskID: taskID)) {
                Image(systemName: "checkmark")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Color(state.palette.ink))
                    .frame(width: 44, height: 44)
                    .background {
                        Circle()
                            .fill(Color(state.palette.surface))
                            .overlay {
                                // Rim light on the TOP edge only — one light
                                // source, from above and slightly left.
                                Circle().strokeBorder(
                                    LinearGradient(
                                        colors: [Color(state.palette.light).opacity(0.9),
                                                 Color(state.palette.light).opacity(0.05)],
                                        startPoint: .top, endPoint: .bottom),
                                    lineWidth: 1)
                            }
                            .shadow(color: Color(state.palette.dark).opacity(0.35),
                                    radius: 5, x: 0, y: 3)
                    }
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(state.palette.surface))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color(state.palette.light).opacity(0.85),
                                         Color(state.palette.light).opacity(0.04)],
                                startPoint: .top, endPoint: .bottom),
                            lineWidth: 1)
                }
        }
        .padding(8)
    }
}

// MARK: - Dynamic Island, expanded

private struct ExpandedIsland: View {
    let state: PinnedTaskAttributes.ContentState
    let taskID: UUID

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(state.title)
                    .font(state.font(15, weight: .medium))
                    .foregroundStyle(Color(state.palette.ink))
                    .lineLimit(2)
                if let chip = state.chip {
                    Text(chip)
                        .font(state.font(12))
                        .foregroundStyle(Color(state.palette.inkMuted))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(intent: CompletePinnedTaskIntent(taskID: taskID)) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(Color(state.palette.accent))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 4)
    }
}
