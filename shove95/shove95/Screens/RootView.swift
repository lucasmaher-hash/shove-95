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
                Button("Seed fillers") { store.seedScrollFillers() }
                Button("Defer 1st") {  // TEMP: headless undo verification
                    if let first = store.tasks(in: .today).active.first {
                        store.step(first, direction: .deferOne)
                    }
                }
                Spacer()
                Text(GestureDebug.shared.last).foregroundStyle(.purple)
            }
            .font(.caption)
            .padding(.horizontal)
            #endif

            // Status bar (FR-009, TASK-024): persistent record of the last
            // move/delete with Undo — plain for now, Win95 sunken panel in
            // Phase 3. Always present (window furniture), empty when idle.
            HStack(spacing: 8) {
                Text(store.lastAction?.statusText ?? "")
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                if store.lastAction != nil {
                    Button("Undo") {
                        withAnimation(.spring(duration: 0.25)) {
                            store.undoLastAction()
                        }
                    }
                }
            }
            .font(.footnote)
            .padding(.horizontal, 12)
            .frame(minHeight: 24)
            .background(Color(white: 0.93))

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
