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
            name: "OneSignalInAppMessages",
            targets: ["OneSignalInAppMessagesWrapper"]),
        .library(
            name: "OneSignalLocation",
            targets: ["OneSignalLocationWrapper"]),
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
                "OneSignalLiveActivities",
                "OneSignalExtension",
                "OneSignalOutcomes",
                "OneSignalOSCore",
                "OneSignalCore"
            ],
            path: "OneSignalFrameworkWrapper"
        ),
        .target(
            name: "OneSignalInAppMessagesWrapper",
            dependencies: [
                "OneSignalInAppMessages",
                "OneSignalUser",
                "OneSignalNotifications",
                "OneSignalOutcomes",
                "OneSignalOSCore",
                "OneSignalCore"
            ],
            path: "OneSignalInAppMessagesWrapper"
        ),
        .target(
            name: "OneSignalLocationWrapper",
            dependencies: [
                "OneSignalLocation",
                "OneSignalUser",
                "OneSignalNotifications",
                "OneSignalOSCore",
                "OneSignalCore"
            ],
            path: "OneSignalLocationWrapper"
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
        .target(
            name: "OneSignalLiveActivitiesWrapper",
            dependencies: [
                "OneSignalUser",
                "OneSignalCore"
            ],
            path: "OneSignalLiveActivitiesWrapper"
        ),
        .binaryTarget(
          name: "OneSignalFramework",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/5.4.0-alpha-01/OneSignalFramework.xcframework.zip",
          checksum: "a435cec39a3e476ac58daa9b84b771ec256bf4690dc31432da08feced001122b"
        ),
        .binaryTarget(
          name: "OneSignalInAppMessages",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/5.4.0-alpha-01/OneSignalInAppMessages.xcframework.zip",
          checksum: "44240b80237b7c3e96ee1694d4d197c8431d4ba259668f28ab5f2d6807d6403d"
        ),
        .binaryTarget(
          name: "OneSignalLocation",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/5.4.0-alpha-01/OneSignalLocation.xcframework.zip",
          checksum: "23e5daedb9b2a157626d9838d10f74d69257dcc8ef3523dc6e723a8dcc4ccefb"
        ),
        .binaryTarget(
          name: "OneSignalUser",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/5.4.0-alpha-01/OneSignalUser.xcframework.zip",
          checksum: "24b0a68fc384cd02a0b466f56bbf4fb24b6f5c001b45e0945c2e5230987bf498"
        ),
        .binaryTarget(
          name: "OneSignalNotifications",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/5.4.0-alpha-01/OneSignalNotifications.xcframework.zip",
          checksum: "f8875b93de79fc85de6275cda63235bb7b866edce94d3e9bb05a7281ce326c12"
        ),
        .binaryTarget(
          name: "OneSignalExtension",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/5.4.0-alpha-01/OneSignalExtension.xcframework.zip",
          checksum: "da447208c073693abf96d914a19a73a8e5683d7eb69b35a707b924d563019322"
        ),
        .binaryTarget(
          name: "OneSignalOutcomes",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/5.4.0-alpha-01/OneSignalOutcomes.xcframework.zip",
          checksum: "88fe91fc35e67d9b36d71333654df686b190ae197e68f5a090e912f06f15442b"
        ),
        .binaryTarget(
          name: "OneSignalOSCore",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/5.4.0-alpha-01/OneSignalOSCore.xcframework.zip",
          checksum: "ab4f2ff0677a3f6448f07558506ed17d0e04a43337bcb15fe0fe7c0765308d03"
        ),
        .binaryTarget(
          name: "OneSignalCore",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/5.4.0-alpha-01/OneSignalCore.xcframework.zip",
          checksum: "0e7d623ed9f8b20d2761af77816d3383f5cbe08b41ee2083cceb5c43fcf4f91c"
        ),
        .binaryTarget(
          name: "OneSignalLiveActivities",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/5.4.0-alpha-01/OneSignalLiveActivities.xcframework.zip",
          checksum: "6db77e1030276fec416a0a2d89af21d929948df283ea2bfefe3c1ed28728d85e"
        )
    ]
)
