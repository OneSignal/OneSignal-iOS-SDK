// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "OneSignalFramework", // Package name MUST be on line 7 for release automation
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
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/5.5.3/OneSignalFramework.xcframework.zip",
          checksum: "8a791005cb50f079ea1bb615106a9e057b4090b6b4bc805eb4e2d159d433414c"
          name: "OneSignalFramework",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/5.5.2/OneSignalFramework.xcframework.zip",
          checksum: "9248d8d4332d94eb60a4ac4d84959415ff46458bd0301f617f0cb0f9669b86cf"
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/5.5.3/OneSignalInAppMessages.xcframework.zip",
          checksum: "23ebb81e5c67e3ca061c1a71f1660a9e363aa1c7e3f1b458adcc851ecefc7505"
          name: "OneSignalInAppMessages",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/5.5.2/OneSignalInAppMessages.xcframework.zip",
          checksum: "f0b071f3121302bcbb301f70c1974059d3a967e457e2e22a9732f34c87d1f686"
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/5.5.3/OneSignalLocation.xcframework.zip",
          checksum: "feef0322af6eceb4da9dc71e1a696793ea628988186c02aa9d4915c3f3b55703"
          name: "OneSignalLocation",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/5.5.2/OneSignalLocation.xcframework.zip",
          checksum: "87b0c97472b7c0818b3bcf8a23b399715aadd656b78fb258233aea1ad4c0828b"
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/5.5.3/OneSignalUser.xcframework.zip",
          checksum: "e2dfe1dea7397daa2ecd8b8e058ffb44358ab04359990d18179d1f6fed516229"
          name: "OneSignalUser",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/5.5.2/OneSignalUser.xcframework.zip",
          checksum: "df474c076004df1eb9d9ee29f581b714cc3da837c5e2c4b50d356ace960130c0"
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/5.5.3/OneSignalNotifications.xcframework.zip",
          checksum: "febc5d7216e040df19f62621f2bd633d89a07271989c24bee35240b930549d2f"
          name: "OneSignalNotifications",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/5.5.2/OneSignalNotifications.xcframework.zip",
          checksum: "a20f65b0dd9cfe7d039925f2e0cbfe94ad6d634b810d39d7c71f76cfbc2a63cb"
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/5.5.3/OneSignalExtension.xcframework.zip",
          checksum: "f74367930b93ed7526aba43e75abd5d550699eabb799385af9b42dcb01d2cc1f"
          name: "OneSignalExtension",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/5.5.2/OneSignalExtension.xcframework.zip",
          checksum: "e95be41f1806c56cd2b96b675c0b3d03d33f42802caf25b568128ff053610ac5"
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/5.5.3/OneSignalOutcomes.xcframework.zip",
          checksum: "6d8b99b085acd10b7d410e854b14e95c011c91acd3469ac8c0d0c7a234202491"
          name: "OneSignalOutcomes",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/5.5.2/OneSignalOutcomes.xcframework.zip",
          checksum: "fd7a646b85cab454b55cf4b46340c513a7c303d5003e993f2be7833d96196fb2"
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/5.5.3/OneSignalOSCore.xcframework.zip",
          checksum: "3d9d89575ba3970c312ce67dd6ef11962e294d3765fe4c60451c17780dccb7a5"
          name: "OneSignalOSCore",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/5.5.2/OneSignalOSCore.xcframework.zip",
          checksum: "a292a4d9905a3f5b8374a335dd1d304f0ee98d8689c63a593497f975ef919ba7"
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/5.5.3/OneSignalCore.xcframework.zip",
          checksum: "1587bc06cff2ebcbceb9376f32013e030c1d7b4e57ce8596f17027acb2aa3a97"
          name: "OneSignalCore",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/5.5.2/OneSignalCore.xcframework.zip",
          checksum: "d76200dc06f0fa92d7cd442e8f6b69c05c76b1d3986e052ab34f986199344006"
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/5.5.3/OneSignalLiveActivities.xcframework.zip",
          checksum: "f823f271085c4dde5e1a4e21a16d65f3efee8fc4a31eeee430f0217a4a414a26"
          name: "OneSignalLiveActivities",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/5.5.2/OneSignalLiveActivities.xcframework.zip",
          checksum: "83c42874dd3e20fea312dc18497a8295b66d4dcbcedba9d9712b5f31d3f3b91d"
        )
    ]
)
