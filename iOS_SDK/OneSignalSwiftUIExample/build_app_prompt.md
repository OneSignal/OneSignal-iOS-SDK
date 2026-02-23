# OneSignal iOS Sample App - Build Guide

This document contains all the prompts and requirements needed to build the OneSignal SwiftUI Sample App from scratch. Give these prompts to an AI assistant or follow them manually to recreate the app.

---

## Phase 1: Initial Setup

### Prompt 1.1 - Project Foundation

```
Build a sample iOS app with:
- SwiftUI app lifecycle (@main App struct with UIApplicationDelegateAdaptor)
- MVVM architecture with a single ObservableObject ViewModel
- @MainActor ViewModel with @Published properties
- @EnvironmentObject for passing ViewModel to views
- iOS 16.0 minimum deployment target
- Xcode project (not Swift Package Manager)
- Bundle identifier: com.onesignal.example
- All sheets should have EMPTY input fields (for test automation - test framework enters values)
- OneSignal brand colors via AccentColor in asset catalog (#E54B4D red)
- App name: "OneSignalSwiftUIExample"
- Top header bar: OneSignal logo image + "Sample App" text, left-aligned, red background spanning full width including status bar area
- Three targets: main app, Notification Service Extension, Widget Extension
```

### Prompt 1.2 - OneSignal Service Layer

```
Centralize all OneSignal SDK calls in a single OneSignalService.swift class (singleton):

App ID:
- Stored in UserDefaults with key "OneSignalAppId"
- Default: "77e32082-ea27-42e3-a898-c72e141824ef"

Initialization:
- initialize(launchOptions:) -> sets log level verbose, calls OneSignal.initialize(), requests push permission

Identity:
- onesignalId: String? (reads OneSignal.User.onesignalId)
- externalId: String? (reads OneSignal.User.externalId)

Consent:
- setConsentRequired(_ required: Bool)
- setConsentGiven(_ granted: Bool)

User operations:
- login(externalId: String)
- logout()

Alias operations:
- addAlias(label: String, id: String)
- addAliases(_ aliases: [String: String])
- removeAlias(_ label: String)
- removeAliases(_ labels: [String])

Push subscription:
- pushSubscriptionId: String?
- isPushEnabled: Bool
- optInPush() / optOutPush()
- requestPushPermission(completion: @escaping (Bool) -> Void) with fallbackToSettings: true

Email operations:
- addEmail(_ email: String)
- removeEmail(_ email: String)

SMS operations:
- addSms(_ number: String)
- removeSms(_ number: String)

Tag operations:
- addTag(key: String, value: String)
- addTags(_ tags: [String: String])
- removeTag(_ key: String)
- removeTags(_ keys: [String])
- getTags() -> [String: String]

Outcome operations:
- sendOutcome(_ name: String)
- sendOutcome(_ name: String, value: NSNumber)
- sendUniqueOutcome(_ name: String)

In-App Messages:
- isInAppMessagesPaused: Bool (get/set)
- addTrigger(key: String, value: String)
- addTriggers(_ triggers: [String: String])
- removeTrigger(_ key: String)
- removeTriggers(_ keys: [String])
- clearTriggers()

Location:
- isLocationShared: Bool (get/set)
- requestLocationPermission()

Notifications:
- clearAllNotifications()
- hasNotificationPermission: Bool

Observers:
- addPushSubscriptionObserver(_ observer: OSPushSubscriptionObserver)
- addUserObserver(_ observer: OSUserStateObserver)
- addPermissionObserver(_ observer: OSNotificationPermissionObserver)
- addNotificationClickListener(_ listener: OSNotificationClickListener)
- addNotificationLifecycleListener(_ listener: OSNotificationLifecycleListener)
- addInAppMessageClickListener(_ listener: OSInAppMessageClickListener)
- addInAppMessageLifecycleListener(_ listener: OSInAppMessageLifecycleListener)
```

### Prompt 1.3 - NotificationSender (REST API Client)

```
Create NotificationSender.swift singleton for sending test notifications via REST API:

Properties:
- apiURL: "https://onesignal.com/api/v1/notifications"
- imageURL: "https://media.onesignal.com/automated_push_templates/ratings_template.png"

Methods:
- sendSimpleNotification(appId:completion:)
- sendNotificationWithImage(appId:completion:)
- sendCustomNotification(title:body:appId:completion:)

All methods:
- Get subscription ID from OneSignal.User.pushSubscription.id
- Check optedIn status
- POST to API with "Accept: application/vnd.onesignal.v1+json" header
- Use include_subscription_ids (not include_player_ids)
- Image notification includes ios_attachments and big_picture
- Completion handler returns Result<Void, Error>

Error enum NotificationError:
- noSubscriptionId
- notOptedIn
- apiError(statusCode: Int)

Note: REST API key is NOT required for sending to self via subscription ID.
```

### Prompt 1.4 - UserFetchService

```
Create UserFetchService.swift singleton:

Method:
- fetchUser(appId: String, onesignalId: String) async -> UserData?

Endpoint:
- GET https://api.onesignal.com/apps/{app_id}/users/by/onesignal_id/{onesignal_id}
- NO Authorization header needed (public endpoint)

Parsing:
- identity object -> aliases (filter out "external_id" and "onesignal_id")
- identity.external_id -> externalId
- properties.tags -> tags (convert all values to String)
- subscriptions where type="Email" -> emails (token field)
- subscriptions where type="SMS" -> smsNumbers (token field)

Returns UserData struct with aliases, tags, emails, smsNumbers, externalId.
```

