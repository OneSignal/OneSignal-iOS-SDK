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

The app follows the **MVVM (Model-View-ViewModel)** pattern:

```
OneSignalSwiftUIExample/
├── App/
│   └── OneSignalSwiftUIExampleApp.swift    # App entry point, SDK init
├── Views/
│   ├── ContentView.swift                   # Main view
│   ├── Sections/                           # Feature sections
│   │   ├── AppInfoSection.swift
│   │   ├── UserSection.swift
│   │   ├── SubscriptionSection.swift
│   │   ├── TagsSection.swift
│   │   ├── MessagingSection.swift
│   │   ├── LocationSection.swift
│   │   └── NotificationSection.swift
│   └── Components/                         # Reusable UI components
│       ├── KeyValueRow.swift
│       ├── AddItemSheet.swift
│       ├── NotificationGrid.swift
│       └── ToastView.swift
├── ViewModels/
│   └── OneSignalViewModel.swift            # Main ViewModel
├── Models/
│   └── AppModels.swift                     # Data models
├── Services/
│   └── OneSignalService.swift              # SDK wrapper
└── Assets.xcassets/                        # App assets
```

## Setup Instructions

### 1. Create Xcode Project

1. Open Xcode and create a new project
2. Select **iOS** → **App**
3. Configure the project:
   - Product Name: `OneSignalSwiftUIExample`
   - Team: Your development team
   - Organization Identifier: `com.onesignal`
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Storage: None
4. Save the project in `iOS_SDK/OneSignalSwiftUIExample/`

### 2. Add Source Files

1. Delete the auto-generated `ContentView.swift` and `OneSignalSwiftUIExampleApp.swift`
2. Drag all the folders from `OneSignalSwiftUIExample/` into your Xcode project:
   - `App/`
   - `Views/`
   - `ViewModels/`
   - `Models/`
   - `Services/`
   - `Assets.xcassets/`
3. Make sure "Copy items if needed" is **unchecked** and "Create groups" is selected

### 3. Add OneSignal SDK Dependencies

#### Option A: Swift Package Manager (Recommended)

1. In Xcode, go to **File** → **Add Package Dependencies...**
2. Enter the OneSignal SDK repository URL: `https://github.com/OneSignal/OneSignal-iOS-SDK`
3. Select version **5.0.0** or later
4. Add the following packages to your main target:
   - `OneSignalFramework`
   - `OneSignalInAppMessages`
   - `OneSignalLocation`

#### Option B: Local Development

If you're developing the SDK locally:

1. Drag the parent `OneSignal-iOS-SDK` folder into your project
2. Or add local package dependency pointing to the repo root

### 4. Configure Capabilities

1. Select your project in the navigator
2. Select your app target
3. Go to **Signing & Capabilities**
4. Add the following capabilities:
   - **Push Notifications**
   - **Background Modes** → Check "Remote notifications"

### 5. Configure Info.plist

The included `Info.plist` already has the required keys:
- `NSLocationWhenInUseUsageDescription`
- `NSLocationAlwaysAndWhenInUseUsageDescription`
- `UIBackgroundModes` with `remote-notification`

### 6. Update App ID (Optional)

The default OneSignal App ID is configured in `OneSignalService.swift`. To use your own:

1. Open `Services/OneSignalService.swift`
2. Change the `defaultAppId` value to your OneSignal App ID

## Running the App

1. Select a simulator or device
2. Build and run (⌘R)
3. Grant notification permissions when prompted
4. Explore the various OneSignal features

## Requirements

- iOS 15.0+
- Xcode 15.0+
- Swift 5.9+
- OneSignal iOS SDK 5.0+

## License

Modified MIT License - See LICENSE file for details.
