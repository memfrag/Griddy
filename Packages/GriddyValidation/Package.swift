// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "GriddyValidation",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .library(name: "GriddyValidation", targets: ["GriddyValidation"])
    ],
    dependencies: [
        .package(path: "../GriddyGeometry"),
        .package(path: "../GriddyDocument"),
        .package(path: "../GriddyConstraints"),
        .package(path: "../GriddySymbols")
    ],
    targets: [
        .target(
            name: "GriddyValidation",
            dependencies: ["GriddyGeometry", "GriddyDocument",
                           "GriddyConstraints", "GriddySymbols"],
            swiftSettings: [
                .defaultIsolation(nil)
            ]
        ),
        .testTarget(
            name: "GriddyValidationTests",
            dependencies: ["GriddyValidation", "GriddySymbols"],
            swiftSettings: [
                .defaultIsolation(nil)
            ]
        )
    ]
)