### Prompt 1.5 - SDK Observers and App Delegate

```
In the AppDelegate within OneSignalSwiftUIExampleApp.swift, set up in didFinishLaunchingWithOptions:

1. BEFORE SDK init: Restore consent state from UserDefaults:
   - OneSignal.setConsentRequired(cached value)
   - OneSignal.setConsentGiven(cached value)

2. Initialize OneSignal via OneSignalService.shared.initialize()

3. Start Live Activity listeners:
   if #available(iOS 16.1, *) { LiveActivityController.start() }

4. AFTER init: Restore remaining cached states from UserDefaults:
   - OneSignal.InAppMessages.paused = cached paused status
   - OneSignal.Location.isShared = cached location shared status

5. Set up listeners:
   - OSNotificationLifecycleListener (onWillDisplay -> log via LogManager)
   - OSNotificationClickListener (onClick -> log via LogManager)
   - OSInAppMessageLifecycleListener (onWillDisplay, onDidDisplay, onWillDismiss, onDidDismiss -> log)
   - OSInAppMessageClickListener (onClick -> log)
   - OSLogListener -> maps SDK log levels to LogManager levels, posts to main actor

6. Initialize TooltipService (fetches on background thread, non-blocking)

7. On the SwiftUI App body, add .onOpenURL handler:
   - Calls OneSignal.LiveActivities.trackClickAndReturnOriginal(url)
   - Logs via LogManager

In OneSignalViewModel.swift, implement observers via private Observers class:
- OSPushSubscriptionObserver -> update pushSubscriptionId, isPushEnabled
- OSUserStateObserver -> log state change, call fetchUserDataFromApi()
- OSNotificationPermissionObserver -> update notificationPermissionGranted, conditionally update isPushEnabled
```

### Prompt 1.6 - LogManager

```
Create LogManager.swift:

@MainActor final class LogManager: ObservableObject {
    static let shared = LogManager()
    @Published var entries: [LogEntry] = []
    private let maxEntries = 100

    func log(_ tag: String, _ message: String, level: LogLevel)
    func clear()
    func d/i/w/e(_ tag: String, _ message: String)  // Convenience
}

LogLevel enum: debug, info, warning, error
- Each has a rawValue (D/I/W/E) and a SwiftUI Color (blue/green/orange/red)

LogEntry struct: Identifiable with UUID, timestamp, level, message
- formattedTimestamp using "HH:mm:ss" format

Every log call also prints to console via print().
Max 100 entries, oldest removed when exceeded.
```

---

## Phase 2: UI Sections

### Section Order (top to bottom) - FINAL

1. **App Section** (App ID, Guidance Banner, Consent Toggles)
2. **User Section** (Status, External ID, Login/Logout)
3. **Push Section** (Push ID, Enabled Toggle, Prompt Push)
4. **Send Push Notification Section** (Simple, With Image, Custom)
5. **In-App Messaging Section** (Pause toggle)
6. **Send In-App Message Section** (Top Banner, Bottom Banner, Center Modal, Full Screen)
7. **Aliases Section** (Add/Add Multiple, read-only list)
8. **Emails Section** (Collapsible list >5 items)
9. **SMS Section** (Collapsible list >5 items)
10. **Tags Section** (Add/Add Multiple/Remove Selected)
11. **Outcome Events Section** (Send Outcome sheet with type selection)
12. **Triggers Section** (Add/Add Multiple/Remove Selected/Clear All - IN MEMORY ONLY)
13. **Track Event Section** (Track Event with JSON validation)
14. **Location Section** (Location Shared toggle, Prompt Location button)
15. **Live Activities Section** (Activity ID field, Enter/Exit buttons)
16. **Next Activity Button**

### Prompt 2.1 - App Section

```
App Section layout:

1. SectionHeader with title "App"

2. CardContainer with App ID display (InfoRow, readonly)

3. Sticky guidance banner below App ID:
   - Text: "Add your own App ID, then rebuild to fully test all functionality."
   - Link text: "Get your keys at onesignal.com" (clickable, opens browser)
   - Light cream/yellow background (Color(red: 1.0, green: 0.98, blue: 0.90))
   - Rounded corners (12pt)

4. Consent card with up to two toggles:
   a. "Consent Required" toggle (always visible):
      - Subtitle: "Require consent before SDK processes data"
      - Sets OneSignal.consentRequired, persists to UserDefaults
   b. "Privacy Consent" toggle (only visible when Consent Required is ON):
      - Subtitle: "Consent given for data collection"
      - Sets OneSignal.consentGiven, persists to UserDefaults
      - Separated from above by CardDivider
   - NOT a blocking overlay - user can interact with app regardless

5. App version display:
   - Reads from Bundle.main CFBundleShortVersionString
```

### Prompt 2.2 - User Section

