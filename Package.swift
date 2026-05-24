// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ListKit",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v16),
        .macCatalyst(.v16),
        .tvOS(.v16),
    ],
    products: [
        .library(
            name: "ListKit",
            targets: ["ListKit"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/ra1028/DifferenceKit.git", from: "1.3.0"),
    ],
    targets: [
        .target(
            name: "ListKit",
            dependencies: [
                .product(name: "DifferenceKit", package: "DifferenceKit"),
            ]
        ),
        .testTarget(
            name: "ListKitTests",
            dependencies: ["ListKit"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
