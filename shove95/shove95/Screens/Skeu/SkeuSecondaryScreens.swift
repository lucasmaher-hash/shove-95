//
//  SkeuSecondaryScreens.swift
//  shove95
//
//  Archive and About in the skeu look. Both are read-mostly screens, so they
//  use the settings card as their container and keep the vocabulary already
//  established: cards for grouping, troughs for chrome, glass for controls,
//  plain text on the ground for content.
//
//  Neither screen has a Win95 counterpart worth transcribing structurally —
//  the originals are built out of window furniture (title bar, sunken well)
//  that has no equivalent here. What IS carried over is their content and
//  their rules: the archive's day grouping and non-actionable rows, About's
//  two licence credits, which are conditions rather than courtesies.
//

import SwiftUI
import Shove95Kit

private enum S {
    static let label: CGFloat = 12.8
    static let cardRadius: CGFloat = 30
    static let cardRim = 7 * (66.4 / 148.2) // 3.1 — the trough contour width
    static let cardPad: CGFloat = 21.3
    static let margin: CGFloat = 21.5
    static let pillHeight: CGFloat = 30
    static let closeCircle: CGFloat = 37
}

// MARK: - Shared chrome

/// Header + scrolling body, shared by both screens.
private struct SkeuSheet<Content: View>: View {
    @Environment(\.skeuTextScale) private var textScale
    @Environment(\.skeuChromeScale) private var chromeScale

    // Dynamic Type (FR-015) — see SkeuTypeScale.
    private var labelSize: CGFloat { S.label * textScale }
    private var pillH: CGFloat { S.pillHeight * chromeScale }
    private var closeSize: CGFloat { S.closeCircle * chromeScale }
    @Environment(\.skeu) private var skeu
    let title: String
    var onClose: () -> Void
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            skeu.canvas.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(title)
                        .font(SkeuFont.title3)
                        .foregroundStyle(skeu.ink)

                    Spacer(minLength: SkeuSpace.sm)

                    Button {
                        SkeuHaptic.press()
                        onClose()
                    } label: {
                        Image(systemName: "xmark")
                            .font(SkeuFont.at(15, weight: .medium))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(skeu.ink)
                            .frame(width: closeSize, height: closeSize)
                            .skeuGlass(Circle(), height: closeSize)
                    }
                    .buttonStyle(.plain)
                    .frame(minWidth: SkeuControl.minTouch, minHeight: SkeuControl.minTouch)
                    .accessibilityLabel("Close")
                }
                .padding(.horizontal, S.margin)
                .padding(.vertical, SkeuSpace.md)

                ScrollView {
                    content
                        .padding(.horizontal, S.margin)
                        .padding(.bottom, SkeuSpace.xxl)
                }
                .scrollBounceBehavior(.always, axes: .vertical)
        .scrollIndicators(.hidden)
            }
        }
    }
}

/// The settings card, reused. Kept private to this file rather than shared
/// with SkeuSettingsView: the two will drift, and a "generic card" that both
/// import is the kind of premature abstraction that ends up with six flags.
private struct SkeuPanel<Content: View>: View {
    @Environment(\.skeuTextScale) private var textScale
    @Environment(\.skeuChromeScale) private var chromeScale

    // Dynamic Type (FR-015) — see SkeuTypeScale.
    private var labelSize: CGFloat { S.label * textScale }
    private var pillH: CGFloat { S.pillHeight * chromeScale }
    private var closeSize: CGFloat { S.closeCircle * chromeScale }
    @Environment(\.skeu) private var skeu
    var title: String?
    @ViewBuilder var content: Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: S.cardRadius, style: .continuous)

        VStack(alignment: .leading, spacing: SkeuSpace.sm) {
            if let title {
                Text(title)
                    .font(SkeuFont.eyebrow)
                    .textCase(.uppercase)
                    .tracking(0.8)
                    .foregroundStyle(skeu.inkFaint)
            }
            content
        }
        .padding(S.cardPad)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            shape.fill(
                LinearGradient(colors: [skeu.materialTop, skeu.material, skeu.materialBottom],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            )
        }
        .overlay {
            // Raised contour: lit on top, falling into shade below.
            shape.strokeBorder(
                LinearGradient(
                    stops: [.init(color: skeu.outlineBottom, location: 0.0),
                            .init(color: skeu.outline, location: 0.55),
                            .init(color: skeu.outline, location: 1.0)],
                    startPoint: .top, endPoint: .bottom),
                lineWidth: S.cardRim)
        }
        .shadow(color: skeu.shadow.opacity(0.19 * skeu.shadowIntensity),
                radius: 26.8, x: -6.5, y: 10.6)
        .shadow(color: skeu.shadow.opacity(0.16 * skeu.shadowIntensity),
                radius: 49, x: -25.4, y: 42)
    }
}

// MARK: - Archive

struct SkeuArchiveView: View {
    @Environment(\.skeuTextScale) private var textScale
    @Environment(\.skeuChromeScale) private var chromeScale

