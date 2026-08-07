//
//  DemoPhotos.swift
//  shove95
//
//  Drawn, not bundled. The App Store screenshots need photos attached to
//  tasks, and the alternatives were both worse: shipping real image assets
//  bloats the app for something only a debug seed uses, and base64 blobs in
//  source are unreadable. These are drawn at seed time and never ship in a
//  Release build.
//
//  They are the kinds of things this app is actually for — a parcel label, a
//  note from a lecture, a receipt. Not scenery.
//

#if DEBUG
import UIKit

enum DemoPhotos {

    static func parcelLabel() -> Data {
        render(size: CGSize(width: 900, height: 620), background: .init(white: 0.93, alpha: 1)) { ctx, rect in
            UIColor(red: 0.10, green: 0.11, blue: 0.13, alpha: 1).setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: rect.width, height: 150))
            text("PAKETSHOP 4471", at: CGPoint(x: 44, y: 44), size: 58, color: .white, bold: true)
            text("Abholung bis Fr. 18:00", at: CGPoint(x: 44, y: 190), size: 40, color: .darkGray)
            text("Sendung  9F 2244 8817 03", at: CGPoint(x: 44, y: 260), size: 34, color: .darkGray)
            text("Fach  B-14", at: CGPoint(x: 44, y: 320), size: 34, color: .darkGray)
            barcode(in: CGRect(x: 44, y: 400, width: 700, height: 140), ctx: ctx)
        }
    }

    static func lectureNote() -> Data {
        render(size: CGSize(width: 900, height: 640), background: .init(white: 0.97, alpha: 1)) { ctx, rect in
            // Faint ruled lines, like a notebook page photographed badly.
            UIColor(white: 0.85, alpha: 1).setStroke()
            let path = UIBezierPath()
            for y in stride(from: 120.0, to: rect.height, by: 62) {
                path.move(to: CGPoint(x: 40, y: y)); path.addLine(to: CGPoint(x: rect.width - 40, y: y))
            }
            path.lineWidth = 2; path.stroke()

            text("Ergonomie — Klausur", at: CGPoint(x: 52, y: 46), size: 52, color: .black, bold: true)
            text("Perzentile: 5. Frau – 95. Mann", at: CGPoint(x: 52, y: 140), size: 38, color: .init(white: 0.2, alpha: 1))
            text("Greifraum ≠ Greifart", at: CGPoint(x: 52, y: 264), size: 38, color: .init(white: 0.2, alpha: 1))
            text("Belastung → Beanspruchung", at: CGPoint(x: 52, y: 388), size: 38, color: .init(white: 0.2, alpha: 1))
            text("ISO 9241 — 7 Grundsätze", at: CGPoint(x: 52, y: 512), size: 38, color: .init(white: 0.2, alpha: 1))
        }
    }

    static func receipt() -> Data {
        render(size: CGSize(width: 620, height: 820), background: .white) { ctx, rect in
            text("HORNBACH", at: CGPoint(x: 40, y: 40), size: 46, color: .black, bold: true)
            text("München–Freimann", at: CGPoint(x: 40, y: 104), size: 28, color: .darkGray)
            UIColor.black.setFill()
            ctx.fill(CGRect(x: 40, y: 168, width: rect.width - 80, height: 3))

            let items = [("Fahrradlampe LED", "24,99"),
                         ("Halterung 31,8mm", " 6,49"),
                         ("Batterien AA x4", " 5,99")]
            var y = 208.0
            for (name, price) in items {
                text(name, at: CGPoint(x: 40, y: y), size: 30, color: .black)
                text(price, at: CGPoint(x: rect.width - 170, y: y), size: 30, color: .black)
                y += 62
            }
            ctx.fill(CGRect(x: 40, y: y + 14, width: rect.width - 80, height: 3))
            text("SUMME", at: CGPoint(x: 40, y: y + 44), size: 34, color: .black, bold: true)
            text("37,47", at: CGPoint(x: rect.width - 180, y: y + 44), size: 34, color: .black, bold: true)
            barcode(in: CGRect(x: 40, y: y + 140, width: rect.width - 80, height: 90), ctx: ctx)
        }
    }

    // MARK: - Drawing helpers

    private static func render(size: CGSize, background: UIColor,
                               _ body: (CGContext, CGRect) -> Void) -> Data {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)
            background.setFill()
            context.cgContext.fill(rect)
            body(context.cgContext, rect)
        }
        return image.jpegData(compressionQuality: 0.85) ?? Data()
    }

    private static func text(_ string: String, at point: CGPoint, size: CGFloat,
                             color: UIColor, bold: Bool = false) {
        let font = bold ? UIFont.systemFont(ofSize: size, weight: .semibold)
                        : UIFont.systemFont(ofSize: size)
        string.draw(at: point, withAttributes: [.font: font, .foregroundColor: color])
    }

    /// Not a real barcode — just the right rhythm of bars. It only has to read
    /// as "a label with a barcode on it" at thumbnail size.
    private static func barcode(in rect: CGRect, ctx: CGContext) {
        UIColor.black.setFill()
        var x = rect.minX
        var seed = 7
        while x < rect.maxX - 4 {
            seed = (seed &* 31 &+ 17) % 97
            let width = CGFloat(2 + seed % 4)
            if seed % 3 != 0 {
                ctx.fill(CGRect(x: x, y: rect.minY, width: width, height: rect.height))
            }
            x += width + CGFloat(2 + seed % 3)
        }
    }
}
#endif
