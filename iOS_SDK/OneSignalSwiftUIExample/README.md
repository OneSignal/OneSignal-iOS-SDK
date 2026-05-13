# OneSignal SwiftUI Example App

A modern SwiftUI example app demonstrating the OneSignal iOS SDK features using MVVM architecture.

## Features

This example app demonstrates all major OneSignal SDK capabilities:

- **User Management**: Login/logout with external user ID
- **Aliases**: Add and remove user aliases
- **Push Subscriptions**: Enable/disable push notifications, view push ID
- **Email & SMS**: Add and remove email and SMS subscriptions
- **Tags**: Manage user tags for segmentation
- **Outcomes**: Track outcome events with optional values
- **In-App Messaging**: Pause/resume IAM, manage triggers
- **Location**: Toggle location sharing, request permissions
- **Test Notifications**: Grid of notification types for testing

## Architecture

The app follows the **MVVM (Model-View-ViewModel)** pattern with a service layer:

```
OneSignalSwiftUIExample/
├── App/
│   └── OneSignalSwiftUIExampleApp.swift    # App entry point, AppDelegate, SDK initialization
├── Models/
│   └── AppModels.swift                     # Data models (KeyValueItem, NotificationType, etc.)
├── Services/
│   └── OneSignalService.swift              # Singleton service wrapping all OneSignal SDK calls
├── ViewModels/
│   └── OneSignalViewModel.swift            # Main ViewModel with state management & observers
└── Views/
    ├── ContentView.swift                   # Root view composing all sections
    ├── Components/                         # Reusable UI components
    │   ├── AddItemSheet.swift              # Sheet for adding items (aliases, tags, etc.)
    │   ├── KeyValueRow.swift               # Row components for displaying data
    │   ├── NotificationGrid.swift          # Grid buttons for notification types
    │   └── ToastView.swift                 # Toast notification overlay
    └── Sections/                           # Feature-specific sections
        ├── AppInfoSection.swift            # App ID display and consent management
        ├── UserSection.swift               # Login/logout and alias management
        ├── SubscriptionSection.swift       # Push, email, and SMS subscriptions
        ├── TagsSection.swift               # User tag management
        ├── MessagingSection.swift          # Outcomes, IAM controls, and triggers
        ├── LocationSection.swift           # Location sharing controls
        └── NotificationSection.swift       # Test notification buttons
```

## Running the App

This project is part of the `OneSignalSDK.xcworkspace` and is configured to work with the local OneSignal SDK frameworks.

### Quick Start

1. Open `iOS_SDK/OneSignalSDK.xcworkspace` in Xcode
2. Select the **OneSignalSwiftUIExample** scheme
3. Select a simulator or physical device
4. Build and run (⌘R)
5. Grant notification permissions when prompted
6. Explore the various OneSignal features

### Using Your Own App ID

The default OneSignal App ID is configured in `OneSignalService.swift`. To use your own:

1. Open `OneSignalSwiftUIExample/Services/OneSignalService.swift`
2. Change the `defaultAppId` value to your OneSignal App ID

```swift
private let defaultAppId = "your-onesignal-app-id"
```

## Project Configuration

### Required Capabilities

The app requires the following capabilities (already configured):

- **Push Notifications**
- **Background Modes** → Remote notifications

### Info.plist Keys

The following keys are configured for location and background notifications:

- `NSLocationWhenInUseUsageDescription`
- `NSLocationAlwaysAndWhenInUseUsageDescription`
- `UIBackgroundModes` with `remote-notification`

### Framework Dependencies

The project links against the following OneSignal frameworks (built from the workspace):

- `OneSignalFramework`
- `OneSignalInAppMessages`
- `OneSignalLocation`
- `OneSignalUser`
- `OneSignalNotifications`
- `OneSignalExtension`
- `OneSignalOutcomes`
- `OneSignalOSCore`

## Key Implementation Details

### SDK Initialization

The OneSignal SDK is initialized in `AppDelegate` via `OneSignalService.shared.initialize()`:

```swift
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        OneSignalService.shared.initialize(launchOptions: launchOptions)
        // Set up notification and IAM listeners...
        return true
    }
}
```

### Service Layer Pattern

All OneSignal SDK calls are encapsulated in `OneSignalService`, providing:

- Centralized SDK access
- Easy mocking for testing
- Clean separation from UI code

### Observer Pattern

The ViewModel sets up observers for SDK state changes:

- `OSPushSubscriptionObserver` - Push subscription state changes
- `OSUserStateObserver` - User state changes
- `OSNotificationPermissionObserver` - Permission changes

### SwiftUI Best Practices

- `@StateObject` for ViewModel ownership
- `@EnvironmentObject` for dependency injection to child views
- `@MainActor` for thread-safe UI updates
- Reusable components for consistent UI

## Requirements

- iOS 16.0+
- Xcode 15.0+
- Swift 5.9+
- OneSignal iOS SDK 5.0+

## License

Modified MIT License - See LICENSE file for details.
