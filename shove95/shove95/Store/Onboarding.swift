//
//  Onboarding.swift
//  shove95
//
//  The first run, held OVER the real app rather than in front of it.
//
//  Not a slideshow (founder direction 2026-08-17). Pictures of an app teach
//  you the pictures; the controls here are the live ones, the list is your
//  list, and the first task you make in step one is a real task you keep. The
//  overlay only says which press does what and gets out of the way — it never
//  swallows a touch, so at any point you can simply ignore it and use the app.
//
//  That is also why there is no sample task to clean up afterwards. An earlier
//  plan made one and deleted it; the walkthrough instead asks you to write
//  your own, and skips the gesture step if you would rather not.
//

import SwiftUI
import Shove95Kit

/// A control the walkthrough can point at. The roots tag their real chrome
/// with these, so the overlay never guesses at a position — see
/// `View.onboardingTarget(_:)`.
enum OnboardingTarget: String, Hashable {
    case addRow
    case taskRow
    case liveButton
    case workspace
}

/// Frames of the tagged controls, in GLOBAL coordinates, gathered up the view
/// tree. Global because the overlay is a sibling of the list, not a child, and
/// the two share no coordinate space of their own.
struct OnboardingTargetKey: PreferenceKey {
    static var defaultValue: [OnboardingTarget: CGRect] { [:] }

