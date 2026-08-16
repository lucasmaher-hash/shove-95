//
//  HowToView.swift
//  shove95
//
//  The gestures, listed, in the Win95 look. Content comes from `HowTo` so this
//  screen and its skeu twin cannot say different things.
//

import SwiftUI

struct HowToView: View {
    @Environment(\.pixel) private var pixel
    /// Read so a face change re-renders this view — see `\.appFace`.
    @Environment(\.appFace) private var face
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            TitleBar(title: "How to use - shove.95", isClose: true, onSettings: onClose)

            SunkenWell {
                ScrollView {
                    VStack(alignment: .leading, spacing: Win95.Px.grid * 5 * pixel) {
                        ForEach(HowTo.sections) { section in
                            VStack(alignment: .leading, spacing: Win95.Px.grid * 2 * pixel) {
                                Text(section.title)
                                    .font(W95Font.small(pixel, role: .chrome))
                                    .textCase(.uppercase)
                                    .tracking(0.8)
                                    .foregroundStyle(Win95.textMuted)

                                ForEach(section.items) { item in
                                    row(item)
                                }
                            }
                        }
                    }
                    .padding(Win95.Px.grid * 2 * pixel)
                    .padding(.bottom, Win95.Px.grid * 8 * pixel)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .background(Win95.surface)
        .ignoresSafeArea(.container, edges: .bottom)
    }

    private func row(_ item: HowTo.Item) -> some View {
        VStack(alignment: .leading, spacing: Win95.Px.grid * pixel) {
            Text(item.action)
                .font(W95Font.standard(pixel))
                .foregroundStyle(Win95.text)

            Text(item.result)
                .font(W95Font.small(pixel))
                .foregroundStyle(Win95.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
