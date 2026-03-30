# OneSignal iOS Sample App - Build Guide

This document extends the shared build guide with iOS-specific details.

**Read the shared guide first:**
https://raw.githubusercontent.com/OneSignal/sdk-shared/refs/heads/main/demo/build.md

Replace `{{PLATFORM}}` with `iOS` everywhere in that guide. Everything below either overrides or supplements sections from the shared guide.

---

## iOS Project Setup

- SwiftUI app lifecycle (`@main App` struct with `UIApplicationDelegateAdaptor`)
- MVVM: single `@MainActor ObservableObject` ViewModel with `@Published` properties
- `@EnvironmentObject` for passing ViewModel to child views
- iOS 16.0 minimum deployment target
- Xcode project (not Swift Package Manager executable)
- Bundle identifier: `com.onesignal.example`
- App name: "OneSignalSwiftUIExample"
- AccentColor in asset catalog: `#E54B4D`
- Three targets: main app, Notification Service Extension, Widget Extension
- Reference OneSignal SDK frameworks from the parent workspace (`OneSignalSDK.xcworkspace`)

### Header Bar

- OneSignal logo image asset + "Sample App" text, centered, red (`osPrimary`) background spanning full width including status bar area
- Logo height: 22pt

---

## OneSignalService.swift (Singleton)

Wraps all OneSignal SDK calls. iOS-specific API surface:

```
App ID:
- Stored in UserDefaults key "OneSignalAppId"
- Default: "77e32082-ea27-42e3-a898-c72e141824ef"

Initialization:
- initialize(launchOptions:) -> sets log level verbose, calls OneSignal.initialize(), requests push permission

Identity:
- onesignalId: String? (OneSignal.User.onesignalId)
- externalId: String? (OneSignal.User.externalId)

Push subscription:
- pushSubscriptionId: String? (OneSignal.User.pushSubscription.id)
- isPushEnabled: Bool (OneSignal.User.pushSubscription.optedIn)
- optInPush() / optOutPush()
- requestPushPermission(completion:) with fallbackToSettings: true

Observers:
- addPushSubscriptionObserver(_ observer: OSPushSubscriptionObserver)
- addUserObserver(_ observer: OSUserStateObserver)
- addPermissionObserver(_ observer: OSNotificationPermissionObserver)
- addNotificationClickListener(_ listener: OSNotificationClickListener)
- addNotificationLifecycleListener(_ listener: OSNotificationLifecycleListener)
- addInAppMessageClickListener(_ listener: OSInAppMessageClickListener)
- addInAppMessageLifecycleListener(_ listener: OSInAppMessageLifecycleListener)
```

All other methods (aliases, email, SMS, tags, triggers, outcomes, location, consent, IAM, notifications) follow the shared spec's OneSignal Repository API.

---

## NotificationSender.swift

Extends the shared API client spec with iOS-specific fields:

- Image notifications include `ios_attachments` dict (in addition to `big_picture`)
- Sound notifications include `ios_sound: "vine_boom.wav"`
- Copy `vine_boom.wav` from `sdk-shared/assets/` into the app bundle

---

## AppDelegate & SDK Observers

In `OneSignalSwiftUIExampleApp.swift`, the `AppDelegate` handles initialization in `didFinishLaunchingWithOptions`:

```
1. BEFORE SDK init: restore consent from UserDefaults
   - OneSignal.setConsentRequired(cached)
   - OneSignal.setConsentGiven(cached)

2. OneSignalService.shared.initialize(launchOptions:)

3. Start Live Activities:
   if #available(iOS 16.1, *) { LiveActivityController.start() }

4. AFTER init: restore cached states
   - OneSignal.InAppMessages.paused = cached
   - OneSignal.Location.isShared = cached

5. Register listeners:
   - OSNotificationLifecycleListener (onWillDisplay -> LogManager)
   - OSNotificationClickListener (onClick -> LogManager)
   - OSInAppMessageLifecycleListener (all 4 callbacks -> LogManager)
   - OSInAppMessageClickListener (onClick -> LogManager)
   - OSLogListener -> maps SDK log levels to LogManager levels

6. Initialize TooltipService (background thread, non-blocking)

7. SwiftUI App body: .onOpenURL handler
   - OneSignal.LiveActivities.trackClickAndReturnOriginal(url)
```

ViewModel observers (private `Observers` class):

- `OSPushSubscriptionObserver` -> update pushSubscriptionId, isPushEnabled
- `OSUserStateObserver` -> log, call fetchUserDataFromApi()
- `OSNotificationPermissionObserver` -> update notificationPermissionGranted

