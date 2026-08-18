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
    /// The keyboard's own animation, kept from its last notification so the
    /// inset and the lift both travel on it.
    @State private var keyboardAnimation: Animation = .easeOut(duration: 0.25)
    /// How far this list's bottom edge sits above the screen's — measured,
    /// because the taskbar's height is not the same number. See KeyboardDock.
    @State private var bottomGap: CGFloat = 0

    /// A section's name, and the control that folds it shut.
    ///
    /// The accent rule that used to sit above each heading is gone: the band
    /// already says where one section ends and the next begins, and two
    /// devices for one boundary is one too many (founder direction
    /// 2026-08-17).
    private func sectionHeading(_ title: String, day: Date?) -> some View {
        let collapsed = settings.isCollapsed(day)

        return HStack(spacing: Win95.Px.grid * pixel) {
            TypedText(text: title, face: settings.face, role: .chrome)
                .font(W95Font.heading(pixel))
                .foregroundStyle(Win95.text)

            Spacer(minLength: 0)

            // The calendar's chevron, stood on end. Rotating a pixel shape by
            // EXACTLY 90° maps the grid onto itself, so both resting states
            // are still whole pixels; only the travel between them is off the
            // grid, and travel is what the founder asked to see.
            PixelChevron(pointsLeft: false)
                .fill(Win95.text)
                .frame(width: Win95.Px.checkbox * pixel * 0.7,
                       height: Win95.Px.checkbox * pixel * 0.7)
                .rotationEffect(.degrees(collapsed ? 0 : 90))
                .animation(.spring(duration: 0.28), value: collapsed)
        }
        // The WINDOW margin, so the heading's text starts exactly where the
        // checkboxes do. It stood at four grid units, which put "General" on
        // no line anything else in the window used (founder bug report
        // 2026-08-17, second report — the first fix aligned the chrome and
        // then this band arrived carrying its own number).
        .padding(.horizontal, Win95.Px.windowMargin * pixel)
        .padding(.vertical, Win95.Px.grid * pixel)
        .frame(minHeight: Win95.rowHeight(pixel))
        // A band, so a heading is not just larger text but a different KIND of
        // thing from the rows under it. The window's surface against the
        // list's well: the two tones the look already owns.
        //
        // The fill sits INSIDE the negative padding below, and the order is
        // load-bearing: a negative pad widens what it WRAPS but reports the
        // original width outward, so a background attached after it fills
        // only the reported frame. Attached the other way round, the band
        // stopped at the margin while claiming in a comment to reach the
        // screen edge (founder bug report 2026-08-17).
        .background(Win95.surface)
        .contentShape(Rectangle())
        .onTapGesture {
            SkeuHaptic.selection()
            withAnimation(.spring(duration: 0.3)) { settings.toggleCollapsed(day) }
        }
        // Out to the screen edge: gives back the list's inset so the band
        // runs the full well. A band that stops where the rows stop reads as
        // one more row rather than as the break between two sections.
        .padding(.horizontal, -(Win95.Px.windowMargin * pixel))
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("\(title), \(collapsed ? "collapsed" : "expanded")")
        .padding(.top, Win95.Px.grid * 3 * pixel)
        // A gap under the band. An edited row paints its own highlight, and
        // butted straight against the heading's the two read as one block
        // (founder bug report 2026-08-17).
        .padding(.bottom, Win95.Px.grid * pixel)
    }

    /// One scheduled day's name.
    private func dayHeading(_ day: Date) -> some View {
        sectionHeading(DayHeading.label(for: day, calendar: .current), day: day)
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
                    sectionHeading("General", day: nil)
                    if !settings.isCollapsed(nil) {
                        ForEach(sections.undated, id: \.id) { task in
                            TaskRowView(task: task)
                                .id(task.id.uuidString)
                        }
                    }
                    // Every section ends in its own add row, which stamps that
                    // section's date on what it creates (founder direction
                    // 2026-08-17). One row at the foot of the list could only
                    // ever add to one section, so typing under a day and
                    // watching the task appear in General was the app
                    // disagreeing with its own layout. Soon therefore has NO
                    // trailing add row — the last day's is the bottom one.
                    //
                    // The add row folds away with its section: a section shut
                    // is a section with nothing showing, and a stray capture
                    // row under a closed heading belongs to nothing visible.
                    if !settings.isCollapsed(nil) {
                        AddRowView(bucket: bucket, day: nil)
                            .id(EditingCoordinator.addRowID(for: nil))
                            // Soon's capture row answers to the walkthrough
                            // too. Only the flat tabs were tagged, so stepping
                            // over to Soon during step one left the caption
                            // saying "type here" over a dimmed screen with
                            // nothing cut out of it (code review 2026-08-17).
                            // General's is the one that stands in: it is the
                            // section a task lands in when no day is chosen.
                            .onboardingTarget(settings.hasOnboarded ? nil : .addRow)
                    }
                    ForEach(sections.days, id: \.day) { section in
                        dayHeading(section.day)
                        if !settings.isCollapsed(section.day) {
                            ForEach(section.tasks, id: \.id) { task in
                                TaskRowView(task: task)
                                    .id(task.id.uuidString)
                            }
                            AddRowView(bucket: bucket, day: section.day)
                                .id(EditingCoordinator.addRowID(for: section.day))
                        }
                    }
                } else {
                    // `first?.id` rather than `enumerated()`: the latter
                    // materialised an N-element tuple array on every render of
                    // the app's hottest list, to answer "is this row the top
                    // one".
                    let firstID = active.first?.id
                    ForEach(active, id: \.id) { task in
                        TaskRowView(task: task)
                            .id(task.id.uuidString)
                            // The walkthrough points at the FIRST row, which is
                            // the one it just asked you to write — and only
                            // while there is a walkthrough to point with.
                            .onboardingTarget(
                                !settings.hasOnboarded && task.id == firstID ? .taskRow : nil)
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
                        .onboardingTarget(settings.hasOnboarded ? nil : .addRow)
                }
            }
            // The WINDOW margin — the same line the title bar and the taskbar
            // stand on. It was a bare grid unit, which held together only as
            // long as the margin happened to equal one.
            .padding(.horizontal, Win95.Px.windowMargin * pixel)
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
        .bottomGapToScreen($bottomGap)
        .scrollDismissesKeyboard(.interactively)
        .onReceive(NotificationCenter.default.publisher(
            for: UIResponder.keyboardWillChangeFrameNotification)) { note in
            guard let change = KeyboardDock.read(note, clearance: bottomGap) else { return }
            keyboardTop = change.top
            // Held so the lift below travels on the same curve — see
            // KeyboardDock for why the keyboard's own is the only right one.
            keyboardAnimation = change.animation
            withAnimation(change.animation) { keyboardOverlap = change.overlap }
        }
        .onChange(of: editing.focused) { _, _ in
            // The NEXT runloop turn, not a fixed beat. The inset is applied in
            // this same pass and a `scrollTo` run inline would aim at the
            // layout the list had before it — but the 80ms this used to wait
            // was long enough to read as a second, later movement chasing the
            // keyboard (founder bug report 2026-08-17).
            Task { @MainActor in liftFocusedFieldIfCovered(proxy) }
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
        withAnimation(keyboardAnimation) {
            proxy.scrollTo(id, anchor: .bottom)
        }
    }
}