    // Dynamic Type (FR-015) — see SkeuTypeScale.
    private var labelSize: CGFloat { S.label * textScale }
    private var pillH: CGFloat { S.pillHeight * chromeScale }
    private var closeSize: CGFloat { S.closeCircle * chromeScale }
    @Environment(\.skeu) private var skeu
    @Environment(TaskStore.self) private var store
    var onClose: () -> Void

    var body: some View {
        SkeuSheet(title: "Archive", onClose: onClose) {
            let days = store.archivedTasksByDay()

            if days.isEmpty {
                Text("(empty)")
                    .font(SkeuFont.at(labelSize))
                    .foregroundStyle(skeu.inkFaint)
                    .frame(maxWidth: .infinity, minHeight: 160)
            } else {
                // Newest day first; the day itself is the only grouping.
                LazyVStack(alignment: .leading, spacing: SkeuSpace.lg) {
                    ForEach(days, id: \.day) { group in
                        SkeuPanel(title: group.day.formatted(
                            .dateTime.weekday(.abbreviated).day().month(.abbreviated))) {
                            VStack(spacing: SkeuSpace.sm) {
                                ForEach(group.tasks, id: \.id) { task in
                                    row(task)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func row(_ task: TaskItem) -> some View {
        HStack(spacing: SkeuSpace.sm) {
            // Struck through and muted, exactly as it looked the moment it
            // left the list — no live checkbox, nothing here is actionable.
            Text(task.title)
                .font(SkeuFont.at(labelSize))
                .strikethrough(color: skeu.inkFaint)
                .foregroundStyle(skeu.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("Delete")
                .font(SkeuFont.at(labelSize * 0.9, weight: .medium))
                .foregroundStyle(skeu.critical)
                .lineLimit(1)
                .padding(.horizontal, SkeuSpace.md)
                .frame(height: pillH)
                .skeuGlass(Capsule(), height: pillH)
                .contentShape(Capsule())
                .onTapGesture {
                    SkeuHaptic.warning()
                    withAnimation(SkeuMotion.layout) { store.delete(task) }
                }
                .accessibilityLabel("Delete \(task.title) from the archive")
        }
        .frame(minHeight: SkeuControl.minTouch)
    }
}

// MARK: - About

struct SkeuAboutView: View {
    @Environment(\.skeuTextScale) private var textScale
    @Environment(\.skeuChromeScale) private var chromeScale

    // Dynamic Type (FR-015) — see SkeuTypeScale.
    private var labelSize: CGFloat { S.label * textScale }
    private var pillH: CGFloat { S.pillHeight * chromeScale }
    private var closeSize: CGFloat { S.closeCircle * chromeScale }
    @Environment(\.skeu) private var skeu
    @Environment(\.openURL) private var openURL
    var onClose: () -> Void

    /// Published alongside the App Store listing.
    private static let privacyPolicyURL =
        URL(string: "https://lucasmaher-hash.github.io/shove-95/privacy")!

    var body: some View {
        SkeuSheet(title: "About", onClose: onClose) {
            VStack(alignment: .leading, spacing: SkeuSpace.lg) {
                SkeuPanel {
                    VStack(alignment: .leading, spacing: SkeuSpace.sm) {
                        Text("shove.95")
                            .font(SkeuFont.display)
                            .foregroundStyle(skeu.ink)

                        Text("Version \(version) (\(build))")
                            .font(SkeuFont.at(labelSize))
                            .foregroundStyle(skeu.inkMuted)

                        Text("Four tabs. One swipe moves a task between them.")
                            .font(SkeuFont.at(labelSize))
                            .foregroundStyle(skeu.inkMuted)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, SkeuSpace.xs)
                    }
                }

                SkeuPanel(title: "Credits") {
                    VStack(alignment: .leading, spacing: SkeuSpace.md) {
                        // Both credits are licence conditions, not courtesies.
                        Text("Typeface: W95FA by Alina Sava (SIL OFL)")
                            .font(SkeuFont.at(labelSize))
                            .foregroundStyle(skeu.inkMuted)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("Not affiliated with Microsoft. Windows 95 is a trademark of Microsoft Corporation.")
                            .font(SkeuFont.at(labelSize))
                            .foregroundStyle(skeu.inkMuted)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("Privacy policy")
                            .font(SkeuFont.at(labelSize, weight: .medium))
                            .foregroundStyle(skeu.ink)
                            .padding(.horizontal, SkeuSpace.lg)
                            .frame(height: 38)
                            .skeuGlass(Capsule(), height: 38)
                            .contentShape(Capsule())
                            .onTapGesture {
                                SkeuHaptic.press()
                                openURL(Self.privacyPolicyURL)
                            }
                            .accessibilityAddTraits(.isLink)
                            .padding(.top, SkeuSpace.xs)
                    }
                }

                Text("© \(year) Lucas Maher")
                    .font(SkeuFont.at(labelSize))
                    .foregroundStyle(skeu.inkFaint)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    private var year: String {
        Calendar.current.component(.year, from: .now).formatted(.number.grouping(.never))
    }
}
