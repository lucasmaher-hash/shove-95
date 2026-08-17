//
//  PhotoCache.swift
//  shove95
//
//  Decoded photos, held so a row can be redrawn without re-decoding them.
//
//  `UIImage(data:)` inside a view's body decodes the JPEG every time the body
//  runs — and a body runs often: a press, a swipe, a menu opening, a
//  neighbouring row changing. On a row carrying a photo that showed as a
//  flicker under long-press, because the image was being rebuilt mid-gesture
//  while the row was already animating (founder bug report 2026-08-17).
//
//  An NSCache rather than a dictionary: it empties itself under memory
//  pressure, which is the right behaviour for something that can always be
//  decoded again.
//

import UIKit

@MainActor
enum PhotoCache {
    private static let cache: NSCache<NSData, UIImage> = {
        let c = NSCache<NSData, UIImage>()
        // Generous — a task's photos are already downscaled to 2048px on
        // import, and the cost of a miss is a visible flicker.
        c.countLimit = 120
        return c
    }()

    static func image(_ data: Data) -> UIImage? {
        let key = data as NSData
        if let hit = cache.object(forKey: key) { return hit }
        guard let decoded = UIImage(data: data) else { return nil }
        cache.setObject(decoded, forKey: key)
        return decoded
    }
}
