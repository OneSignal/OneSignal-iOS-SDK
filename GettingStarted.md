# Getting Started

This repo ships two ways to exercise the OneSignal iOS SDK:

| App | Location | Purpose |
|-----|----------|---------|
| **OneSignalDevApp** | `iOS_SDK/OneSignalDevApp/` | Internal dev/test app wired into `OneSignalSDK.xcworkspace`. Builds against **local SDK source**, so any changes you make to the SDK are picked up immediately. Use this when modifying the SDK. |
| **examples/demo** | `examples/demo/` | Customer-facing SwiftUI demo that mirrors the OneSignal Capacitor / Cordova / RN demos (same section layout, accessibility identifiers, sdk-shared tooltip content). Builds against the published SwiftPM SDK. Use this as a reference integration. |

## Prerequisites

| Requirement | Minimum Version |
|-------------|-----------------|
| macOS       | 13 Ventura+     |
| Xcode       | 15.0+           |
| Swift       | 5.9+            |
| iOS target  | 16.0+           |

## Running OneSignalDevApp (SDK contributors)

This is the recommended path when you're working on the SDK itself.

1. Open `iOS_SDK/OneSignalSDK.xcworkspace` in Xcode (the workspace, not any individual `.xcodeproj`).
2. Select the **OneSignalDevApp** scheme.
3. Pick a simulator or a connected device.
4. Press **Cmd + R** to build and run.

SDK debug logs stream to the Xcode console — useful for verifying network calls, subscription state, and in-app message events.

> Push notification delivery requires a **physical device** with a valid APNs configuration. The simulator supports permission prompts and token generation but won't receive remote pushes.

## Running examples/demo (reference integration)

The `examples/demo/` app demonstrates the recommended integration shape for app developers, including a Notification Service Extension target and a Live Activities Widget Extension target.

See [`examples/demo/README.md`](examples/demo/README.md) for full setup steps. In short:

1. Create the Xcode project at `examples/demo/App.xcodeproj` (the source files and extension folders are checked in but `project.pbxproj` is not).
2. Add the OneSignal SwiftPM dependency (`https://github.com/OneSignal/OneSignal-iOS-SDK`, 5.0.0+) and attach the right products to each of the three targets (App / NSE / Widget).
3. Configure capabilities (Push Notifications, App Groups, Background Modes → Remote notifications) and run.

## Using your own App ID

Both apps default to a shared OneSignal App ID. To switch to your own:

- **OneSignalDevApp** — open `iOS_SDK/OneSignalDevApp/OneSignalDevApp/AppDelegate.m` and replace the App ID passed to `OneSignal.initialize`.
- **examples/demo** — edit `examples/demo/App/Services/OneSignalService.swift` and replace `defaultAppId`, or override at runtime via `UserDefaults` (key `OneSignalAppId`).

Changing the App ID requires uninstalling and reinstalling the app for it to take effect.

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Build fails with missing framework | Open the workspace (`OneSignalSDK.xcworkspace`), not an individual `.xcodeproj`. |
| Push notifications don't arrive on simulator | Push delivery requires a physical device with APNs configured. |
| "Consent Required" blocks SDK calls | Toggle **Consent Required** off, or grant consent via the SDK's consent API. |
