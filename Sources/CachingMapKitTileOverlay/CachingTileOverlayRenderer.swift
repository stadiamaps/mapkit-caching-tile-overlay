import MapKit

#if canImport(UIKit)
    typealias ImageType = UIImage
#elseif canImport(AppKit)
    typealias ImageType = NSImage
#endif

/// A tile overlay renderer that uses a custom cache
/// and supports overzooming fallback tiles as the user zooms in.
///
/// This class helps reduce flickering and blank map behavior when zooming
/// which is prevalent in MapKit's MKTileOverlayRenderer.
public class CachingTileOverlayRenderer: MKOverlayRenderer {
    private var loadingTiles = AtomicSet<String>()

    public init(overlay: any CachingTileOverlay) {
        super.init(overlay: overlay)
    }

    override public func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        // Shift the type; our constructor ensures we can't get this wrong by accident though.
        guard let tileOverlay = overlay as? CachingTileOverlay else {
            fatalError("The overlay must implement MKCachingTileOverlay")
        }

        let overlayRect = overlay.boundingMapRect

        let tileSizePoints = tileOverlay.tileSize.width
        let tileMapSize = Double(tileSizePoints) / Double(zoomScale)

        // Calculate the starting tile indices
        let offsetX = overlayRect.origin.x
        let offsetY = overlayRect.origin.y

        let firstCol = Int(floor((mapRect.origin.x - offsetX) / tileMapSize))
        let lastCol = Int(floor((mapRect.maxX - offsetX) / tileMapSize))
        let firstRow = Int(floor((mapRect.origin.y - offsetY) / tileMapSize))
        let lastRow = Int(floor((mapRect.maxY - offsetY) / tileMapSize))

        // Calculate the current zoom level
        let currentZoom = zoomLevel(for: zoomScale)

        // Loop over the tiles that intersect mapRect...
        for x in firstCol ... lastCol {
            for y in firstRow ... lastRow {
                // Compute the mapRect for this tile
                let tileOriginX = Double(x) * tileMapSize
                let tileOriginY = Double(y) * tileMapSize
                let tileRect = MKMapRect(x: tileOriginX, y: tileOriginY, width: tileMapSize, height: tileMapSize)

                // Create the tile overlay path
                let tilePath = MKTileOverlayPath(x: x, y: y, z: currentZoom, contentScaleFactor: contentScaleFactor)

                let drawRect = rect(for: tileRect)

                if let image = cachedTileImage(for: tilePath) {
                    // If we have a cached image for this tile, just draw it!
                    drawImage(image, in: drawRect, context: context)
                } else if let fallbackImage = fallbackTileImage(for: tilePath) {
                    // If we have a fallback image, draw that instead to start.
                    drawImage(fallbackImage, in: drawRect, context: context)

                    // Then, load the tile from the cache (if necessary)
                    loadTileIfNeeded(for: tilePath, in: tileRect)
                } else {
                    // Total cache miss; load the tile
                    loadTileIfNeeded(for: tilePath, in: tileRect)
                }
            }
        }
    }

    //
    // Internal helpers
    //

    /// Approximates a zoom level from the current zoomScale.
    ///
    /// There’s no public API to convert zoomScale to a “zoom level,” but this works well enough.
    func zoomLevel(for zoomScale: MKZoomScale) -> Int {
        let tileOverlay = overlay as! CachingTileOverlay
        let numTiles = MKMapSize.world.width / Double(tileOverlay.tileSize.width)
        // Adjust for the current zoomScale. (This formula is an approximation.)
        let zoomLevel = max(0, Int(log2(numTiles) + floor(log2(Double(zoomScale)) + 0.5)))

        return zoomLevel
    }

    func loadTileIfNeeded(for path: MKTileOverlayPath, in tileMapRect: MKMapRect) {
        guard let overlay = overlay as? CachingTileOverlay else { return }

        // Create a unique key for the tile (MKTileOverlayPath is not hashable)
        // and use this to avoid duplicate requests.
        let tileKey = "\(path.z)/\(path.x)/\(path.y)@\(path.contentScaleFactor)"
        guard !loadingTiles.contains(tileKey) else { return }

        loadingTiles.insert(tileKey)

        Task { [weak self] in
            _ = try? await overlay.loadTile(at: path)
            self?.loadingTiles.remove(tileKey)

            // When the tile has loaded, schedule a redraw of the tile region.
            self?.setNeedsDisplay(tileMapRect)
        }
    }

    func cachedTileImage(for path: MKTileOverlayPath) -> ImageType? {
        guard let overlay = overlay as? CachingTileOverlay else { return nil }
        if let data = overlay.cachedData(at: path) {
            return ImageType(data: data)
        }
        return nil
    }

    /// Attempts to get a fallback tile image from a lower zoom level.
    ///
    /// The idea is to try successively lower zoom levels until we find a tile we have cached,
    /// then use it until the real tile loads.
    func fallbackTileImage(for path: MKTileOverlayPath) -> ImageType? {
        var fallbackPath = path
        var d = 0
        while fallbackPath.z > 0 && d < 2 {
            d += 1
            fallbackPath = fallbackPath.parent

            if let image = cachedTileImage(for: fallbackPath) {
                let srcRect = cropRect(d: d, originalPath: path, imageSize: image.size)

                return image.cropped(to: srcRect)
            }
        }
        return nil
    }

    func drawImage(_ image: ImageType, in rect: CGRect, context: CGContext) {
        #if canImport(UIKit)
            UIGraphicsPushContext(context)

            image.draw(in: rect)

            UIGraphicsPopContext()
        #elseif canImport(AppKit)
            let graphicsContext = NSGraphicsContext(cgContext: context, flipped: true)

            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = graphicsContext
            image.draw(in: rect)
            NSGraphicsContext.restoreGraphicsState()
        #endif
    }
}

private func cropRect(d: Int, originalPath: MKTileOverlayPath, imageSize: CGSize) -> CGRect {
    let factor = 1 << d
    let remX = originalPath.x % factor
    let remY = originalPath.y % factor

    let subWidth = imageSize.width / CGFloat(factor)
    let subHeight = imageSize.height / CGFloat(factor)
    return CGRect(x: CGFloat(remX) * subWidth,
                  y: CGFloat(remY) * subHeight,
                  width: subWidth,
                  height: subHeight)
}
