//
//  SkeuLiveSection.swift
//  shove95
//
//  The Live tab's own screen: one box, one line of text.
//
//  It is not a list (founder direction 2026-08-17). The other three tabs
//  divide the date line between them and each holds however many tasks fall in
//  its range; this holds exactly one thing, the thing you are doing, and it
//  shows it the size that deserves.
//
//  The live note lives HERE and in no tab — see `TaskItem.isLiveNote`. Typing
//  it puts it on the Lock Screen straight away, because that is the whole
//  point of typing it. The switch afterwards controls only whether it is still
//  showing there; the text stays in this box either way. The bin is what
//  deletes.
//
//  There is no tick. Finishing a live task is something you do from the Lock
//  Screen without opening the app — that is what makes it worth putting there
//  — and a second tick in here would be a second place to look.
//

import SwiftUI
import Shove95Kit

struct SkeuLiveSection: View {
    @Environment(\.skeu) private var skeu
    @Environment(\.skeuTextScale) private var textScale
    @Environment(\.skeuChromeScale) private var chromeScale
    @Environment(TaskStore.self) private var store

    /// What is being typed before it becomes the note. Empty when a note
    /// already exists — the box shows that instead.
    @State private var draft = ""
    @State private var typing = false
    @State private var pendingDelete = false
    @FocusState private var focused: Bool

    private var note: TaskItem? { store.liveNote() }
    private var textSize: CGFloat { 22 * textScale }
    private var buttonH: CGFloat { SkeuToggle.height * chromeScale
                                   - SkeuToggle.padV * chromeScale * 2 }

    var body: some View {
        VStack(spacing: SkeuSpace.lg) {
            Spacer(minLength: 0)
            box
            // Directly under the box, not pushed to the floor (founder
            // direction 2026-08-17). They act on what is IN the box, and a
            // control parked at the far end of the screen reads as belonging
            // to the screen instead.
            controls
            Spacer(minLength: 0)
        }
        .padding(.vertical, SkeuSpace.xl)
        .overlay {
            if pendingDelete {
                SkeuPinReplaceDialog(
                    outgoing: note?.title ?? "",
                    title: "Delete this",
                    message: "It goes for good, and it stops showing on the Lock Screen.",
                    confirmLabel: "Delete",
                    confirmTint: skeu.accent
                ) {
                    pendingDelete = false
                    withAnimation(SkeuMotion.layout) { store.clearLiveNote() }
                } onCancel: {
                    pendingDelete = false
                }
            }
        }
    }

    // MARK: The box

    /// A trough, not a card: this is a place a thing SITS, cut into the page,
    /// which is the same reading every field in the app gets.
    private var box: some View {
        let shape = RoundedRectangle(cornerRadius: SkeuRadius.lg, style: .continuous)

        return Group {
            if let note {
                Text(note.title)
                    .font(SkeuFont.at(textSize, weight: .medium))
                    .foregroundStyle(skeu.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            } else if typing {
                TextField("", text: $draft,
                          prompt: Text("What are you doing?")
                            .foregroundStyle(skeu.inkFaint),
                          axis: .vertical)
                    .font(SkeuFont.at(textSize, weight: .medium))
                    .foregroundStyle(skeu.ink)
                    .multilineTextAlignment(.center)
                    .focused($focused)
                    .submitLabel(.done)
                    .onSubmit(commit)
            } else {
                // Nothing at all. An empty box with a prompt in it would be a
                // field you cannot type in — the Go Live button below is what
                // opens this.
                Color.clear.frame(height: 1)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(SkeuSpace.xl)
        .frame(minHeight: 260 * chromeScale)
        // The rim is stated at CONTROL size, not at the box's own.
        //
        // `skeuTrough` scales every inset by `height / 148.2`, so handing it
        // the real 260 drew the channel at nearly twice weight and the box
        // read as a thick picture frame (founder bug report 2026-08-17). The
        // depth of a channel does not grow with the thing sitting in it.
        .skeuTrough(shape, height: 64)
        .padding(.horizontal, SkeuSpace.xl)
    }

    // MARK: The controls

    @ViewBuilder
    private var controls: some View {
        HStack(spacing: SkeuSpace.md) {
            if note != nil {
                liveSwitch
                bin
            } else if typing {
                pill(label: "Go", filled: !draft.isEmpty) { commit() }
            } else {
                pill(label: "Go Live", filled: false) {
                    withAnimation(SkeuMotion.layout) { typing = true }
                    focused = true
                }
            }
        }
        .padding(.horizontal, SkeuSpace.xl)
        .animation(SkeuMotion.layout, value: note?.id)
    }

    /// Reads as what it CONTROLS, not as what it will do: lit when the note is
    /// on the Lock Screen, dark when it is only in this box.
    private var liveSwitch: some View {
        let on = note?.isPinned ?? false

        return HStack(spacing: SkeuSpace.sm) {
            LiveGlyph(tint: on ? skeu.accent : skeu.inkMuted,
                      lineWidth: 1.7 * chromeScale)
                .frame(width: buttonH * 0.42, height: buttonH * 0.42)
            Text(on ? "Live" : "Off air")
                .font(SkeuFont.at(SkeuToggle.label * textScale, weight: .medium))
                .foregroundStyle(on ? skeu.ink : skeu.inkMuted)
        }
        .padding(.horizontal, SkeuSpace.lg)
        .frame(height: buttonH)
        .frame(maxWidth: .infinity)
        .skeuGlass(Capsule(), height: buttonH, prominent: on)
        .contentShape(Capsule())
        .skeuPress {
            withAnimation(SkeuMotion.tint) { store.setLiveOnLockScreen(!on) }
        }
        .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
        .accessibilityLabel(on ? "Showing on the Lock Screen" : "Not on the Lock Screen")
    }

    private var bin: some View {
        Image(systemName: "trash")
            .font(.system(size: SkeuToggle.label * textScale))
            .foregroundStyle(skeu.inkMuted)
            .frame(width: buttonH * 1.6, height: buttonH)
            .skeuGlass(Capsule(), height: buttonH)
            .contentShape(Capsule())
            .skeuPress { pendingDelete = true }
            .accessibilityLabel("Delete")
    }

    private func pill(label: String, filled: Bool,
                      action: @escaping () -> Void) -> some View {
        HStack(spacing: SkeuSpace.sm) {
            LiveGlyph(tint: skeu.ink, lineWidth: 1.7 * chromeScale)
                .frame(width: buttonH * 0.42, height: buttonH * 0.42)
            Text(label)
                .font(SkeuFont.at(SkeuToggle.label * textScale, weight: .medium))
                .foregroundStyle(skeu.ink)
        }
        .padding(.horizontal, SkeuSpace.xl)
        .frame(height: buttonH)
        .skeuGlass(Capsule(), height: buttonH, prominent: filled)
        .contentShape(Capsule())
        .skeuPress(action)
        .accessibilityAddTraits(.isButton)
    }

    private func commit() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            withAnimation(SkeuMotion.layout) { typing = false }
            focused = false
            return
        }
        SkeuHaptic.success()
        withAnimation(SkeuMotion.layout) {
            store.setLiveNote(text)
            draft = ""
            typing = false
        }
        focused = false
    }
}
