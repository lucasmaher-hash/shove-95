//
//  ArchiveView.swift
//  shove95
//
//  TASK-053. Where completed tasks go once their day is over (locked Q11:
//  "once the day is over they move into an archive that lives in the settings
//  screen").
//
//  Read-only by design. The archive is a record of what happened, not a second
//  inbox — no editing, no un-completing, no swiping. The one action is Delete,
//  because a record you can't discard is a hoard.
//

import SwiftUI
import Shove95Kit

struct ArchiveView: View {
    @Environment(\.pixel) private var pixel
    @Environment(TaskStore.self) private var store
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            TitleBar(title: "Archive - shove.95", isClose: true, onSettings: onClose)

            SunkenWell {
                let days = store.archivedTasksByDay()
                ScrollView {
                    if days.isEmpty {
                        Text("(empty)")
                            .font(W95Font.standard(pixel))
                            .foregroundStyle(Win95.textMuted)
                            .frame(maxWidth: .infinity, minHeight: Win95.rowHeight(pixel) * 3)
                    } else {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(days, id: \.day) { group in
                                dayHeader(group.day)
                                ForEach(group.tasks, id: \.id) { task in
                                    row(task)
                                }
                            }
                        }
                        .padding(.horizontal, Win95.Px.grid * pixel)
                        .padding(.vertical, Win95.Px.grid * pixel)
                    }
                }
                .scrollBounceBehavior(.always, axes: .vertical)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Win95.surface)
        // In from the left edge, or down from the title bar — the same two
        // ways out the skeu sheets take. See SwipeToDismiss.
        .swipeToDismiss(headerHeight: Win95.Px.titleBar * pixel,
                        // CLEAR, not a colour. The skeu sheets get away with
                        // their canvas because the screen behind them is that
                        // same canvas; a Win95 home screen is a title bar, a
                        // well and a taskbar, and no single tone stands in for
                        // it (founder bug report 2026-08-17). Asking the
                        // presentation itself to be transparent shows the real
                        // screen instead of guessing at it.
                        backdrop: .clear, onClose)
        .presentationBackground(.clear)
        .ignoresSafeArea(.container, edges: .bottom)
    }

    /// Newest day first; the day itself is the only grouping (PRD § Archive).
    private func dayHeader(_ day: Date) -> some View {
        Text(day.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
            .font(W95Font.small(pixel))
            .foregroundStyle(Win95.text)
            .padding(.horizontal, Win95.Px.grid * pixel)
            .frame(maxWidth: .infinity, minHeight: Win95.Px.statusBar * 2 * pixel,
                   alignment: .leading)
            .background(Win95.statusBG)
            .padding(.top, Win95.Px.grid * pixel)
    }

    private func row(_ task: TaskItem) -> some View {
        HStack(spacing: Win95.Px.grid * pixel) {
            // Struck through and grey, exactly as it looked the moment it left
            // the list — no live checkbox, because nothing here is actionable.
            Text(task.title)
                .font(W95Font.standard(pixel))
                .strikethrough()
                .foregroundStyle(Win95.textMuted)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            Win95Button(action: { store.delete(task) }, compact: true) {
                Text("Delete")
                    .font(W95Font.small(pixel))
                    .foregroundStyle(Win95.important)
            }
            .fixedSize()
            .accessibilityLabel("Delete \(task.title) from the archive")
        }
        .padding(.horizontal, Win95.Px.grid * pixel)
        .frame(minHeight: Win95.rowHeight(pixel))
    }
}
