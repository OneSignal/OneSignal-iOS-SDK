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
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/5.5.2/OneSignalFramework.xcframework.zip",
          checksum: "9248d8d4332d94eb60a4ac4d84959415ff46458bd0301f617f0cb0f9669b86cf"
          name: "OneSignalFramework",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/5.5.1/OneSignalFramework.xcframework.zip",
          checksum: "a58df0c7417b0785da6d0c8718a77aea45f599ad5650bd01781035eb273ef17f"
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/5.5.2/OneSignalInAppMessages.xcframework.zip",
          checksum: "f0b071f3121302bcbb301f70c1974059d3a967e457e2e22a9732f34c87d1f686"
          name: "OneSignalInAppMessages",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/5.5.1/OneSignalInAppMessages.xcframework.zip",
          checksum: "f9d7f766ed7f2e95d38af149e8a4173508704938053b36d2f58dd5f93dbc2d68"
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/5.5.2/OneSignalLocation.xcframework.zip",
          checksum: "87b0c97472b7c0818b3bcf8a23b399715aadd656b78fb258233aea1ad4c0828b"
          name: "OneSignalLocation",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/5.5.1/OneSignalLocation.xcframework.zip",
          checksum: "7c702867a7aca6571873bd9d9bbec5a27489808d83a5ab4fa6c56ff29460dd2e"
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/5.5.2/OneSignalUser.xcframework.zip",
          checksum: "df474c076004df1eb9d9ee29f581b714cc3da837c5e2c4b50d356ace960130c0"
          name: "OneSignalUser",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/5.5.1/OneSignalUser.xcframework.zip",
          checksum: "58d6e32ef0580f6cc355165ee627c5ebef1943ab0db0dd278677d0b3794fa6f6"
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/5.5.2/OneSignalNotifications.xcframework.zip",
          checksum: "a20f65b0dd9cfe7d039925f2e0cbfe94ad6d634b810d39d7c71f76cfbc2a63cb"
          name: "OneSignalNotifications",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/5.5.1/OneSignalNotifications.xcframework.zip",
          checksum: "044af3b7091bb41a75d682f6511be44a7a6bf1e1dfba6f74cf594cb15399c3ed"
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/5.5.2/OneSignalExtension.xcframework.zip",
          checksum: "e95be41f1806c56cd2b96b675c0b3d03d33f42802caf25b568128ff053610ac5"
          name: "OneSignalExtension",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/5.5.1/OneSignalExtension.xcframework.zip",
          checksum: "cb1b6d28eaf0beac27bb42e98d3e35a55f5b8840ca765b0b43678edacad3a5f7"
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/5.5.2/OneSignalOutcomes.xcframework.zip",
          checksum: "fd7a646b85cab454b55cf4b46340c513a7c303d5003e993f2be7833d96196fb2"
          name: "OneSignalOutcomes",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/5.5.1/OneSignalOutcomes.xcframework.zip",
          checksum: "18f0c36fc1a82ab05226ed26cdf63b8ae9d3c0daa98040b3e32ffa8060bef586"
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/5.5.2/OneSignalOSCore.xcframework.zip",
          checksum: "a292a4d9905a3f5b8374a335dd1d304f0ee98d8689c63a593497f975ef919ba7"
          name: "OneSignalOSCore",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/5.5.1/OneSignalOSCore.xcframework.zip",
          checksum: "e427d9ade8c642cc32e50ac772294e2f3c1617edebee2e2e3456d609ea19ceb2"
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/5.5.2/OneSignalCore.xcframework.zip",
          checksum: "d76200dc06f0fa92d7cd442e8f6b69c05c76b1d3986e052ab34f986199344006"
          name: "OneSignalCore",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/5.5.1/OneSignalCore.xcframework.zip",
          checksum: "027b2485ccf6dabb523bba2628982637d57b73d491efc3e86ed008885858979e"
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/5.5.2/OneSignalLiveActivities.xcframework.zip",
          checksum: "83c42874dd3e20fea312dc18497a8295b66d4dcbcedba9d9712b5f31d3f3b91d"
          name: "OneSignalLiveActivities",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/5.5.1/OneSignalLiveActivities.xcframework.zip",
          checksum: "b8118f029efac9bec0f7f0047d690bfb2609f70aa1b799444918ab3353cc193d"
        )
    ]
)
