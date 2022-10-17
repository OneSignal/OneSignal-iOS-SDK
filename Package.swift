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
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/3.11.3/OneSignal.xcframework.zip",
          checksum: "fc0b8a39c68113297ec5b87617056d26d262b5c82ae47df52a9ca6e2de07d841"
        ),
        .binaryTarget(
          name: "OneSignalExtension",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/3.11.3/OneSignalExtension.xcframework.zip",
          checksum: "acdcaf4daf9f386340619160e1660d10b0347ea7a78ab4f5f4c5d9c5b6d974fa"
        ),
        .binaryTarget(
          name: "OneSignalOutcomes",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/3.11.3/OneSignalOutcomes.xcframework.zip",
          checksum: "a3adb9a69aad90b193062bd7911cdd0b63c6b40b3f91e71cc36f1c62927e0090"
        ),
        .binaryTarget(
          name: "OneSignalCore",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/3.11.3/OneSignalCore.xcframework.zip",
          checksum: "76ecb5ed39d25544543408a35e071bea8904883ce568ae977f8037e894a2e630"
        )
    ]
)
