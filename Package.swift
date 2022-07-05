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
                "OneSignalUser",
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
        .target(
            name: "OneSignalUserWrapper",
            dependencies: [
                "OneSignalUser",
                "OneSignalCore"
            ],
            path: "OneSignalUserWrapper"
        ),
        .binaryTarget(
          name: "OneSignal",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/5.0.0/OneSignal.xcframework.zip",
          checksum: "795663c3e45b09952a8943ee7eca7366bc52724ea111ddc6dc683e81c9ed7bf7"
        ),
        .binaryTarget(
          name: "OneSignalExtension",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/5.0.0/OneSignalExtension.xcframework.zip",
          checksum: "878294e61e07fe47baebd09881b4b72f65ce0f2be3f89043ad1babe6b14f529a"
        ),
        .binaryTarget(
          name: "OneSignalOutcomes",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/5.0.0/OneSignalOutcomes.xcframework.zip",
          checksum: "d31f5ee9c53f2c2ac88e57c32c1aaadd1d057c93a4914905b100f55172d4e13a"
        ),
        .binaryTarget(
          name: "OneSignalCore",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/5.0.0/OneSignalCore.xcframework.zip",
          checksum: "61a959657706991c8f2dcc9bae1f82aef62f905548d3d15f760edab321e05d2e"
        ),
        .binaryTarget(
          name: "OneSignalUser",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/5.0.0/OneSignalUser.xcframework.zip",
          checksum: "73a37c45f741641f7464c3bcb4db9687fa46d266187f65b28e9a10531df4dd85"
        )
    ]
)

