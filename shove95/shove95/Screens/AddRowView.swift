//
//  AddRowView.swift
//  shove95
//
//  Permanent inline capture row (PRD FR-006, locked Q15-A). Return commits
//  and dismisses the keyboard.
//

import SwiftUI
import Shove95Kit

struct AddRowView: View {
    let bucket: Bucket
    @Environment(TaskStore.self) private var store
    @Environment(\.pixel) private var pixel
    @Environment(EditingCoordinator.self) private var editing

    @State private var text = ""
    @State private var frame: CGRect = .zero
    @FocusState private var focused: Bool

    /// Return commits instead of adding a line — see TaskRowView for why this
    /// has to be intercepted in the binding rather than in `onChange`.
    private var returnCommitting: Binding<String> {
        Binding(
            get: { text },
            set: { new in
                guard new.contains("\n") else { text = new; return }
                let title = new.replacingOccurrences(of: "\n", with: "")
                text = ""
                // Deferred for the same reason as TaskRowView: a store write
                // and a focus change from inside a binding setter both land
                // mid-update, where SwiftUI drops them.
                Task { @MainActor in
                    store.addTask(title: title, in: bucket) // empty → no-op
                    // Keyboard DISMISSES on commit (2026-08-04): a field that
                    // stays open reads as "still typing" and hides the list
                    // you just added to.
                    focused = false
                }
            }
        )
    }

    var body: some View {
        // Vertical axis: a long entry wraps and the field grows a line at a
        // time instead of scrolling the text out of sight. That growth is the
        // ONLY way a line is added — Return is a commit, never a line break.
        TextField("+ new task", text: returnCommitting, axis: .vertical)
            .lineLimit(1...4)
            .font(W95Font.standard(pixel))
            .foregroundStyle(Win95.text)
            .focused($focused)
            .submitLabel(.done)
            .onChange(of: focused) { _, isFocused in
                if isFocused {
                    editing.begin(EditingCoordinator.addRowID, bottom: frame.maxY)
                } else {
                    editing.end(EditingCoordinator.addRowID)
                }
            }
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .onChange(of: proxy.frame(in: .global)) { _, new in frame = new }
                        .task { frame = proxy.frame(in: .global) }
                }
            }
            .padding(.horizontal, Win95.Px.grid * pixel)
            .frame(minHeight: Win95.rowHeight(pixel))
            .background(Win95.well)
            .bevelSunken(pixel)
            .padding(.top, Win95.Px.grid * pixel)
    }
}
