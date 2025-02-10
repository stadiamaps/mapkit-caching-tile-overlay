import MapKit

/// A tile overlay renderer that uses a custom cache
/// and supports overzooming fallback tiles as the user zooms in.
///
/// This class helps reduce flickering and blank map behavior when zooming
/// which is prevalent in MapKit's MKTileOverlayRenderer.
public class CachingTileOverlayRenderer: MKOverlayRenderer {
    private var loadingTiles = Set<String>()

    public init(overlay: any CachingTileOverlay) {
        super.init(overlay: overlay)
    }

    public override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
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
        let lastCol  = Int(floor((mapRect.maxX - offsetX) / tileMapSize))
        let firstRow = Int(floor((mapRect.origin.y - offsetY) / tileMapSize))
        let lastRow  = Int(floor((mapRect.maxY - offsetY) / tileMapSize))

        // Calculate the current zoom level
        let currentZoom = self.zoomLevel(for: zoomScale)

        // Loop over the tiles that intersect mapRect...
        for x in firstCol...lastCol {
            for y in firstRow...lastRow {
                // Compute the mapRect for this tile
                let tileOriginX = Double(x) * tileMapSize
                let tileOriginY = Double(y) * tileMapSize
                let tileRect = MKMapRect(x: tileOriginX, y: tileOriginY, width: tileMapSize, height: tileMapSize)

                // Create the tile overlay path
                let tilePath = MKTileOverlayPath(x: x, y: y, z: currentZoom, contentScaleFactor: UIScreen.main.scale)

                let drawRect = self.rect(for: tileRect)

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

    func drawImage(_ image: UIImage, in rect: CGRect, context: CGContext) {
        UIGraphicsPushContext(context)

        image.draw(in: rect)

        UIGraphicsPopContext()
    }

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
        guard let overlay = self.overlay as? CachingTileOverlay else { return }

        // Create a unique key for the tile (MKTileOverlayPath is not hashable)
        // and use this to avoid duplicate requests.
        let tileKey = "\(path.z)/\(path.x)/\(path.y)@\(path.contentScaleFactor)"
        guard !loadingTiles.contains(tileKey) else { return }

        loadingTiles.insert(tileKey)

        overlay.loadTile(at: path) { [weak self] data, error in
            guard let self = self else { return }
            self.loadingTiles.remove(tileKey)

            // When the tile has loaded, schedule a redraw of the tile region.
            DispatchQueue.main.async {
                self.setNeedsDisplay(tileMapRect)
            }
        }
    }

    func cachedTileImage(for path: MKTileOverlayPath) -> UIImage? {
        guard let overlay = self.overlay as? CachingTileOverlay else { return nil }
        if let data = overlay.cachedData(at: path) {
            return UIImage(data: data)
        }
        return nil
    }

    /// Attempts to get a fallback tile image from a lower zoom level.
    ///
    /// The idea is to try successively lower zoom levels until we find a tile we have cached,
    /// then use it (optionally scaling it up) until the real tile loads.
    func fallbackTileImage(for path: MKTileOverlayPath) -> UIImage? {
        var fallbackPath = path
        var d = 0
        while fallbackPath.z > 0 && d < 2 {
            d += 1

            // Move one zoom level down.
            fallbackPath.z -= 1
            // Adjust x and y accordingly.
            fallbackPath.x = fallbackPath.x % 2 == 0 ? (fallbackPath.x / 2) : ((fallbackPath.x - 1) / 2)
            fallbackPath.y = fallbackPath.y % 2 == 0 ? (fallbackPath.y / 2) : ((fallbackPath.y - 1) / 2)
            if let image = cachedTileImage(for: fallbackPath) {
                let factor = 1 << d
                let remX = path.x % factor
                let remY = path.y % factor

                let subWidth = image.size.width / CGFloat(factor)
                let subHeight = image.size.height / CGFloat(factor)
                let srcRect = CGRect(x: CGFloat(remX) * subWidth,
                                     y: CGFloat(remY) * subHeight,
                                     width: subWidth,
                                     height: subHeight)

                return image.cropped(to: srcRect)
            }
        }
        return nil
    }
}
