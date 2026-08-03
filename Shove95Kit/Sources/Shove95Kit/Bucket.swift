import Foundation

/// The four time buckets, ordered as the line `today → tomorrow → week → general`.
/// Buckets are *filters over a task's date*, never storage (PRD §3).
public enum Bucket: String, CaseIterable, Sendable, Codable {
    case today
    case tomorrow
    case week
    case general

    /// The line, in order. `CaseIterable` order is the source of truth.
    public static let line: [Bucket] = Bucket.allCases

    public var displayName: String {
        switch self {
        case .today: "Today"
        case .tomorrow: "Tomorrow"
        case .week: "Week"
        case .general: "General"
        }
    }

    /// Abbreviated taskbar label for the 4× accessibility scale (FR-015).
    public var shortName: String {
        switch self {
        case .today: "Tod"
        case .tomorrow: "Tom"
        case .week: "Wk"
        case .general: "Gen"
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
    ///   today    → `> Week`, `>> General`
    ///   tomorrow → `> General`
    ///   week     → `< Today`
    ///   general  → `< Tomorrow`, `<< Today`
    public var menuDestinations: [MenuDestination] {
        switch self {
        case .today:
            [MenuDestination(label: "> Week", bucket: .week),
             MenuDestination(label: ">> General", bucket: .general)]
        case .tomorrow:
            [MenuDestination(label: "> General", bucket: .general)]
        case .week:
            [MenuDestination(label: "< Today", bucket: .today)]
        case .general:
            [MenuDestination(label: "< Tomorrow", bucket: .tomorrow),
             MenuDestination(label: "<< Today", bucket: .today)]
        }
    }
}
