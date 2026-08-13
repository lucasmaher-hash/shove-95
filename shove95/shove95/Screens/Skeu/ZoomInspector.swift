//
//  ZoomInspector.swift
//  shove95
//
//  TEMPORARY SCAFFOLD — not part of the app.
//
//  Wraps a screen in a magnifier so fine surface work can be judged on device:
//  ＋/－ step the zoom, and above 1× a drag pans around. It exists because the
//  skeu details being tuned right now (rim gradients, lens layers, a 0.85pt
//  blur) are sub-pixel at 1× and cannot be assessed by eye at real size.
//
//  Delete this file, and its use in AppShell, once the surface work is signed
//  off. It deliberately sits outside SkeuKit so it cannot be mistaken for part
//  of the design system.
//

import SwiftUI

struct ZoomInspector<Content: View>: View {
    @Environment(\.skeu) private var skeu
    @ViewBuilder var content: Content

    @State private var zoom: CGFloat = 1
    @State private var pan: CGSize = .zero
    /// Pan at the moment the current drag began, so drags accumulate.
    @State private var panAnchor: CGSize = .zero

    private let steps: [CGFloat] = [1, 1.5, 2, 3, 4, 6, 8]

    var body: some View {
        ZStack {
            // Panned far enough, the magnified content runs out and the window
            // shows through white — which wrecks the very colour judgement this
            // thing exists for. The canvas backs the whole screen instead.
            skeu.canvas.ignoresSafeArea()

            // No GeometryReader and no explicit frame: the content keeps its
            // own layout, safe areas and all, and `scaleEffect` magnifies the
            // result. Measuring it first and re-framing it to `geo.size` was
            // tried and breaks the layout — the reader reports the size INSIDE
            // the safe area, so the canvas stops reaching the screen edges and
            // black bars appear top and bottom.
            content
                .scaleEffect(zoom)
                .offset(pan)
                // Only claims the drag once magnified, so taps on the real
                // controls keep working at 1×.
                .highPriorityGesture(zoom > 1 ? panGesture : nil)

            controls
                .frame(maxWidth: .infinity, maxHeight: .infinity,
                       alignment: .bottomTrailing)
                .padding(.trailing, 12)
                .padding(.bottom, 96)
        }
    }

    private var panGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                pan = CGSize(width: panAnchor.width + value.translation.width,
                             height: panAnchor.height + value.translation.height)
            }
            .onEnded { _ in panAnchor = pan }
    }

    private var controls: some View {
        VStack(spacing: 1) {
            button("plus.magnifyingglass") { step(+1) }
            Text(zoom == 1 ? "1×" : String(format: "%.1f×", zoom))
                .font(.system(size: 11, weight: .semibold).monospacedDigit())
                .foregroundStyle(.white)
                .frame(width: 44, height: 22)
                .background(.black.opacity(0.55))
            button("minus.magnifyingglass") { step(-1) }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func button(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 44, height: 40)
                .background(.black.opacity(0.55))
        }
        .buttonStyle(.plain)
    }

    private func step(_ direction: Int) {
        guard let current = steps.firstIndex(of: zoom) else { zoom = 1; return }
        let next = min(max(current + direction, 0), steps.count - 1)
        withAnimation(.easeOut(duration: 0.18)) {
            zoom = steps[next]
            if zoom == 1 { pan = .zero; panAnchor = .zero }
        }
    }
}
