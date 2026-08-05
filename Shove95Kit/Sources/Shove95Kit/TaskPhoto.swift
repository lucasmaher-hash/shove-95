import Foundation
import SwiftData

/// One attached photo. A separate entity purely so it can SYNC: as a field on
/// TaskItem an array of image blobs serialises into a single value, and a
/// CKRecord caps non-asset payload at 1MB — two photos would have broken sync
/// with no error surfaced. Here `data` maps to a CKAsset instead.
///
/// CloudKit-compatible by construction, like TaskItem: every property
/// defaulted or optional, the inverse relationship optional, no `#Unique`.
@Model
public final class TaskPhoto {
    public var id: UUID = UUID()
    /// Position in the strip, left to right. Sparse values are fine — only the
    /// ordering matters, so removing one never renumbers the rest.
    public var order: Int = 0
    @Attribute(.externalStorage) public var data: Data? = nil
    public var createdAt: Date = Date.now
    /// Inverse of `TaskItem.photos`. Optional because CloudKit requires it.
    public var task: TaskItem? = nil

    public init() {}
}
