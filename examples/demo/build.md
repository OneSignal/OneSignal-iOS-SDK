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

### Environment / secrets

Per-developer build settings and OneSignal credentials are split across two layers, both wired into XcodeGen via `project.yml`:

- `Build.xcconfig` -- root xcconfig referenced by every target's `configFiles: { Debug, Release }`. It only does `#include? "Local.xcconfig"`, so a fresh clone builds with no extra setup.
- `Local.xcconfig` (gitignored) -- per-developer overrides such as `DEVELOPMENT_TEAM`, `CODE_SIGN_STYLE`, and `PROVISIONING_PROFILE_SPECIFIER`. Anything set here survives `xcodegen generate`. See `Local.xcconfig.example` for the template.
- `App/Secrets.plist` (gitignored, `optional: true` in `project.yml`) -- `<dict>` with `ONESIGNAL_APP_ID` and `ONESIGNAL_API_KEY` strings. Parsed at runtime by `App/Services/SecretsConfig.swift`. Bundled via an explicit `buildPhase: resources` source entry because XcodeGen otherwise treats `.plist` files as Info.plist-like and skips Copy Bundle Resources.
- `App/vine_boom.wav` (gitignored optional) -- bundled custom notification sound; XcodeGen picks it up automatically from the `App/` source path.

### Build & run

There is no `setup.sh` / `run-ios.sh` script -- Xcode handles everything:

1. `open iOS_SDK/OneSignalSDK.xcworkspace`
2. Pick the **App** scheme
3. ⌘R to build and run on the selected simulator or device

The only manual step is running `xcodegen generate` after editing `project.yml`.

---

## State Management

Use a single `OneSignalViewModel` (`App/ViewModels/OneSignalViewModel.swift`) as the central state manager. There is no repository wrapper -- the view-model calls the OneSignal SDK directly through a thin `OneSignalService` singleton (`App/Services/OneSignalService.swift`).

- `@MainActor final class OneSignalViewModel: ObservableObject` with `@Published` properties for reactive state (app id, push subscription id, aliases, tags, emails, SMS, triggers, consent, location, IAM paused, `isLoading`)
- The only `@Published` UI overlay state is `activeTooltip: TooltipData?`. Action dialogs are NOT in the view-model -- each section owns its own `@State` boolean and binds `.osCenteredDialog(isPresented:)` locally
- `init` calls `refreshState()` and the private `setupObservers()`, which registers `OSPushSubscriptionObserver`, `OSUserStateObserver`, and `OSNotificationPermissionObserver`. SwiftUI keeps the view-model alive for the app lifetime via `@StateObject` in `App.swift`, so no manual teardown is needed
- `OneSignalService` (singleton, `App/Services/OneSignalService.swift`) funnels every SDK call through one entry point and mirrors any setters the SDK doesn't expose as getters (consent flags) into `UserDefaults`
- `NotificationSender` (singleton, `App/Services/NotificationSender.swift`) wraps the `/notifications` REST endpoint with `URLSession` and retries with exponential backoff when the API returns 200 with empty `id` / `recipients == 0` / a non-empty `errors` payload (transient race between subscription create and notification fan-out)
- `UserFetchService` (singleton, `App/Services/UserFetchService.swift`) hydrates aliases / tags / emails / SMS via `GET /users/by/onesignal_id/{id}` -- no auth header, public endpoint
- `LiveActivityController` (`App/Services/LiveActivityController.swift`) wraps `OneSignal.LiveActivities.startDefault(...)` plus the authenticated REST update/end calls. Reads the API key via `SecretsConfig.apiKey`; missing/empty key disables UPDATE / END
- `SecretsConfig` (`App/Services/SecretsConfig.swift`) reads `ONESIGNAL_APP_ID` and `ONESIGNAL_API_KEY` from a bundled `Secrets.plist` (iOS equivalent of `.env`); both keys optional, app ID falls back to a placeholder when missing
- `TooltipService` (singleton, `App/Services/TooltipService.swift`) loads the shared tooltip JSON from `sdk-shared` on a detached task with a bundled fallback so the first render isn't blocked

### SDK initialization

`AppDelegate.application(_:didFinishLaunchingWithOptions:)` in `App/App.swift` is intentionally minimal:

```swift
OneSignalService.shared.initialize(launchOptions: launchOptions)
setupNotificationListeners()
setupInAppMessageListeners()
if #available(iOS 16.1, *) { LiveActivityController.setup() }
```

