//
//  TaskRowView.swift
//  shove95
//
//  Phase-1 functional row: checkbox, title (tap = inline edit, PRD FR-007),
//  overdue chip, completed strikethrough. Deliberately stock-looking — the
//  Win95 treatment lands in Phase 3.
//

import SwiftUI
import Shove95Kit

struct TaskRowView: View {
    let task: TaskItem
    @Environment(TaskStore.self) private var store

    @State private var isEditing = false
    @State private var draft = ""
    @FocusState private var editFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Checkbox placeholder (Win95Checkbox arrives in Phase 3).
            Button {
                store.toggleCompleted(task)
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.square.fill" : "square")
                    .foregroundStyle(task.isCompleted ? Color.gray : Color.primary)
            }
            .buttonStyle(.plain)
            .frame(minWidth: 32, minHeight: Win95.rowMinHeight)

            if isEditing {
                TextField("", text: $draft)
                    .focused($editFocused)
                    .onSubmit { commitEdit() }
                    .onChange(of: editFocused) { _, focused in
                        if !focused { commitEdit() }
                    }
            } else {
                Text(task.title)
                    .strikethrough(task.isCompleted)
                    .foregroundStyle(task.isCompleted ? Color.gray : (task.isImportant ? Win95.important : Color.primary))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard !task.isCompleted else { return }
                        draft = task.title
                        isEditing = true
                        editFocused = true
                    }
            }

            Spacer(minLength: 8)

            // Trailing chip column — fixed width so chips align (locked Q23).
            if let chip = ChipFormat.label(dueDate: task.dueDate, isCompleted: task.isCompleted,
                                           now: store.now(), calendar: store.calendar) {
                Text(chip)
                    .foregroundStyle(Color.gray)
                    .monospacedDigit()
                    .frame(width: 44, alignment: .trailing)
            }
        }
        .frame(minHeight: Win95.rowMinHeight)
    }

    private func commitEdit() {
        guard isEditing else { return }
        isEditing = false
        store.editTitle(task, to: draft) // empty draft → store reverts (no-op)
    }
}
