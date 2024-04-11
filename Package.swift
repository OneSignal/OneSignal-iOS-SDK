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
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/5.2.0-beta-01/OneSignalFramework.xcframework.zip",
          checksum: "efeb89f2c796bd99f12bd42193b5851ffb35efefd1289d6235630e6d95c2850b"
        ),
        .binaryTarget(
          name: "OneSignalInAppMessages",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/5.2.0-beta-01/OneSignalInAppMessages.xcframework.zip",
          checksum: "9376db9ac7f9a944570503a1ee2c13da6178a9c8aee4d1ea97f2fcbe514ba6b8"
        ),
        .binaryTarget(
          name: "OneSignalLocation",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/5.2.0-beta-01/OneSignalLocation.xcframework.zip",
          checksum: "0860cd71363f76f824bde7dc72ae3b05a714791f153e3593b962561e7d396587"
        ),
        .binaryTarget(
          name: "OneSignalUser",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/5.2.0-beta-01/OneSignalUser.xcframework.zip",
          checksum: "8c0a491808976d582c7a50d3eef3b0012445279a87d46d054816f2e48c768830"
        ),
        .binaryTarget(
          name: "OneSignalNotifications",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/5.2.0-beta-01/OneSignalNotifications.xcframework.zip",
          checksum: "edde1ded67265a8623309cc7234c6c5cb25b57547c09bca11ad979708b325873"
        ),
        .binaryTarget(
          name: "OneSignalExtension",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/5.2.0-beta-01/OneSignalExtension.xcframework.zip",
          checksum: "de7101d8c8bb34e906f76d091647a56f637a0b01db0638766cee8fe7bf3293c6"
        ),
        .binaryTarget(
          name: "OneSignalOutcomes",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/5.2.0-beta-01/OneSignalOutcomes.xcframework.zip",
          checksum: "5e916271ad505379fb1052cf461ef76163160719866dd82332b212cc0b8cbc38"
        ),
        .binaryTarget(
          name: "OneSignalOSCore",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/5.2.0-beta-01/OneSignalOSCore.xcframework.zip",
          checksum: "db96b9e9a3b02cd3e8e87001703ddf7277c34e8fb6f01a4a8313e1187bdad6ee"
        ),
        .binaryTarget(
          name: "OneSignalCore",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/5.2.0-beta-01/OneSignalCore.xcframework.zip",
          checksum: "b2e214f24a8ccf64e2644b1c1fef396158c5317b68603d36b2e0793c476e8e02"
        ),
        .binaryTarget(
          name: "OneSignalLiveActivities",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/5.2.0-beta-01/OneSignalLiveActivities.xcframework.zip",
          checksum: "e746689051a2e7a673b5252bdfe299fd0bd6d05451695fbb0fa0e1e1a935da73"
        )
    ]
)