---

## Live Activities (iOS-only)

### Live Activities Section (after Location, before Next Activity)

- SectionHeader "Live Activities" with tooltipKey "liveActivities"
- CardContainer with Activity ID text field (trailing aligned)
- ENTER LIVE ACTIVITY button -> `LiveActivityController.createOneSignalAwareActivity(activityId:)`
  - Guarded by `@available(iOS 16.1, *)`
- EXIT LIVE ACTIVITY button (outlined) -> `OneSignal.LiveActivities.exit(activityId)`

### LiveActivityController.swift

In Services folder, wrapped in `#if targetEnvironment(macCatalyst) #else ... #endif`:

```
static func start():
- OneSignal.LiveActivities.setup(ExampleAppFirstWidgetAttributes.self)
- OneSignal.LiveActivities.setup(ExampleAppSecondWidgetAttributes.self)
- OneSignal.LiveActivities.setupDefault()
- iOS 17.2+: monitor pushToStartTokenUpdates for ExampleAppThirdWidgetAttributes

static func createOneSignalAwareActivity(activityId:):
- Creates ExampleAppFirstWidgetAttributes with OneSignalLiveActivityAttributeData
- Requests Activity with .token push type

static func createDefaultActivity(activityId:):
- Uses OneSignal.LiveActivities.startDefault()

static func createActivity(activityId:) async:
- Creates ExampleAppThirdWidgetAttributes (non-OneSignal-aware)
- Manually monitors pushTokenUpdates and calls OneSignal.LiveActivities.enter()
```

### ExampleAppWidgetAttributes.swift (shared between main app and widget targets)

Wrapped in `#if targetEnvironment(macCatalyst) #else ... #endif`:

- `ExampleAppFirstWidgetAttributes`: `OneSignalLiveActivityAttributes` (simple message)
- `ExampleAppSecondWidgetAttributes`: `OneSignalLiveActivityAttributes` (message, status, progress, bugs)
- `ExampleAppThirdWidgetAttributes`: `ActivityAttributes` (NOT OneSignal-aware)

### Live Activity Click Tracking

In SwiftUI App body, `.onOpenURL` intercepts Live Activity taps:
- `OneSignal.LiveActivities.trackClickAndReturnOriginal(url)` sends click event and returns original URL

---

## Extensions

### Notification Service Extension

- Target: `OneSignalNotificationServiceExtension`
- Bundle ID: `com.onesignal.example.OneSignalNotificationServiceExtensionA`
- Deployment target: iOS 16.0
- Frameworks: OneSignalExtension, OneSignalCore, OneSignalOutcomes
- `NotificationService.swift` (`UNNotificationServiceExtension`):
  - `didReceive`: calls `OneSignalExtension.didReceiveNotificationExtensionRequest()`
  - `serviceExtensionTimeWillExpire`: calls `OneSignalExtension.serviceExtensionTimeWillExpireRequest()`

### Widget Extension

- Target: `OneSignalWidgetExtension`
- Bundle ID: `com.onesignal.example.OneSignalWidgetExtension`
- Deployment target: iOS 16.1
- Frameworks: WidgetKit, SwiftUI, OneSignalLiveActivities

Files:

1. `OneSignalWidgetExtensionBundle.swift` (`@main WidgetBundle`)
2. `OneSignalWidgetExtensionLiveActivity.swift` - 4 activity widgets
   - Use `.onesignalWidgetURL()` instead of `.widgetURL()` for click tracking
   - Apply `.foregroundColor(.black)` to Lock Screen VStacks (white background)
   - Use `.activityBackgroundTint(.white)` and `.activitySystemActionForegroundColor(.black)`
3. `OneSignalWidgetExtension.swift` - basic `StaticConfiguration` widget
   - Uses `containerBackground(.fill.tertiary, for: .widget)` on iOS 17+

---

## iOS-Specific Implementation Notes

### Smart Quotes

iOS keyboard replaces straight quotes with curly quotes in text fields. In `TrackEventSheet`, always replace before JSON parsing:

```swift
.replacingOccurrences(of: "\u{201C}", with: "\"")  // Left double quotation mark
.replacingOccurrences(of: "\u{201D}", with: "\"")  // Right double quotation mark
```

### Consent Initialization Order

Consent state MUST be set BEFORE `OneSignal.initialize()`:

