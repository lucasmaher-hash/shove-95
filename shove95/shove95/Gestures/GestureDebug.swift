//
//  GestureDebug.swift
//  shove95
//
//  On-screen gesture diagnostics for DEBUG builds (simulator log capture is
//  unreliable). Shown in RootView's debug bar.
//

import Foundation
import Observation

@Observable
final class GestureDebug {
    nonisolated(unsafe) static let shared = GestureDebug()
    var last = "no pan events yet"
}
