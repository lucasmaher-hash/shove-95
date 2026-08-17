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
//  through.
//

import SwiftUI
import Shove95Kit

struct TaskListView: View {
    let bucket: Bucket
    @Environment(\.pixel) private var pixel
    @Environment(TaskStore.self) private var store
    @Environment(EditingCoordinator.self) private var editing
    /// Read so a day heading takes the pixel face under Blend — a heading is
    /// the app labelling its own list, which is chrome. See TextRole.
    @Environment(AppSettings.self) private var settings

    /// How much of the well the keyboard is covering, in points.
    @State private var keyboardOverlap: CGFloat = 0
    /// The keyboard's top edge in global coordinates; .infinity when hidden.
    @State private var keyboardTop: CGFloat = .infinity

    /// A section's name. A pixel label on the well, not a row: it is something
    /// to read, not something to act on.
    private func sectionHeading(_ title: String) -> some View {
        TypedText(text: title, face: settings.face, role: .chrome)
            .font(W95Font.small(pixel))
            .foregroundStyle(Win95.textMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, Win95.Px.grid * 3 * pixel)
            .padding(.bottom, Win95.Px.grid * pixel)
            .padding(.horizontal, Win95.Px.grid * 2 * pixel)
    }

    /// One scheduled day's name.
    private func dayHeading(_ day: Date) -> some View {
        sectionHeading(DayHeading.label(for: day, calendar: .current))
    }

    var body: some View {
        let (active, completed) = store.tasks(in: bucket)

        // ScrollViewReader so a field that opens under the keyboard can be
        // brought up to sit just above it (founder request 2026-08-04). A row
        // already clear of the keyboard is left exactly where it is.
        ScrollViewReader { proxy in
        ScrollView {
            LazyVStack(spacing: 0) {
                // No empty-state text: the add row's own "add" placeholder
                // already says the list is empty and where to start — a
                // second "(empty)" line above it was saying the same thing
                // twice (founder direction 2026-08-14).
                //
                // Soon is the one tab with structure inside it: the undated
                // block, then a heading per scheduled day (founder direction
                // 2026-08-17). The others are one flat run.
                if bucket == .general {
                    let sections = store.soonSections()
                    // The undated block carries its own heading. It was left
                    // bare originally, on the reasoning that the tab name
                    // already said what it was — but once dated days sit below
                    // it, an unlabelled run reads as a preamble to the first
                    // day rather than as a section of its own. The founder
                    // reversed that decision (founder direction 2026-08-17).
                    // Shown even when empty: the section still has its add row.
                    sectionHeading("General")
                    ForEach(sections.undated, id: \.id) { task in
                        TaskRowView(task: task)
                            .id(task.id.uuidString)
                    }
                    // Every section ends in its own add row, which stamps that
                    // section's date on what it creates (founder direction
                    // 2026-08-17). One row at the foot of the list could only
                    // ever add to one section, so typing under a day and
                    // watching the task appear in General was the app
                    // disagreeing with its own layout. Soon therefore has NO
                    // trailing add row — the last day's is the bottom one.
                    AddRowView(bucket: bucket, day: nil)
                        .id(EditingCoordinator.addRowID(for: nil))
                    ForEach(sections.days, id: \.day) { section in
                        dayHeading(section.day)
                        ForEach(section.tasks, id: \.id) { task in
                            TaskRowView(task: task)
                                .id(task.id.uuidString)
                        }
                        AddRowView(bucket: bucket, day: section.day)
                            .id(EditingCoordinator.addRowID(for: section.day))
                    }
                } else {
                    ForEach(active, id: \.id) { task in
                        TaskRowView(task: task)
                            .id(task.id.uuidString)
                    }
                }

                if !completed.isEmpty {
                    Color.clear.frame(height: Win95.Px.grid * 2 * pixel)
                    ForEach(completed, id: \.id) { task in
                        TaskRowView(task: task)
                    }
                }

                if bucket != .general {
                    AddRowView(bucket: bucket)
                        .id(EditingCoordinator.addRowID)
                }
            }
            .padding(.horizontal, Win95.Px.grid * pixel)
            .padding(.vertical, Win95.Px.grid * pixel)
        }
        // Follow the add row down as the list grows. Committing a task inserts
        // it exactly where the add row was standing, which pushes the add row
        // below the fold — the task lands, the keyboard drops, and there is
        // suddenly nowhere to type the next one (founder bug report
        // 2026-08-14). Keyed on the count rather than `store.revision` so that
        // ticking, renaming or moving a task doesn't yank the list downward.
        .onChange(of: active.count + completed.count) { old, new in
            guard new > old else { return } // only on ADD, never on delete
            // Follow the row that was TYPED INTO, not the one at the bottom:
            // with an add row per section, the two are usually different.
            let target = editing.lastAddRowID ?? EditingCoordinator.addRowID
            withAnimation(.easeOut(duration: 0.25)) {
                proxy.scrollTo(target, anchor: .bottom)
            }
        }
        // The list keeps its own bottom inset so the keyboard has somewhere to
        // sit; RootView's `.ignoresSafeArea(.keyboard)` keeps the TASKBAR
        // docked, and that same modifier is why the automatic field-avoidance
        // never fired here — the inset and the scroll below replace it.
        .contentMargins(.bottom, keyboardOverlap, for: .scrollContent)
        .scrollDismissesKeyboard(.interactively)
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
