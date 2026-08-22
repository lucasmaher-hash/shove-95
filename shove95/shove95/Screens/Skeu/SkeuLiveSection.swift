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

    /// How far the keyboard eats into this screen, and the curve it travels
    /// on — read off the keyboard's own notification, see `KeyboardDock`.
    ///
    /// The tab bar and the workspace bar are furniture and deliberately hold
    /// still under the keyboard, which is why the screen around them ignores
    /// the keyboard safe area entirely. That leaves this box knowing nothing
    /// about the keyboard: it stayed its resting size with the keyboard drawn
    /// over the bottom of it (founder direction 2026-08-22, against MonoNote,
    /// where the field takes the whole space above the keys).
    @State private var keyboardOverlap: CGFloat = 0
    @State private var keyboardAnimation: Animation = SkeuMotion.layout
    /// This screen's own clearance from the bottom of the display, so the
    /// keyboard is not counted twice — see `KeyboardDock.read`.
    @State private var bottomGap: CGFloat = 0

    /// Whether the box is filling the space above the keyboard.
    ///
    /// Keyed on the KEYBOARD rather than on focus, so growing and the keys
    /// arriving are one movement on one curve. Focus alone would snap the box
    /// open while the keyboard was still sliding, and with a hardware keyboard
    /// there is no space above anything to fill.
    private var isExpanded: Bool { keyboardOverlap > 0 }

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
        // The height is COMPUTED from the space this screen was handed, not
        // asked for with `.infinity` and a bottom padding. That first attempt
        // fed back on itself: the box's own growth pushed the frame it was
        // measuring its clearance from, which shrank the clearance, which
        // asked for more growth — until it had climbed over the workspace bar
        // and the gear, which the founder wants left where they are
        // (2026-08-22). A slot cannot be moved by what is put in it.
        GeometryReader { geo in
            VStack(spacing: SkeuSpace.lg) {
                // The box is centred at rest and fills the screen when the
                // keyboard is up, so the spacers stand down for the expansion
                // — left in, they would claim half the growth each.
                if !isExpanded { Spacer(minLength: 0) }
                box(maxHeight: boxHeight(in: geo))
                // Directly under the box, not pushed to the floor (founder
                // direction 2026-08-17). They act on what is IN the box, and a
                // control parked at the far end of the screen reads as
                // belonging to the screen instead.
                controls
                if !isExpanded { Spacer(minLength: 0) }
            }
            // TOP-aligned once expanded. The box is sized to the space above
            // the keys, but a centred stack puts that size in the middle of
            // the whole screen and half of it ends up behind them.
            .frame(maxWidth: .infinity, maxHeight: .infinity,
                   alignment: isExpanded ? .top : .center)
            .padding(.vertical, SkeuSpace.xl)
            .bottomGapToScreen($bottomGap)
            .onReceive(NotificationCenter.default.publisher(
                for: UIResponder.keyboardWillChangeFrameNotification)) { note in
                guard let change = KeyboardDock.read(note, clearance: bottomGap) else { return }
                keyboardAnimation = change.animation
                withAnimation(change.animation) { keyboardOverlap = change.overlap }
            }
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
        } // GeometryReader
    }

    /// The box's resting size: one line, shown at the size it deserves.
    private var restingHeight: CGFloat { 260 * chromeScale }

    /// How tall the box may grow, given the space this screen was handed.
    ///
    /// Everything that has to keep its room is subtracted by name, so the sum
    /// can be read rather than trusted. Never below the resting size: on a
    /// short screen under a tall keyboard the box holds its size and the
    /// keyboard covers what it covers, which is what it did before any of
    /// this.
    private func boxHeight(in geo: GeometryProxy) -> CGFloat {
        guard isExpanded else { return restingHeight }
        let spokenFor = SkeuSpace.xl * 2   // this screen's own top and bottom
                      + SkeuSpace.lg       // the gap down to the controls
                      + buttonH            // the controls themselves
                      + keyboardOverlap    // and the keys
        return max(restingHeight, geo.size.height - spokenFor)
    }

    // MARK: The box

    /// A trough, not a card: this is a place a thing SITS, cut into the page,
    /// which is the same reading every field in the app gets.
    private func box(maxHeight: CGFloat) -> some View {
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
        // At rest this is a floor and the box grows with wrapped text; with
        // the keyboard up it is both floor and ceiling, and the box stands
        // exactly in the space above the keys.
        .frame(minHeight: restingHeight,
               maxHeight: isExpanded ? maxHeight : nil)
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
        // The whole trough is the field. The text line is one line in a box a
        // few hundred points tall, and a tap on the empty ground under it did
        // nothing (founder direction 2026-08-17). The TextField still wins
        // taps on the text itself; this catches the rest of the box.
        .contentShape(shape)
        .onTapGesture { focused = true }
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
        // Off air, the CONTENTS recede — mark and word together. Applied here
        // rather than to the finished control, so the glass keeps its full
        // strength: the capsule is the button, and fading it made the whole
        // thing read as disabled (founder direction 2026-08-17).
        .opacity(on ? 1 : 0.55)
        .animation(SkeuMotion.tint, value: on)
        .padding(.horizontal, SkeuSpace.lg)
        .frame(height: buttonH)
        .frame(maxWidth: .infinity)
        // Prominent in BOTH states. `prominent: on` drew the capsule itself at
        // a weaker glass step when off air, so the frame washed out alongside
        // its label even after the opacity was moved off it (founder bug
        // report 2026-08-17). The state is carried entirely by the mark and
        // the word now; the button looks like a button either way.
        .skeuGlass(Capsule(), height: buttonH, prominent: true)
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
            // FULL ink, not muted. It stands beside a switch that is muted on
            // purpose — to say "not on air" — and wearing the same grey made
            // the bin look like it was in that state too, when deleting is
            // always available (founder direction 2026-08-17).
            .foregroundStyle(skeu.ink)
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
