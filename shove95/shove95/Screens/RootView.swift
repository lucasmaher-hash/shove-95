//
//  RootView.swift
//  shove95
//
//  Shell: tab switching + rollover triggers. Tab switching is INSTANT —
//  motion never accompanies appearance changes (design.md §8). The plain
//  button strip becomes the Win95 taskbar in Phase 3.
//

import SwiftUI
import Shove95Kit

struct RootView: View {
    @State private var selected: Bucket = .today
    @Environment(\.pixel) private var pixel
    @Environment(TaskStore.self) private var store

    var body: some View {
        VStack(spacing: 0) {
            TaskListView(bucket: selected)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            #if DEBUG
            HStack {
                Button("Seed debug data") { store.seedDebugData() }
                    .font(.caption)
                Spacer()
            }
            .padding(.horizontal)
            #endif

            // Placeholder tab strip — becomes the Win95 taskbar in Phase 3.
            HStack(spacing: 0) {
                ForEach(Bucket.line, id: \.self) { bucket in
                    Button {
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
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            // Fires at midnight, timezone changes, clock changes (PRD §2).
            store.runDayRolloverPassIfNeeded()
        }
    }
}
