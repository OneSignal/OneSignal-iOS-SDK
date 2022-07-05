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
            targets: ["OneSignalExtensionWrapper"])
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
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/3.11.2/OneSignal.xcframework.zip",
          checksum: "e9cf7ebef15ab8757e6e9c95d359998f018f4de381944f4cc62bc4c25d1cdb9d"
        ),
        .binaryTarget(
          name: "OneSignalExtension",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/3.11.2/OneSignalExtension.xcframework.zip",
          checksum: "1725ed62c9a3630caccb04e6c52db02348719428e6a3eca6b1fec8ee35828162"
        ),
        .binaryTarget(
          name: "OneSignalOutcomes",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/3.11.2/OneSignalOutcomes.xcframework.zip",
          checksum: "d1345bda87e3f0b4f50cc4f31de7c7f8a6be38e7b768d7ce4e599dc6e6f467ba"
        ),
        .binaryTarget(
          name: "OneSignalCore",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/3.11.2/OneSignalCore.xcframework.zip",
          checksum: "6378ad0fdba2e485274b87b192d0c6419f37e92bd33d9a2f7993b9c5e137b94f"
        ),
        .binaryTarget(
          name: "OneSignalUser",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/3.11.2/OneSignalUser.xcframework.zip",
          checksum: "6378ad0fdba2e485274b87b192d0c6419f37e92bd33d9a2f7993b9c5e137b94f"
        )
    ]
)
