//
//  AddRowView.swift
//  shove95
//
//  Permanent inline capture row (PRD FR-006, locked Q15-A). Return commits
//  and dismisses the keyboard.
//
//  A PLAIN row, not a boxed input (founder direction 2026-08-14): it shares
//  the checkbox-then-text layout every task row uses, sits directly on the
//  well with no sunken frame of its own, and reads as the list's last row
//  rather than a separate control bolted underneath it. The photo ✚ only
//  appears once the field is focused — an idle row has nothing to attach a
//  photo TO yet, so showing the control earlier would invite a press that
//  does nothing.
//

import SwiftUI
import PhotosUI
import Shove95Kit

struct AddRowView: View {
    let bucket: Bucket
    @Environment(TaskStore.self) private var store
    @Environment(\.pixel) private var pixel
    @Environment(EditingCoordinator.self) private var editing

    @State private var text = ""
    @State private var frame: CGRect = .zero
    @FocusState private var focused: Bool

    /// Guards against a double insert. SwiftUI can hand the binding the same
    /// newline-bearing value more than once for a single Return — the text
    /// view still holds the newline when the second call arrives — and each
    /// call was creating its own task (founder bug report 2026-08-04).
    @State private var committing = false
    /// Held until commit, like `pendingPhotos` on the skeu add row: there is
    /// nothing to pin until the task exists, and committing early would
    /// dismiss the keyboard out from under someone still typing.

    // Photo attached during capture: the task is created first, then the
    // picker targets it (TASK-044).
    @State private var showPhotoPicker = false
    @State private var showCamera = false
    @State private var showSourceChoice = false
    @State private var pickedItem: PhotosPickerItem?
    @State private var photoTarget: TaskItem?

    /// Return commits instead of adding a line.
    ///
    /// A vertical-axis TextField can answer the Return key TWO ways, and which
    /// one you get is not stable across iOS versions: it either inserts a "\n"
    /// into the binding, or it fires `onSubmit` and inserts nothing. Both paths
    /// are wired to `commit()` — intercepting only the newline is what made the
    /// row appear dead on device while working in the simulator, because
    /// synthetic text injection writes the "\n" as a character whereas a real
    /// keyboard sends a submit (founder bug report, unreproducible until the
    /// two input paths were separated).
    ///
    /// `commit()` guards against running twice, so a build where BOTH fire is
    /// harmless.
    ///
    /// The title travels as an ARGUMENT, never by reading `text` back. The
    /// field's own buffer outlives this setter: after the commit clears
    /// `text`, UIKit writes its copy of the string back through this same
    /// binding, with no newline in it, and the branch below would happily
    /// restore the draft the commit had just cleared. That left the typed
    /// string sitting in the add row afterwards, where it draws as an
    /// ordinary task in every tab (audit round 5).
    private var returnCommitting: Binding<String> {
        Binding(
            get: { text },
            set: { new in
                guard new.contains("\n") else { text = new; return }
                commit(title: new.replacingOccurrences(of: "\n", with: ""))
            }
        )
    }

