// swift-tools-version:5.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "OneSignal",
    products: [
        .library(
            name: "OneSignal",
            type: .static,
            targets: ["OneSignal"]),
        .library(
            name: "OneSignalDynamic",
            type: .dynamic,
            targets: ["OneSignal"]),
    ],
    targets: [
        .target(
            name: "OneSignal",
            dependencies: [],
            path: "iOS_SDK/OneSignalSDK/",
            sources: ["Source"],
            publicHeadersPath:"Source"),
    ]
)

