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
    let point: CGPoint

    static func == (a: RowMenuRequest, b: RowMenuRequest) -> Bool {
        a.taskID == b.taskID && a.point == b.point
    }
}

@Observable @MainActor
final class MenuCoordinator {
    var request: RowMenuRequest?

    /// Springs in with a little overshoot; the anchor is the row's bottom-left,
    /// so it grows out of the row the way a Win95 menu drops from its title.
    func show(task: TaskItem, at point: CGPoint) {
        withAnimation(.spring(duration: 0.26, bounce: 0.38)) {
            request = RowMenuRequest(taskID: task.id, point: point)
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

    var body: some View {
        GeometryReader { geo in
            if let request = menu.request,
               let task = store.task(withID: request.taskID) {
                ZStack(alignment: .topLeading) {
                    // Tap-anywhere-else to dismiss.
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { menu.dismiss() }

                    Win95Menu(task: task)
                        .fixedSize()
                        .modifier(ClampedPosition(point: request.point, bounds: geo.size))
                        .transition(.scale(scale: 0.86, anchor: .topLeading)
                            .combined(with: .opacity))
                }
            }
        }
    }
}

/// Anchors the panel's top-left at the touch, then pulls it back inside the
/// screen edges if it would overflow.
private struct ClampedPosition: ViewModifier {
    let point: CGPoint
    let bounds: CGSize

    func body(content: Content) -> some View {
        content
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(key: MenuSizeKey.self, value: proxy.size)
                }
            }
            .modifier(OffsetToFit(point: point, bounds: bounds))
    }
}

private struct MenuSizeKey: PreferenceKey {
    static let defaultValue = CGSize.zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) { value = nextValue() }
}

private struct OffsetToFit: ViewModifier {
    let point: CGPoint
    let bounds: CGSize
    @State private var size: CGSize = .zero

    func body(content: Content) -> some View {
        content
            .onPreferenceChange(MenuSizeKey.self) { size = $0 }
            .offset(
                x: min(max(0, point.x), max(0, bounds.width - size.width)),
                y: min(max(0, point.y), max(0, bounds.height - size.height))
            )
    }
}
