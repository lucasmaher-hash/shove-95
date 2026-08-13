//
//  SkeuTrough.swift
//  shove95
//
//  A trough is a channel cut THROUGH the material — the thing the reference's
//  nav bar actually is. It is not `skeuSurface(depth: .recessed)` with more
//  shadow; it is a different construction, and the difference is why the first
//  attempt read as a raised slab.
//
//  Transcribed from the Figma node (2:284), scaled from its 134pt bar height:
//
//    fill      linear #aa171f → #d7434f, top to bottom
//              (DARK at the top: the near wall shades the cavity.
//               The floor at the bottom is nearly the ground colour.)
//    contour   4.66px solid #85141a — darker than either stop
//    inner     inset  8.22  12.33 blur  8.22  black 0.25   ← from top-left
//              inset -8.25  -2.06 blur  8.25  black 0.25   ← from bottom-right
//              inset  0    -11.89 blur 29.71  black 0.30   ← up from the floor
//              inset  0     17.83 blur 11.89  black 0.25   ← down from the lip
//
//  All four are kept — dropping the two diagonal ones flattens it immediately,
//  they are what give the channel corners.
//
//  The ALPHAS and the floor shadow's radius are deliberately below the frame's
//  values (founder direction 2026-08-13: lighter than the reference itself, and
//  tighter). Figma renders these at 3.72× the phone size, where a 29.71 blur is
//  a narrow band along one edge; at 39.9pt it washes over the whole channel.
//  Blur does not scale linearly with perceived tightness, so the transcription
//  cannot be literal here.
//

import SwiftUI

struct SkeuTrough<S: InsettableShape>: ViewModifier {
    @Environment(\.skeu) private var skeu
    let shape: S
    /// Height of the trough, used to scale the transcribed inset values. The
    /// reference bar is 134pt tall; everything above is stated at that size.
    var height: CGFloat = 56

    /// The main-screen frame states the same shadows at a 148.2pt trough
    /// height; every offset below is that height's fraction, so they scale.
    private var k: CGFloat { height / 148.2 }

    func body(content: Content) -> some View {
        content
            .background {
                shape.fill(
                    LinearGradient(colors: [skeu.recess, skeu.recessBottom],
                                   startPoint: .top, endPoint: .bottom)
                )
            }
            // The lip, casting down into the channel.
            .innerShadow(shape, color: shadow(0.22), radius: 11.885 * k,
                         offset: CGSize(width: 0, height: 17.828 * k))
            // The far wall, throwing shade back up from the floor. The RADIUS
            // is pulled in hard from the frame's 29.714 — at that spread the
            // blur covers most of a 39.9pt channel and stops being an edge at
            // all. The ALPHA is close to the frame's again: it was taken down
            // with the radius at first, which fixed the smear but left the
            // channel washed out (founder notes 2026-08-13).
            .innerShadow(shape, color: shadow(0.19), radius: 16 * k,
                         offset: CGSize(width: 0, height: -11.885 * k))
            // The two diagonals — these are what round the channel's corners.
            .innerShadow(shape, color: shadow(0.20), radius: 8.217 * k,
                         offset: CGSize(width: 8.217 * k, height: 12.326 * k))
            .innerShadow(shape, color: shadow(0.20), radius: 8.247 * k,
                         offset: CGSize(width: -8.247 * k, height: -2.062 * k))
            // Drawn LAST, over everything: the founder's construction order is
            // bloom → trough → stroke, and the stroke has to sit on top of the
            // inner shadows or the lip loses its edge.
            //
            // A GRADIENT, not a flat colour: dark at the near lip, light at the
            // far one. Figma's code export flattens gradient strokes to a
            // single averaged hex (#85141a) and that average was taken at face
            // value in the first build — flat, it reads as an outline drawn on
            // the surface instead of an edge cut into it.
            .overlay {
                shape.strokeBorder(
                    // Held dark through the top half, then ramped. An even
                    // top-to-bottom ramp spreads the highlight up the sides and
                    // the lit lip stops reading as a lip; the light belongs on
                    // the bottom arc.
                    LinearGradient(
                        stops: [.init(color: skeu.outline, location: 0.0),
                                .init(color: skeu.outline, location: 0.45),
                                .init(color: skeu.outlineBottom, location: 1.0)],
                        startPoint: .top, endPoint: .bottom),
                    lineWidth: max(1, 7 * k))
            }
            .clipShape(shape)
    }

    private func shadow(_ alpha: Double) -> Color {
        skeu.shadow.opacity(alpha * skeu.shadowIntensity)
    }
}

extension View {
    /// Cuts this view's background into the material as a channel.
    /// `height` scales the transcribed inset shadows — pass the real height.
    func skeuTrough<S: InsettableShape>(_ shape: S, height: CGFloat = 56) -> some View {
        modifier(SkeuTrough(shape: shape, height: height))
    }
}