```swift
OneSignal.setConsentRequired(cachedValue)
OneSignal.setConsentGiven(cachedValue)
OneSignal.initialize(appId, withLaunchOptions: launchOptions)
```

### Data Persistence (UserDefaults keys)

```
"OneSignalAppId"              - App ID
"CachedConsentRequired"       - Consent required status
"CachedPrivacyConsent"        - Privacy consent status
"CachedInAppMessagesPaused"   - IAM paused status
"CachedLocationShared"        - Location shared status
```

External user ID is NOT cached — read from `OneSignal.User.externalId` on launch.

---

## Configuration

### Info.plist

```xml
<key>NSSupportsLiveActivities</key>
<true/>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>This app uses your location to provide location-based notifications and services.</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app uses your location to provide location-based notifications.</string>
<key>UIBackgroundModes</key>
<array>
    <string>remote-notification</string>
</array>
```

### Entitlements

```
Main app:
- aps-environment: development
- com.apple.security.application-groups: group.com.onesignal.example.onesignal

NSE:
- com.apple.security.application-groups: group.com.onesignal.example.onesignal

Widget Extension:
- com.apple.security.app-sandbox: true
- com.apple.security.network.client: true
```

### Bundle Identifiers

```
Main app: com.onesignal.example
NSE:      com.onesignal.example.OneSignalNotificationServiceExtensionA
Widget:   com.onesignal.example.OneSignalWidgetExtension
```

### OneSignal Frameworks

```
Main app: OneSignalFramework, OneSignalCore, OneSignalExtension, OneSignalOutcomes,
          OneSignalOSCore, OneSignalUser, OneSignalNotifications,
          OneSignalInAppMessages, OneSignalLocation, OneSignalLiveActivities,
          CoreLocation, SystemConfiguration, UserNotifications, WebKit

NSE:      OneSignalExtension, OneSignalCore, OneSignalOutcomes

Widget:   WidgetKit, SwiftUI, OneSignalLiveActivities
```

---

## File Structure

```
OneSignalSwiftUIExample/
├── OneSignalSwiftUIExample.xcodeproj/
├── OneSignalSwiftUIExample.entitlements
├── OneSignalWidgetExtension.entitlements
├── OneSignalSwiftUIExample/
│   ├── App/
│   │   └── OneSignalSwiftUIExampleApp.swift
│   ├── Models/
│   │   └── AppModels.swift
│   ├── Services/
│   │   ├── OneSignalService.swift
│   │   ├── NotificationSender.swift
│   │   ├── UserFetchService.swift
│   │   ├── TooltipService.swift
│   │   ├── LogManager.swift
│   │   └── LiveActivityController.swift
│   ├── ViewModels/
│   │   └── OneSignalViewModel.swift
│   ├── Views/
│   │   ├── ContentView.swift
│   │   ├── Components/
│   │   │   ├── KeyValueRow.swift          # Design tokens + all reusable UI components
│   │   │   ├── NotificationGrid.swift     # Push and IAM button groups
│   │   │   ├── AddItemSheet.swift
│   │   │   ├── AddMultiItemSheet.swift
│   │   │   ├── RemoveMultiSheet.swift
│   │   │   ├── CustomNotificationSheet.swift
│   │   │   ├── TrackEventSheet.swift
│   │   │   ├── LogView.swift
│   │   │   ├── ToastView.swift
│   │   │   └── GuidanceBanner.swift
│   │   └── Sections/
│   │       ├── AppInfoSection.swift
│   │       ├── UserSection.swift          # User + Aliases
│   │       ├── SubscriptionSection.swift  # Push + Emails + SMS
│   │       ├── NotificationSection.swift  # Send Push + Send IAM
│   │       ├── MessagingSection.swift     # IAM + Outcomes + Triggers
│   │       ├── TagsSection.swift
│   │       ├── TrackEventSection.swift
│   │       ├── LocationSection.swift
│   │       ├── LiveActivitySection.swift
│   │       └── NextScreenSection.swift
│   ├── ExampleAppWidgetAttributes.swift   # Shared (both targets)
│   ├── Assets.xcassets/
│   └── Info.plist
├── OneSignalNotificationServiceExtension/
│   ├── NotificationService.swift
│   ├── Info.plist
│   └── OneSignalNotificationServiceExtension.entitlements
└── OneSignalWidgetExtension/
    ├── OneSignalWidgetExtensionBundle.swift
    ├── OneSignalWidgetExtensionLiveActivity.swift
    ├── OneSignalWidgetExtension.swift
    └── Info.plist
```
