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
            targets: ["OneSignalExtensionWrapper"]),
    ],
    targets: [
        .target(
            name: "OneSignalWrapper",
            dependencies: [
                "OneSignal",
                "OneSignalExtension",
                "OneSignalOutcomes",
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
        .binaryTarget(
          name: "OneSignal",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/3.11.0-alpha-01/OneSignal.xcframework.zip",
          checksum: "e084a5690f7e7c515ac85f11fdc2b4b167661e85fb369a485fa202314997e3ff"
        ),
        .binaryTarget(
          name: "OneSignalExtension",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/3.11.0-alpha-01/OneSignalExtension.xcframework.zip",
          checksum: "5c44996c61062d4badc10c0fb38a8e2a7420f8e7f2274d811b787639d54f04ad"
        ),
        .binaryTarget(
          name: "OneSignalOutcomes",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/3.11.0-alpha-01/OneSignalOutcomes.xcframework.zip",
          checksum: "c0e679155aef6dfe3573fd286d5ec1de025548284db4fb123a42418376b6008c"
        ),
        .binaryTarget(
          name: "OneSignalCore",
          url: "https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/3.11.0-alpha-01/OneSignalCore.xcframework.zip",
          checksum: "ae963b00b9a2e259e0d617fc82c72b4a0f9c4847c3dbbb46e4643a51f8f08d7a"
        )
    ]
)

