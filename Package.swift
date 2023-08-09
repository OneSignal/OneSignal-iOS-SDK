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
            targets: ["OneSignalExtensionWrapper"])
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
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/3.12.6/OneSignal.xcframework.zip",
          checksum: "48d79753e67f2ad802e1cc738dbdce1a2d24517f9812e67d76c2387965bc9c5d"
        ),
        .binaryTarget(
          name: "OneSignalExtension",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/3.12.6/OneSignalExtension.xcframework.zip",
          checksum: "22d050a8e2d41dd7cea7331bf98363ff264c38175128df0f14a3c7d86c8156ae"
        ),
        .binaryTarget(
          name: "OneSignalOutcomes",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/3.12.6/OneSignalOutcomes.xcframework.zip",
          checksum: "4d6e08640dc49986424caa0163afa022faa4020dc4e642812fc9a04d57dca12b"
        ),
        .binaryTarget(
          name: "OneSignalCore",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/3.12.6/OneSignalCore.xcframework.zip",
          checksum: "0b9ac1abd8fb242be1597939fbd3d6b807bad15253c22bea05936789cd0fbd6b"
        )
    ]
)
