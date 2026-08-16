//
//  PinReplaceDialog.swift
//  shove95
//
//  "Something else is already pinned. Replace it?"
//
//  One question, drawn twice. The Win95 half is a modal dialog box — title
//  bar, message, two buttons, the raised bevel — because that is what 1995
//  did when it needed an answer. The skeu half is a floating card. Neither
//  reuses the other's geometry; only the words and the outcome are shared,
//  and those live in `PinCoordinator`.
//
//  Both dim the screen behind them and swallow taps outside, which is the
//  one behaviour a modal question must have: there is no third answer.
//

import SwiftUI

// MARK: - Windows 95

struct Win95PinReplaceDialog: View {
    @Environment(\.pixel) private var pixel
    let outgoing: String
    var onReplace: () -> Void
    var onCancel: () -> Void

    var body: some View {
        ZStack {
            // The scrim is a control: tapping it cancels, the way clicking
            // outside a Win95 modal beeps and keeps focus. Cancelling is the
            // safe answer, so it is the one that costs least.
            // `darkShadow` from the scheme, not black: the scrim has to
            // re-tint with the palette like everything else, and a scheme
            // whose darkest tone is not black would have shown a black veil
            // over its own colours.
            Win95.darkShadow.opacity(0.4)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: onCancel)

            VStack(spacing: 0) {
                TitleBar(title: "Replace pinned task", isClose: true, onSettings: onCancel)

                VStack(alignment: .leading, spacing: Win95.Px.grid * 3 * pixel) {
                    Text("\u{201C}\(outgoing)\u{201D} is pinned to your Lock Screen. Only one task can be pinned.")
                        .font(W95Font.standard(pixel))
                        .foregroundStyle(Win95.text)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: Win95.Px.grid * 2 * pixel) {
                        Spacer(minLength: 0)

                        Win95Button(action: onCancel, compact: true,
                                    width: Win95.Px.grid * 14 * pixel) {
                            Text("Cancel")
                                .font(W95Font.small(pixel))
                                .foregroundStyle(Win95.text)
                        }

                        Win95Button(action: onReplace, compact: true,
                                    width: Win95.Px.grid * 14 * pixel) {
                            Text("Replace")
                                .font(W95Font.small(pixel))
                                .foregroundStyle(Win95.text)
                        }
                    }
                }
                .padding(Win95.Px.grid * 3 * pixel)
            }
            .background(Win95.surface)
            .bevelRaised(pixel)
            .padding(.horizontal, Win95.Px.grid * 6 * pixel)
        }
    }
}

// MARK: - Skeu

struct SkeuPinReplaceDialog: View {
    @Environment(\.skeu) private var skeu
    @Environment(\.skeuTextScale) private var textScale
    @Environment(\.skeuChromeScale) private var chromeScale
    let outgoing: String
    var onReplace: () -> Void
    var onCancel: () -> Void

    var body: some View {
        let buttonH = SkeuToggle.height - SkeuToggle.padV * 2

        ZStack {
            skeu.shadow.opacity(0.45)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: onCancel)

            VStack(alignment: .leading, spacing: SkeuSpace.lg) {
                Text("Replace pinned task")
                    .font(SkeuFont.title3)
                    .foregroundStyle(skeu.ink)

                Text("\u{201C}\(outgoing)\u{201D} is pinned to your Lock Screen. Only one task can be pinned.")
                    .font(SkeuFont.callout)
                    .foregroundStyle(skeu.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: SkeuSpace.sm) {
                    Spacer(minLength: 0)

                    dialogButton("Cancel", tint: skeu.inkMuted,
                                 height: buttonH * chromeScale, action: onCancel)
                    dialogButton("Replace", tint: skeu.ink,
                                 height: buttonH * chromeScale, action: onReplace)
                }
            }
            .padding(SkeuSpace.xl)
            .frame(maxWidth: 340)
            // A card, not a trough: this floats ABOVE the screen it covers,
            // so it takes the top of the depth ladder rather than being cut
            // into the ground like every control underneath it.
            .skeuSurface(RoundedRectangle(cornerRadius: SkeuRadius.lg, style: .continuous),
                         depth: .overlay)
            .padding(.horizontal, SkeuSpace.xl)
        }
    }

    private func dialogButton(_ title: String,
                              tint: Color,
                              height: CGFloat,
                              action: @escaping () -> Void) -> some View {
        Text(title)
            .font(SkeuFont.at(SkeuToggle.label * textScale, weight: .medium))
            .foregroundStyle(tint)
            .lineLimit(1)
            .padding(.horizontal, SkeuSpace.lg)
            .frame(height: height)
            .skeuGlass(Capsule(), height: height)
            .contentShape(Capsule())
            .onTapGesture {
                SkeuHaptic.press()
                action()
            }
            .accessibilityAddTraits(.isButton)
    }
}
