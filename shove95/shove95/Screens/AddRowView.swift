//
//  AddRowView.swift
//  shove95
//
//  Permanent inline capture row (PRD FR-006, locked Q15-A). Return commits
//  and dismisses the keyboard. A ✚ to the right attaches a photo to the task
//  being written, so a photo doesn't have to wait for a second pass.
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

    // Photo attached during capture: the task is created first, then the
    // picker targets it (TASK-044).
    @State private var showPhotoPicker = false
    @State private var showCamera = false
    @State private var showSourceChoice = false
    @State private var pickedItem: PhotosPickerItem?
    @State private var photoTarget: TaskItem?

    /// Return commits instead of adding a line — see TaskRowView for why this
    /// has to be intercepted in the binding rather than in `onChange`.
    private var returnCommitting: Binding<String> {
        Binding(
            get: { text },
            set: { new in
                guard new.contains("\n") else { text = new; return }
                guard !committing else { return } // second call for one Return
                committing = true
                let title = new.replacingOccurrences(of: "\n", with: "")
                text = ""
                // Deferred: a store write and a focus change from inside a
                // binding setter both land mid-update, where SwiftUI drops them.
                Task { @MainActor in
                    store.addTask(title: title, in: bucket) // empty → no-op
                    // Keyboard DISMISSES on commit (2026-08-04): a field that
                    // stays open reads as "still typing" and hides the list
                    // you just added to.
                    focused = false
                    committing = false
                }
            }
        )
    }

    var body: some View {
        // Field and ✚ share ONE sunken frame, so the row reads as a single
        // input with a control in it rather than a box plus a floating glyph.
        // The placeholder is bare "new task": the ✚ is now the add affordance,
        // and a second plus in the text was saying it twice.
        HStack(spacing: 0) {
            // Vertical axis: a long entry wraps and the field grows a line at a
            // time instead of scrolling the text out of sight. That growth is
            // the ONLY way a line is added — Return is a commit, never a break.
            TextField("new task", text: returnCommitting, axis: .vertical)
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
                .padding(.horizontal, Win95.Px.grid * pixel)

            // Same bare theme-coloured glyph as an existing task's ✚. Dimmed
            // and inert until there's something to attach it to.
            PlusGlyph()
                .fill(Win95.accent)
                .frame(width: Win95.Px.checkbox * pixel, height: Win95.Px.checkbox * pixel)
                .frame(width: Win95.rowHeight(pixel), height: Win95.rowHeight(pixel))
                .opacity(canAttach ? 1 : 0.3)
                .contentShape(Rectangle())
                .onTapGesture { attachPhoto() }
                .disabled(!canAttach)
                .accessibilityLabel("Add photo to new task")
        }
        .frame(minHeight: Win95.rowHeight(pixel))
        .background(Win95.well)
        .bevelSunken(pixel)
        .background {
            GeometryReader { proxy in
                Color.clear
                    .onChange(of: proxy.frame(in: .global)) { _, new in frame = new }
                    .task { frame = proxy.frame(in: .global) }
            }
        }
        .padding(.top, Win95.Px.grid * pixel)
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
}
