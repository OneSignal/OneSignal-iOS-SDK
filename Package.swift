// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "OneSignalFramework", // Package name MUST be on line 7 for release automation
    platforms: [
        .iOS(.v15),
        .macCatalyst(.v15),
    ],
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
                "OneSignalOSCore",
                "OneSignalCore"
            ],
            path: "OneSignalNotificationsWrapper"
        ),
        .target(
            name: "OneSignalExtensionWrapper",
            dependencies: [
                "OneSignalExtension",
                "OneSignalOutcomes",
                "OneSignalOSCore",
                "OneSignalCore"
            ],
            path: "OneSignalExtensionWrapper"
        ),
        .target(
            name: "OneSignalOutcomesWrapper",
            dependencies: [
                "OneSignalOutcomes",
                "OneSignalOSCore",
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
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/5.8.1/OneSignalFramework.xcframework.zip",
          checksum: "fa4be464c4ad2da152a8f4e782c2374b8c18870a0f3946559c03e626360e6066"
        ),
        .binaryTarget(
          name: "OneSignalInAppMessages",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/5.8.1/OneSignalInAppMessages.xcframework.zip",
          checksum: "2891e9ca896e074b2f1ec43c4d37e79357de3f9cd92a92c954f6a4e9cb229151"
        ),
        .binaryTarget(
          name: "OneSignalLocation",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/5.8.1/OneSignalLocation.xcframework.zip",
          checksum: "2d331b843592a7d31d76a29243d0cb8090603eca8994509f228398bb56f98dc7"
        ),
        .binaryTarget(
          name: "OneSignalUser",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/5.8.1/OneSignalUser.xcframework.zip",
          checksum: "ecb18076d98491786fe066d193448321ec8c9e457fe100d2d4de71ca25fd322e"
        ),
        .binaryTarget(
          name: "OneSignalNotifications",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/5.8.1/OneSignalNotifications.xcframework.zip",
          checksum: "766d1a0fcee322cfff1575b6642b5398dfc22c66f542db4bc36e01eb7966fbdb"
        ),
        .binaryTarget(
          name: "OneSignalExtension",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/5.8.1/OneSignalExtension.xcframework.zip",
          checksum: "30f62bdb7561abf948dbb8c4ce6052819b4eb855e2dd7ef5ad0ca605aaa92bc7"
        ),
        .binaryTarget(
          name: "OneSignalOutcomes",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/5.8.1/OneSignalOutcomes.xcframework.zip",
          checksum: "e173544ad49ed2f2e7021b4b65f707eba441bf92c1aa8736afc6c74f787c2abf"
        ),
        .binaryTarget(
          name: "OneSignalOSCore",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/5.8.1/OneSignalOSCore.xcframework.zip",
          checksum: "d948fdcea945692e19c1c3d5c8507553f48e1203a042145d11515e5c643b6dbe"
        ),
        .binaryTarget(
          name: "OneSignalCore",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/5.8.1/OneSignalCore.xcframework.zip",
          checksum: "a9d71b6f23f01ed21fde79f8019efb28d9a79a2ff3b78e89aaeb4af6fe772643"
        ),
        .binaryTarget(
          name: "OneSignalLiveActivities",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/5.8.1/OneSignalLiveActivities.xcframework.zip",
          checksum: "3a6bd67aa01eece9f8faeea0a230acc9ea4572b4250df9a8ce4daa9e33e14d33"
        )
    ]
)
