//
//  SkeuSecondaryScreens.swift
//  shove95
//
//  Archive and About in the skeu look. Both are read-mostly screens, so they
//  use the settings card as their container and keep the vocabulary already
//  established: cards for grouping, troughs for chrome, glass for controls,
//  plain text on the ground for content.
//
//  Neither screen took its structure from the version that came before — those
//  were built out of window furniture (title bar, sunken well) that has no
//  equivalent here. What IS carried over is their content and their rules: the
//  archive's day grouping and non-actionable rows, About's two licence
//  credits, which are conditions rather than courtesies.
//

import SwiftUI
import StoreKit
import Shove95Kit

private enum S {
    static let label: CGFloat = 12.8
    static let cardRadius: CGFloat = 30
    static let cardRim = 7 * (66.4 / 148.2) // 3.1 — the trough contour width
    static let cardPad: CGFloat = 21.3
    static let margin: CGFloat = 21.5
    static let pillHeight: CGFloat = 30
    /// The ✕ on these sheets. One figure for every circular control in the
    /// look — the settings gear, the sheet ✕, the photo viewer's pair — so
    /// switching between them is not a size change (founder direction
    /// 2026-08-17).
    static let closeCircle: CGFloat = SkeuTopBar.control
}

// MARK: - Shared chrome

/// Header + scrolling body, shared by both screens.
private struct SkeuSheet<Content: View>: View {
    @Environment(AppSettings.self) private var settings
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
                    // CHROME, like the Settings header — a screen's own name
                    // is the app labelling itself, so it holds the pixel face
                    // under Blend (founder bug report 2026-08-17).
                    Text(title)
                        .font(SkeuFont.title3Chrome)
                        .foregroundStyle(skeu.ink)

                    Spacer(minLength: SkeuSpace.sm)