```
User Section:
- SectionHeader with title "User"
- Status card (CardContainer) with two rows separated by CardDivider:
  - Row 1: "Status" label | value ("Anonymous" in gray, or "Logged In" in green)
  - Row 2: "External ID" label | value (actual ID or em dash "—")
  - Green color: Color(red: 0.20, green: 0.66, blue: 0.33)

- LOGIN USER button (ActionButton):
  - Shows "LOGIN USER" when no user logged in
  - Shows "SWITCH USER" when user is logged in
  - Opens AddItemSheet with .externalUserId type

- LOGOUT USER button (OutlineActionButton):
  - Only visible when a user is logged in
```

### Prompt 2.3 - Push Section

```
Push Section:
- SectionHeader with title "Push" and tooltipKey "push"
- CardContainer with:
  - InfoRow showing Push Subscription ID (readonly, truncated middle)
  - CardDivider
  - ToggleRow for "Enabled" (controls optIn/optOut)
    - isEnabled parameter bound to notificationPermissionGranted
    - When disabled (no permission): toggle appears dimmed at 50% opacity

- PROMPT PUSH button (ActionButton):
  - Only visible when notification permission is NOT granted
  - Requests notification permission with fallbackToSettings
  - Hidden once permission is granted

Notification permission is automatically requested during SDK initialization.
```

### Prompt 2.4 - Send Push Notification Section

```
Send Push Notification Section:
- SectionHeader with title "Send Push Notification" and tooltipKey "sendPushNotification"
- Three full-width ActionButtons stacked vertically with 8pt spacing:
  1. SIMPLE - sends basic notification via NotificationSender
  2. WITH IMAGE - sends notification with big picture attachment
  3. CUSTOM - opens CustomNotificationSheet for custom title/body
```

### Prompt 2.5 - In-App Messaging Section

```
In-App Messaging Section:
- SectionHeader with title "In-App Messaging" and tooltipKey "inAppMessaging"
- CardContainer with ToggleRow:
  - Title: "Pause In-App Messages"
  - Subtitle: "Toggle in-app message display"
  - Persists to UserDefaults on toggle
```

### Prompt 2.6 - Send In-App Message Section

```
Send In-App Message Section:
- SectionHeader with title "Send In-App Message" and tooltipKey "sendInAppMessage"
- Four full-width ActionButtonWithIcon buttons with 8pt spacing:
  1. TOP BANNER - icon "arrow.up.to.line", trigger: "iam_type" = "top_banner"
  2. BOTTOM BANNER - icon "arrow.down.to.line", trigger: "iam_type" = "bottom_banner"
  3. CENTER MODAL - icon "square", trigger: "iam_type" = "center_modal"
  4. FULL SCREEN - icon "arrow.up.left.and.arrow.down.right", trigger: "iam_type" = "full_screen"
- Button styling:
  - RED background (AccentColor)
  - WHITE text and icon
  - SF Symbol icon on LEFT side
  - Full width, left-aligned content
  - UPPERCASE text
- On tap: adds trigger key/value and shows toast
```

### Prompt 2.7 - Aliases Section

```
Aliases Section:
- SectionHeader with title "Aliases" and tooltipKey "aliases"
- CardContainer list showing key-value pairs (read-only, NO delete icons)
- Each item shows Label | ID via KeyValueRow (no onDelete)
- Filter out "external_id" and "onesignal_id" from display
- "No aliases added" EmptyListRow when empty
- ADD button -> opens AddItemSheet with .alias type
- ADD MULTIPLE button -> opens AddMultiItemSheet with .aliases type
- No remove/delete functionality (aliases are add-only from the UI)
```

### Prompt 2.8 - Emails Section

```
Emails Section:
- SectionHeader with title "Emails" and tooltipKey "emails"
- CardContainer showing email addresses via SingleValueRow with delete (xmark) icon
- "No emails added" EmptyListRow when empty
- ADD EMAIL button -> opens AddItemSheet with .email type
- Collapse behavior when >5 items:
  - Show first 5 items
  - Show "X more available" text (tappable, AccentColor)
  - Expand to show all when tapped
```

### Prompt 2.9 - SMS Section

```
SMS Section:
- SectionHeader with title "SMS" and tooltipKey "sms"
- Same pattern as Emails Section but for phone numbers
- ADD SMS button -> opens AddItemSheet with .sms type
- Same collapse behavior when >5 items
```

### Prompt 2.10 - Tags Section

```
Tags Section:
- SectionHeader with title "Tags" and tooltipKey "tags"
- CardContainer list of key-value pairs via KeyValueRow with delete icon
- "No tags added" EmptyListRow when empty
- ADD button -> opens AddItemSheet with .tag type
- ADD MULTIPLE button -> opens AddMultiItemSheet with .tags type
- REMOVE SELECTED button (OutlineActionButton):
  - Only visible when at least one tag exists
  - Opens RemoveMultiSheet with checkboxes
```

### Prompt 2.11 - Outcome Events Section

```
Outcome Events Section:
- SectionHeader with title "Outcome Events" and tooltipKey "outcomes"
- SEND OUTCOME button -> opens OutcomeSheet with 3 radio options:
  1. Normal Outcome -> shows name input field
  2. Unique Outcome -> shows name input field
  3. Outcome with Value -> shows name and value (decimal) input fields
- Radio buttons using SF Symbols: largecircle.fill.circle (selected) / circle (unselected)
- Send button disabled until name is filled AND (if with value) value is valid number
```

