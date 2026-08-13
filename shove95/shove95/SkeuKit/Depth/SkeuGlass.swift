//
//  SkeuGlass.swift
//  shove95
//
//  The glass pill, transcribed from the isolated component (shove95 file, node
//  4:882 — a 221.31 × 104.54 button). It has NO fill of its own. What makes it
//  read as a lens, outside in:
//
//    shadows   a five-stop ladder falling straight down
//              0/81.44/22.68 @0     · 0/52.57/20.62 @.01 · 0/29.90/17.53 @.05
//              0/13.40/13.40 @.09   · 0/3.09/7.22   @.10
//    rim       2.971 of white at 0.5 alpha, the whole way round
//    glow      an ELLIPTICAL white gradient centred BELOW the pill
//              (111.02, 125.83 in a 221.31 × 104.54 box → x 0.5, y 1.20),
//              blended plus-lighter at 0.5 — additive, so it brightens
//              without tinting
//    lenses    five stacked layers, each rgba(255,255,255,0.01), each inset
//              further than the last, the group blurred by 3.281
//
//  The lens stack is the part that is easy to get backwards. Each layer is
//  SMALLER than the one below it, so the alphas accumulate toward the MIDDLE:
//  ~5% at the centre, 1% at the rim. An earlier build had a rim-weighted
//  gradient instead — brightest at the edge — which is the exact inverse and
//  read as a chrome ring rather than as thickness.
//
//  In Figma each layer also carries a backdrop-blur (41 → 20.5 → 10.25 → 4.1 →
//  0.82), giving true progressive refraction. SwiftUI's only backdrop-blur
//  primitive is `Material`, whose radius is fixed and which tints neutral grey
//  — it drains the hue straight out of the lens, which was tried and rejected.
//  What is kept is the layer geometry and the group blur; on the near-flat
//  surfaces this sits on, there is nothing behind it to refract anyway.
//

import SwiftUI

struct SkeuGlass<S: InsettableShape>: ViewModifier {
    @Environment(\.skeu) private var skeu
    let shape: S
    /// Reference pill height (104.54 in the frame) — scales every figure below.
    var height: CGFloat = 44
    /// The two glass states of the settings reference (nodes 1:101 vs 1:87).
    /// Prominent — the active option: full rim, bottom glow, full shadows.
    /// Subdued — a resting option: rim and shadows at half strength, NO glow,
    /// and the caller dims its label. The lens stack is identical in both;
    /// what changes is only how much light the piece is catching.
    var prominent: Bool = true

    private var k: CGFloat { height / 104.54 }

    /// The five lens insets, (vertical, horizontal), in frame units.
    private let lenses: [(v: CGFloat, h: CGFloat)] = [
        (0, 0), (2.46, 1.70), (7.39, 5.09), (15.59, 10.74), (31.99, 22.03),
    ]

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    lensStack
                    if prominent { glow }
                }
            }
            .overlay {
                shape.strokeBorder(rim, lineWidth: max(0.8, 2.971 * k))
            }
            .clipShape(shape)
            .shadow(color: drop(0.05), radius: 17.525 * k, y: 29.895 * k)
            .shadow(color: drop(0.09), radius: 13.401 * k, y: 13.401 * k)
            .shadow(color: drop(0.10), radius: 7.216 * k, y: 3.093 * k)
    }

    /// Halves every light the piece throws when it is at rest.
    private var strength: Double { prominent ? 1 : 0.5 }

    /// Five concentric layers at 1% white each. Thickness, not a highlight.
    private var lensStack: some View {
        ZStack {
            ForEach(Array(lenses.enumerated()), id: \.offset) { _, inset in
                shape
                    .fill(.white.opacity(0.01))
                    .padding(.vertical, inset.v * k)
                    .padding(.horizontal, inset.h * k)
            }
        }
        .blur(radius: 3.281 * k)
        .allowsHitTesting(false)
    }

    /// The rim: bright along the top and bottom edges, all but gone across the
    /// middle of the two ends.
    ///
    /// Figma's export states this as a flat `rgba(255,255,255,0.5)`, because it
    /// cannot represent a gradient stroke — the same flattening that hid the
    /// trough contour's gradient. Taken literally it lights the whole perimeter
    /// evenly, which turns the lens into a ring. Only the surfaces facing the
    /// key light should catch it; the sides are edge-on to it and stay dark.
    private var rim: LinearGradient {
        LinearGradient(
            stops: [.init(color: .white.opacity(0.55 * strength), location: 0.0),
                    .init(color: .white.opacity(0.05 * strength), location: 0.5),
                    .init(color: .white.opacity(0.60 * strength), location: 1.0)],
            startPoint: .top, endPoint: .bottom)
    }

    /// Rises from below the bottom edge; additive, so it lifts the material
    /// underneath without staining it.
    private var glow: some View {
        shape.fill(
            EllipticalGradient(
                stops: [.init(color: .white.opacity(0.50), location: 0.0),
                        .init(color: .white.opacity(0.00), location: 1.0)],
                center: UnitPoint(x: 0.5, y: 1.20),
                startRadiusFraction: 0,
                endRadiusFraction: 0.62)
        )
        .blendMode(.plusLighter)
        .allowsHitTesting(false)
    }

    private func drop(_ alpha: Double) -> Color {
        skeu.shadow.opacity(alpha * skeu.shadowIntensity * strength)
    }
}

extension View {
    /// The glass lens treatment. `height` scales every transcribed figure;
    /// `prominent: false` is the resting-option state of a settings panel.
    func skeuGlass<S: InsettableShape>(_ shape: S,
                                       height: CGFloat = 44,
                                       prominent: Bool = true) -> some View {
        modifier(SkeuGlass(shape: shape, height: height, prominent: prominent))
    }
}