    static func reduce(value: inout [OnboardingTarget: CGRect],
                       nextValue: () -> [OnboardingTarget: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

extension View {
    /// Publishes this view's frame under `target`. In a BACKGROUND, never as a
    /// wrapper: a GeometryReader that wraps content lays it out rather than
    /// measuring it, which is how four screens once lost their headers under
    /// the status bar.
    ///
    /// Optional so a row inside a ForEach can tag only the first without the
    /// call site branching around the modifier.
    @ViewBuilder
    func onboardingTarget(_ target: OnboardingTarget?) -> some View {
        if let target {
            background {
                GeometryReader { proxy in
                    Color.clear.preference(key: OnboardingTargetKey.self,
                                           value: [target: proxy.frame(in: .global)])
                }
            }
        } else {
            self
        }
    }
}

/// Hangs the walkthrough off a root: collects the tagged frames, starts it on
/// a first run, keeps it in step with the store, and draws whichever look's
/// overlay it was handed.
///
/// A modifier rather than four clauses inlined in a root's body, because
/// inlined they put both roots over the type checker's budget — and because
/// the two looks then differ in exactly one thing, which is the overlay.
struct OnboardingHost<Overlay: View>: ViewModifier {
    let onboarding: OnboardingCoordinator
    /// This look's pace. Everything else the host does is look-agnostic.
    let animation: Animation
    /// Handed `next` and `skip` rather than the roots owning them: the rule
    /// that finishing OR skipping both retire the walkthrough for good is one
    /// rule, and it was written out in both roots.
    let overlay: (OnboardingCoordinator.Step,
                  _ next: @escaping () -> Void,
                  _ skip: @escaping () -> Void) -> Overlay

    @Environment(TaskStore.self) private var store
    @Environment(AppSettings.self) private var settings

    func body(content: Content) -> some View {
        content
            .onPreferenceChange(OnboardingTargetKey.self) { frames in
                // Also the START signal. This callback IS the event the
                // walkthrough was waiting for — it used to sleep 400ms first,
                // a guess about layout speed on one device under one load,
                // when the arrival of the first target's frame says exactly
                // when there is something to point at.
                if !settings.hasOnboarded, !onboarding.isRunning,
                   frames[OnboardingCoordinator.Step.addRow.target] != nil {
                    withAnimation(animation) {
                        onboarding.start(taskCount: store.activeTally().all)
                    }
                }
                // GUARDED. Two of the tagged controls live inside the scrolling
                // list, so their global frames change every frame of a scroll —
                // unguarded, this wrote an @Observable sixty times a second for
                // the life of the app, for a walkthrough that runs once.
                guard onboarding.isRunning else { return }
                onboarding.targets = frames
            }
            .overlay {
                if let step = onboarding.step {
                    overlay(step, advance, finish).transition(.opacity)
                }
            }
            .onChange(of: store.revision) {
                guard onboarding.isRunning else { return }
                let counts = store.activeTally()
                withAnimation(animation) {
                    onboarding.storeChanged(taskCount: counts.all,
                                            todayCount: counts.today)
                }
            }
    }

    private func advance() {
        let counts = store.activeTally()
        withAnimation(animation) {
            onboarding.next(taskCount: counts.all, todayCount: counts.today)
        }
        if !onboarding.isRunning { settings.hasOnboarded = true }
    }

    private func finish() {
        withAnimation(animation) { onboarding.finish() }
        settings.hasOnboarded = true
    }
}

@Observable @MainActor
final class OnboardingCoordinator {
    enum Step: Int, CaseIterable {
        case addRow, shove, live, workspace

        var target: OnboardingTarget {
            switch self {
            case .addRow:    .addRow
            case .shove:     .taskRow
            case .live:      .liveButton
            case .workspace: .workspace
            }
        }

        var title: String {
            switch self {
            case .addRow:    "Write one down"
            case .shove:     "Shove it"
            case .live:      "The one you're on"
            case .workspace: "Separate lists"
            }
        }

        var detail: String {
            switch self {
            case .addRow:    "Type here, then press Return."
            case .shove:     "Swipe it right for later, left for earlier."
            case .live:      "One live thing, on your Lock Screen."
            case .workspace: "Work, home, whatever. Live is shared."
            }
        }

        /// The docked button's word. Stated here beside the other two strings
        /// rather than as a ternary in each overlay, so "which step is last"
        /// is answered once.
        var nextLabel: String { self == .workspace ? "Done" : "Show me next" }
    }

    private(set) var step: Step?
    var isRunning: Bool { step != nil }

    /// Where the real controls are, refreshed by the roots every layout pass.
    var targets: [OnboardingTarget: CGRect] = [:]

    /// How many tasks there were when the current step began. The gesture
    /// steps watch this rather than any particular task: a count that grows
    /// means one was written, and a bucket that changes means one was shoved.
    private var mark: Int = 0

    func start(taskCount: Int) {
        guard step == nil else { return }
        mark = taskCount
        step = .addRow
    }

    /// The docked button, and the way the two non-gesture steps are passed.
    func next(taskCount: Int, todayCount: Int) {
        guard let current = step else { return }
        advance(from: current, taskCount: taskCount, todayCount: todayCount)
    }

    /// Called by the roots when the store changes. A step that is waiting on a
    /// gesture ends the moment the gesture lands, so the walkthrough keeps up
    /// with someone who is already using the app rather than reading it.
    func storeChanged(taskCount: Int, todayCount: Int) {
        switch step {
        case .addRow where taskCount > mark:
            advance(from: .addRow, taskCount: taskCount, todayCount: todayCount)
        case .shove where todayCount < mark:
            // The task left Today, which is the only thing a swipe can do from
            // the tab this opens on.
            advance(from: .shove, taskCount: taskCount, todayCount: todayCount)
        default:
            break
        }
    }

    func finish() {
        step = nil
        targets = [:]
    }

    /// `mark` is re-armed for whatever the NEXT step is waiting on: a count of
    /// tasks for the one that wants a task written, a count of Today's for the
    /// one that wants a task shoved out of it.
    private func advance(from current: Step, taskCount: Int, todayCount: Int) {
        var nextStep = Step(rawValue: current.rawValue + 1)
        // Nothing to shove: someone who passed on writing a task should not
        // then be asked to swipe one that is not there.
        if nextStep == .shove, todayCount == 0 {
            nextStep = .live
        }
        mark = nextStep == .shove ? todayCount : taskCount
        step = nextStep
    }
}