### Prompt 2.12 - Triggers Section (IN MEMORY ONLY)

```
Triggers Section:
- SectionHeader with title "Triggers" and tooltipKey "triggers"
- CardContainer list of key-value pairs with delete icon
- "No triggers added" EmptyListRow when empty
- ADD button -> opens AddItemSheet with .trigger type
- ADD MULTIPLE button -> opens AddMultiItemSheet with .triggers type
- Two action buttons (only visible when triggers exist):
  - REMOVE SELECTED (OutlineActionButton) -> RemoveMultiSheet
  - CLEAR ALL (OutlineActionButton) -> removes all triggers at once

IMPORTANT: Triggers are stored IN MEMORY ONLY during the app session.
- triggers is a @Published [KeyValueItem] in ViewModel
- Triggers are NOT persisted to UserDefaults
- Triggers are cleared when the app is killed/restarted
- This is intentional - triggers are transient test data for IAM testing
```

### Prompt 2.13 - Track Event Section

```
Track Event Section:
- SectionHeader with title "Track Event" and tooltipKey "trackEvent"
- TRACK EVENT button -> opens TrackEventSheet with:
  - "Event Name" label + empty text field (required, shows "Required" error if empty on submit)
  - "Properties (optional, JSON)" label + text field with placeholder {"ABC":123}
    - If non-empty and not valid JSON, shows "Invalid JSON" error
    - If valid JSON, parsed via JSONSerialization to [String: Any]
    - If empty, passes nil
  - IMPORTANT: Replace iOS smart quotes (U+201C, U+201D) with standard quotes before JSON parsing
  - Calls OneSignal.User.trackEvent(name:properties:)
```

### Prompt 2.14 - Location Section

```
Location Section:
- SectionHeader with title "Location" and tooltipKey "location"
- CardContainer with ToggleRow:
  - Title: "Location Shared"
  - Subtitle: "Share device location with OneSignal"
  - Persists to UserDefaults on toggle
- PROMPT LOCATION button (ActionButton)
```

### Prompt 2.15 - Live Activities Section

```
Live Activities Section:
- SectionHeader with title "Live Activities" and tooltipKey "liveActivities"
- CardContainer with a text field for Activity ID:
  - Label "Activity ID" on left, TextField on right (trailing aligned)
  - autocorrectionDisabled, textInputAutocapitalization(.never)
- ENTER LIVE ACTIVITY button (ActionButton):
  - Validates ID is non-empty
  - Calls LiveActivityController.createOneSignalAwareActivity(activityId:)
  - Guarded by @available(iOS 16.1, *)
- EXIT LIVE ACTIVITY button (OutlineActionButton):
  - Validates ID is non-empty
  - Calls OneSignal.LiveActivities.exit(activityId)
```

### Prompt 2.16 - Secondary View

```
Next Activity section:
- NavigationLink styled as full-width ActionButton
- Navigates to SecondaryView

SecondaryView:
- Centered content: bell.circle.fill icon (60pt), "Secondary Activity" title, description text
- Navigation title "Secondary Activity" with inline display mode
- Simple screen for testing navigation and IAM display on different screen
```

---

## Phase 3: View User API Integration

### Prompt 3.1 - Data Loading Flow

```
Loading indicator overlay:
- Full-screen semi-transparent overlay (Color.black.opacity(0.3)) with centered ProgressView
- isLoading @Published property in ViewModel
- Show/hide based on isLoading state
- IMPORTANT: Add 100ms delay after populating data before dismissing loading indicator
  - Use Task.sleep(nanoseconds: 100_000_000)

On cold start (init):
- Check if OneSignal.User.onesignalId is not null
- If exists: call fetchUserDataFromApi() -> populate UI -> delay 100ms -> set isLoading = false
- If null: just show empty state

On login:
- Set isLoading = true immediately
- Call OneSignal.login(externalId)
- Clear old data (aliases, emails, sms, tags)
- Wait for onUserStateDidChange callback
- Callback calls fetchUserDataFromApi()

On logout:
- Set isLoading = true
- Call OneSignal.logout()
- Clear local lists
- Set isLoading = false

On onUserStateDidChange:
- Call fetchUserDataFromApi() to sync with server state

Note: REST API key is NOT required for fetchUser endpoint.
```

### Prompt 3.2 - UserData Model

```
struct UserData {
    let aliases: [String: String]    // From identity (filter out external_id, onesignal_id)
    let tags: [String: String]        // From properties.tags
    let emails: [String]              // From subscriptions where type="Email" -> token
    let smsNumbers: [String]          // From subscriptions where type="SMS" -> token
    let externalId: String?           // From identity.external_id
}
```

---

## Phase 4: Info Tooltips

### Prompt 4.1 - Tooltip Content (Remote)

```
Tooltip content is fetched at runtime from the sdk-shared repo. Do NOT bundle a local copy.

URL:
https://raw.githubusercontent.com/OneSignal/sdk-shared/main/demo/tooltip_content.json

This file is maintained in the sdk-shared repo and shared across all platform demo apps.
```

### Prompt 4.2 - TooltipService

