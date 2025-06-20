// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let settings: [SwiftSetting] = [
    .enableExperimentalFeature("StrictConcurrency"),
]

let package = Package(
    name: "CachingMapKitTileOverlay",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
        .watchOS(.v6),
        .tvOS(.v13),
        .visionOS(.v1),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "CachingMapKitTileOverlay",
            targets: ["CachingMapKitTileOverlay"]
        ),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "CachingMapKitTileOverlay",
            swiftSettings: settings
        ),
        .testTarget(
            name: "CachingMapKitTileOverlayTests",
            dependencies: ["CachingMapKitTileOverlay"],
            swiftSettings: settings
        ),
    ]
)
