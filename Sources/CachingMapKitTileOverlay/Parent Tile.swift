import MapKit

extension MKTileOverlayPath {
    var parent: MKTileOverlayPath {
        let newX = x % 2 == 0 ? (x / 2) : ((x - 1) / 2)
        let newY = y % 2 == 0 ? (y / 2) : ((y - 1) / 2)
        return MKTileOverlayPath(x: newX, y: newY, z: z - 1, contentScaleFactor: contentScaleFactor)
    }
}
