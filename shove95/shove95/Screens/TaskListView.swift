//
//  TaskListView.swift
//  shove95
//
//  One tab's list (PRD § UI/UX > Screen: Main). Rendering order: active by
//  sortOrder → completed (struck through) by completion time → add row.
//
//  TASK-019 SPIKE DECISION (2026-08-04): ScrollView + LazyVStack, NOT List.
//  List's cell infrastructure swallows horizontal pans before row-level
//  SwiftUI gestures see them (verified: the same DragGesture fires outside
//  List and never inside it), which kills the app's core swipe. ScrollView
//  passes them through. Costs accepted: hand-rolled long-press-drag reorder
//  (TASK-025) — and the Win95 skin (Phase 3) prefers a bare ScrollView anyway.
//

import SwiftUI
import Shove95Kit

struct TaskListView: View {
    let bucket: Bucket
    @Environment(TaskStore.self) private var store

    /// Reorder session state (TASK-025): id of the row being dragged.
    @State private var reorderingID: UUID?

    var body: some View {
        let (active, completed) = store.tasks(in: bucket)

        ScrollView {
            LazyVStack(spacing: 0) {
                if active.isEmpty && completed.isEmpty {
                    Text("(empty)")
                        .foregroundStyle(Color.gray)
                        .frame(maxWidth: .infinity, minHeight: Win95.rowMinHeight, alignment: .center)
                }

                ForEach(active, id: \.id) { task in
                    TaskRowView(task: task)
                    Divider()
                }

                if !completed.isEmpty {
                    Color.clear.frame(height: 16) // section gap
                    ForEach(completed, id: \.id) { task in
                        TaskRowView(task: task)
                        Divider()
                    }
                }

                AddRowView(bucket: bucket)
            }
            .padding(.horizontal, 16)
        }
        .scrollDismissesKeyboard(.interactively)
    }
}
