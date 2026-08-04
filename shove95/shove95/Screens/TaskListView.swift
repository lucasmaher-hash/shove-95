//
//  TaskListView.swift
//  shove95
//
//  One tab's list: the contents of the Win95 list box, no row separators
//  (design.md §5). Order: active by sortOrder → completed (struck through) →
//  add row.
//
//  The sunken well itself lives in RootView, NOT here. It is window furniture:
//  when tabs slide, the frame must stay nailed down and only the contents may
//  travel through it. Wrapping each list in its own well made two bevelled
//  panels slide past each other, which reads as two windows, not one.
//
//  TASK-019 SPIKE DECISION (2026-08-04): ScrollView + LazyVStack, NOT List.
//  List's cell machinery consumes horizontal pans before row-level SwiftUI
//  gestures see them, which kills the app's core swipe (verified: the same
//  DragGesture fires outside List and never inside it). ScrollView passes them
//  through. Cost accepted: reorder is hand-rolled — see TaskRowView's header
//  for why that lands in this phase alongside the custom menu.
//

import SwiftUI
import Shove95Kit

struct TaskListView: View {
    let bucket: Bucket
    @Environment(\.pixel) private var pixel
    @Environment(TaskStore.self) private var store

    var body: some View {
        let (active, completed) = store.tasks(in: bucket)

        ScrollView {
            LazyVStack(spacing: 0) {
                if active.isEmpty && completed.isEmpty {
                    Text("(empty)")
                        .font(W95Font.standard(pixel))
                        .foregroundStyle(Win95.shadow)
                        .frame(maxWidth: .infinity, minHeight: Win95.rowHeight(pixel) * 2)
                }

                ForEach(active, id: \.id) { task in
                    TaskRowView(task: task)
                }

                if !completed.isEmpty {
                    Color.clear.frame(height: Win95.Px.grid * 2 * pixel)
                    ForEach(completed, id: \.id) { task in
                        TaskRowView(task: task)
                    }
                }

                AddRowView(bucket: bucket)
            }
            .padding(.horizontal, Win95.Px.grid * pixel)
            .padding(.vertical, Win95.Px.grid * pixel)
        }
        .scrollDismissesKeyboard(.interactively)
    }
}