    /// Creates the task and clears the row. Safe to call from a binding setter:
    /// the store write and the focus change are deferred a runloop turn, since
    /// both land mid-update otherwise and SwiftUI drops them.
    private func commit(title raw: String) {
        guard !committing else { return } // second call for one Return
        let title = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            // Nothing typed — Return just closes the row rather than sitting
            // there looking broken.
            text = ""
            Task { @MainActor in focused = false }
            return
        }
        committing = true
        text = ""
        Task { @MainActor in
            let task = store.addTask(title: title, in: bucket)
            // The pin is applied AFTER the task exists, and through the
            // coordinator rather than the store, so composing a task while
            // another one holds the pin still asks before replacing it.
            // Keyboard DISMISSES on commit (2026-08-04): a field that stays
            // open reads as "still typing" and hides the list you just added to.
            focused = false
            // Cleared a SECOND time, deliberately: by now UIKit has had its
            // runloop turn to write its own buffer back through the binding.
            // Focus is already gone, so there is nothing a user could have
            // typed in between for this to swallow.
            text = ""
            committing = false
        }
    }

    var body: some View {
        // .top: matches every task row, so the add row lines up with them
        // even though it never wraps to a second line.
        HStack(alignment: .top, spacing: Win95.Px.grid * pixel) {
            // The same sunken box a task's checkbox uses, but permanently
            // empty and inert — there is no task yet to check off. Tapping it
            // focuses the field, exactly like tapping the row text would.
            Rectangle()
                .fill(Win95.well)
                .frame(width: Win95.Px.checkbox * pixel, height: Win95.Px.checkbox * pixel)
                .bevelSunken(pixel)
                .frame(width: Win95.rowHeight(pixel), height: Win95.rowHeight(pixel))
                .contentShape(Rectangle())
                .onTapGesture { focused = true }
                .accessibilityHidden(true)

            // Vertical axis: a long entry wraps and the field grows a line at
            // a time instead of scrolling the text out of sight. That growth
            // is the ONLY way a line is added — Return is a commit, never a
            // break. No background, no bevel: the row sits directly on the
            // well like any other.
            TextField("add", text: returnCommitting, axis: .vertical)
                .lineLimit(1...4)
                .font(W95Font.standard(pixel))
                .foregroundStyle(Win95.text)
                .focused($focused)
                .submitLabel(.done)
                // The other half of the Return story — see `returnCommitting`.
                .onSubmit { commit(title: text) }
                .onChange(of: focused) { _, isFocused in
                    if isFocused {
                        editing.begin(EditingCoordinator.addRowID, bottom: frame.maxY)
                    } else {
                        editing.end(EditingCoordinator.addRowID)
                    }
                }
                .padding(.vertical, firstLineInset)
                .frame(maxWidth: .infinity, alignment: .leading)

            // NO pin here. A task becomes live by being typed into the Live
            // section, and that is the only door (founder direction
            // 2026-08-17).

            // Same bare theme-coloured glyph an existing task's photo control
            // uses — appears only while composing, matching the skeu row.
            if focused {
                PlusGlyph()
                    .fill(Win95.accent)
                    .frame(width: Win95.Px.checkbox * pixel, height: Win95.Px.checkbox * pixel)
                    .frame(width: Win95.rowHeight(pixel), height: Win95.rowHeight(pixel))
                    .opacity(canAttach ? 1 : 0.3)
                    .contentShape(Rectangle())
                    .onTapGesture { SkeuHaptic.press(); attachPhoto() }
                    .disabled(!canAttach)
                    .accessibilityLabel("Add photo to new task")
            }
        }
        .padding(.trailing, Win95.Px.grid * pixel)
        .frame(minHeight: Win95.rowHeight(pixel))
        .background {
            GeometryReader { proxy in
                Color.clear
                    .onChange(of: proxy.frame(in: .global)) { _, new in frame = new }
                    .task { frame = proxy.frame(in: .global) }
            }
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $pickedItem, matching: .images)
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { data in
                showCamera = false
                guard let data, let target = photoTarget else { return }
                store.addPhoto(target, data: ImageImport.prepare(data))
                photoTarget = nil
            }
            .ignoresSafeArea()
        }
        .confirmationDialog("Add photo", isPresented: $showSourceChoice) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Camera") { showCamera = true }
            }
            Button("Photo Library") { showPhotoPicker = true }
            Button("Cancel", role: .cancel) { photoTarget = nil }
        }
        .onChange(of: pickedItem) { _, item in
            guard let item, let target = photoTarget else { return }
            Task { @MainActor in
                if let data = try? await item.loadTransferable(type: Data.self) {
                    store.addPhoto(target, data: ImageImport.prepare(data))
                }
                pickedItem = nil
                photoTarget = nil
            }
        }
    }

    private var canAttach: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// The task has to exist before a photo can hang off it, so the ✚ commits
    /// what you've typed and then opens the picker against that new task —
    /// the row clears exactly as if you'd pressed Return.
    private func attachPhoto() {
        guard let task = store.addTask(title: text, in: bucket) else { return }
        text = ""
        focused = false
        photoTarget = task
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            showSourceChoice = true
        } else {
            showPhotoPicker = true
        }
    }

    /// Half the slack between one text line and the 44pt row band — the same
    /// measurement TaskRowView uses, so the add row's text sits on the same
    /// baseline as every task above it.
    private var firstLineInset: CGFloat {
        let lineHeight = UIFont(name: W95Font.postScriptName,
                                size: Win95.Px.fontStandard * pixel)?.lineHeight
            ?? Win95.Px.fontStandard * pixel * 1.2
        return max(0, (Win95.rowHeight(pixel) - lineHeight) / 2)
    }
}
