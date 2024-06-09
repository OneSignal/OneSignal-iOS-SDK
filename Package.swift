// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "OneSignalXCFramework",
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
          url: "https://github.com/OneSignal/OneSignal-XCFramework/releases/download/5.1.4/OneSignalFramework.xcframework.zip",
          checksum: "603beecbcc83bd9cba00c752323ca43852551a0b57384fe77ca38e521e026613"
        ),
        .binaryTarget(
          name: "OneSignalInAppMessages",
          url: "https://github.com/OneSignal/OneSignal-XCFramework/releases/download/5.1.4/OneSignalInAppMessages.xcframework.zip",
          checksum: "d419860e27d78977ad4dacbb5e45bacafe4da722e11ff0ad8658aa3e6a396c38"
        ),
        .binaryTarget(
          name: "OneSignalLocation",
          url: "https://github.com/OneSignal/OneSignal-XCFramework/releases/download/5.1.4/OneSignalLocation.xcframework.zip",
          checksum: "03f9fb7932adaeb405f1439e196a34fb6abe01e93eb784defe3608c8a0597cc2"
        ),
        .binaryTarget(
          name: "OneSignalUser",
          url: "https://github.com/OneSignal/OneSignal-XCFramework/releases/download/5.1.4/OneSignalUser.xcframework.zip",
          checksum: "dfd3b632b3f6ea93e6223e120ecf8db41ec71df806f1465e81dae7bb84acdf25"
        ),
        .binaryTarget(
          name: "OneSignalNotifications",
          url: "https://github.com/OneSignal/OneSignal-XCFramework/releases/download/5.1.4/OneSignalNotifications.xcframework.zip",
          checksum: "6f6e788246b18c10994fed68b13cb240e7a81df872d2b3cbdc518f68c8406523"
        ),
        .binaryTarget(
          name: "OneSignalExtension",
          url: "https://github.com/OneSignal/OneSignal-XCFramework/releases/download/5.1.4/OneSignalExtension.xcframework.zip",
          checksum: "dcfb0399bab274d6b0a3788c75c2ee63c3fe579387f28efa61f62d5fe6c15dfd"
        ),
        .binaryTarget(
          name: "OneSignalOutcomes",
          url: "https://github.com/OneSignal/OneSignal-XCFramework/releases/download/5.1.4/OneSignalOutcomes.xcframework.zip",
          checksum: "3550564d5719be99940a401cc7d80d03d5f358bf2718dd9b9e1d8e22cc3873e4"
        ),
        .binaryTarget(
          name: "OneSignalOSCore",
          url: "https://github.com/OneSignal/OneSignal-XCFramework/releases/download/5.1.4/OneSignalOSCore.xcframework.zip",
          checksum: "b1a76ab073887ca3b29424f49c4ea080d96157a0825d1d3efffbf489a33b1c26"
        ),
        .binaryTarget(
          name: "OneSignalCore",
          url: "https://github.com/OneSignal/OneSignal-XCFramework/releases/download/5.1.4/OneSignalCore.xcframework.zip",
          checksum: "e7f0991729dc3964c832361b261940b2b06b810d6af286c35a76b693f848a34c"
        ),
        .binaryTarget(
          name: "OneSignalLiveActivities",
          url: "https://github.com/OneSignal/OneSignal-XCFramework/releases/download/5.1.4/OneSignalLiveActivities.xcframework.zip",
          checksum: "a5554f708d5906b85f80f148f6f9dc7422b4710e194eeada024ecd55579c7154"
        )
    ]
)