```
Create TooltipService.swift:

final class TooltipService: ObservableObject {
    static let shared = TooltipService()
    @Published private(set) var tooltips: [String: TooltipData] = [:]
    private var initialized = false

    func initialize() {
        guard !initialized else { return }
        initialized = true
        // Fetch on background thread (DispatchQueue.global(qos: .utility))
        // Parse JSON into tooltips map
        // Update on main thread
        // On failure: leave tooltips empty - tooltips are non-critical
    }

    func getTooltip(key: String) -> TooltipData?
}

struct TooltipData {
    let title: String
    let description: String
    let options: [TooltipOption]?
}

struct TooltipOption {
    let name: String
    let description: String
}
```

### Prompt 4.3 - Tooltip UI Integration

```
SectionHeader has an optional tooltipKey parameter.
When tooltipKey is set, an info.circle.fill icon button appears.
On tap, shows an Alert with:
- Title from tooltip.title
- Message from tooltip.description + options list
- Single "OK" dismiss button
If tooltip not available: shows "Tooltip content not available."
```

---

## Phase 5: Data Persistence & Initialization

### What IS Persisted (UserDefaults)

```
UserDefaults stores:
- "OneSignalAppId" - App ID
- "CachedConsentRequired" - Consent required status
- "CachedPrivacyConsent" - Privacy consent status
- "CachedInAppMessagesPaused" - IAM paused status
- "CachedLocationShared" - Location shared status

Note: External user ID is NOT cached in UserDefaults.
It is read from OneSignal.User.externalId on each app launch.
```

### Initialization Flow

```
On app startup, state is restored in two layers:

1. AppDelegate.didFinishLaunchingWithOptions restores SDK state from UserDefaults BEFORE init:
   - OneSignal.setConsentRequired(cached)
   - OneSignal.setConsentGiven(cached)
   - OneSignalService.shared.initialize()
   Then AFTER init:
   - Start LiveActivityController
   - OneSignal.InAppMessages.paused = cached
   - OneSignal.Location.isShared = cached

2. OneSignalViewModel.init() reads UI state from the SDK (not UserDefaults):
   - consentRequired and consentGiven read from UserDefaults at @Published declaration
   - All other state read from OneSignalService (which reads from SDK)
   - refreshState() syncs push ID, push enabled, IAM paused, location, permission, external ID, tags

This two-layer approach ensures:
- The SDK is configured before anything else runs
- The ViewModel reads SDK's actual state as the source of truth
- The UI always reflects what the SDK reports
```

### What is NOT Persisted (In-Memory Only)

```
ViewModel holds in memory:
- triggers: [KeyValueItem] - session-only, cleared on restart
- aliases: populated from REST API each session
- emails, smsNumbers: populated from REST API each session
- tags: can be read from SDK via getTags(), also fetched from API
```

---

## Phase 6: Reusable Components

### Prompt 6.1 - Button Styles

```
ActionButtonStyle: ButtonStyle
- 16pt semibold white text, uppercase
- Full width, 14pt vertical padding
- AccentColor background with 0.8 opacity on press
- 8pt corner radius

ActionButton: View (title: String, action: () -> Void)
- Wraps Button with ActionButtonStyle

OutlineActionButtonStyle: ButtonStyle
- 16pt semibold AccentColor text, uppercase
- Full width, 14pt vertical padding
- systemBackground background
- 1.5pt AccentColor border, 8pt corner radius

OutlineActionButton: View (title: String, action: () -> Void)
- Wraps Button with OutlineActionButtonStyle

ActionButtonWithIcon: View (title: String, iconName: String, action: () -> Void)
- HStack with SF Symbol icon (18pt) + text (16pt semibold uppercase) + Spacer
- White text on AccentColor background, 8pt corner radius
- Left-aligned content
```

### Prompt 6.2 - Card and Layout Components

```
CardContainer<Content: View>: View
- VStack(spacing: 0) wrapping content
- systemBackground color, 12pt corner radius

SectionHeader: View (title: String, tooltipKey: String?)
- HStack with title (14pt medium, secondary color) + Spacer + optional info icon
- Padding: horizontal 4, top 16, bottom 8

CardDivider: View
- Rectangle, separator color, 0.5pt height

InfoRow: View (label: String, value: String, isMonospaced: Bool = false)
- HStack with label (15pt medium secondary) + Spacer + value (15pt primary, lineLimit 1, truncateMiddle)
- 16pt horizontal, 12pt vertical padding

ToggleRow: View (title: String, subtitle: String?, isOn: Binding<Bool>, isEnabled: Bool = true)
- HStack with VStack(title, subtitle) + Spacer + Toggle
- When !isEnabled: toggle disabled, entire row at 50% opacity
- 16pt horizontal, 12pt vertical padding

KeyValueRow: View (item: KeyValueItem, onDelete: (() -> Void)?)
- HStack with VStack(key as subheadline secondary, value as body) + Spacer + optional xmark delete button

SingleValueRow: View (value: String, onDelete: (() -> Void)?)
- HStack with value text + Spacer + optional xmark delete button

EmptyListRow: View (message: String)
- Centered text (16pt medium), 16pt vertical padding
```

### Prompt 6.3 - Sheets

