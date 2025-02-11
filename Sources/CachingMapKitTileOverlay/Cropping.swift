#if canImport(UIKit)
import UIKit

extension UIImage {
    /// Returns a new image by cropping to the specified rect (in the image’s point coordinate space).
    func cropped(to rect: CGRect) -> UIImage? {
        // Create an image context of the desired size.
        UIGraphicsBeginImageContextWithOptions(rect.size, false, self.scale)
        // Draw the image, offsetting by the negative origin of the cropping rect.
        self.draw(at: CGPoint(x: -rect.origin.x, y: -rect.origin.y))
        let croppedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return croppedImage
    }
}
#elseif canImport(AppKit)
import AppKit

extension NSImage {
    /// Returns a new image by cropping self to the specified rect.
    /// The cropRect is assumed to be defined in a UIKit-style coordinate system (origin at top‑left).
    func cropped(to cropRect: CGRect) -> NSImage? {
        return NSImage(size: cropRect.size, flipped: true, drawingHandler: { bounds in
            let drawingRect = NSRect(
                x: -cropRect.origin.x,
                y: -cropRect.origin.y,
                width: self.size.width,
                height: self.size.height
            )
            self.draw(in: drawingRect,
                      from: NSRect(origin: .zero, size: self.size),
                      operation: .copy,
                      fraction: 1.0,
                      respectFlipped: true,
                      hints: nil)
            return true
        })
    }
}
#endif
