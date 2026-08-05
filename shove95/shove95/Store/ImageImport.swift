//
//  ImageImport.swift
//  shove95
//
//  TASK-043. The one place a photo is turned into bytes we're willing to
//  store. Everything that accepts an image — library picker, camera — goes
//  through `prepare`.
//
//  Budget: a 48MP HDR photo must land under ~1.5MB, because these rows sync
//  through CloudKit in Phase 5 and a fat blob per task is what makes a sync
//  feel broken.
//

import UIKit

enum ImageImport {
    /// Longest edge after downscale, in pixels.
    static let maxEdge: CGFloat = 2048
    /// JPEG quality — 0.8 is the knee: below it artefacts show on flat skies.
    static let quality: CGFloat = 0.8

    /// Decode → downscale → re-encode. Returns nil on anything unreadable;
    /// callers leave the task untouched rather than showing an error, because
    /// a failed import is not worth a modal (PRD edge cases).
    static func prepare(_ data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }

        let longEdge = max(image.size.width, image.size.height)
        let scale = min(1, maxEdge / max(longEdge, 1))
        let target = CGSize(width: (image.size.width * scale).rounded(),
                            height: (image.size.height * scale).rounded())
        guard target.width >= 1, target.height >= 1 else { return nil }

        // Drawing bakes EXIF orientation into the pixels, so a photo taken
        // sideways stays upright everywhere downstream.
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1 // target is already in pixels
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: target, format: format)
        let flattened = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return flattened.jpegData(compressionQuality: quality)
    }
}
