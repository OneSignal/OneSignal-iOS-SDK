// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "OneSignal",
    products: [
        .library(
            name: "OneSignal",
            targets: ["OneSignal"]),
    ],
    targets: [
        .target(
            name: "OneSignal",
            dependencies: [],
            path: "iOS_SDK/OneSignalSDK/",
            sources: ["Source"],
            publicHeadersPath:"SwiftPM/Public/Headers"),
    ]
)

