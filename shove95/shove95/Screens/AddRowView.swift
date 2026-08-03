//
//  AddRowView.swift
//  shove95
//
//  Permanent inline capture row (PRD FR-006, locked Q15-A). Return commits
//  and KEEPS focus so entering five tasks feels like writing a list, not
//  operating an app. Camera glyph slot arrives with photos in Phase 4.
//

import SwiftUI
import Shove95Kit

struct AddRowView: View {
    let bucket: Bucket
    @Environment(TaskStore.self) private var store

    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        TextField("+ new task", text: $text)
            .focused($focused)
            .submitLabel(.return)
            .onSubmit {
                store.addTask(title: text, in: bucket) // empty → no-op (store guards)
                text = ""
                // Re-assert focus on the next runloop tick — the keyboard
                // must never dismiss during rapid entry (US-007).
                Task { @MainActor in
                    focused = true
                }
            }
            .frame(minHeight: Win95.rowMinHeight)
    }
}
