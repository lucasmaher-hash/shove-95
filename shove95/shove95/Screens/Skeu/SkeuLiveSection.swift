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
    @State private var pendingDelete = false
    @FocusState private var focused: Bool

    private var note: TaskItem? { store.liveNote() }
    private var textSize: CGFloat { 22 * textScale }
    /// Every control down here is the height of the ✕ and the gear.
    ///
    /// The bin is a circle at exactly their size, so the three round controls
    /// in the app are one family; the pills beside it take the same height so
    /// the row has a single baseline (founder direction 2026-08-17).
    private var buttonH: CGFloat { SkeuTopBar.control * chromeScale }
    private var binIcon: CGFloat { SkeuTopBar.icon * chromeScale }

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
        // A downward drag anywhere puts the keyboard away, which is the
        // gesture every reader already has in their hand. There is no scroll
        // view here to hand that job to.
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 24)
                .onEnded { value in
                    if value.translation.height > 40 { focused = false }
                }
        )
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

        return TextField("", text: $draft,
                         prompt: Text("What are you doing?")
                            .foregroundStyle(skeu.inkFaint),
                         axis: .vertical)
            .font(SkeuFont.at(textSize, weight: .medium))
            .foregroundStyle(skeu.ink)
            .multilineTextAlignment(.center)
            .focused($focused)
            // Return CLOSES the field, having written what is in it. The
            // keyboard's blue key is the way out of a box that is otherwise
            // always open (founder direction 2026-08-17).
            .submitLabel(.done)
            .onSubmit { commit(); focused = false }
            // RETURN, caught by hand. A field on the vertical axis treats the
            // blue key as a newline and never calls `onSubmit`, so the only
            // way out of the keyboard was to leave the tab (founder bug report
            // 2026-08-17). Wrapping is worth keeping — a live note can run to
            // two lines — so the newline is intercepted rather than the axis
            // given up.
            .onChange(of: draft) { _, new in
                guard new.contains("\n") else { return }
                draft = new.replacingOccurrences(of: "\n", with: " ")
                    .trimmingCharacters(in: .whitespaces)
                commit()
                focused = false
            }
            // Leaving by any other route writes too — tapping away from a
            // half-typed thought should not throw it away.
            .onChange(of: focused) { _, isFocused in
                if !isFocused { commit() }
            }
            // The box shows what IS live whenever you are not the one
            // changing it, so a note arriving from another device lands here.
            .task(id: note?.id) { if !focused { draft = note?.title ?? "" } }
            .onChange(of: note?.title) { _, new in
                if !focused { draft = new ?? "" }
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
        // The ramp finishes in the top quarter and the floor tone holds the
        // rest, and the inner shadows come down to two thirds. At full weight
        // over 260pt the upper half read as gloom rather than a lip (founder
        // bug report 2026-08-17).
        .skeuTrough(shape, height: 64, fillStop: 0.26, shadeScale: 0.65,
                    fillLift: 0.55)
        .padding(.horizontal, SkeuSpace.xl)
    }

    // MARK: The controls

    @ViewBuilder
    private var controls: some View {
        HStack(spacing: SkeuSpace.md) {
            if note != nil {
                liveSwitch
                bin
            } else {
                // The field is always open, so this is not "start typing" any
                // more — it is "send what I typed", and before that it is the
                // thing that puts the cursor in the box.
                pill(label: draft.isEmpty ? "Go Live" : "Go",
                     filled: !draft.isEmpty) {
                    if draft.isEmpty { focused = true } else { commit(); focused = false }
                }
            }
        }
        // TWO THIRDS of the screen, centred. Run edge to edge these two read
        // as a bar across the bottom of the section rather than as the pair of
        // controls belonging to the box above them (founder direction
        // 2026-08-17).
        .containerRelativeFrame(.horizontal, alignment: .center) { width, _ in
            width * 0.68
        }
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
        // The MARK and the WORD breathe together, the same breath the tab
        // shows (founder direction 2026-08-17). The glass holds still: the
        // button is not what is on air, its contents are what say so.
        .skeuPulse(on)
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
            .font(.system(size: binIcon * 0.72))
            .foregroundStyle(skeu.inkMuted)
            .frame(width: buttonH, height: buttonH)
            .skeuGlass(Circle(), height: buttonH)
            // A filled Circle is hittable only where the ink lands.
            .contentShape(Circle())
            .skeuPress { pendingDelete = true }
            .accessibilityAddTraits(.isButton)
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
        guard !text.isEmpty else { return }
        // Renames what is there rather than replacing it, so editing the text
        // of something already live does not flick it off the Lock Screen and
        // back on. Silent when nothing changed.
        guard text != note?.title else { return }
        SkeuHaptic.success()
        withAnimation(SkeuMotion.layout) { store.writeLiveNote(text) }
    }
}
