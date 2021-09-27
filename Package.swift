// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "OneSignalSwift",
    products: [
        .library(
            name: "OneSignalSwift",
            targets: ["OneSignalSwift"]),
    ],
    targets: [
        .binaryTarget(
          name: "OneSignalSwift",
          path: "iOS_SDK/OneSignalSDK/OneSignal_XCFramework/OneSignal.xcframework"
        )
    ]
)

