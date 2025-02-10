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
