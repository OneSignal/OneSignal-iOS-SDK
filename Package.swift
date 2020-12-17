// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "OneSignal",
    products: [
        .library(
            name: "OneSignal",
            targets: ["OneSignal"]),
    ],
    targets: [
        .binaryTarget(
          name: "OneSignal",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/3.0.1/OneSignal.xcframework.zip",
          checksum: "3f36d8f8f3bde549ae4409972b09088fe969c1845d3419dccf2e8a56ebeac25f"
        )
    ]
)
