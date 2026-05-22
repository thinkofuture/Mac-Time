import AppKit
import SwiftUI

extension NSImage {
    var averageColor: Color? {
        let targetSize = NSSize(width: 1, height: 1)
        let image = NSImage(size: targetSize)

        image.lockFocus()
        draw(
            in: NSRect(origin: .zero, size: targetSize),
            from: NSRect(origin: .zero, size: size),
            operation: .copy,
            fraction: 1.0
        )
        image.unlockFocus()

        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let color = bitmap.colorAt(x: 0, y: 0) else {
            return nil
        }

        return Color(nsColor: color)
    }
}