```
AddItemSheet: View (itemType: AddItemType, onAdd: (String, String) -> Void, onCancel: () -> Void)
- Presents title, one or two text fields based on itemType.requiresKeyValue
- UnderlineTextFieldStyle (custom: font 17, 8pt vertical padding, 1pt separator line below)
- CANCEL / ADD (or LOGIN) buttons at bottom right
- ADD disabled until fields are valid (non-empty after trimming)
- presentationDetents([.medium]), presentationDragIndicator(.visible)
- autocorrectionDisabled, textInputAutocapitalization(.never)

AddMultiItemSheet: View (type: MultiAddItemType, onAdd: ([(String, String)]) -> Void, onCancel: () -> Void)
- Dynamic rows of key-value pairs
- "+ ADD ROW" button to append new empty row
- Remove button (xmark) per row, hidden when only one row
- ADD disabled until ALL key AND value fields in every row are non-empty
- Batch submit

RemoveMultiSheet: View (type: RemoveMultiItemType, items: [KeyValueItem], onRemove: ([String]) -> Void, onCancel: () -> Void)
- Checkbox list (checkmark.square.fill / square SF Symbols)
- Each row shows "key: value"
- REMOVE button disabled when nothing selected

CustomNotificationSheet: View (onSend: (String, String) -> Void, onCancel: () -> Void)
- Title and Body text fields
- SEND disabled until both non-empty

TrackEventSheet: View (onTrack: (String, [String: Any]?) -> Void, onCancel: () -> Void)
- Event Name field (required, shows "Required" error)
- Properties field (optional JSON, shows "Invalid JSON" error)
- IMPORTANT: Replace smart quotes (\u{201C}, \u{201D}) with standard quotes before parsing
- Parse via JSONSerialization.jsonObject as [String: Any]

OutcomeSheet: View
- Radio selection: Normal / Unique / With Value
- Name field always shown
- Value field only when "Outcome with Value" selected
- Send button disabled until valid
```

### Prompt 6.4 - LogView

```
LogView: View (@ObservedObject logManager: LogManager)
- Collapsible header bar (default collapsed):
  - "LOGS" text + "(N)" count + trash button + chevron
  - Tap to expand/collapse with animation
- When expanded:
  - 100pt height ScrollView
  - LazyVStack of log entries
  - Each entry: timestamp (11pt mono secondary) + level indicator (11pt bold mono, color-coded) + message (11pt mono, 2 line limit)
  - Auto-scroll to bottom on new entries via ScrollViewReader + onChange
  - "No logs yet" when empty

ToastView: View (message: String)
- Subheadline white text
- Black 80% opacity background, 8pt corner radius, 4pt shadow
- ViewModifier that overlays at bottom with slide+opacity transition
- Auto-dismiss after 2 seconds (handled in ViewModel's showToast method)

GuidanceBanner: View
- VStack with instruction text + Link to onesignal.com
- Light cream background, 12pt corner radius
```

---

## Phase 7: Extensions

### Prompt 7.1 - Notification Service Extension

```
Target: OneSignalNotificationServiceExtension
- Bundle ID: com.onesignal.example.OneSignalNotificationServiceExtensionA
- Deployment target: iOS 16.0
- Frameworks: OneSignalExtension, OneSignalCore, OneSignalOutcomes

NotificationService.swift (UNNotificationServiceExtension subclass):
- didReceive: calls OneSignalExtension.didReceiveNotificationExtensionRequest()
- serviceExtensionTimeWillExpire: calls OneSignalExtension.serviceExtensionTimeWillExpireRequest()

Info.plist:
- NSExtensionPointIdentifier: com.apple.usernotifications.service
- NSExtensionPrincipalClass: $(PRODUCT_MODULE_NAME).NotificationService

Entitlements:
- com.apple.security.application-groups: group.com.onesignal.example.onesignal
```

### Prompt 7.2 - Widget Extension for Live Activities

```
Target: OneSignalWidgetExtension
- Bundle ID: com.onesignal.example.OneSignalWidgetExtension
- Deployment target: iOS 16.1
- Frameworks: WidgetKit, SwiftUI, OneSignalLiveActivities

REQUIRED: Add NSSupportsLiveActivities = true to main app's Info.plist

Shared file (compiled into BOTH main app and widget extension targets):
ExampleAppWidgetAttributes.swift:
- Wrapped in #if targetEnvironment(macCatalyst) #else ... #endif
- ExampleAppFirstWidgetAttributes: OneSignalLiveActivityAttributes (simple message)
- ExampleAppSecondWidgetAttributes: OneSignalLiveActivityAttributes (message, status, progress, bugs)
- ExampleAppThirdWidgetAttributes: ActivityAttributes (NOT OneSignal-aware, manual token management)

Widget Extension files:
1. OneSignalWidgetExtensionBundle.swift (@main WidgetBundle):
   - Registers: OneSignalWidgetExtensionWidget, ExampleAppFirstWidget, ExampleAppSecondWidget,
     ExampleAppThirdWidget, DefaultOneSignalLiveActivityWidget

2. OneSignalWidgetExtensionLiveActivity.swift:
   - 4 widgets using ActivityConfiguration(for:) with Lock Screen and Dynamic Island UI
   - IMPORTANT: Apply .foregroundColor(.black) to each Lock Screen VStack (white background = invisible text otherwise)
   - Use .onesignalWidgetURL() instead of .widgetURL() for click tracking
   - Use .activityBackgroundTint(.white) and .activitySystemActionForegroundColor(.black)

3. OneSignalWidgetExtension.swift:
   - Basic StaticConfiguration widget showing time
   - Uses containerBackground(.fill.tertiary, for: .widget) on iOS 17+ (required by Apple)

4. Info.plist: NSExtensionPointIdentifier = com.apple.widgetkit-extension

Entitlements:
- com.apple.security.app-sandbox: true
- com.apple.security.network.client: true
```

