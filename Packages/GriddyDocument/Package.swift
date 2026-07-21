// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "GriddyDocument",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .library(name: "GriddyDocument", targets: ["GriddyDocument"])
    ],
    dependencies: [
        .package(path: "../GriddyGeometry"),
        .package(path: "../GriddyConstraints")
    ],
    targets: [
        .target(
            name: "GriddyDocument",
            dependencies: ["GriddyGeometry", "GriddyConstraints"],
            swiftSettings: [
                .defaultIsolation(nil)
            ]
        ),
        .testTarget(
            name: "GriddyDocumentTests",
            dependencies: ["GriddyDocument"],
            swiftSettings: [
                .defaultIsolation(nil)
            ]
        )
    ]
)
