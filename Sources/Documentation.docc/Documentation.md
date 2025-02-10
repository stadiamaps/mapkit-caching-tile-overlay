# ``CachingMapKitTileOverlay``

A MapKit overlay renderer and associated protocol
that addresses bugs and shortcomings of `MKTileOverlayRenderer`.
If you're having issues with your tile overlays flickering,
or wish they would overzoom existing tiles while loading instead of showing a blank,
you're in the right place!

## Overview

Here's an example of a custom overlay:

```swift
class SatelliteTileOverlay: MKTileOverlay {
    let apiKey: String
    // Disk cache of 100MB
    let cache = URLCache(memoryCapacity: 25 * 1024 * 1024, diskCapacity: 100 * 1024 * 1024)
    let urlSession: URLSession

    init(apiKey: String) {
        self.apiKey = apiKey

        let configuration = URLSessionConfiguration.default
        configuration.urlCache = cache
        self.urlSession = URLSession(configuration: configuration)

        super.init(urlTemplate: nil)

        self.maximumZ = 20
        self.canReplaceMapContent = true
    }

    override func url(forTilePath path: MKTileOverlayPath) -> URL {
        let scale = path.contentScaleFactor > 1 ? "@2x" : ""

        return URL(string: "https://tiles.stadiamaps.com/tiles/alidade_satellite/\(path.z)/\(path.x)/\(path.y)\(scale).png?api_key=\(apiKey)")!
    }

    override func loadTile(at path: MKTileOverlayPath, result: @escaping (Data?, (any Error)?) -> Void) {
        let url = self.url(forTilePath: path)
        let request = URLRequest(url: url, cachePolicy: .useProtocolCachePolicy)

        if let response = cache.cachedResponse(for: request) {
            result(response.data, nil)
            return
        }

        urlSession.dataTask(with: request) { data, _, error in
            result(data, error)
        }.resume()
    }
}

extension StadiaMapsOverlay: CachingTileOverlay {
    func cachedData(at path: MKTileOverlayPath) -> Data? {
        cache.cachedResponse(for: URLRequest(url: self.url(forTilePath: path)))?.data
    }
}
```

You can use this with your `MKMapView` like so:

```swift
import UIKit
import MapKit

let stadiaApiKey = "YOUR-API-KEY"
class ViewController: UIViewController {

    @IBOutlet var mapView: MKMapView!

    override func viewDidLoad() {
        super.viewDidLoad()

        let overlay = SatelliteTileOverlay(apiKey: stadiaApiKey)
        mapView.addOverlay(overlay, level: .aboveLabels)
    }
}

extension ViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let cachingOverlay = overlay as? CachingTileOverlay {
            return CachingTileOverlayRenderer(overlay: cachingOverlay)
        } else {
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}
```

## Topics

- ``CachingTileOverlay``
- ``CachingTileOverlayRenderer``
