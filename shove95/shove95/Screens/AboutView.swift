//
//  AboutView.swift
//  shove95
//
//  TASK-055. Terse: what this is, what version, who made it, the two credits
//  that are legal obligations, and a link to the privacy policy. No marketing
//  copy — the app doesn't talk about itself anywhere else either.
//

import SwiftUI
import StoreKit

struct AboutView: View {
    @Environment(\.pixel) private var pixel
    /// The system review prompt. Apple rate-limits it, so a press may show
    /// nothing — which is why the button says "Rate", not "Open the App Store".
    @Environment(\.requestReview) private var requestReview
    @Environment(\.openURL) private var openURL
    var onClose: () -> Void

    /// Published alongside the App Store listing (TASK-056).
    private static let privacyPolicyURL = URL(string: "https://lucasmaher-hash.github.io/shove-95/privacy")!

    var body: some View {
        VStack(spacing: 0) {
            TitleBar(title: "About - shove.95", isClose: true, onSettings: onClose)

            SunkenWell {
                ScrollView {
                    VStack(alignment: .leading, spacing: Win95.Px.grid * 2 * pixel) {
                        Text("shove.95")
                            .font(W95Font.standard(pixel))
                            .foregroundStyle(Win95.text)

                        Text("Version \(version) (\(build))")
                            .font(W95Font.small(pixel))
                            .foregroundStyle(Win95.textMuted)

                        Text("Four tabs. One swipe moves a task between them.")
                            .font(W95Font.small(pixel))
                            .foregroundStyle(Win95.textMuted)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, Win95.Px.grid * pixel)

                        Divider().overlay(Win95.shadow)

                        // Both credits are licence conditions, not courtesies.
                        Text("Typeface: W95FA by Alina Sava (SIL OFL)")
                            .font(W95Font.small(pixel))
                            .foregroundStyle(Win95.textMuted)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("Not affiliated with Microsoft. Windows 95 is a trademark of Microsoft Corporation.")
                            .font(W95Font.small(pixel))
                            .foregroundStyle(Win95.textMuted)
                            .fixedSize(horizontal: false, vertical: true)

                        Win95Button(action: { requestReview() }, compact: true) {
                            Text("Rate the app")
                                .font(W95Font.small(pixel))
                                .foregroundStyle(Win95.text)
                        }
                        .fixedSize()
                        .padding(.top, Win95.Px.grid * 2 * pixel)

                        Win95Button(action: { openURL(Self.privacyPolicyURL) }, compact: true) {
                            Text("Privacy policy")
                                .font(W95Font.small(pixel))
                                .foregroundStyle(Win95.text)
                        }
                        .fixedSize()
                        .padding(.top, Win95.Px.grid * pixel)

                        Text("© \(year) Lucas Maher")
                            .font(W95Font.small(pixel))
                            .foregroundStyle(Win95.textMuted)
                            .padding(.top, Win95.Px.grid * 2 * pixel)
                    }
                    .padding(Win95.Px.grid * 2 * pixel)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Win95.surface)
        .ignoresSafeArea(.container, edges: .bottom)
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
