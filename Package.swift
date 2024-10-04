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
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/5.3.0-beta-01/OneSignalFramework.xcframework.zip",
          checksum: "3c624e4652257bc8caf3839d5712d6240458ee4209859a36c757caabea25d540"
        ),
        .binaryTarget(
          name: "OneSignalInAppMessages",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/5.3.0-beta-01/OneSignalInAppMessages.xcframework.zip",
          checksum: "1ad9dd8eaae601de4a95ef69ed85bff54a26426cb01fb115e7a7627a34101ad4"
        ),
        .binaryTarget(
          name: "OneSignalLocation",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/5.3.0-beta-01/OneSignalLocation.xcframework.zip",
          checksum: "a27149012543cd9a37590efc478b6be78143e2c8d050fe9bc9d74f1a1b81c702"
        ),
        .binaryTarget(
          name: "OneSignalUser",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/5.3.0-beta-01/OneSignalUser.xcframework.zip",
          checksum: "8310477ce98babbc7e8cd78bf82e672a4b735752ab6d117019c4d7d808e67e9b"
        ),
        .binaryTarget(
          name: "OneSignalNotifications",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/5.3.0-beta-01/OneSignalNotifications.xcframework.zip",
          checksum: "9b1bbba1e4750be9b6a25015e60fd8b519dc5fbca27c6bf310c2d7e2494ce776"
        ),
        .binaryTarget(
          name: "OneSignalExtension",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/5.3.0-beta-01/OneSignalExtension.xcframework.zip",
          checksum: "28a7fa28b8f6b7eaad9af269f76b4aa12c84223db340f568ad5c461077dfabb3"
        ),
        .binaryTarget(
          name: "OneSignalOutcomes",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/5.3.0-beta-01/OneSignalOutcomes.xcframework.zip",
          checksum: "dcfc10935e3f43ddfb89f4f611598bceabdab28038a3904c714941a0af8ca279"
        ),
        .binaryTarget(
          name: "OneSignalOSCore",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/5.3.0-beta-01/OneSignalOSCore.xcframework.zip",
          checksum: "cbe78142acaff003f3a369a26bc62a14681423ce9d4f4a009b5773ee2fa3db3a"
        ),
        .binaryTarget(
          name: "OneSignalCore",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/5.3.0-beta-01/OneSignalCore.xcframework.zip",
          checksum: "61efa7bc0a6a4a317f0a3894181e13bb6fd0e0b3761834c24b3f83b6249c0543"
        ),
        .binaryTarget(
          name: "OneSignalLiveActivities",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/5.3.0-beta-01/OneSignalLiveActivities.xcframework.zip",
          checksum: "987ea4d56e8ea79c24a087e40370fe93534b92a09568e9f85c8e68a230ec04f7"
        )
    ]
)
