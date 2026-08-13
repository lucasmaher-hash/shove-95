//
//  SkeuEnvironment.swift
//  shove95
//
//  Environment injection (§2.6). This is the ONLY permitted way for a component
//  to read colour:
//
//      @Environment(\.skeu) private var skeu
//      Text("Hello").foregroundStyle(skeu.ink)
//
//  Note the contrast with the Win95 side, which reads its palette from statics
//  (`Win95.surface`) and has to force redraws with `.id(scheme.id)`. SkeuKit
//  goes through the environment, so SwiftUI sees the dependency and repaints on
//  its own — no rebuild hack needed anywhere in the skeu tree.
//

import SwiftUI

extension EnvironmentValues {
    /// The active palette. Default is the shipping theme (§2.4).
    @Entry var skeu: SkeuPalette = .cream
}

extension View {
    /// Re-skins this subtree. Changing only this call must re-theme every screen
    /// correctly — that is the acceptance test for the whole system.
    func skeuTheme(_ palette: SkeuPalette) -> some View {
        environment(\.skeu, palette)
    }
}