- `OneSignalService.initialize(launchOptions:)` mirrors the Capacitor `useOneSignal` startup order so toggles persist across cold launches:
  1. `OneSignal.Debug.setLogLevel(.LL_VERBOSE)`
  2. `OneSignal.setConsentRequired(prefs.getConsentRequired())`
  3. `OneSignal.setConsentGiven(prefs.getConsentGiven())`
  4. `OneSignal.initialize(appId, withLaunchOptions:)`
  5. `OneSignal.InAppMessages.paused = prefs.getIamPaused()`
  6. `OneSignal.Location.isShared = prefs.getLocationShared()`
  7. If `prefs.getExternalUserId()` is non-nil: `OneSignal.login(storedExternalId)`
- `LiveActivityController.setup()` wraps `OneSignal.LiveActivities.setupDefault()` (iOS 16.1+ guard lives in the controller, not inline)
- The four SDK listeners (`NotificationLifecycleHandler`, `NotificationClickHandler`, `InAppMessageLifecycleHandler`, `InAppMessageClickHandler`) are registered via `OneSignal.Notifications.add*Listener(...)` / `OneSignal.InAppMessages.add*Listener(...)` from the `setupNotificationListeners` / `setupInAppMessageListeners` helpers

`PreferencesService` (`App/Services/PreferencesService.swift`) is the demo's UserDefaults-backed cache, keyed under `onesignal.demo.*`. It's the single source of truth for any state the demo needs to restore on a fresh launch: consent flags, IAM-paused, location-shared, and the last-logged-in external user id. Setters on `OneSignalService` read-through and write-through this cache (in addition to forwarding to the SDK), so the view model's `@Published` props can hydrate from `service.consentRequired` / `service.consentGiven` / `service.isInAppMessagesPaused` / `service.isLocationShared` and get cached values on cold launch.

