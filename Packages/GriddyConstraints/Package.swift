// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "GriddyConstraints",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .library(name: "GriddyConstraints", targets: ["GriddyConstraints"])
    ],
    dependencies: [
        .package(path: "../GriddyGeometry")
    ],
    targets: [
        .target(
            name: "GriddyConstraints",
            dependencies: ["GriddyGeometry"],
            swiftSettings: [
                .defaultIsolation(nil)
            ]
        ),
        .testTarget(
            name: "GriddyConstraintsTests",
            dependencies: ["GriddyConstraints"],
            swiftSettings: [
                .defaultIsolation(nil)
            ]
        )
    ]
)
