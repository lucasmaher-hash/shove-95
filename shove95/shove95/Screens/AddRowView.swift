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
    @Environment(\.pixel) private var pixel

    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        TextField("+ new task", text: $text)
            .font(W95Font.standard(pixel))
            .foregroundStyle(Win95.text)
            .focused($focused)
            .submitLabel(.return)
            .onSubmit {
                store.addTask(title: text, in: bucket) // empty → no-op (store guards)
                text = ""
                // Keyboard DISMISSES on commit (changed 2026-08-04 on device
                // feedback, overriding the original keep-focus rider): a field
                // that stays open reads as "still typing" and hides the list
                // you just added to. Tap the row again to add another.
                focused = false
            }
            .padding(.horizontal, Win95.Px.grid * pixel)
            .frame(minHeight: Win95.rowHeight(pixel))
            .background(Win95.well)
            .bevelSunken(pixel)
            .padding(.top, Win95.Px.grid * pixel)
    }
}
