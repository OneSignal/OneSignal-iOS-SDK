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

```
OneSignalSwiftUIExample/
├── App/
│   └── OneSignalSwiftUIExampleApp.swift   # @main + AppDelegate, SDK + Live Activities setup
├── Views/
│   ├── ContentView.swift                  # Composes sections + sheets in Capacitor demo order
│   ├── Sections/                          # AppSection, UserSection, PushSection, ...
│   └── Components/                        # SectionCard, ActionButton, ToggleRow,
│                                          # AddItemSheet, MultiPairInputSheet, RemoveMultiSheet,
│                                          # OutcomeSheet, CustomNotificationSheet, TrackEventSheet,
│                                          # TooltipSheet, ToastView, ListWidgets, KeyValueRow
├── ViewModels/
│   └── OneSignalViewModel.swift           # Single ObservableObject backing every section
├── Models/
│   └── AppModels.swift                    # KeyValueItem, NotificationType, InAppMessageType,
│                                          # AddItemType, MultiAddItemType, RemoveMultiItemType,
│                                          # OutcomeMode, TooltipData, UserData
├── Services/
│   ├── OneSignalService.swift             # Thin wrapper over OneSignal.* APIs
│   ├── NotificationSender.swift           # Posts to /notifications with retry on transient failures
│   ├── UserFetchService.swift             # Hydrates aliases / tags / channels via /users
│   ├── TooltipService.swift               # Loads tooltip JSON from sdk-shared (with fallback)
│   └── LiveActivityController.swift       # Wraps OneSignal.LiveActivities + REST update / end
└── Assets.xcassets/
```

## Setup Instructions

### 1. Create the Xcode project

1. Open Xcode and create a new **iOS App** (Interface: SwiftUI, Language: Swift, Storage: None)
2. Save the project as `OneSignalSwiftUIExample` inside `examples/demo/`
3. Delete the auto-generated `ContentView.swift` and `OneSignalSwiftUIExampleApp.swift`
4. Drag the `App/`, `Views/`, `ViewModels/`, `Models/`, `Services/`, and `Assets.xcassets/` folders from this repo into your project, with **Copy items if needed unchecked**

### 2. Add OneSignal SDK dependencies

Use Swift Package Manager:

1. **File → Add Package Dependencies…**
2. Enter `https://github.com/OneSignal/OneSignal-iOS-SDK`, select 5.0.0+
3. Add these packages to the main app target:
   - `OneSignalFramework`
   - `OneSignalInAppMessages`
   - `OneSignalLiveActivities`
   - `OneSignalLocation`

### 3. Configure capabilities

In **Signing & Capabilities** add:

- **Push Notifications**
- **Background Modes** → Remote notifications
- **Live Activities** (iOS 16.1+): set `NSSupportsLiveActivities = YES` in Info.plist

### 4. Update App ID

`Services/OneSignalService.swift` ships with a placeholder. Either edit `defaultAppId` or override it at runtime via `UserDefaults` (key `OneSignalAppId`).

### 5. (Optional) Live Activities REST API key

To exercise **Update** / **End** of Live Activities, add a `Secrets.plist` file to the bundle with key `ONESIGNAL_API_KEY` set to a OneSignal REST API key for your app. Without a key the section disables those buttons and shows a hint.

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
