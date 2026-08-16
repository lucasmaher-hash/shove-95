//
//  SkeuMenu.swift
//  shove95
//
//  The row menu in the skeu look. The COORDINATION is shared — MenuCoordinator
//  and RowMenuRequest are look-agnostic and this file reuses them — only the
//  panel is different: a raised card in the settings-panel construction
//  (material fill, the mirrored contour stroke, floating shadows) instead of a
//  bevelled Win95 rectangle.
//
//  Placement logic is a transcription of MenuOverlay (Win95Menu.swift): global
//  row frame → overlay space, drop below the row unless the panel would run
//  off-screen, then flip above. Height is CALCULATED from the item table, not
//  measured — a PreferenceKey round-trip reports zero on the first pass and
//  the flip decision is made on that pass (the original's hard-won lesson).
//

import SwiftUI
import Shove95Kit

private enum M {
    static let itemHeight: CGFloat = 44
    static let width: CGFloat = 210
    static let label: CGFloat = 12.8
    static let padding: CGFloat = 10
    static let radius: CGFloat = SkeuRadius.lg
    static let separator: CGFloat = 9 // 1pt line + 4pt breathing room each side
}

// MARK: - Panel

struct SkeuMenu: View {
    @Environment(\.skeu) private var skeu
    @Environment(TaskStore.self) private var store
    @Environment(MenuCoordinator.self) private var menu

    let task: TaskItem

    private var bucket: Bucket {
        task.bucket(now: store.now(), calendar: store.calendar)
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: M.radius, style: .continuous)

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
        .padding(M.padding)
        .frame(width: M.width, alignment: .leading)
        .background {
            shape.fill(
                LinearGradient(colors: [skeu.materialTop, skeu.material, skeu.materialBottom],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            )
        }
        // The raised contour — light on top, falling into shade, the same
        // stroke the settings cards wear.
        .overlay {
            shape.strokeBorder(
                LinearGradient(
                    stops: [.init(color: skeu.outlineBottom, location: 0.0),
                            .init(color: skeu.outline, location: 0.55),
                            .init(color: skeu.outline, location: 1.0)],
                    startPoint: .top, endPoint: .bottom),
                lineWidth: 3.1)
        }
        // Floating depth: this panel hovers over the list.
        .shadow(color: drop(0.22), radius: 20, x: -4, y: 10)
        .shadow(color: drop(0.16), radius: 40, x: -12, y: 26)
    }

    private func item(_ label: String, destructive: Bool = false,
                      action: @escaping () -> Void) -> some View {
        Text(label)
            .font(SkeuFont.at(M.label))
            .tracking(-0.02 * M.label)
            .foregroundStyle(destructive ? skeu.critical : skeu.ink)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, SkeuSpace.md)
            .frame(minHeight: M.itemHeight)
            .contentShape(Rectangle())
            .onTapGesture {
                SkeuHaptic.selection()
                menu.dismiss()
                action()
            }
            .accessibilityAddTraits(.isButton)
    }

    private var separator: some View {
        Rectangle()
            .fill(skeu.outline.opacity(0.35))
            .frame(height: 1)
            .padding(.horizontal, SkeuSpace.sm)
            .padding(.vertical, 4)
    }

    private func drop(_ alpha: Double) -> Color {
        skeu.shadow.opacity(alpha * skeu.shadowIntensity)
    }

    /// The item table is known, so the height is arithmetic — see file header.
    static func estimatedHeight(for task: TaskItem, store: TaskStore) -> CGFloat {
        let bucket = task.bucket(now: store.now(), calendar: store.calendar)
        let items = task.isCompleted ? 1 : bucket.menuDestinations.count + 2
        let separators = task.isCompleted ? 0 : 2
        return CGFloat(items) * M.itemHeight
            + CGFloat(separators) * M.separator
            + M.padding * 2
    }
}

// MARK: - Overlay

/// Places the menu near the row, clamped inside the screen. No scrim — a tap
/// anywhere else dismisses, exactly as the Win95 overlay behaves.
struct SkeuMenuOverlay: View {
    @Environment(MenuCoordinator.self) private var menu
    @Environment(TaskStore.self) private var store

    var body: some View {
        GeometryReader { geo in
            if let request = menu.request,
               let task = store.task(withID: request.taskID) {
                // The row reports GLOBAL coordinates; this overlay draws in its
                // own space, which starts below the status bar.
                let origin = geo.frame(in: .global).origin
                let row = request.rowFrame.offsetBy(dx: -origin.x, dy: -origin.y)
                let gap = SkeuSpace.sm
                let below = row.maxY + gap
                let height = SkeuMenu.estimatedHeight(for: task, store: store)
                let dropsBelow = below + height <= geo.size.height

                ZStack(alignment: dropsBelow ? .topLeading : .bottomLeading) {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { menu.dismiss() }

                    SkeuMenu(task: task)
                        .fixedSize()
                        .offset(
                            x: max(0, min(row.minX, geo.size.width - 210 - SkeuSpace.sm)),
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
}
