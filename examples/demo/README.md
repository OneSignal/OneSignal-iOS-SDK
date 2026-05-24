# OneSignal SwiftUI Example App

A SwiftUI demo app that exercises every public surface of the OneSignal iOS SDK and mirrors the layout, naming, and behavior of other OneSignal SDKS so the same end-to-end test suite (`@onesignal/sdk-shared`) can drive both apps.

## Features

The demo covers all major OneSignal SDK capabilities:

- **App / Consent**: App ID display, `consent_required` and `privacy_consent` toggles
- **User**: Login / logout with external user ID
- **Push Subscription**: Push subscription ID, opt-in toggle, prompt for permission
- **Send Push Notification**: Simple / image / sound / custom notifications via the OneSignal REST API
- **In-App Messaging**: Pause / resume IAM display, send IAM trigger to surface dashboard messages
- **Aliases / Emails / SMS / Tags**: Add (single or multiple), remove (single or selected)
- **Outcomes**: Send normal / unique / value outcomes
- **Triggers**: Add (single or multiple), remove (single or selected), clear all
- **Custom Events**: Track event with optional JSON properties
- **Location**: Location sharing toggle, request permission
- **Live Activities** (iOS 16.1+): Start / update / end an activity, status cycler

Section headers use ALL CAPS and an info icon (where Capacitor has one) that opens a tooltip sheet with descriptions sourced from `https://github.com/OneSignal/sdk-shared` (with a bundled fallback).

Every interactive element exposes an `accessibilityIdentifier` matching the Capacitor demo's `data-testid` so the shared E2E tests can target it.

## Architecture

The Xcode project ships three targets, mirroring the Capacitor / Cordova / RN demos:

```
examples/demo/
├── App.xcodeproj
├── App.entitlements                                  # main app: aps-environment + app group
├── App/                                              # Main app target source
│   ├── App.swift                                     # @main + AppDelegate, SDK + Live Activity setup
│   ├── Views/
│   │   ├── ContentView.swift                         # Composes sections + sheets in Capacitor order
│   │   ├── Sections/                                 # AppSection, UserSection, PushSection, ...
│   │   └── Components/                               # SectionCard, ActionButton, ToggleRow,
│   │                                                 # AddItemSheet, MultiPairInputSheet, RemoveMultiSheet,
│   │                                                 # OutcomeSheet, CustomNotificationSheet, TrackEventSheet,
│   │                                                 # TooltipSheet, ToastView, ListWidgets, KeyValueRow
│   ├── ViewModels/
│   │   └── OneSignalViewModel.swift                  # Single ObservableObject backing every section
│   ├── Models/
│   │   └── AppModels.swift                           # KeyValueItem, NotificationType, InAppMessageType,
│   │                                                 # AddItemType, MultiAddItemType, RemoveMultiItemType,
│   │                                                 # OutcomeMode, TooltipData, UserData
│   ├── Services/
│   │   ├── OneSignalService.swift                    # Thin wrapper over OneSignal.* APIs
│   │   ├── NotificationSender.swift                  # Posts to /notifications with retry on transient failures
│   │   ├── UserFetchService.swift                    # Hydrates aliases / tags / channels via /users
│   │   ├── TooltipService.swift                      # Loads tooltip JSON from sdk-shared (with fallback)
│   │   └── LiveActivityController.swift              # Wraps OneSignal.LiveActivities + REST update / end
│   ├── Assets.xcassets/
│   └── Info.plist
│
├── OneSignalNotificationServiceExtension/            # NSE target — required for rich push (images, decryption, mutable content)
│   ├── NotificationService.swift                     # Forwards to OneSignalExtension.didReceiveNotificationExtensionRequest
│   ├── Info.plist                                    # NSExtension/usernotifications.service
│   └── OneSignalNotificationServiceExtension.entitlements   # app group (must match main app)
│
└── OneSignalWidget/                                  # Widget Extension target — required to render Live Activities
    ├── OneSignalWidgetBundle.swift                   # @main WidgetBundle
    ├── OneSignalWidgetLiveActivity.swift             # Lock screen + Dynamic Island UI for DefaultLiveActivityAttributes
    ├── Info.plist                                    # NSExtension/widgetkit-extension
    └── Assets.xcassets/                              # WidgetBackground, AccentColor, AppIcon
```

This mirrors the Capacitor demo's iOS layout (`OneSignal-Capacitor-SDK/examples/demo/ios/App/{App,OneSignalNotificationServiceExtension,OneSignalWidget}/`).

## Setup Instructions

The Xcode project is generated from `project.yml` with [XcodeGen](https://github.com/yonaskolb/XcodeGen) and is wired into `iOS_SDK/OneSignalSDK.xcworkspace`, so it builds against the SDK source tree directly. There are no manual Xcode setup steps.

### 1. Open the workspace

```bash
open iOS_SDK/OneSignalSDK.xcworkspace
```

In the scheme picker pick **App** and run on a simulator or device. Granting notification permissions and selecting a section is enough to exercise the SDK against your local source.

### 2. Regenerate the project (only when `project.yml` changes)

```bash
brew install xcodegen           # one time
cd examples/demo
xcodegen generate               # rewrites App.xcodeproj
```

`project.yml` declares three targets — `App`, `OneSignalNotificationServiceExtension`, `OneSignalWidget` — and references the framework targets in `iOS_SDK/OneSignalSDK/OneSignal.xcodeproj` so each one links and embeds the right SDK frameworks at build time.

### 3. Capabilities & App Group

The shipped `App.entitlements` and `OneSignalNotificationServiceExtension/OneSignalNotificationServiceExtension.entitlements` use `group.com.onesignal.example.onesignal`. If you need a different group (for example to install on a real device under your own team), change the value in both files to the same string. The other capabilities (Push Notifications, Remote notifications background mode, `NSSupportsLiveActivities`) are already declared in the entitlements / `App/Info.plist`.

### 4. Update the App ID

`App/Services/OneSignalService.swift` ships with a placeholder OneSignal App ID. Either edit `defaultAppId` or override it at runtime via `UserDefaults` (key `OneSignalAppId`).

### 5. (Optional) Live Activities REST API key

To exercise **Update** / **End** of Live Activities, add a `Secrets.plist` file to the main app bundle with key `ONESIGNAL_API_KEY` set to a OneSignal REST API key for your app. Without a key the section disables those buttons and shows a hint.

> The widget renders `DefaultLiveActivityAttributes` (provided by the SDK), so the Activity ID + Order # you type into the demo flows through to the same widget regardless of whether the update came from `OneSignal.LiveActivities` locally or from the REST `/live_activities/{id}/notifications` endpoint.

## Running the App

1. Select a simulator or device
2. Build and run (⌘R)
3. Grant notification permissions when prompted
4. Explore each section

## Requirements

- iOS 15.0+ (Live Activities require iOS 16.1+)
- Xcode 15.0+
- Swift 5.9+
- OneSignal iOS SDK 5.0+

## License

Modified MIT License — see the repository LICENSE file.
