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
    @Environment(ReorderCoordinator.self) private var reorder
    @Environment(EditingCoordinator.self) private var editing

    /// How much of the well the keyboard is covering, in points.
    @State private var keyboardOverlap: CGFloat = 0
    /// The keyboard's top edge in global coordinates; .infinity when hidden.
    @State private var keyboardTop: CGFloat = .infinity

    var body: some View {
        let (active, completed) = store.tasks(in: bucket)

        // ScrollViewReader so a field that opens under the keyboard can be
        // brought up to sit just above it (founder request 2026-08-04). A row
        // already clear of the keyboard is left exactly where it is.
        ScrollViewReader { proxy in
        ScrollView {
            LazyVStack(spacing: 0) {
                if active.isEmpty && completed.isEmpty {
                    Text("(empty)")
                        .font(W95Font.standard(pixel))
                        .foregroundStyle(Win95.shadow)
                        .frame(maxWidth: .infinity, minHeight: Win95.rowHeight(pixel) * 2)
                }

                ForEach(Array(active.enumerated()), id: \.element.id) { index, task in
                    TaskRowView(task: task, index: index)
                        .id(task.id.uuidString)
                        // Applied HERE, not inside the row: zIndex only orders
                        // a stack's own children, so from inside the row it was
                        // ignored and a downward drag slid under its neighbours.
                        .zIndex(reorder.isDragging(task.id) ? 1 : 0)
                        .offset(y: reorder.isDragging(task.id) ? 0
                                : reorder.displacement(for: index,
                                                       rowHeight: Win95.rowHeight(pixel)))
                }
                // Rows part around the lifted one as it travels.
                .animation(.spring(duration: 0.22), value: reorder.steps)

                if !completed.isEmpty {
                    Color.clear.frame(height: Win95.Px.grid * 2 * pixel)
                    ForEach(completed, id: \.id) { task in
                        TaskRowView(task: task, index: nil) // completed rows don't reorder
                    }
                }

                AddRowView(bucket: bucket)
            }
            .padding(.horizontal, Win95.Px.grid * pixel)
            .padding(.vertical, Win95.Px.grid * pixel)
        }
        // The list keeps its own bottom inset so the keyboard has somewhere to
        // sit; RootView's `.ignoresSafeArea(.keyboard)` keeps the TASKBAR
        // docked, and that same modifier is why the automatic field-avoidance
        // never fired here — the inset and the scroll below replace it.
        .contentMargins(.bottom, keyboardOverlap, for: .scrollContent)
        .scrollDismissesKeyboard(.interactively)
        // A row that has just been long-pressed owns the vertical axis; without
        // this the scroll view swallows the pan and the reorder never starts.
        .scrollDisabled(reorder.isArmed)
        .onReceive(NotificationCenter.default.publisher(
            for: UIResponder.keyboardWillChangeFrameNotification)) { note in
            guard let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey]
                as? CGRect else { return }
            let screenHeight = (note.object as? UIScreen)?.bounds.height
                ?? UIApplication.shared.connectedScenes
                    .compactMap { ($0 as? UIWindowScene)?.screen.bounds.height }
                    .first ?? frame.maxY
            // What the keyboard covers, minus the chrome already parked down
            // there: only the part that eats into the list matters.
            let covered = max(0, screenHeight - frame.origin.y)
            let chrome = Win95.Px.taskbar * pixel + Win95.Px.grid * 4 * pixel
            keyboardTop = covered > 0 ? frame.origin.y : .infinity
            withAnimation(.easeOut(duration: 0.25)) {
                keyboardOverlap = max(0, covered - chrome)
            }
        }
        .onChange(of: editing.focused) { _, _ in
            // A beat for the inset to land, then lift the field if it needs it.
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(80))
                liftFocusedFieldIfCovered(proxy)
            }
        }
        .onChange(of: keyboardTop) { _, _ in liftFocusedFieldIfCovered(proxy) }
        // Bounce at both ends even when the list is shorter than the well —
        // the give at the limit is what tells you the list ended (founder
        // request 2026-08-04).
        .scrollBounceBehavior(.always, axes: .vertical)
        } // ScrollViewReader
    }

    /// Docks the focused field just above the keyboard — but ONLY if the
    /// keyboard is actually covering it. A field already in the clear stays
    /// exactly where it is (founder spec 2026-08-04); yanking it would be as
    /// disorienting as hiding it.
    private func liftFocusedFieldIfCovered(_ proxy: ScrollViewProxy) {
        guard let id = editing.focused, editing.focusedBottom > 0 else { return }
        let margin = Win95.Px.grid * 2 * pixel
        guard editing.focusedBottom + margin > keyboardTop else { return }
        withAnimation(.easeOut(duration: 0.25)) {
            proxy.scrollTo(id, anchor: .bottom)
        }
    }
}
