# OneSignal iOS Sample App - Build Guide

This document extends the shared build guide with iOS-specific details.

**Read the shared guide first:**
https://raw.githubusercontent.com/OneSignal/sdk-shared/refs/heads/main/demo/build.md

Replace `{{PLATFORM}}` with `iOS` everywhere in that guide. Everything below either overrides or supplements sections from the shared guide.

---

## Project Setup

The demo lives at `examples/demo/` (relative to the SDK repo root) and is wired into the same Xcode workspace as the SDK source (`iOS_SDK/OneSignalSDK.xcworkspace`), so it builds against your local SDK tree directly — no tarball, CocoaPods, or SPM package reference required.

`App.xcodeproj` is generated from `project.yml` with [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```bash
brew install xcodegen           # one time
cd examples/demo
xcodegen generate               # regenerates App.xcodeproj from project.yml
```

`project.yml` declares three targets and links them against the SDK framework targets defined in `iOS_SDK/OneSignalSDK/OneSignal.xcodeproj` via a `projectReferences` entry:

- **App** — main app target, embeds and signs every public SDK framework (`OneSignalCore`, `OneSignalOSCore`, `OneSignalOutcomes`, `OneSignalNotifications`, `OneSignalUser`, `OneSignalExtension`, `OneSignalLocation`, `OneSignalInAppMessages`, `OneSignalLiveActivities`, `OneSignalFramework`) plus the two local extensions
- **OneSignalNotificationServiceExtension** — links (does NOT embed) `OneSignalCore`, `OneSignalOutcomes`, `OneSignalExtension`
- **OneSignalWidget** — links (does NOT embed) `OneSignalLiveActivities`

Open `iOS_SDK/OneSignalSDK.xcworkspace`, select the **App** scheme, and run. The app and both extensions build from local SDK source, so SDK edits flow through immediately.

### App icons

`App/Assets.xcassets/AppIcon.appiconset/` ships pre-populated with the OneSignal logo asset. The widget extension has its own `OneSignalWidget/Assets.xcassets/AppIcon.appiconset/` plus an `AccentColor` and `WidgetBackground` color set (referenced via `ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME` / `ASSETCATALOG_COMPILER_WIDGET_BACKGROUND_COLOR_NAME` in `project.yml`). No regeneration step is needed.

### Build & run

There is no `setup.sh` / `run-ios.sh` script — Xcode handles everything:

1. `open iOS_SDK/OneSignalSDK.xcworkspace`
2. Pick the **App** scheme
3. ⌘R to build and run on the selected simulator or device

The only manual step is running `xcodegen generate` after editing `project.yml`.

---

## State Management

Use a single `OneSignalViewModel` (`App/ViewModels/OneSignalViewModel.swift`) as the central state manager. There is no repository wrapper — the view-model calls the OneSignal SDK directly through a thin `OneSignalService` singleton (`App/Services/OneSignalService.swift`).

- `@MainActor final class OneSignalViewModel: ObservableObject` with `@Published` properties for reactive state (app id, push subscription id, aliases, tags, emails, SMS, triggers, consent, location, IAM paused, loading, sheet visibility)
- A `requestSequence` counter discards stale REST results when a newer fetch is in flight (mirrors the `requestSequenceRef` in Capacitor)
- One `setup()` call registers SDK observers (`OSPushSubscriptionObserver`, `OSUserStateObserver`, `OSNotificationPermissionObserver`); SwiftUI keeps the view-model alive for the app lifetime via `@StateObject` in `App.swift`, so no manual teardown is needed
- `OneSignalService` (singleton, `App/Services/OneSignalService.swift`) funnels every SDK call through one entry point and mirrors any setters the SDK doesn't expose as getters (consent flags) into `UserDefaults`
- `NotificationSender` (singleton, `App/Services/NotificationSender.swift`) wraps the `/notifications` REST endpoint with `URLSession` and retries with exponential backoff when the API returns 200 with empty `id` / `recipients == 0` / a non-empty `errors` payload (transient race between subscription create and notification fan-out)
- `UserFetchService` (singleton, `App/Services/UserFetchService.swift`) hydrates aliases / tags / emails / SMS via `GET /users/by/onesignal_id/{id}` — no auth header, public endpoint
- `LiveActivityController` (`App/Services/LiveActivityController.swift`) wraps `OneSignal.LiveActivities.startDefault(...)` plus the authenticated REST update/end calls. Reads the API key via `SecretsConfig.apiKey`; missing/empty key disables UPDATE / END
- `SecretsConfig` (`App/Services/SecretsConfig.swift`) reads `ONESIGNAL_APP_ID` and `ONESIGNAL_API_KEY` from a bundled `Secrets.plist` (iOS equivalent of `.env`); both keys optional, app ID falls back to a placeholder when missing
- `TooltipService` (singleton, `App/Services/TooltipService.swift`) loads the shared tooltip JSON from `sdk-shared` on a detached task with a bundled fallback so the first render isn't blocked

### SDK state restoration

In `App.swift`'s `AppDelegate.application(_:didFinishLaunchingWithOptions:)`, restore SDK state from `UserDefaults` BEFORE calling `initialize`:

```swift
OneSignal.Debug.setLogLevel(.LL_VERBOSE)
OneSignal.setConsentRequired(cachedConsentRequired)
OneSignal.setConsentGiven(cachedConsentGiven)
OneSignalService.shared.initialize(launchOptions: launchOptions)
```

Then AFTER initialize:

```swift
OneSignal.LiveActivities.setupDefault()          // iOS 16.1+
OneSignal.InAppMessages.paused = cachedIamPaused
OneSignal.Location.isShared    = cachedLocationShared
```

Read UI state directly from the SDK once it's initialized (`OneSignal.User.pushSubscription.id`, `OneSignal.User.pushSubscription.optedIn`, `OneSignal.User.externalId`, `OneSignal.Notifications.permission`) instead of from cache.

---

## iOS-Specific UI Details

### Notification Permission

- `OneSignalViewModel` exposes `isReady` (set after the initial `refreshState()` runs) and `promptPush()`
- `PushSection` calls `viewModel.promptPush()` from a `.task` modifier gated on `isReady`
- The PROMPT PUSH button is rendered conditionally — hidden once `hasNotificationPermission == true`

### Loading State

- No global overlay; the four list sections that depend on the `/users` fetch (Aliases, Emails, SMS, Tags) render an inline `ProgressView` in the empty-state slot when `viewModel.isLoading` is true
- Stale-result protection via `requestSequence` in the view-model (each fetch captures the counter; results are dropped if a newer fetch has incremented it)

### Toast

- A lightweight `ToastView` modifier (`App/Views/Components/ToastView.swift`) attached via `.toast(message: $viewModel.toastMessage)` on the root `ContentView`. Setting `toastMessage` shows it; auto-dismisses after 3s
- Only login / logout / outcomes / track event / location-check actions feed the toast (matches Phase 7.6 of the shared guide); everything else uses `print()` only

### Send In-App Message Icons

Use SF Symbols: `arrow.up.to.line`, `arrow.down.to.line`, `square`, `rectangle.expand.vertical`.

### Sheets

All modals live in `App/Views/Components/` and render through SwiftUI's `.sheet(isPresented:)`. Single-field prompts use `AddItemSheet` (typed via `AddItemType`); pair prompts go through the same `AddItemSheet` with a key-and-value layout selected by the type; bulk add/remove use `MultiPairInputSheet` and `RemoveMultiSheet`. Specialized sheets: `OutcomeSheet`, `CustomNotificationSheet`, `TrackEventSheet`, `TooltipSheet`.

### Accessibility (Appium)

Apply test ids with SwiftUI's `.accessibilityIdentifier("…")` modifier on every interactive element and value display. The ids match the `data-testid` values used by the Capacitor / React Native / Cordova demos one-for-one so the shared Appium suite under `sdk-shared/appium/tests/` runs unchanged against the iOS build.

XCUITest does NOT inherit identifiers from `Button(role:)` automatically — set `.accessibilityIdentifier(...)` on every `Button`, `Toggle`, `TextField`, and the wrapping `VStack` of each section.

---

## Xcode Project Targets

### Notification Service Extension

`OneSignalNotificationServiceExtension/NotificationService.swift` forwards every push to `OneSignalExtension` so rich attachments (`ios_attachments`), confidential pushes, and `mutable_content` payloads work:

```swift
override func didReceive(_ request: UNNotificationRequest,
                         withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
    self.receivedRequest = request
    self.contentHandler = contentHandler
    self.bestAttemptContent = request.content.mutableCopy() as? UNMutableNotificationContent

    if let bestAttemptContent = bestAttemptContent {
        OneSignalExtension.didReceiveNotificationExtensionRequest(
            request, with: bestAttemptContent, withContentHandler: contentHandler)
    }
}

override func serviceExtensionTimeWillExpire() {
    if let contentHandler, let bestAttemptContent {
        OneSignalExtension.serviceExtensionTimeWillExpireRequest(receivedRequest, with: bestAttemptContent)
        contentHandler(bestAttemptContent)
    }
}
```

The NSE entitlements file (`OneSignalNotificationServiceExtension/OneSignalNotificationServiceExtension.entitlements`) **must** declare the same `com.apple.security.application-groups` value as the main app — both ship with `group.com.onesignal.example.onesignal`. If you change the group to install on a real device under your own team, change it in BOTH files to the same string.

### Widget Extension (Live Activities)

`OneSignalWidget/OneSignalWidgetLiveActivity.swift` renders the order tracking flow using `DefaultLiveActivityAttributes` from `OneSignalLiveActivities`. Replace the file with the shared reference implementation at `https://raw.githubusercontent.com/OneSignal/sdk-shared/main/demo/LiveActivity.swift` whenever the canonical version is updated.

The widget target's deployment target is `16.2` (project-wide is `16.0`) because Dynamic Island APIs require 16.2. `NSSupportsLiveActivities = true` is declared in `App/Info.plist`.

---

## Platform Config

### Entitlements

`App.entitlements` (main app):

```xml
<key>aps-environment</key>
<string>development</string>
<key>com.apple.security.application-groups</key>
<array>
    <string>group.com.onesignal.example.onesignal</string>
</array>
```

`OneSignalNotificationServiceExtension.entitlements` mirrors the same app group. Both must match or rich pushes fail silently.

### Info.plist

`App/Info.plist` declares:

- `NSLocationWhenInUseUsageDescription` and `NSLocationAlwaysAndWhenInUseUsageDescription` — required for the Location section's prompt
- `NSSupportsLiveActivities = true` — required for the Live Activity section
- `UIBackgroundModes` with `remote-notification` — required for silent / background pushes

### Custom Notification Sound

The demo bundles `examples/demo/App/vine_boom.wav` (sourced from [sdk-shared/assets](https://github.com/OneSignal/sdk-shared/tree/main/assets)). XcodeGen picks it up automatically via the `sources: - path: App` block, and `NotificationSender.swift`'s WITH SOUND payload sets `ios_sound = "vine_boom.wav"` to play it.

### Credentials (App ID & REST API key)

The iOS demo does NOT use a `.env` file. Instead, `App/Services/SecretsConfig.swift` reads both `ONESIGNAL_APP_ID` and `ONESIGNAL_API_KEY` from a single `Secrets.plist` bundled with the App target — the iOS-idiomatic equivalent of `.env`:

```xml
<dict>
    <key>ONESIGNAL_APP_ID</key>
    <string>YOUR_APP_ID</string>
    <key>ONESIGNAL_API_KEY</key>
    <string>YOUR_REST_API_KEY</string>
</dict>
```

- `ONESIGNAL_APP_ID` — optional. Falls back to `SecretsConfig.defaultAppId` (the placeholder defined in `sdk-shared/demo/build.md`) when missing or empty. `OneSignalService.shared.appId` is captured from `SecretsConfig.appId` once during `init`, so the value is stable for the running session.
- `ONESIGNAL_API_KEY` — optional, only needed for Live Activity **update** / **end**. `LiveActivityController.hasApiKey` is `true` when set; otherwise the UPDATE / END buttons disable themselves and show a hint in the Live Activity section.

`Secrets.plist` is gitignored.

---

## File Structure

```
examples/demo/
├── App.xcodeproj                                  # Generated by `xcodegen generate`
├── project.yml                                    # XcodeGen project definition
├── App.entitlements                               # aps-environment + app group
├── build.md                                       # This file
├── README.md
├── App/                                           # Main app target source
│   ├── App.swift                                  # @main + AppDelegate, SDK init,
│   │                                              # notification/IAM listeners, Live Activity setup
│   ├── Info.plist
│   ├── Assets.xcassets/                           # AppIcon + AccentColor
│   ├── Models/
│   │   └── AppModels.swift                        # KeyValueItem, NotificationType,
│   │                                              # AddItemType, MultiAddItemType,
│   │                                              # RemoveMultiItemType, OutcomeMode,
│   │                                              # TooltipData, UserData
│   ├── ViewModels/
│   │   └── OneSignalViewModel.swift               # @MainActor ObservableObject, all UI state,
│   │                                              # request-sequence guard, mergePairs/mergeUnique
│   ├── Services/
│   │   ├── OneSignalService.swift                 # Thin wrapper over OneSignal.* APIs
│   │   ├── NotificationSender.swift               # /notifications POST + transient-retry loop
│   │   ├── UserFetchService.swift                 # /users GET, parses identity + tags + subs
│   │   ├── TooltipService.swift                   # Loads sdk-shared tooltip JSON (with fallback)
│   │   └── LiveActivityController.swift           # OneSignal.LiveActivities + REST update/end
│   └── Views/
│       ├── ContentView.swift                      # NavigationStack + ScrollView, composes sections,
│       │                                          # binds every sheet to the view-model
│       ├── Theme.swift                            # Design tokens from sdk-shared/demo/styles.md
│       ├── Sections/
│       │   ├── AppSection.swift
│       │   ├── UserSection.swift
│       │   ├── PushSection.swift
│       │   ├── SendPushSection.swift
│       │   ├── InAppSection.swift
│       │   ├── SendIamSection.swift
│       │   ├── AliasesSection.swift
│       │   ├── EmailsSection.swift
│       │   ├── SmsSection.swift
│       │   ├── TagsSection.swift
│       │   ├── OutcomesSection.swift
│       │   ├── TriggersSection.swift
│       │   ├── CustomEventsSection.swift
│       │   ├── LocationSection.swift
│       │   └── LiveActivitySection.swift
│       └── Components/
│           ├── SectionCard.swift
│           ├── ActionButton.swift
│           ├── ToggleRow.swift
│           ├── ListWidgets.swift                  # PairItem, SingleItem, EmptyState, LoadingState,
│           │                                      # CollapsibleList, PairList
│           ├── KeyValueRow.swift
│           ├── AddItemSheet.swift                 # Single + Pair input sheets (typed)
│           ├── MultiPairInputSheet.swift          # Bulk add (aliases / tags / triggers)
│           ├── RemoveMultiSheet.swift             # Bulk remove (tags / triggers)
│           ├── OutcomeSheet.swift                 # Normal / Unique / With Value
│           ├── CustomNotificationSheet.swift
│           ├── TrackEventSheet.swift              # Name + JSON properties, validates JSON
│           ├── TooltipSheet.swift
│           └── ToastView.swift
│
├── OneSignalNotificationServiceExtension/         # NSE target — rich push
│   ├── NotificationService.swift                  # Forwards to OneSignalExtension
│   ├── Info.plist                                 # NSExtension/usernotifications.service
│   └── OneSignalNotificationServiceExtension.entitlements   # MUST match main app group
│
└── OneSignalWidget/                               # Widget Extension target — Live Activities
    ├── OneSignalWidgetBundle.swift                # @main WidgetBundle
    ├── OneSignalWidgetLiveActivity.swift          # Lock screen + Dynamic Island UI for
    │                                              # DefaultLiveActivityAttributes
    ├── Info.plist                                 # NSExtension/widgetkit-extension
    └── Assets.xcassets/                           # WidgetBackground, AccentColor, AppIcon
```

---

## iOS Best Practices

- Re-run `xcodegen generate` after any change to `project.yml` so `App.xcodeproj` stays in sync. Commit the regenerated project file with the YAML change.
- Always link the SDK frameworks through the workspace's `projectReferences` (not via SPM or CocoaPods inside the demo) so the demo builds against your local SDK edits without an extra publish step.
- Keep the app group string identical in `App.entitlements` AND `OneSignalNotificationServiceExtension.entitlements` — they MUST match for confidential pushes and badge sync.
- Embed and code-sign each SDK framework on the App target only; the NSE and Widget targets must link the frameworks they need without embedding (the App target owns them in `Frameworks/`).
- Restore consent flags BEFORE `OneSignal.initialize(...)`; restore IAM paused / location shared AFTER. The SDK is the source of truth for everything else (push subscription id, external id, permission, tags) — read it directly instead of caching.
- Use `OneSignal.User.pushSubscription.optIn()` / `optOut()` rather than touching `optedIn` directly; the SDK applies side effects (token registration, server sync) inside the methods.
- Drive `fetchUserDataFromApi` from the `OSUserStateObserver` only — never call it synchronously right after `OneSignal.login(...)`. The SDK assigns the new `onesignalId` asynchronously, so a synchronous fetch races the assignment and returns null.
- Set `.accessibilityIdentifier(...)` on every interactive control and value display you want to drive from Appium / XCUITest. SwiftUI does not derive identifiers from button titles, and the shared E2E suite selects by identifier.
- Bundle `Secrets.plist` with the App target for the Live Activity REST calls; without it the section disables UPDATE / END instead of failing at runtime.