Push subscription id, opt-in, notification permission, and the live `OneSignal.User.externalId` are still read directly from the SDK at runtime (they don't need preference caching).

---

## iOS-Specific UI Details

### Notification Permission

- `OneSignalViewModel` exposes `promptPushPermission()` (no `isReady` gate, no separate `promptPush()` method)
- `ContentView` auto-prompts on first appear via an unconditional `.task { viewModel.promptPushPermission() }` modifier on the root view -- this races the OneSignal iOS-params response so the standard alert shows before the SDK can register provisional auth
- `PushSection` renders a conditional `PROMPT PUSH` button that calls `viewModel.promptPushPermission()`. The button is hidden once `hasNotificationPermission == true`

### Loading State

- `isLoading` is currently dead state in the view model -- it's flipped inside `fetchUserDataFromApi()` and `login(externalId:)` but no file under `App/Views/` references it. The Aliases / Emails / SMS / Tags sections always render their static empty-state copy via `PairList` / `SingleList` regardless of fetch state
- Stale-result protection: `fetchUserDataFromApi()` increments a `requestSequence` counter on entry, captures the value, and short-circuits after the `await` if a newer fetch has run in the meantime. Mirrors the `requestSequenceRef` pattern from the Capacitor demo so back-to-back logout / login flows don't get overwritten by a slow earlier fetch

### Toast

- `ToastPresenter` (`App/ViewModels/ToastPresenter.swift`) is a `@MainActor` `ObservableObject` with `@Published var message: String?` and a `show(_:)` method. It is created as a `@StateObject` in `App.swift` and injected into `ContentView` via `.environmentObject(toastPresenter)`.
- Section views declare `@EnvironmentObject var toast: ToastPresenter` and call `toast.show(...)` from action handlers. Only Outcomes, Custom Events, and Location check trigger the toast; everything else uses `print()` only.
- `ContentView` attaches the host `.toast(message: $toast.message)` modifier (defined in `App/Views/Components/ToastView.swift`) so a single host renders the current message regardless of which section emitted it.
- Replace-on-show: `show(_:)` cancels the previous `dismissTask`, sets `self.message`, and starts a new `Task` that sleeps `ToastPresenter.toastDurationMs` (milliseconds) and clears `message` only if it still matches the captured target string.
- Duration is the static constant `static let toastDurationMs: UInt64 = 3_000` (milliseconds).
- `OneSignalViewModel` must not hold any toast state, expose `toastMessage`, or call a `showToast` method.

### Dialogs

- Tooltip state lives on the view model as `@Published var activeTooltip: TooltipData?`. `ContentView` owns layout only and binds the tooltip dialog via `viewModel.activeTooltip` / `viewModel.dismissTooltip()` attached with `.osCenteredDialog`. Sections call `viewModel.showTooltip(for:)` from info icons.
- Sections declare `@State` booleans for their action dialogs (`@State private var addOpen = false`, `@State private var loginOpen = false`, ...) and attach `.osCenteredDialog(isPresented: $addOpen) { AddItemDialog(...) }` on the section view. Dialog confirm handlers call ViewModel SDK methods and (where applicable) `toast.show(...)`.
- `OneSignalViewModel` must not hold any action dialog visibility flags or dialog input drafts.
- `osCenteredDialog` (in `App/Views/Components/OSDialog.swift`) is implemented on top of `.fullScreenCover` with a `ClearBackgroundView` (`UIViewRepresentable`) so the dialog presents at the window level instead of being clipped to the section's frame inside `ScrollView`. The default slide-up animation is suppressed via `.transaction { $0.disablesAnimations = true }` so the dialog's own fade-in is preserved.
- Shared dialog primitives live in `App/Views/Components/`: `AddItemDialog` (typed via `AddItemType` -- single-field and pair layouts both flow through it), `MultiPairInputDialog`, `RemoveMultiDialog`, `OutcomeDialog`, `CustomNotificationDialog`, `TrackEventDialog`, `TooltipDialog`. Sections import and compose them locally.

### Accessibility (Appium)

Apply test ids with SwiftUI's `.accessibilityIdentifier("…")` modifier on every interactive element and value display. The ids match the `data-testid` values used by the Capacitor / React Native / Cordova demos one-for-one so the shared Appium suite under `sdk-shared/appium/tests/` runs unchanged against the iOS build.

XCUITest does NOT inherit identifiers from `Button(role:)` automatically -- set `.accessibilityIdentifier(...)` on every `Button`, `Toggle`, `TextField`, and the wrapping `VStack` of each section.

- `ContentView` anchors `accessibilityIdentifier("main_scroll_view")` on the SwiftUI `ScrollView` itself (not the inner `VStack`) so XCUITest exposes it as `XCUIElementTypeScrollView` with the visible viewport's rect. The shared Appium swipe workaround on iOS depends on this anchoring -- attaching the id to the inner stack reports the full content rect (multiple screens tall) and WDIO `swipe` then computes gestures outside the viewport, which iOS clips to the visible region and registers as taps on whatever button sits there.
- `ContentView` runs the auto push-permission prompt via `.task { viewModel.promptPushPermission() }` on mount. It races the OneSignal iOS-params response, so the standard alert can show before the SDK registers provisional auth (which would otherwise silently grant permission and skip the prompt entirely).

### Branding assets

`App/Assets.xcassets/` ships three branded asset folders alongside the standard `AppIcon` / `AccentColor`:

- `LaunchBackground.colorset` -- referenced by `UILaunchScreen.UIColorName` in `App/Info.plist`
- `onesignal_launch_icon.imageset` -- referenced by `UILaunchScreen.UIImageName`
- `onesignal_logo.imageset` -- rendered as a template image in the `ContentView` toolbar's principal placement

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
            self.receivedRequest, with: bestAttemptContent, withContentHandler: contentHandler)
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