                    // NO Button around this. A Button takes the touch before
                    // the modifier's own gesture can see it, so the ✕ closed
                    // the sheet and never swelled (founder bug report
                    // 2026-08-17). `.skeuPress` is the control.
                    SkeuChromeGlyph(kind: .close, face: settings.skeuFace,
                                    size: SkeuTopBar.icon * chromeScale,
                                    tint: skeu.ink)
                        .frame(width: closeSize, height: closeSize)
                        .skeuGlass(Circle(), height: closeSize)
                        .skeuPress { onClose() }
                        .frame(minWidth: SkeuControl.minTouch, minHeight: SkeuControl.minTouch)
                        .accessibilityAddTraits(.isButton)
                        .accessibilityLabel("Close")
                }
                .padding(.horizontal, S.margin)
                .padding(.vertical, SkeuSpace.md)

                ScrollView {
                    content
                        .padding(.horizontal, S.margin)
                        // Room for the panels' own shadows. They reach about
                        // 16pt above their frame, and the scroll view clips to
                        // its bounds — so the first card's top shading was cut
                        // straight off (founder bug report 2026-08-17).
                        .padding(.top, SkeuSpace.md)
                        // Clears the home indicator by padding, since the
                        // scroll view now runs past the safe area — the same
                        // fix the settings sheet took (2026-08-16).
                        //
                        // The SAME clearance settings uses, no more. These
                        // three carried an extra band that read as a strip cut
                        // off the bottom of the page (founder bug report
                        // 2026-08-17).
                        .padding(.bottom, SkeuSpace.md + 34)
                }
                .scrollBounceBehavior(.always, axes: .vertical)
                .scrollIndicators(.hidden)
                // The header is docked here too, so content dissolves as it
                // passes under it — the settings sheet got this and Archive,
                // About and How to use were left without it.
                .skeuScrollEdgeFade(28 * chromeScale, edges: .top)
                // LAST, after the fade — the order settings uses.
                //
                // The fade is a MASK, and a mask is built from the bounds of
                // the view it wraps. Reaching past the safe area first and
                // masking afterwards handed the mask the un-expanded size, so
                // the scroll view stopped a home-indicator's height short and
                // sliced the last card off along a hard line, with a dead
                // strip beneath it (founder bug report 2026-08-17, twice —
                // the first attempt changed the clearance, which was never
                // what made the cut).
                .ignoresSafeArea(.container, edges: .bottom)
            }
        }
        .swipeToDismiss(headerHeight: S.closeCircle * chromeScale
                        + SkeuSpace.md * 3,
                        // CLEAR. A canvas-coloured
                        // backdrop was standing in for the screen behind, and
                        // once the sheet started fading it out on its way off
                        // the edge, what it uncovered was the void a
                        // full-screen cover leaves (founder bug report
                        // 2026-08-17). Asking the presentation itself to be
                        // transparent shows the real screen instead.
                        backdrop: .clear, onClose)
        .presentationBackground(.clear)
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
                    stops: [.init(color: skeu.outlineLit, location: 0.0),
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
                        day(group)
                    }
                }
            }
        }
    }

    /// One day's block: the date ABOVE the frame, and the tasks cut into the
    /// page below it (founder direction 2026-08-23).
    ///
    /// It was a raised card with the date inside it — `SkeuPanel`, which is
    /// what About and How to use still are. Two changes at once:
    ///
    ///   - INDENTED rather than standing off the page, like the live box. A
    ///     screen of read-only records is a set of things filed away, and the
    ///     look already says "filed" with a trough.
    ///   - The date is a LABEL for the frame, so it sits above it rather than
    ///     inside it.
    ///
    /// And it is the reason the screen was heavy. Every panel carried two
    /// blurred shadows, at radius 26.8 and 49, one pair per day and none of
    /// them baked — the archive was the last place in the app still paying
    /// that per frame. A trough's inner shadows are rasterised once (see
    /// InnerShadow), so the whole cost goes.
    @ViewBuilder
    private func day(_ group: (day: Date, tasks: [TaskItem])) -> some View {
        let shape = RoundedRectangle(cornerRadius: S.cardRadius, style: .continuous)

        VStack(alignment: .leading, spacing: SkeuSpace.sm) {
            Text(group.day.formatted(
                .dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                .font(SkeuFont.eyebrow)
                .textCase(.uppercase)
                .tracking(0.8)
                .foregroundStyle(skeu.inkFaint)
                .padding(.leading, SkeuSpace.sm)

            VStack(spacing: SkeuSpace.sm) {
                ForEach(group.tasks, id: \.id) { task in
                    row(task)
                }
            }
            .padding(S.cardPad)
            .frame(maxWidth: .infinity, alignment: .leading)
            // SHALLOWER than the live box, which the founder asked for by
            // name: the ramp finishes sooner, the shade runs at under half
            // weight and the floor is lifted further. A well holding a few
            // lines of struck-through text should read as a recess, not as a
            // pit.
            .skeuTrough(shape, height: 56, fillStop: 0.20, shadeScale: 0.42,
                        fillLift: 0.70)
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
    /// See AboutView: the system prompt, which Apple rate-limits.
    @Environment(\.requestReview) private var requestReview
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

                        // Same pill as Privacy policy below it — one glass
                        // control, two errands.
                        Text("Rate the app")
                            .font(SkeuFont.at(labelSize, weight: .medium))
                            .foregroundStyle(skeu.ink)
                            .padding(.horizontal, SkeuSpace.lg)
                            .frame(height: 38)
                            .skeuGlass(Capsule(), height: 38)
                            .frame(minHeight: SkeuControl.minTouch)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                SkeuHaptic.press()
                                requestReview()
                            }
                            .accessibilityAddTraits(.isButton)
                            .padding(.top, SkeuSpace.sm)

                        Text("Privacy policy")
                            .font(SkeuFont.at(labelSize, weight: .medium))
                            .foregroundStyle(skeu.ink)
                            .padding(.horizontal, SkeuSpace.lg)
                            .frame(height: 38)
                            .skeuGlass(Capsule(), height: 38)
                            // Glass pill stays 38; the target is 44.
                            .frame(minHeight: SkeuControl.minTouch)
                            .contentShape(Rectangle())
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

// MARK: - How to use

/// The gestures, listed. Content comes from `HowTo`, which is what kept this
/// screen and the walkthrough from saying different things.
struct SkeuHowToView: View {
    @Environment(\.skeuTextScale) private var textScale
    @Environment(\.skeuChromeScale) private var chromeScale

    private var labelSize: CGFloat { S.label * textScale }
    @Environment(\.skeu) private var skeu
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var onClose: () -> Void
    /// Runs the first-run walkthrough again. The caller closes this screen
    /// AND settings behind it — the walkthrough plays over the list, and a
    /// sheet on top of it would be pointing at controls nobody can see.
    var onReplay: () -> Void

    /// Drives the label's breath. Set once on appear.
    @State private var breathing = false
    /// The docked bar's measured height, so the last card can clear it.
    /// Measured rather than assumed: the bar is a tenth of the screen, which
    /// is not a number this file otherwise knows.
    @State private var barHeight: CGFloat = 0

    var body: some View {
        SkeuSheet(title: "How to use", onClose: onClose) {
            LazyVStack(alignment: .leading, spacing: SkeuSpace.lg) {
                // The shape of the app: its own panel, and untitled, because
                // these are not a category — see HowToContent.
                SkeuPanel {
                    VStack(alignment: .leading, spacing: SkeuSpace.md) {
                        ForEach(HowTo.essentials) { item in
                            row(item)
                        }
                    }
                }

                // The GAP, and it is the whole point of the split: what
                // follows is lookup, not more of the same. A rule would say
                // "another section"; empty ground says "you can stop here"
                // (founder direction 2026-08-17).
                Color.clear.frame(height: SkeuSpace.xl)

                ForEach(HowTo.sections) { section in
                    SkeuPanel(title: section.title) {
                        VStack(alignment: .leading, spacing: SkeuSpace.md) {
                            ForEach(section.items) { item in
                                row(item)
                            }
                        }
                    }
                }
            }
            // Clears the docked bar below, which lies OVER this scroll view
            // rather than beside it — the sheet's own frame is one piece.
            .padding(.bottom, barHeight)
        }
        .overlay(alignment: .bottom) { replayBar }
    }

    /// The whole bottom edge of the screen, a tenth of it tall (founder
    /// direction 2026-08-17).
    private var replayBar: some View {
        Text("Show me")
            .font(SkeuFont.at(labelSize * 1.32, weight: .semibold))
            // The CANVAS, on the accent — the one pairing in the palette that
            // is guaranteed to hold at both appearances, since the canvas is
            // what the accent is always seen against.
            .foregroundStyle(skeu.canvas)
            // The BREATH. Scale, not tone: the founder asked for it to grow
            // and shrink, and tone in this look already means depth.
            .scaleEffect(breathing && !reduceMotion ? 1.08 : 1.0)
            .animation(breath, value: breathing)
            .frame(maxWidth: .infinity)
            // A tenth of the SCREEN, inset from all three edges (founder
            // direction 2026-08-17). It was a full-bleed slab, which is the
            // one thing this look never does — nothing here runs into the
            // bezel, and a rounded shape needs room to be seen rounding.
            .containerRelativeFrame(.vertical) { height, _ in height * 0.1 }
            // FLAT, and the one flat object in the look (founder direction
            // 2026-08-17). Everything else here is a surface with a rim and a
            // shadow; this is asked to stand apart from all of it, and the
            // accent at full strength with no depth is what does that. The
            // press still answers — `skeuPress` scales it — so the control is
            // not silent, it simply has no material.
            .background {
                RoundedRectangle(cornerRadius: SkeuRadius.lg, style: .continuous)
                    .fill(skeu.accent)
            }
            .padding(.horizontal, S.margin)
            .padding(.bottom, SkeuSpace.lg)
            .contentShape(RoundedRectangle(cornerRadius: SkeuRadius.lg, style: .continuous))
            .skeuPress { onReplay() }
            .onAppear { breathing = true }
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { barHeight = proxy.size.height }
                        .onChange(of: proxy.size.height) { _, h in barHeight = h }
                }
            }
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel("Show me how to use the app")
    }

    /// §8.5: Reduce Motion holds it still rather than slowing it down — a
    /// breath is decoration, and decoration is what that setting turns off.
    private var breath: Animation {
        reduceMotion
            ? .easeOut(duration: 0.01)
            : .easeInOut(duration: 0.9).repeatForever(autoreverses: true)
    }

    /// The gesture reads as the heading and its outcome as the body — the same
    /// two-line stack the settings eyebrows use, so a reader can scan the left
    /// column alone and still find what they came for.
    /// Picture first, then the name of the gesture, then one line. A reader
    /// looking something up scans the left column and only reads the line
    /// under the picture that matches.
    private func row(_ item: HowTo.Item) -> some View {
        HStack(alignment: .top, spacing: SkeuSpace.md) {
            HowToGlyph(glyph: item.glyph, tint: skeu.inkMuted,
                       size: 26 * chromeScale)

            VStack(alignment: .leading, spacing: SkeuSpace.xs) {
                Text(item.action)
                    .font(SkeuFont.at(labelSize, weight: .medium))
                    .foregroundStyle(skeu.ink)

                Text(item.result)
                    .font(SkeuFont.at(labelSize))
                    .foregroundStyle(skeu.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}
