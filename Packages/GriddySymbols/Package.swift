// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "GriddySymbols",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .library(name: "GriddySymbols", targets: ["GriddySymbols"])
    ],
    dependencies: [
        .package(path: "../GriddyGeometry"),
        .package(path: "../GriddyDocument")
    ],
    targets: [
        .target(
            name: "GriddySymbols",
            dependencies: ["GriddyGeometry", "GriddyDocument"],
            swiftSettings: [
                .defaultIsolation(nil)
            ]
        ),
        .testTarget(
            name: "GriddySymbolsTests",
            dependencies: ["GriddySymbols"],
            resources: [.copy("Fixtures")],
            swiftSettings: [
                .defaultIsolation(nil)
            ]
        )
    ]
)