- `NSLocationWhenInUseUsageDescription` and `NSLocationAlwaysAndWhenInUseUsageDescription` -- required for the Location section's prompt
- `NSSupportsLiveActivities = true` -- required for the Live Activity section
- `NSSupportsLiveActivitiesFrequentUpdates = true` -- enables high-frequency push updates to running activities
- `UIBackgroundModes` with `remote-notification` -- required for silent / background pushes
- `UILaunchScreen` references the `LaunchBackground` color set and `onesignal_launch_icon` image set bundled in `App/Assets.xcassets/`

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
├── Build.xcconfig                                 # Root xcconfig wired into every target;
│                                                  # only does `#include? "Local.xcconfig"`
├── Local.xcconfig.example                         # Per-developer overrides template
│                                                  # (DEVELOPMENT_TEAM, CODE_SIGN_STYLE, ...)
├── build.md                                       # This file
├── README.md
├── App/                                           # Main app target source
│   ├── App.swift                                  # @main + AppDelegate; calls
│   │                                              # OneSignalService.shared.initialize,
│   │                                              # registers NotificationLifecycleHandler /
│   │                                              # NotificationClickHandler /
│   │                                              # InAppMessageLifecycleHandler /
│   │                                              # InAppMessageClickHandler, runs
│   │                                              # LiveActivityController.setup() on iOS 16.1+
│   ├── Info.plist
│   ├── Secrets.plist                              # gitignored optional; ONESIGNAL_APP_ID +
│   │                                              # ONESIGNAL_API_KEY consumed by SecretsConfig
│   ├── vine_boom.wav                              # gitignored optional; custom notification sound
│   ├── Assets.xcassets/
│   │   ├── AppIcon.appiconset/
│   │   ├── AccentColor.colorset/
│   │   ├── LaunchBackground.colorset/             # UILaunchScreen background color
│   │   ├── onesignal_launch_icon.imageset/        # UILaunchScreen image
│   │   └── onesignal_logo.imageset/               # Used by ContentView toolbar
│   ├── Models/
│   │   └── AppModels.swift                        # KeyValueItem, NotificationType,
│   │                                              # AddItemType, MultiAddItemType,
│   │                                              # RemoveMultiItemType, OutcomeMode,
│   │                                              # TooltipData, UserData
│   ├── ViewModels/
│   │   ├── OneSignalViewModel.swift               # @MainActor ObservableObject, holds
│   │   │                                          # @Published activeTooltip, drives REST
│   │   │                                          # fetches via UserFetchService, registers
│   │   │                                          # SDK observers via private setupObservers()
│   │   └── ToastPresenter.swift                   # @MainActor ObservableObject; @Published
│   │                                              # message + show() with replace-on-show
│   ├── Services/
│   │   ├── OneSignalService.swift                 # Thin wrapper over OneSignal.* APIs
│   │   ├── SecretsConfig.swift                    # Reads ONESIGNAL_APP_ID / ONESIGNAL_API_KEY
│   │   │                                          # from Secrets.plist with defaults
│   │   ├── NotificationSender.swift               # /notifications POST + transient-retry loop
│   │   ├── UserFetchService.swift                 # /users GET, parses identity + tags + subs
│   │   ├── TooltipService.swift                   # Loads sdk-shared tooltip JSON (with fallback)
│   │   └── LiveActivityController.swift           # OneSignal.LiveActivities + REST update/end
│   └── Views/
│       ├── ContentView.swift                      # NavigationStack + ScrollView; layout +
│       │                                          # auto push-permission `.task` + tooltip dialog
│       │                                          # via viewModel.activeTooltip; sections own
│       │                                          # action dialog state
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
│           ├── ListWidgets.swift                  # PairList + SingleList; private helpers
│           │                                      # ListCardEmpty, ItemDivider, DeleteButton,
│           │                                      # MoreLink. No LoadingState / CollapsibleList
│           ├── KeyValueRow.swift                  # Filename vs type name differ -- type is
│           │                                      # `InfoRow` (currently unused in demo)
│           ├── OSDialog.swift                    # osCenteredDialog modifier + ClearBackgroundView
│           ├── AddItemDialog.swift                # Single + Pair input dialogs (typed via AddItemType)
│           ├── MultiPairInputDialog.swift        # Bulk add (aliases / tags / triggers)
│           ├── RemoveMultiDialog.swift           # Bulk remove (tags / triggers)
│           ├── OutcomeDialog.swift               # Normal / Unique / With Value
│           ├── CustomNotificationDialog.swift
│           ├── TrackEventDialog.swift            # Name + JSON properties, validates JSON
│           ├── TooltipDialog.swift
│           └── ToastView.swift                   # toast(message:) host modifier
│
├── OneSignalNotificationServiceExtension/         # NSE target -- rich push
│   ├── NotificationService.swift                  # Forwards to OneSignalExtension
│   ├── Info.plist                                 # NSExtension/usernotifications.service
│   └── OneSignalNotificationServiceExtension.entitlements   # MUST match main app group
│
└── OneSignalWidget/                               # Widget Extension target -- Live Activities
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
- Consent / IAM-paused / location-shared restore is NOT implemented in `App.swift` today. The view model only tracks UI toggle state in `Cached*` UserDefaults keys; the SDK side mirrors its own writes through separate `OneSignal*` UserDefaults keys via `OneSignalService`, and the two key sets are not synced. The SDK is the source of truth for everything else (push subscription id, external id, permission, tags) -- read it directly instead of caching.
- Use `OneSignal.User.pushSubscription.optIn()` / `optOut()` rather than touching `optedIn` directly; the SDK applies side effects (token registration, server sync) inside the methods.
- Drive `fetchUserDataFromApi` from the `OSUserStateObserver` only — never call it synchronously right after `OneSignal.login(...)`. The SDK assigns the new `onesignalId` asynchronously, so a synchronous fetch races the assignment and returns null.
- Set `.accessibilityIdentifier(...)` on every interactive control and value display you want to drive from Appium / XCUITest. SwiftUI does not derive identifiers from button titles, and the shared E2E suite selects by identifier.
- Bundle `Secrets.plist` with the App target for the Live Activity REST calls; without it the section disables UPDATE / END instead of failing at runtime.
