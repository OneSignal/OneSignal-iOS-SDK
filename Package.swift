// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "OneSignal",
    products: [
        .library(
            name: "OneSignal",
            targets: ["OneSignalWrapper"]),
        .library(
            name: "OneSignalExtension",
            targets: ["OneSignalExtensionWrapper"]),
    ],
    targets: [
        .target(
            name: "OneSignalWrapper",
            dependencies: [
                "OneSignal",
                "OneSignalExtension",
                "OneSignalOutcomes",
                "OneSignalCore"
            ],
            path: "OneSignalWrapper"
        ),
        .target(
            name: "OneSignalExtensionWrapper",
            dependencies: [
                "OneSignalExtension",
                "OneSignalOutcomes",
                "OneSignalCore"
            ],
            path: "OneSignalExtensionWrapper"
        ),
        .target(
            name: "OneSignalOutcomesWrapper",
            dependencies: [
                "OneSignalOutcomes",
                "OneSignalCore"
            ],
            path: "OneSignalOutcomesWrapper"
        ),
        .binaryTarget(
          name: "OneSignal",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/3.9.1/OneSignal.xcframework.zip",
          checksum: "7b5f7c306ad2ad4a56d5de3426c220c1ea44417e141b0b132d290bf6a15e7aae"
        ),
        .binaryTarget(
          name: "OneSignalExtension",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/3.9.1/OneSignalExtension.xcframework.zip",
          checksum: "372f8fce6f80d3b6a24c2a4ee883c9ecb7dce3d01c92e347e1a16559834e81c1"
        ),
        .binaryTarget(
          name: "OneSignalOutcomes",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/3.9.1/OneSignalOutcomes.xcframework.zip",
          checksum: "e59761a2c32a0ccf6fa8f059119e962390bbccc5f0786fc0a0cc032dbcff4bc0"
        ),
        .binaryTarget(
          name: "OneSignalCore",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/3.9.1/OneSignalCore.xcframework.zip",
          checksum: "bf61c8bbc856d8ac1d28981542f3cc66294ac75ed4267aae7c05af460dece2ac"
        )
    ]
)

