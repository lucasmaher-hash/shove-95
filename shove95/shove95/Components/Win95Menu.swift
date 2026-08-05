//
//  Win95Menu.swift
//  shove95
//
//  The hand-drawn replacement for `.contextMenu` (design.md §9 prohibits the
//  system menu's rounded corners, blur and translucency). Owning the menu also
//  frees the long-press: with UIContextMenuInteraction attached, SwiftUI's
//  LongPressGesture never fired a single phase, which is what blocked
//  drag-reorder through the whole of Phase 2.
//
//  A Win95 menu is a raised silver panel of text rows that appears at the
//  pointer, with no scrim. Tapping anywhere else dismisses it.
//
//  It DOES spring in (founder direction 2026-08-04): the app is a static vintage
//  surface that responds like a modern one, so the panel arrives with the same
//  small bounce iOS gives a long-press menu. It leaves fast and flat — a bouncy
//  dismissal reads as hesitation.
//

import SwiftUI
import Shove95Kit

// MARK: - Coordinator

/// What the root view needs in order to draw a menu: which task, and where the
/// finger was. Lives above the list so the panel is never clipped by the
/// scroll view.
struct RowMenuRequest: Equatable {
    let taskID: UUID
    /// The row's frame in GLOBAL coordinates. The overlay needs the whole rect,
    /// not a single anchor: near the bottom of the screen the menu has to flip
    /// ABOVE the row, or Delete lands off-screen and is unreachable (founder
    /// bug report 2026-08-04).
    let rowFrame: CGRect

    static func == (a: RowMenuRequest, b: RowMenuRequest) -> Bool {
        a.taskID == b.taskID && a.rowFrame == b.rowFrame
    }
}

@Observable @MainActor
final class MenuCoordinator {
    var request: RowMenuRequest?

    /// Springs in with a little overshoot; the anchor is the row's bottom-left,
    /// so it grows out of the row the way a Win95 menu drops from its title.
    func show(task: TaskItem, rowFrame: CGRect) {
        withAnimation(.spring(duration: 0.26, bounce: 0.38)) {
            request = RowMenuRequest(taskID: task.id, rowFrame: rowFrame)
        }
    }

    func dismiss() {
        withAnimation(.easeOut(duration: 0.11)) { request = nil }
    }

    func isShowing(_ task: TaskItem) -> Bool {
        request?.taskID == task.id
    }
}

// MARK: - Menu panel

struct Win95Menu: View {
    @Environment(\.pixel) private var pixel
    @Environment(TaskStore.self) private var store
    @Environment(MenuCoordinator.self) private var menu

    let task: TaskItem

    private var bucket: Bucket {
        task.bucket(now: store.now(), calendar: store.calendar)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if task.isCompleted {
                // Completed rows: untick to act on them; only Delete applies.
                item("Delete", destructive: true) { store.delete(task) }
            } else {
                ForEach(bucket.menuDestinations, id: \.label) { destination in
                    item(destination.label) {
                        withAnimation(.spring(duration: 0.25)) {
                            store.move(task, to: destination.bucket)
                        }
                    }
                }
                separator
                item(task.isImportant ? "Unmark Important" : "Mark as Important") {
                    withAnimation(.spring(duration: 0.25)) {
                        store.toggleImportant(task)
                    }
                }
                separator
                item("Delete", destructive: true) { store.delete(task) }
            }
        }
        .padding(pixel * 2)
        .frame(minWidth: Win95.Px.buttonMinWidth * pixel * 1.6, alignment: .leading)
        .background(Win95.surface)
        .bevelRaised(pixel)
    }

    private func item(_ label: String, destructive: Bool = false,
                      action: @escaping () -> Void) -> some View {
        Text(label)
            .font(W95Font.standard(pixel))
            .foregroundStyle(destructive ? Win95.important : Win95.text)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Win95.Px.grid * pixel)
            .frame(minHeight: Win95.rowHeight(pixel))
            .contentShape(Rectangle())
            .onTapGesture {
                menu.dismiss()
                action()
            }
            .accessibilityAddTraits(.isButton)
    }

    private var separator: some View {
        // Win95 menu separator: one shadow line, one highlight line.
        VStack(spacing: 0) {
            Rectangle().fill(Win95.shadow).frame(height: pixel)
            Rectangle().fill(Win95.highlight).frame(height: pixel)
        }
        .padding(.vertical, pixel)
    }
}

// MARK: - Root overlay

/// Places the menu near the touch point, clamped inside the screen. No scrim.
/// The spring lives in `MenuCoordinator`; the transition here just gives it
/// something to spring from.
struct MenuOverlay: View {
    @Environment(MenuCoordinator.self) private var menu
    @Environment(TaskStore.self) private var store
    @Environment(\.pixel) private var pixel

    var body: some View {
        GeometryReader { geo in
            if let request = menu.request,
               let task = store.task(withID: request.taskID) {
                // The row reports GLOBAL coordinates, but this overlay draws in
                // its own space, which starts below the status bar — using the
                // global rect directly put the menu a full row too low.
                let origin = geo.frame(in: .global).origin
                let row = request.rowFrame.offsetBy(dx: -origin.x, dy: -origin.y)
                let gap = Win95.Px.grid * pixel
                let below = row.maxY + gap
                let dropsBelow = below + estimatedHeight(for: task) <= geo.size.height

                ZStack(alignment: dropsBelow ? .topLeading : .bottomLeading) {
                    // Tap-anywhere-else to dismiss.
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { menu.dismiss() }

                    Win95Menu(task: task)
                        .fixedSize()
                        .offset(
                            x: max(0, min(row.minX, geo.size.width - menuWidth)),
                            // Flipped: bottom-anchored, so the panel's own
                            // height positions it — no measurement needed.
                            y: dropsBelow ? below
                                          : (row.minY - gap) - geo.size.height
                        )
                        .transition(.scale(scale: 0.86,
                                           anchor: dropsBelow ? .topLeading : .bottomLeading)
                            .combined(with: .opacity))
                }
            }
        }
    }

    /// Menus are built from a known table, so their height is CALCULATED, not
    /// measured. A PreferenceKey round-trip reports zero on the first layout
    /// pass, and the decision is made on that pass — which is why the panel
    /// kept dropping below and running off the bottom of the screen (founder
    /// bug report 2026-08-04).
    private func estimatedHeight(for task: TaskItem) -> CGFloat {
        let bucket = task.bucket(now: store.now(), calendar: store.calendar)
        let items = task.isCompleted ? 1 : bucket.menuDestinations.count + 2
        let separators = task.isCompleted ? 0 : 2
        return CGFloat(items) * Win95.rowHeight(pixel)
            + CGFloat(separators) * 4 * pixel
            + 4 * pixel // panel padding
    }

    private var menuWidth: CGFloat { Win95.Px.buttonMinWidth * pixel * 1.6 }
}