### Prompt 7.3 - LiveActivityController (Main App)

```
Create LiveActivityController.swift in Services:
- Wrapped in #if targetEnvironment(macCatalyst) #else ... #endif

static func start():
- OneSignal.LiveActivities.setup(ExampleAppFirstWidgetAttributes.self)
- OneSignal.LiveActivities.setup(ExampleAppSecondWidgetAttributes.self)
- OneSignal.LiveActivities.setupDefault()
- For iOS 17.2+: manually monitor pushToStartTokenUpdates and activityUpdates
  for ExampleAppThirdWidgetAttributes (non-OneSignal-aware type)

static func createOneSignalAwareActivity(activityId:):
- Creates ExampleAppFirstWidgetAttributes with OneSignalLiveActivityAttributeData
- Requests Activity with .token push type

static func createDefaultActivity(activityId:):
- Uses OneSignal.LiveActivities.startDefault() with attribute/content dictionaries

static func createActivity(activityId:) async:
- Creates ExampleAppThirdWidgetAttributes (non-OneSignal-aware)
- Manually monitors pushTokenUpdates and calls OneSignal.LiveActivities.enter()
```

---

## Phase 8: Important Implementation Details

### Smart Quotes Handling

```
iOS automatically replaces straight double quotes with smart/curly quotes in text fields.
This breaks JSON parsing. In TrackEventSheet, ALWAYS replace smart quotes before parsing:

let trimmedProps = propertiesText
    .trimmingCharacters(in: .whitespaces)
    .replacingOccurrences(of: "\u{201C}", with: "\"")  // Left double quotation mark
    .replacingOccurrences(of: "\u{201D}", with: "\"")  // Right double quotation mark
```

### Consent Initialization Order

```
Consent state MUST be set BEFORE OneSignal.initialize():

1. Read from UserDefaults
2. OneSignal.setConsentRequired(cachedValue)
3. OneSignal.setConsentGiven(cachedValue)
4. OneSignal.initialize(appId, withLaunchOptions: launchOptions)

If consent is set after init, the SDK may process data before consent is configured.
```

### Push Permission and Enabled Toggle

```
The Push "Enabled" toggle must be disabled when notification permission is not granted:
- ToggleRow has isEnabled parameter
- Pass isEnabled: viewModel.notificationPermissionGranted
- When isEnabled is false: Toggle is .disabled(), row opacity is 0.5
- This matches Android behavior where the toggle is grayed out without permission
```

### Live Activity Click Tracking

```
When a user taps a Live Activity on the Lock Screen, iOS opens the app via a URL.
The URL is set in the widget via .onesignalWidgetURL().

In the SwiftUI App body, intercept with .onOpenURL:
- Call OneSignal.LiveActivities.trackClickAndReturnOriginal(url)
- This sends the click event to OneSignal and returns the original URL
- Log the event via LogManager
```

### Alias Management

```
Aliases use a hybrid approach:
1. On app start/login: Fetched from REST API via fetchUserDataFromApi()
2. When user adds locally: SDK call + immediate local list update (don't wait for API)
3. On next launch: fresh data from API includes synced alias
```

### Toast Messages

```
All user actions display toast messages:
- Login: "Logged in as {userId}"
- Logout: "Logged out"
- Add alias/tag/trigger: "Alias added", "Tag added", etc.
- Add multiple: "{count} alias(es) added"
- Notifications: "Simple notification sent!" or "Failed: {error}"
- In-App Messages: "Sent In-App Message: {type}"
- Outcomes: "Outcome '{name}' sent"
- Events: "Event '{name}' tracked"
- Location: "Location sharing enabled/disabled"
- Push: "Push enabled/disabled"
- Live Activities: "Live Activity '{id}' entered/exited"

Implementation:
- ViewModel has @Published toastMessage: String?
- showToast() sets message and auto-nils after 2 seconds via Task.sleep
- ToastModifier overlays at bottom of screen with animation
```

---

## Configuration

### Info.plist Required Keys

```xml
<!-- Main app Info.plist -->
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
Main app (OneSignalSwiftUIExample.entitlements):
- aps-environment: development
- com.apple.security.application-groups: group.com.onesignal.example.onesignal

NSE (OneSignalNotificationServiceExtension.entitlements):
- com.apple.security.application-groups: group.com.onesignal.example.onesignal

Widget Extension (OneSignalWidgetExtension.entitlements):
- com.apple.security.app-sandbox: true
- com.apple.security.network.client: true
```

### Bundle Identifiers

