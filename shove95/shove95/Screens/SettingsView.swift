//
//  SettingsView.swift
//  shove95
//
//  A maximized Win95 settings window. Presented full-screen rather than as a
//  sheet — sheets carry rounded corners and a drag indicator, both prohibited
//  (design.md §9).
//
//  Archive, iCloud status and About arrive in Phase 5; what exists here now is
//  the appearance scheme picker and tab renaming.
//

import SwiftUI
import Shove95Kit

struct SettingsView: View {
    @Environment(\.pixel) private var pixel
    @Environment(AppSettings.self) private var settings
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            TitleBar(title: "Settings - shove.95", isClose: true, onSettings: onClose)

            SunkenWell {
                ScrollView {
                    VStack(alignment: .leading, spacing: Win95.Px.grid * 2 * pixel) {
                        appearanceSection
                        namesSection
                        comingSoonSection
                    }
                    .padding(Win95.Px.grid * 2 * pixel)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .background(Win95.surface)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .preferredColorScheme(.light)
    }

    // MARK: Appearance

    private var appearanceSection: some View {
        GroupBox95(title: "Appearance") {
            VStack(alignment: .leading, spacing: Win95.Px.grid * pixel) {
                // One row of window miniatures — the Win95 Appearance tab
                // showed you the scheme rather than naming it. Five stacked
                // rows for five colours was a wall of chrome for one choice.
                HStack(spacing: Win95.Px.grid * pixel) {
                    ForEach(Win95Scheme.all) { scheme in
                        SchemeSwatch(
                            scheme: scheme,
                            isSelected: scheme.id == settings.scheme.id
                        ) {
                            var t = Transaction()
                            t.disablesAnimations = true // appearance never animates
                            withTransaction(t) { settings.scheme = scheme }
                        }
                    }
                }

                Text(settings.scheme.name)
                    .font(W95Font.small(pixel))
                    .foregroundStyle(Win95.shadow)
            }
        }
    }

    // MARK: Tab names

    private var namesSection: some View {
        GroupBox95(title: "Tab names") {
            VStack(alignment: .leading, spacing: Win95.Px.grid * pixel) {
                ForEach(Bucket.line, id: \.self) { bucket in
                    NameField(bucket: bucket)
                }
                Text("Leave a field empty to restore the original name. Renaming a tab changes its label only — Today still means today.")
                    .font(W95Font.small(pixel))
                    .foregroundStyle(Win95.shadow)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, Win95.Px.grid * pixel)
            }
        }
    }

    private var comingSoonSection: some View {
        GroupBox95(title: "Data") {
            Text("Archive, iCloud status and About arrive with sync.")
                .font(W95Font.small(pixel))
                .foregroundStyle(Win95.shadow)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Scheme swatch

/// A scheme as a miniature window: title bar over body over well. Selected reads
/// as a pressed toolbar button — sunken bevel, nudged down and right one pixel.
private struct SchemeSwatch: View {
    @Environment(\.pixel) private var pixel
    let scheme: Win95Scheme
    let isSelected: Bool
    var action: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [Color(hex: scheme.titleA), Color(hex: scheme.titleB)],
                           startPoint: .leading, endPoint: .trailing)
                .frame(height: Win95.Px.grid * 3 * pixel)
            Color(hex: scheme.surface)
            Color(hex: scheme.well)
                .frame(height: Win95.Px.grid * 2 * pixel)
        }
        .frame(maxWidth: .infinity)
        .frame(height: Win95.rowHeight(pixel))
        .padding(pixel * 2)
        .background(Win95.surface)
        .modifier(SwatchBevel(isSelected: isSelected, pixel: pixel))
        .offset(x: isSelected ? pixel : 0, y: isSelected ? pixel : 0)
        .contentShape(Rectangle())
        .onTapGesture(perform: action)
        .accessibilityLabel(scheme.name)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

private struct SwatchBevel: ViewModifier {
    let isSelected: Bool
    let pixel: CGFloat

    func body(content: Content) -> some View {
        if isSelected { content.bevelSunken(pixel) } else { content.bevelRaised(pixel) }
    }
}

// MARK: - Name field

private struct NameField: View {
    @Environment(\.pixel) private var pixel
    @Environment(AppSettings.self) private var settings
    let bucket: Bucket

    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: Win95.Px.grid * pixel) {
            Text(bucket.displayName)
                .font(W95Font.small(pixel))
                .foregroundStyle(Win95.shadow)
                .frame(width: Win95.Px.grid * 16 * pixel, alignment: .leading)

            TextField(bucket.displayName, text: $draft)
                .font(W95Font.standard(pixel))
                .foregroundStyle(Win95.text)
                .focused($focused)
                .submitLabel(.done)
                .onSubmit { commit() }
                .onChange(of: focused) { _, isFocused in
                    if !isFocused { commit() }
                }
                .padding(.horizontal, Win95.Px.grid * pixel)
                .frame(minHeight: Win95.rowHeight(pixel))
                .background(Win95.well)
                .bevelSunken(pixel)
        }
        .task {
            let current = settings.name(for: bucket)
            draft = current == bucket.displayName ? "" : current
        }
    }

    private func commit() {
        settings.setName(draft, for: bucket)
    }
}

// MARK: - Group box

/// Win95 group box: a sunken hairline frame with the title sitting on it.
struct GroupBox95<Content: View>: View {
    @Environment(\.pixel) private var pixel
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Win95.Px.grid * pixel) {
            Text(title)
                .font(W95Font.standard(pixel))
                .foregroundStyle(Win95.text)

            content
                .padding(Win95.Px.grid * 2 * pixel)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Win95.surface)
                .bevelRaised(pixel)
        }
    }
}
