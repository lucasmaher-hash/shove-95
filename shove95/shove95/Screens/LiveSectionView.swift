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
    @State private var typing = false
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
        Group {
            if let note {
                TypedText(text: note.title, face: settings.face, role: .content)
                    .font(W95Font.standard(pixel))
                    .foregroundStyle(Win95.text)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            } else if typing {
                TextField("What are you doing?", text: $draft, axis: .vertical)
                    .font(W95Font.standard(pixel))
                    .foregroundStyle(Win95.text)
                    .multilineTextAlignment(.center)
                    .focused($focused)
                    .submitLabel(.done)
                    .onSubmit(commit)
            } else {
                // Empty on purpose — the Go Live button below is what opens
                // this, so a prompt sitting here would be a field you cannot
                // type in.
                Color.clear.frame(height: pixel)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(Win95.Px.grid * 3 * pixel)
        .frame(minHeight: Win95.Px.grid * 34 * pixel)
        .background(Win95.well)
        .bevelSunken(pixel)
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
                }

                Win95Button(action: { pendingDelete = true }) {
                    Text("Delete")
                        .font(W95Font.standard(pixel))
                        .foregroundStyle(Win95.important)
                }
            } else {
                Win95Button(action: {
                    if typing { commit() } else { typing = true; focused = true }
                }) {
                    HStack(spacing: Win95.Px.grid * pixel) {
                        PixelLiveGlyph(pixel: pixel, tint: Win95.text)
                        TypedText(text: typing ? "Go" : "Go Live",
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
        guard !text.isEmpty else {
            typing = false
            focused = false
            return
        }
        SkeuHaptic.success()
        store.setLiveNote(text)
        draft = ""
        typing = false
        focused = false
    }
}
