//
//  InnerShadow.swift
//  shove95
//
//  SwiftUI has no inner shadow, so one is built the standard way: stroke the
//  shape with a thick line, offset it, blur it, then mask it back to the shape
//  so only the part that falls INSIDE survives (§4.5).
//

import SwiftUI

struct InnerShadow<S: Shape>: ViewModifier {
    let shape: S
    let color: Color
    let radius: CGFloat
    let offset: CGSize

    func body(content: Content) -> some View {
        content.overlay {
            shape
                .stroke(color, lineWidth: radius * 2)
                .offset(x: offset.width, y: offset.height)
                .blur(radius: radius)
                .mask(shape.fill())
                .allowsHitTesting(false)
        }
    }
}

extension View {
    func innerShadow<S: Shape>(_ shape: S, color: Color,
                               radius: CGFloat, offset: CGSize) -> some View {
        modifier(InnerShadow(shape: shape, color: color,
                             radius: radius, offset: offset))
    }
}
