// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "OneSignalFramework",
    products: [
        .library(
            name: "OneSignalFramework",
            targets: ["OneSignalFrameworkWrapper"]),
        .library(
            name: "OneSignalExtension",
            targets: ["OneSignalExtensionWrapper"])
    ],
    targets: [
        .target(
            name: "OneSignalFrameworkWrapper",
            dependencies: [
                "OneSignalFramework",
                "OneSignalUser",
                "OneSignalNotifications",
                "OneSignalExtension",
                "OneSignalOutcomes",
                "OneSignalOSCore",
                "OneSignalCore"
            ],
            path: "OneSignalFrameworkWrapper"
        ),
        .target(
            name: "OneSignalUserWrapper",
            dependencies: [
                "OneSignalUser",
                "OneSignalNotifications",
                "OneSignalExtension",
                "OneSignalOutcomes",
                "OneSignalOSCore",
                "OneSignalCore"
            ],
            path: "OneSignalUserWrapper"
        ),
        .target(
            name: "OneSignalNotificationsWrapper",
            dependencies: [
                "OneSignalNotifications",
                "OneSignalExtension",
                "OneSignalOutcomes",
                "OneSignalCore"
            ],
            path: "OneSignalNotificationsWrapper"
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
            name: "OneSignalOSCoreWrapper",
            dependencies: [
                "OneSignalOSCore",
                "OneSignalCore"
            ],
            path: "OneSignalOSCoreWrapper"
        ),
        .binaryTarget(
          name: "OneSignalFramework",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/5.0.0-beta-02/OneSignalFramework.xcframework.zip",
          checksum: "ac54ab258ed1c05fe148a4e897f5f6c5586c1a4ff8a3a54695edf98115e2bc10"
        ),
        .binaryTarget(
          name: "OneSignalUser",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/5.0.0-beta-02/OneSignalUser.xcframework.zip",
          checksum: "1517a07d0f4f3d4f530d0f8517c1502197352040b87fa0b7a83e00ba7d8cc436"
        ),
        .binaryTarget(
          name: "OneSignalNotifications",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/5.0.0-beta-02/OneSignalNotifications.xcframework.zip",
          checksum: "cf9213fdd4a542f2f58c6a8f28954ea5ad1b2157937b2c6ee3638f547b51bfb1"
        ),
        .binaryTarget(
          name: "OneSignalExtension",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/5.0.0-beta-02/OneSignalExtension.xcframework.zip",
          checksum: "2c641ae706d5468daff8ee4a05d66af56b5d690c50daaca071e5adde7ca04f8d"
        ),
        .binaryTarget(
          name: "OneSignalOutcomes",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/5.0.0-beta-02/OneSignalOutcomes.xcframework.zip",
          checksum: "dd82376dbf772d535007d8fdd49ae39b439f1c2e3fe6f2d753852a0205b8733a"
        ),
        .binaryTarget(
          name: "OneSignalOSCore",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/5.0.0-beta-02/OneSignalOSCore.xcframework.zip",
          checksum: "f06b75928922345f3def0466b23e7e51861394528dc767b366db59b611be2165"
        ),
        .binaryTarget(
          name: "OneSignalCore",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/5.0.0-beta-02/OneSignalCore.xcframework.zip",
          checksum: "a84b073a6b9d59c0737b728177e5a939f572da9368853213e303a476c8df9ea9"
        )
    ]
)
