//
//  OnboardingOverlay.swift
//  shove95
//
//  What the first run draws over the app: a dimmed page with the control in
//  question cut out of it, a line naming what that control does, and a docked
//  bar to move on.
//
//  NOTHING here takes a touch except the docked bar. The scrim and the caption
//  are `allowsHitTesting(false)`, so the highlighted control is the real one
//  and pressing it does the real thing — which is the entire point of running
//  this over the app instead of over a slideshow (founder direction
//  2026-08-17). It also means someone who wants none of it can simply carry
//  on; the walkthrough follows rather than blocks.
//
//  `OnboardingLayout` decides where the caption sits and how big the hole is;
//  the overlay below draws it. There were two of these, one per look, until
//  the Windows 95 interface was removed on 2026-08-22.
//

import SwiftUI

/// Where the pieces go, given the target's frame and the screen.
enum OnboardingLayout {
    /// Breathing room around the cut-out, so the control is not clipped by
    /// the hole meant to reveal it.
    static let halo: CGFloat = 8

    /// How hard the page is dimmed. Stated once — both looks were carrying
    /// the same number with the same comment beside it.
    static let scrim: Double = 0.62

    static func hole(for target: CGRect) -> CGRect {
        target.insetBy(dx: -halo, dy: -halo)
    }

    /// The caption goes UNDER the control when the control is in the top half
    /// and OVER it otherwise — always on the side with room, so it never
    /// covers the thing it is describing.
    static func captionIsBelow(_ target: CGRect, in screen: CGSize) -> Bool {
        target.midY < screen.height * 0.5
    }

    /// The docked bar moves to the TOP when the control being pointed at
    /// lives in the bottom band. Two of the four steps point at the Live ring
    /// and the tabs, which are exactly where a bottom-docked bar sits — it
    /// covered the very thing it was explaining (caught on first run,
    /// 2026-08-17).
    static func barAtTop(_ target: CGRect?, in screen: CGSize) -> Bool {
        guard let target else { return false }
        return target.maxY > screen.height - 170
    }
}

struct SkeuOnboardingOverlay: View {
    @Environment(\.skeu) private var skeu
    @Environment(\.skeuTextScale) private var textScale
    @Environment(\.skeuChromeScale) private var chromeScale
    let step: OnboardingCoordinator.Step
    let target: CGRect?
    var onNext: () -> Void
    var onSkip: () -> Void

    private var labelSize: CGFloat { SkeuToggle.label * textScale }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ZStack(alignment: .topLeading) {
                    scrim(in: geo.size)

                    if let target {
                        // The hole gets a rim of its own: on a dimmed page a
                        // cut-out alone reads as a gap, not as a thing.
                        RoundedRectangle(cornerRadius: SkeuRadius.md, style: .continuous)
                            .strokeBorder(skeu.outlineLit, lineWidth: 1.5)
                            .frame(width: OnboardingLayout.hole(for: target).width,
                                   height: OnboardingLayout.hole(for: target).height)
                            .position(x: target.midX, y: target.midY)

                        caption(for: target, in: geo.size)
                    }
                }
                .allowsHitTesting(false)
                .ignoresSafeArea()

                // OUTSIDE the expansion above, so a bar sent to the top clears
                // the status bar instead of sitting under it.
                bar.frame(maxHeight: .infinity,
                          alignment: OnboardingLayout.barAtTop(target, in: geo.size)
                              ? .top : .bottom)
            }
        }
    }

    private func scrim(in size: CGSize) -> some View {
        Path { path in
            path.addRect(CGRect(origin: .zero, size: size))
            if let target {
                path.addRoundedRect(in: OnboardingLayout.hole(for: target),
                                    cornerSize: CGSize(width: SkeuRadius.md,
                                                       height: SkeuRadius.md),
                                    style: .continuous)
            }
        }
        // EVEN-ODD, so the rounded rectangle punches the page rather than
        // painting over it. The palette's own shadow rather than black, so a
        // dimmed page still belongs to the theme it is dimming.
        .fill(skeu.shadow.opacity(OnboardingLayout.scrim),
              style: FillStyle(eoFill: true))
    }

    private func caption(for target: CGRect, in size: CGSize) -> some View {
        let below = OnboardingLayout.captionIsBelow(target, in: size)
        let hole = OnboardingLayout.hole(for: target)

        return VStack(alignment: .leading, spacing: SkeuSpace.xs) {
            Text(step.title)
                .font(SkeuFont.at(labelSize * 1.32, weight: .semibold))
                .foregroundStyle(skeu.ink)
            Text(step.detail)
                .font(SkeuFont.at(labelSize))
                .foregroundStyle(skeu.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(SkeuSpace.lg)
        // The dialog surface, not SkeuCard: a card is a fixed-height ROW and
        // crushes anything multi-line into one band.
        .skeuSurface(RoundedRectangle(cornerRadius: SkeuRadius.lg, style: .continuous),
                     depth: .overlay)
        .padding(.horizontal, SkeuSpace.lg)
        .frame(width: size.width, alignment: .leading)
        .position(x: size.width / 2,
                  y: below ? hole.maxY + 56 * chromeScale
                           : hole.minY - 56 * chromeScale)
    }

    private var bar: some View {
        let height = SkeuToggle.height * chromeScale

        return HStack(spacing: SkeuSpace.md) {
            Text("Skip")
                .font(SkeuFont.at(labelSize, weight: .medium))
                .foregroundStyle(skeu.inkMuted)
                .padding(.horizontal, SkeuSpace.lg)
                .frame(height: height)
                .skeuGlass(Capsule(), height: height, prominent: false)
                .contentShape(Capsule())
                .skeuPress(onSkip)

            Spacer(minLength: 0)

            Text(step.nextLabel)
                .font(SkeuFont.at(labelSize, weight: .medium))
                .foregroundStyle(skeu.ink)
                .padding(.horizontal, SkeuSpace.xl)
                .frame(height: height)
                .skeuGlass(Capsule(), height: height, prominent: true)
                .contentShape(Capsule())
                .skeuPress(onNext)
        }
        .padding(.horizontal, SkeuSpace.lg)
        .padding(.vertical, SkeuSpace.md)
        .background {
            Rectangle().fill(skeu.canvas).ignoresSafeArea()
        }
    }
}
