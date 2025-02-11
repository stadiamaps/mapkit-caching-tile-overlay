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
    /// Returns a new image by cropping to the specified rect (in the image’s coordinate space).
    ///
    /// NOTE: This assumes UIKit coordinates.
    func cropped(to rect: CGRect) -> NSImage? {
        // Create a new image with the desired cropped size.
        let newImage = NSImage(size: rect.size, flipped: true) { rect in
            let drawPoint = CGPoint(x: -rect.origin.x, y: -rect.origin.y)
            self.draw(
                at: drawPoint,
                from: NSRect(origin: .zero, size: self.size),
                operation: .copy,
                fraction: 1.0
            )

            return true
        }

        return newImage
    }
}
#endif
