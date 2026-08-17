//
//  LiveSectionView.swift
//  shove95
//
//  The Live tab in the Win95 look. Same screen as `SkeuLiveSection`, drawn in
//  this look's parts: a sunken well holding one line, and two buttons under it.
//
//  The two looks have to agree on what a control DOES; only how it is drawn
//  differs (C4). So: typing puts the note straight on the Lock Screen, the
//  switch controls only whether it still shows there, the bin deletes, and
//  there is no tick — that lives on the Lock Screen, which is the point.
//

import SwiftUI
import Shove95Kit

struct LiveSectionView: View {
    @Environment(\.pixel) private var pixel
    @Environment(\.win95Scheme) private var scheme
    /// Read so a face change re-renders this view — see `\.appFace`.
    @Environment(\.appFace) private var face
    @Environment(AppSettings.self) private var settings
    @Environment(TaskStore.self) private var store

    @State private var draft = ""
    @State private var pendingDelete = false
    @FocusState private var focused: Bool

    private var note: TaskItem? { store.liveNote() }

    var body: some View {
        VStack(spacing: Win95.Px.grid * 4 * pixel) {
            Spacer(minLength: 0)
            box
            // Directly under the box — see SkeuLiveSection.
            controls
            Spacer(minLength: 0)
        }
        .padding(Win95.Px.grid * 4 * pixel)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // A downward drag puts the keyboard away — see SkeuLiveSection.
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 24)
                .onEnded { value in
                    if value.translation.height > 40 { focused = false }
                }
        )
        .overlay {
            if pendingDelete {
                Win95PinReplaceDialog(
                    outgoing: note?.title ?? "",
                    title: "Delete this",
                    message: "It goes for good, and it stops showing on the Lock Screen.",
                    confirmLabel: "Delete",
                    destructive: true
                ) {
                    pendingDelete = false
                    store.clearLiveNote()
                } onCancel: {
                    pendingDelete = false
                }
            }
        }
    }

    // MARK: The box

    private var box: some View {
        TextField("What are you doing?", text: $draft, axis: .vertical)
            .font(W95Font.standard(pixel))
            .foregroundStyle(Win95.text)
            .multilineTextAlignment(.center)
            .focused($focused)
            // Return CLOSES the field, having written what is in it — see
            // SkeuLiveSection for why the box is always open.
            .submitLabel(.done)
            .onSubmit { commit(); focused = false }
            // RETURN, caught by hand — see SkeuLiveSection.
            .onChange(of: draft) { _, new in
                guard new.contains("\n") else { return }
                draft = new.replacingOccurrences(of: "\n", with: " ")
                    .trimmingCharacters(in: .whitespaces)
                commit()
                focused = false
            }
            .onChange(of: focused) { _, isFocused in
                if !isFocused { commit() }
            }
            .task(id: note?.id) { if !focused { draft = note?.title ?? "" } }
            .onChange(of: note?.title) { _, new in
                if !focused { draft = new ?? "" }
            }
        .frame(maxWidth: .infinity)
        .padding(Win95.Px.grid * 3 * pixel)
        .frame(minHeight: Win95.Px.grid * 34 * pixel)
        .background(Win95.well)
        .bevelSunken(pixel)
        // The whole well is the field. The text line is one line in a box a
        // hundred points tall, and a tap on the empty ground under it did
        // nothing (founder direction 2026-08-17). The TextField still wins
        // taps on the text itself; this catches the rest of the box.
        .contentShape(Rectangle())
        .onTapGesture { focused = true }
    }

    // MARK: The controls

    @ViewBuilder
    private var controls: some View {
        HStack(spacing: Win95.Px.grid * 2 * pixel) {
            if let note {
                Win95Button(action: {
                    store.setLiveOnLockScreen(!note.isPinned)
                }) {
                    HStack(spacing: Win95.Px.grid * pixel) {
                        PixelLiveGlyph(pixel: pixel,
                                       tint: note.isPinned ? Win95.accent : Win95.textMuted)
                        TypedText(text: note.isPinned ? "Live" : "Off air",
                                  face: settings.face, role: .content)
                            .font(W95Font.standard(pixel))
                            .foregroundStyle(Win95.text)
                    }
                    // Mark and word together — see SkeuLiveSection. The bevel
                    // holds still; the button is not what is on air.
                    .skeuPulse(note.isPinned, dark: scheme.isDark)
                    // Off air, the CONTENTS recede. Inside the label, so the
                    // BEVEL keeps its full strength — a faded bevel reads as a
                    // disabled button, and this one is always pressable
                    // (founder direction 2026-08-17).
                    .opacity(note.isPinned ? 1 : 0.55)
                    .animation(.easeOut(duration: 0.2), value: note.isPinned)
                }

                // The BIN, not the word: a mark needs no button-width, and
                // this look already draws one on its photo viewer's title bar
                // (founder direction 2026-08-17).
                Win95Button(action: { pendingDelete = true }) {
                    BinGlyph()
                        .fill(Win95.important)
                        .frame(width: Win95.Px.checkbox * pixel,
                               height: Win95.Px.checkbox * pixel)
                }
            } else {
                Win95Button(action: {
                    if draft.isEmpty { focused = true } else { commit(); focused = false }
                }) {
                    HStack(spacing: Win95.Px.grid * pixel) {
                        PixelLiveGlyph(pixel: pixel, tint: Win95.text)
                        TypedText(text: draft.isEmpty ? "Go Live" : "Go",
                                  face: settings.face, role: .content)
                            .font(W95Font.standard(pixel))
                            .foregroundStyle(Win95.text)
                    }
                }
            }
        }
    }

    private func commit() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text != note?.title else { return }
        SkeuHaptic.success()
        store.writeLiveNote(text)
    }
}
