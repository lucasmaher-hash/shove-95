//
//  SkeuGlassBakery.swift
//  shove95
//
//  The glass lens stack, rendered once and reused — the old trick, applied to
//  a new toolkit.
//
//  Skeuomorphic interfaces were never slow. The iOS that looked like this
//  drew leather and felt and brushed steel on hardware a fraction of what a
//  phone has now, and it did it at sixty frames a second, because none of it
//  was being COMPUTED while you scrolled. It was pictures. The chip copied a
//  texture into place and moved on (founder direction 2026-08-22).
//
//  What was expensive here was never the drawing — a device trace put the GPU
//  at 5% of its budget. It was the BUILDING: five concentric shapes, five
//  padding pairs, a Gaussian blur and a gradient, constructed and diffed for
//  every glass object on screen, on every update. SwiftUI's cost there is
//  generic-metadata lookup and tree comparison, and the profile showed exactly
//  that — `getGenericMetadata`, `initializeWithCopy`, `AGGraph` compares.
//
//  An Image is ONE node. That is the whole idea.
//
//  Keyed on everything the picture depends on and nothing else: the shape, the
//  size it is drawn at, whether it is prominent, and the palette. Content is
//  deliberately absent from the key — the lens stack never depended on what
//  sits inside it, which is precisely why it can be baked at all.
//

import SwiftUI

@MainActor
enum SkeuGlassBakery {
    /// The picture depends on these and nothing else.
    private struct Key: Hashable {
        let shape: String
        let width: Int
        let height: Int
        let prominent: Bool
    }

    private static var cache: [Key: Image] = [:]
    /// One palette is live at a time, so the cache is generational rather than
    /// keyed by theme: when the palette changes, every picture in it is stale
    /// at once and the cheapest thing to do is drop the lot.
    private static var bakedFor: SkeuPalette?

    /// How far the blur is allowed to spread past the frame before being
    /// clipped. Rendering at exactly the frame size is what cut the highlight
    /// off square at the rim (founder bug report 2026-08-16) — the note in
    /// SkeuGlass refusing `drawingGroup` is about this. Baking with room
    /// around it reproduces the un-rasterised result instead of arguing
    /// with it.
    static func bleed(k: CGFloat) -> CGFloat { ceil(3.281 * k * 3) }

    /// The baked lens stack, or nil if it could not be rendered — callers fall
    /// back to building it live, so a failure here costs speed and never
    /// correctness.
    static func background<S: InsettableShape>(
        shape: S,
        size: CGSize,
        k: CGFloat,
        prominent: Bool,
        skeu: SkeuPalette
    ) -> Image? {
        guard size.width > 0, size.height > 0,
              size.width.isFinite, size.height.isFinite else { return nil }

        if bakedFor != skeu {
            cache.removeAll()
            bakedFor = skeu
        }

        let pad = bleed(k: k)
        let key = Key(shape: String(describing: shape),
                      width: Int((size.width + pad * 2).rounded()),
                      height: Int((size.height + pad * 2).rounded()),
                      prominent: prominent)
        if let hit = cache[key] { return hit }

        let renderer = ImageRenderer(
            content: SkeuGlassBackground(shape: shape, k: k, prominent: prominent)
                .environment(\.skeu, skeu)
                .frame(width: size.width, height: size.height)
                .padding(pad)
        )
        renderer.scale = UIScreen.main.scale
        // Opaque would fill the transparent ground black; the lens stack is
        // almost entirely alpha.
        renderer.isOpaque = false
        guard let rendered = renderer.uiImage else { return nil }

        let image = Image(uiImage: rendered)
        cache[key] = image
        return image
    }
}

/// The lens stack and its glow, as a view of its own so the same code can be
/// drawn live or handed to the renderer above. Nothing in here reads the
/// content it will sit behind — that is what makes it bakeable.
struct SkeuGlassBackground<S: InsettableShape>: View {
    @Environment(\.skeu) private var skeu
    let shape: S
    let k: CGFloat
    var prominent: Bool = true

    /// The five lens insets, (vertical, horizontal), in frame units.
    private let lenses: [(v: CGFloat, h: CGFloat)] = [
        (0, 0), (2.46, 1.70), (7.39, 5.09), (15.59, 10.74), (31.99, 22.03),
    ]

    var body: some View {
        ZStack {
            lensStack
            if prominent { glow }
        }
    }

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
}