```
Main app: com.onesignal.example
NSE: com.onesignal.example.OneSignalNotificationServiceExtensionA
Widget: com.onesignal.example.OneSignalWidgetExtension
```

### OneSignal Frameworks

```
Main app links:
- OneSignalFramework, OneSignalCore, OneSignalExtension, OneSignalOutcomes
- OneSignalOSCore, OneSignalUser, OneSignalNotifications
- OneSignalInAppMessages, OneSignalLocation, OneSignalLiveActivities
- CoreLocation, SystemConfiguration, UserNotifications, WebKit

NSE links:
- OneSignalExtension, OneSignalCore, OneSignalOutcomes

Widget Extension links:
- WidgetKit, SwiftUI, OneSignalLiveActivities
```

---

## Key Files Structure

```
OneSignalSwiftUIExample/
├── OneSignalSwiftUIExample.xcodeproj/
├── OneSignalSwiftUIExample.entitlements
├── OneSignalWidgetExtension.entitlements
├── OneSignalSwiftUIExample/
│   ├── App/
│   │   └── OneSignalSwiftUIExampleApp.swift    # @main App, AppDelegate, observers
│   ├── Models/
│   │   └── AppModels.swift                      # KeyValueItem, enums, UserData, TooltipData
│   ├── Services/
│   │   ├── OneSignalService.swift               # SDK wrapper singleton
│   │   ├── NotificationSender.swift             # REST API notification sender
│   │   ├── UserFetchService.swift               # REST API user data fetcher
│   │   ├── TooltipService.swift                 # Remote tooltip loader
│   │   ├── LogManager.swift                     # Thread-safe pass-through logger
│   │   └── LiveActivityController.swift         # Live Activity setup and creation
│   ├── ViewModels/
│   │   └── OneSignalViewModel.swift             # Main @MainActor ObservableObject
│   ├── Views/
│   │   ├── ContentView.swift                    # Root view composing all sections
│   │   ├── Components/
│   │   │   ├── KeyValueRow.swift                # All reusable UI components
│   │   │   ├── NotificationGrid.swift           # Push and IAM button groups
│   │   │   ├── AddItemSheet.swift               # Single-item add sheet
│   │   │   ├── AddMultiItemSheet.swift          # Multi-pair add sheet
│   │   │   ├── RemoveMultiSheet.swift           # Checkbox remove sheet
│   │   │   ├── CustomNotificationSheet.swift    # Custom notification sheet
│   │   │   ├── TrackEventSheet.swift            # Track event with JSON sheet
│   │   │   ├── LogView.swift                    # Collapsible log viewer
│   │   │   ├── ToastView.swift                  # Toast overlay
│   │   │   └── GuidanceBanner.swift             # Setup instruction banner
│   │   └── Sections/
│   │       ├── AppInfoSection.swift             # App ID, banner, consent
│   │       ├── UserSection.swift                # User + Aliases sections
│   │       ├── SubscriptionSection.swift        # Push + Emails + SMS sections
│   │       ├── NotificationSection.swift        # Send Push + Send IAM sections
│   │       ├── MessagingSection.swift           # IAM toggle + Triggers + Outcomes
│   │       ├── TagsSection.swift                # Tags section
│   │       ├── TrackEventSection.swift          # Track Event section
│   │       ├── LocationSection.swift            # Location section
│   │       ├── LiveActivitySection.swift        # Live Activities section
│   │       └── NextScreenSection.swift          # Navigation + SecondaryView
│   ├── ExampleAppWidgetAttributes.swift         # Shared ActivityAttributes (both targets)
│   ├── Assets.xcassets/                         # App icon, AccentColor, OneSignalLogo
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

Note:

- All UI is SwiftUI (no UIKit storyboards/xibs)
- Tooltip content is fetched from remote URL (not bundled locally)
- LogView at top of screen displays SDK and app logs for debugging
- Multiple sections may share a single .swift file (e.g., MessagingSection.swift contains OutcomeEvents, IAM, and Triggers)

---

## Summary

This app demonstrates all OneSignal iOS SDK features:

- User management (login/logout, aliases with batch add)
- Push notifications (subscription, sending with images, permission handling)
- Email and SMS subscriptions
- Tags for segmentation (batch add/remove support)
- Triggers for in-app message targeting (in-memory only, batch operations)
- Outcomes for conversion tracking
- Event tracking with JSON properties validation
- In-app messages (display testing with type-specific icons)
- Location sharing
- Privacy consent management
- Live Activities (enter/exit, push-to-start, widget extension, click tracking)
- Notification Service Extension (rich notifications)

The app is designed to be:

1. **Testable** - Empty sheets for test automation
2. **Comprehensive** - All SDK features demonstrated
3. **Clean** - MVVM architecture with SwiftUI
4. **Cross-platform ready** - Tooltip content shared via JSON across all platforms
5. **Session-based triggers** - Triggers stored in memory only, cleared on restart
6. **Responsive UI** - Loading indicator with delay to ensure UI populates before dismissing
7. **Performant** - Tooltip JSON loaded on background thread
8. **Modern UI** - SwiftUI with reusable components matching Android Material3 design
9. **Batch Operations** - Add multiple items at once, select and remove multiple items
10. **Extension-ready** - Notification Service Extension and Widget Extension for Live Activities
