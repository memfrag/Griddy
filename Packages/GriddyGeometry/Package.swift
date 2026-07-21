// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "GriddyGeometry",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .library(name: "GriddyGeometry", targets: ["GriddyGeometry"])
    ],
    targets: [
        .target(
            name: "GriddyGeometry",
            dependencies: [],
            swiftSettings: [
                // The app target builds with SWIFT_DEFAULT_ACTOR_ISOLATION =
                // MainActor. Geometry must be free of that default so it can
                // run off the main actor for Tier 2 validation. See spec 16.1.
                .defaultIsolation(nil)
            ]
        ),
        .testTarget(
            name: "GriddyGeometryTests",
            dependencies: ["GriddyGeometry"],
            swiftSettings: [
                .defaultIsolation(nil)
            ]
        )
    ]
)
