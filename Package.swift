// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ListKit",
    platforms: [
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
    targets: [
        .target(
            name: "ListKit"
        ),
        .testTarget(
            name: "ListKitTests",
            dependencies: ["ListKit"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
