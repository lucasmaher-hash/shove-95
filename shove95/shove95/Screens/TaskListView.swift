//
//  TaskListView.swift
//  shove95
//
//  One tab's list (PRD § UI/UX > Screen: Main). Rendering order: active by
//  sortOrder → completed (struck through) by completion time → add row.
//  Stock List for now — the Phase-2 spike (TASK-019) decides whether it
//  survives the gesture requirements; Phase 3 skins it.
//

import SwiftUI
import Shove95Kit

struct TaskListView: View {
    let bucket: Bucket
    @Environment(TaskStore.self) private var store

    var body: some View {
        let (active, completed) = store.tasks(in: bucket)

        List {
            if active.isEmpty && completed.isEmpty {
                Text("(empty)")
                    .foregroundStyle(Color.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowSeparator(.hidden)
            }

            ForEach(active, id: \.id) { task in
                TaskRowView(task: task)
            }

            if !completed.isEmpty {
                Section {
                    ForEach(completed, id: \.id) { task in
                        TaskRowView(task: task)
                    }
                }
            }

            Section {
                AddRowView(bucket: bucket)
            }
        }
        .listStyle(.plain)
    }
}
