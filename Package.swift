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
          checksum: "40ec6a392a1aa22b49eed82f563ee395a7672a1cc64ed818f27dd12dcb12e390"
        ),
        .binaryTarget(
          name: "OneSignalExtension",
          url: "https://github.com/OneSignal/OneSignal-XCFramework/releases/download/3.9.1/OneSignalExtension.xcframework.zip",
          checksum: "dae3cc4871ec80919fda2f7c4559f5b79eb55efe1f4bf1f8d41c7a0e7df20e7b"
        ),
        .binaryTarget(
          name: "OneSignalOutcomes",
          url: "https://github.com/OneSignal/OneSignal-XCFramework/releases/download/3.9.1/OneSignalOutcomes.xcframework.zip",
          checksum: "569d2ba216a8d185cf2c6dc7fcda515956771dfa23aba322c4b9be8852faa03c"
        ),
        .binaryTarget(
          name: "OneSignalCore",
          url: "https://github.com/OneSignal/OneSignal-XCFramework/releases/download/3.9.1/OneSignalCore.xcframework.zip",
          checksum: "21393874f707c9e508f6dfe0278821e212f5d4d1206a4c8f1a8c77f8b958a253"
        )
    ]
)

