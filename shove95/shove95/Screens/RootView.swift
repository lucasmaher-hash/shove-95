//
//  RootView.swift
//  shove95
//
//  Phase-0 shell: four switchable tabs, no styling yet (the Win95 taskbar
//  replaces the plain buttons in Phase 3). Tab switching is INSTANT — motion
//  never accompanies appearance changes (design.md §8).
//

import SwiftUI
import Shove95Kit

struct RootView: View {
    @State private var selected: Bucket = .today
    @Environment(\.pixel) private var pixel

    var body: some View {
        VStack(spacing: 0) {
            // Placeholder content area — replaced by the task list in Phase 1.
            // Rendered in W95FA so the font registration (TASK-004) is verifiable on screen.
            VStack(spacing: Win95.Px.grid * pixel) {
                Text(selected.displayName)
                    .font(W95Font.standard(pixel))
                    .foregroundStyle(Win95.text)
                Text("(empty)")
                    .font(W95Font.standard(pixel))
                    .foregroundStyle(Win95.shadow)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Win95.highlight)

            // Placeholder tab strip — becomes the Win95 taskbar in Phase 3.
            HStack(spacing: 0) {
                ForEach(Bucket.line, id: \.self) { bucket in
                    Button {
                        // Instant switch: suppress all implicit animation.
                        var t = Transaction()
                        t.disablesAnimations = true
                        withTransaction(t) { selected = bucket }
                    } label: {
                        Text(bucket.displayName)
                            .font(W95Font.small(pixel))
                            .foregroundStyle(selected == bucket ? Win95.highlight : Win95.text)
                            .frame(maxWidth: .infinity, minHeight: Win95.rowMinHeight)
                    }
                    .buttonStyle(.plain)
                    .background(selected == bucket ? Win95.darkShadow : Win95.surface)
                }
            }
            .background(Win95.surface)
        }
        .preferredColorScheme(.light) // Win95 has no dark mode (design.md §1)
    }
}

#Preview {
    RootView()
}
