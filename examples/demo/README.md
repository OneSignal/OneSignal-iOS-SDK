# OneSignal SwiftUI Example App

A SwiftUI demo app that exercises every public surface of the OneSignal iOS SDK and mirrors the layout, naming, and behavior of the OneSignal Capacitor demo so the same end-to-end test suite (`@onesignal/sdk-shared`) can drive both apps.

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
│   ├── OneSignalSwiftUIExampleApp.swift              # @main + AppDelegate, SDK + Live Activity setup
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

### 1. Create the Xcode project

1. Open Xcode and create a new **iOS App** named `App` (Interface: SwiftUI, Language: Swift, Storage: None)
2. Save it inside `examples/demo/` so the project file ends up at `examples/demo/App.xcodeproj`
3. Delete the auto-generated `App/ContentView.swift` and `App/AppApp.swift`
4. Drag the existing source folders from `examples/demo/App/` into the target with **Copy items if needed unchecked**: `Views/`, `ViewModels/`, `Models/`, `Services/`, `Assets.xcassets/`, and the `OneSignalSwiftUIExampleApp.swift` entry point at the root

### 2. Add the Notification Service Extension target

1. **File → New → Target… → Notification Service Extension**, name it `OneSignalNotificationServiceExtension`
2. Delete the auto-generated `NotificationService.swift` and `Info.plist` from the new target
3. Drag in the existing `OneSignalNotificationServiceExtension/` files from this folder, with **target membership** set to the new extension only
4. Set the entitlements file to `OneSignalNotificationServiceExtension.entitlements`

### 3. Add the Widget Extension target (for Live Activities)

1. **File → New → Target… → Widget Extension**, name it `OneSignalWidget`. **Uncheck** "Include Configuration Intent"
2. Delete the auto-generated `OneSignalWidget.swift`, `OneSignalWidgetBundle.swift`, `Info.plist`, and `Assets.xcassets`
3. Drag in the existing `OneSignalWidget/` files from this folder, target membership set to the widget target only
4. In the widget target's build settings, set **iOS Deployment Target** to 16.2 or later

### 4. Add OneSignal SDK dependencies

Use Swift Package Manager (**File → Add Package Dependencies…**, URL `https://github.com/OneSignal/OneSignal-iOS-SDK`, version 5.0.0+) and attach products to targets:

| Product                     | Main app | NSE | Widget |
| --------------------------- | -------- | --- | ------ |
| `OneSignalFramework`        | yes      |     |        |
| `OneSignalInAppMessages`    | yes      |     |        |
| `OneSignalLocation`         | yes      |     |        |
| `OneSignalLiveActivities`   | yes      |     | yes    |
| `OneSignalExtension`        |          | yes |        |

### 5. Configure capabilities

For the **main app** target in **Signing & Capabilities**:

- **Push Notifications**
- **Background Modes** → Remote notifications
- **App Groups** → `group.com.onesignal.example.onesignal` (rename to your own app group, then update both entitlements files)

For the **NSE** target:

- **App Groups** → same group as the main app

The widget target needs no capabilities beyond what Xcode adds for you. `NSSupportsLiveActivities` is already set in `App/Info.plist`.

### 6. Update App ID

`Services/OneSignalService.swift` ships with a placeholder. Either edit `defaultAppId` or override it at runtime via `UserDefaults` (key `OneSignalAppId`).

### 7. (Optional) Live Activities REST API key

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
