import Foundation

/// The three time buckets, ordered as the line `today → tomorrow → general`.
///
/// `week` was removed on 2026-08-17 (founder direction). It was never storage
/// — a task dated four days out simply reports `general` now and KEEPS its
/// date, so the chip still says "Fri" and the rollover still walks it into
/// Tomorrow and then Today when its day arrives. Nothing was lost but a tab.
/// Buckets are *filters over a task's date*, never storage (PRD §3).
public enum Bucket: String, CaseIterable, Sendable, Codable {
    case today
    case tomorrow
    case general

    /// The line, in order. `CaseIterable` order is the source of truth.
    public static let line: [Bucket] = Bucket.allCases

    public var displayName: String {
        switch self {
        case .today: "Today"
        case .tomorrow: "Tomorrow"
        // "Soon", not "General" (founder direction 2026-08-17). The tab holds
        // the undated AND everything scheduled past tomorrow, so it is about
        // WHEN rather than about being unclassified.
        case .general: "Soon"
        }
    }

    /// Abbreviated taskbar label for the 4× accessibility scale (FR-015).
    public var shortName: String {
        switch self {
        case .today: "Tod"
        case .tomorrow: "Tom"
        case .general: "Soon"
        }
    }
}

/// Direction of a one-step move along the line (PRD §4).
public enum StepDirection: Sendable {
    /// One step toward `general` (swipe left).
    case deferOne
    /// One step toward `today` (swipe right).
    case pullOne
}

extension Bucket {
    /// The bucket one step along the line, or nil at a dead end
    /// (deferring from `general`, pulling from `today`) — caller rubber-bands (FR-002).
    public func steppedOnce(_ direction: StepDirection) -> Bucket? {
        let i = Bucket.line.firstIndex(of: self)!
        switch direction {
        case .deferOne:
            return i + 1 < Bucket.line.count ? Bucket.line[i + 1] : nil
        case .pullOne:
            return i > 0 ? Bucket.line[i - 1] : nil
        }
    }

    /// A labeled context-menu move destination (PRD §3).
    public struct MenuDestination: Equatable, Sendable {
        public let label: String
        public let bucket: Bucket
        public init(label: String, bucket: Bucket) {
            self.label = label
            self.bucket = bucket
        }
    }

    /// Context-menu move entries: only destinations a single swipe can't reach
    /// (adjacent buckets are excluded). Arrows point in the direction of travel
    /// (`<` toward Today, `>` toward General); one arrow for the nearer shown
    /// destination, two for the further. Locked table from PRD §3:
    ///
    ///   today    → `>> Soon`
    ///   tomorrow → (nothing: both neighbours are one swipe away)
    ///   general  → `<< Today`
    public var menuDestinations: [MenuDestination] {
        switch self {
        case .today:
            [MenuDestination(label: ">> Soon", bucket: .general)]
        case .tomorrow:
            []
        case .general:
            [MenuDestination(label: "<< Today", bucket: .today)]
        }
    }
}
