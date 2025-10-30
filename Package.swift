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
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/1.1.1-alpha-01/OneSignalFramework.xcframework.zip",
          checksum: "4c87d1cb2ce4c6eec2a437430808e0ad529a7514b803baec96b0868fca83a847"
        ),
        .binaryTarget(
          name: "OneSignalInAppMessages",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/1.1.1-alpha-01/OneSignalInAppMessages.xcframework.zip",
          checksum: "4e7a36dc842e86f76431e712451fbd3dd83bc77d5e059c9f0f2152d125ba203a"
        ),
        .binaryTarget(
          name: "OneSignalLocation",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/1.1.1-alpha-01/OneSignalLocation.xcframework.zip",
          checksum: "8a22acf4761eb193117c4b813719812da48d1bc51446282454987f59e4f1fdb5"
        ),
        .binaryTarget(
          name: "OneSignalUser",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/1.1.1-alpha-01/OneSignalUser.xcframework.zip",
          checksum: "b8b0182d068fd66fe731fc1e1253a728ec9615fce9f1ba9116e87c800ebc6ff1"
        ),
        .binaryTarget(
          name: "OneSignalNotifications",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/1.1.1-alpha-01/OneSignalNotifications.xcframework.zip",
          checksum: "88d0afc4c759f340fa057aeeff28e1a3b13105c0b5ac8bc88473f343e9444191"
        ),
        .binaryTarget(
          name: "OneSignalExtension",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/1.1.1-alpha-01/OneSignalExtension.xcframework.zip",
          checksum: "2e0546446ff0e8898d7ef6dd3b762f166e6eeded3789c282a4b292dc399eefb9"
        ),
        .binaryTarget(
          name: "OneSignalOutcomes",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/1.1.1-alpha-01/OneSignalOutcomes.xcframework.zip",
          checksum: "5266a37b621a44102461f9cee187e8ce40ce546fb7a151c30d6a03702c9ad4a8"
        ),
        .binaryTarget(
          name: "OneSignalOSCore",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/1.1.1-alpha-01/OneSignalOSCore.xcframework.zip",
          checksum: "05264287132ff99f7a98a0651e7fefffa4417f2c963f0415f45cf55655e6e86a"
        ),
        .binaryTarget(
          name: "OneSignalCore",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/1.1.1-alpha-01/OneSignalCore.xcframework.zip",
          checksum: "2f583062c9bcf41739bbff2d976c689012dac4715517cc7f232c3a483368bc39"
        ),
        .binaryTarget(
          name: "OneSignalLiveActivities",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/1.1.1-alpha-01/OneSignalLiveActivities.xcframework.zip",
          checksum: "6815b9e1613ecafb7d9ce4a9faab14d66bfb52d4809d28c618111d1aad4479fe"
        )
    ]
)
