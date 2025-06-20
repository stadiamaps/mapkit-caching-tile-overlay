import Foundation
import MapKit

/// A generic protocol for MapKit tile overlays which implement their own queryable cache.
///
/// This is useful for making overlays more responsive, and allowing for fallback tiles
/// to be fetched by the renderer while waiting for the higher zoom tiles to load over the network.
/// While technically not required, it's easiest to just sublcass `MKTileOverlay`.
public protocol CachingTileOverlay: MKOverlay {
    /// Fetches a tile from the cache, if present.
    ///
    /// This method should retorn as quickly as possible.
    func cachedData(at path: MKTileOverlayPath) -> Data?
    func loadTile(at path: MKTileOverlayPath) async throws -> Data

    var tileSize: CGSize { get }
}
