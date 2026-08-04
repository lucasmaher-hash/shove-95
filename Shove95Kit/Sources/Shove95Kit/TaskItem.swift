import Foundation
import SwiftData

/// The one entity (PRD §3). CloudKit-compatible by construction:
/// every stored property is defaulted or optional, no `#Unique`,
/// no relationships. NEVER name this `Task` — it collides with
/// Swift Concurrency.
@Model
public final class TaskItem {
    public var id: UUID = UUID()
    public var title: String = ""
    /// Start-of-day date this task is scheduled for. nil = General (dateless).
    public var dueDate: Date? = nil
    public var isImportant: Bool = false
    public var isCompleted: Bool = false
    /// Set when ticked; cleared when unticked. Drives archive visibility.
    public var completedAt: Date? = nil
    public var createdAt: Date = Date.now
    /// Global manual ordering. Placement rules assign it once on events;
    /// drag-reorder mutates it. Fractional (midpoint) inserts.
    public var sortOrder: Double = 0
    /// True once the day-rollover pass has positioned this task in Today's
    /// overdue block. Reset whenever `dueDate` changes, so a re-deferred task
    /// gets placed again the next time it goes overdue. Prevents re-placing a
    /// task the user has dragged (PRD §3 placement table).
    public var overduePlaced: Bool = false
    /// First photo (legacy slot — kept so pre-multi-photo tasks need no
    /// migration). Downscaled on import: ≤2048px long edge, JPEG q0.8.
    @Attribute(.externalStorage) public var photoData: Data? = nil
    /// Additional photos, in the order they were added (they render to the
    /// RIGHT of earlier ones). Defaulted, so the store migrates lightweight.
    /// CloudKit note for Phase 5: an array of Data does not become CKAssets —
    /// if records exceed 1MB this needs restructuring into a child entity.
    public var extraPhotos: [Data] = []
    /// Which workspace this task lives in. nil = the default workspace, which
    /// is also what every pre-workspace task migrates to (optional + defaulted
    /// keeps the model CloudKit-compatible and the store migration lightweight).
    public var workspaceID: String? = nil

    public init() {}

    /// Every photo, oldest first. The legacy single slot leads.
    public var allPhotos: [Data] {
        (photoData.map { [$0] } ?? []) + extraPhotos
    }

    /// Appends to the end — new photos appear to the right of existing ones.
    public func addPhoto(_ data: Data) {
        if photoData == nil && extraPhotos.isEmpty {
            photoData = data
        } else {
            extraPhotos.append(data)
        }
    }
}
