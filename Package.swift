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
          url: "https://github.com/OneSignal/OneSignal-XCFramework/releases/download/3.9.1/OneSignal.xcframework.zip",
          checksum: "4445e4d3e0b92cae55602415c43d07ff1de0f8ab81f83c1a54f0094848988a47"
        ),
        .binaryTarget(
          name: "OneSignalExtension",
          url: "https://github.com/OneSignal/OneSignal-XCFramework/releases/download/3.9.1/OneSignalExtension.xcframework.zip",
          checksum: "15431226ccb672a5d2eff6dfde7b7b32af7e378f5a71ea36dc3d2396c0cb8f3a"
        ),
        .binaryTarget(
          name: "OneSignalOutcomes",
          url: "https://github.com/OneSignal/OneSignal-XCFramework/releases/download/3.9.1/OneSignalOutcomes.xcframework.zip",
          checksum: "a0c123ddf3dbee1696674d8129d795e8a5e60704ae2a0c0d9a2025245046956a"
        ),
        .binaryTarget(
          name: "OneSignalCore",
          url: "https://github.com/OneSignal/OneSignal-XCFramework/releases/download/3.9.1/OneSignalCore.xcframework.zip",
          checksum: "338da36a9b097178b31e14eb6f3eea97594db2dc5786e75ed4e56ac1f344be07"
        )
    ]
)

