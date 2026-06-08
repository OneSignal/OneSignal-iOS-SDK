/**
 * Modified MIT License
 *
 * Copyright 2024 OneSignal
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * 1. The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * 2. All copies of substantial portions of the Software may only be used in connection
 * with services provided by OneSignal.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

import Foundation
import Combine
import OneSignalFramework

/// ViewModel that backs every section of the demo
@MainActor
final class OneSignalViewModel: ObservableObject {

    // MARK: - App / Consent

    @Published var appId: String
    @Published var consentRequired: Bool = false
    @Published var consentGiven: Bool = false

    // MARK: - Identity

    @Published var externalUserId: String?
    @Published var aliases: [KeyValueItem] = []

    // MARK: - Push

    @Published var pushSubscriptionId: String?
    @Published var isPushEnabled: Bool = false
    @Published var hasNotificationPermission: Bool = false

    // MARK: - Channels

    @Published var emails: [String] = []
    @Published var smsNumbers: [String] = []

    // MARK: - Tags / Triggers

    @Published var tags: [KeyValueItem] = []
    @Published var triggers: [KeyValueItem] = []

    // MARK: - In-App / Location

    @Published var isInAppMessagesPaused: Bool = false
    @Published var isLocationShared: Bool = false

    // MARK: - UI State

    @Published var activeTooltip: TooltipData?

    // MARK: - Computed

    var isLoggedIn: Bool {
        guard let id = externalUserId else { return false }
        return !id.isEmpty
    }

    var loginButtonTitle: String { isLoggedIn ? "SWITCH USER" : "LOGIN USER" }

    // MARK: - Private

    private let service: OneSignalService
    private let prefs: PreferencesService
    private var observers = Observers()

    /// Monotonically incremented on every `fetchUserDataFromApi` call. The
    /// value captured at entry guards the post-await write so a slow fetch
    /// for an old `onesignalId` cannot overwrite a newer fetch's results.
    private var requestSequence: UInt64 = 0

    // MARK: - Init

    init(service: OneSignalService = .shared, prefs: PreferencesService = .shared) {
        self.service = service
        self.prefs = prefs
        self.appId = service.appId
        self.consentRequired = service.consentRequired
        self.consentGiven = service.consentGiven
        self.externalUserId = service.externalId ?? prefs.getExternalUserId()
        self.hasNotificationPermission = service.hasNotificationPermission
        refreshState()
        setupObservers()

        TooltipService.shared.loadIfNeeded()

        if service.onesignalId != nil {
            Task { await fetchUserDataFromApi() }
        }
    }

    // MARK: - State sync

    func refreshState() {
        pushSubscriptionId = service.pushSubscriptionId
        isPushEnabled = service.isPushEnabled
        isInAppMessagesPaused = service.isInAppMessagesPaused
        isLocationShared = service.isLocationShared
        hasNotificationPermission = service.hasNotificationPermission
        externalUserId = service.externalId

        let sdkTags = service.getTags()
        tags = sdkTags.map { KeyValueItem(key: $0.key, value: $0.value) }
    }

    func fetchUserDataFromApi() async {
        guard let onesignalId = service.onesignalId else { return }
        requestSequence &+= 1
        let captured = requestSequence

        let userData = await UserFetchService.shared.fetchUser(appId: appId, onesignalId: onesignalId)

        // Drop the result if a newer fetch has started while this one was in flight.
        guard captured == requestSequence else { return }

        if let userData = userData {
            aliases = userData.aliases.map { KeyValueItem(key: $0.key, value: $0.value) }
            tags = userData.tags.map { KeyValueItem(key: $0.key, value: $0.value) }
            emails = userData.emails
            smsNumbers = userData.smsNumbers
            if let extId = userData.externalId, !extId.isEmpty {
                externalUserId = extId
            }
        }
    }

    // MARK: - Consent

    func setConsentRequired(_ required: Bool) {
        consentRequired = required
        service.consentRequired = required
        if !required {
            consentGiven = true
            service.consentGiven = true
        }
    }

    func setConsentGiven(_ granted: Bool) {
        consentGiven = granted
        service.consentGiven = granted
    }

    // MARK: - User

    func login(externalId: String, token: String? = nil) {
        let trimmed = externalId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let trimmedToken = token?.trimmingCharacters(in: .whitespacesAndNewlines)
        service.login(externalId: trimmed, token: (trimmedToken?.isEmpty ?? true) ? nil : trimmedToken)
        externalUserId = trimmed
        clearUserData()
    }

    func updateUserJwt(externalId: String, token: String) {
        let trimmedId = externalId.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedId.isEmpty, !trimmedToken.isEmpty else { return }
        service.updateUserJwt(externalId: trimmedId, token: trimmedToken)
    }

    func logout() {
        service.logout()
        externalUserId = nil
        clearUserData()
    }

    private func clearUserData() {
        aliases.removeAll()
        emails.removeAll()
        smsNumbers.removeAll()
        tags.removeAll()
        triggers.removeAll()
    }

    // MARK: - Aliases

    func addAlias(label: String, id: String) {
        service.addAlias(label: label, id: id)
        aliases.removeAll { $0.key == label }
        aliases.append(KeyValueItem(key: label, value: id))
    }

    func addAliases(_ pairs: [(String, String)]) {
        let dict = Dictionary(pairs, uniquingKeysWith: { _, last in last })
        service.addAliases(dict)
        for (key, value) in pairs {
            aliases.removeAll { $0.key == key }
            aliases.append(KeyValueItem(key: key, value: value))
        }
    }

    func removeAlias(_ item: KeyValueItem) {
        service.removeAlias(item.key)
        aliases.removeAll { $0.id == item.id }
    }

    // MARK: - Push

    func setPushEnabled(_ enabled: Bool) {
        if enabled {
            service.optInPush()
            isPushEnabled = true
        } else {
            service.optOutPush()
            isPushEnabled = false
        }
    }

    func promptPushPermission() {
        service.requestPushPermission { [weak self] accepted in
            Task { @MainActor in
                self?.hasNotificationPermission = accepted
                self?.isPushEnabled = accepted
            }
        }
    }

    // MARK: - Email

    func addEmail(_ email: String) {
        service.addEmail(email)
        if !emails.contains(email) { emails.append(email) }
    }

    func removeEmail(_ email: String) {
        service.removeEmail(email)
        emails.removeAll { $0 == email }
    }

    // MARK: - SMS

    func addSms(_ number: String) {
        service.addSms(number)
        if !smsNumbers.contains(number) { smsNumbers.append(number) }
    }

    func removeSms(_ number: String) {
        service.removeSms(number)
        smsNumbers.removeAll { $0 == number }
    }

    // MARK: - Tags

    func addTag(key: String, value: String) {
        service.addTag(key: key, value: value)
        tags.removeAll { $0.key == key }
        tags.append(KeyValueItem(key: key, value: value))
    }

    func addTags(_ pairs: [(String, String)]) {
        let dict = Dictionary(pairs, uniquingKeysWith: { _, last in last })
        service.addTags(dict)
        for (key, value) in pairs {
            tags.removeAll { $0.key == key }
            tags.append(KeyValueItem(key: key, value: value))
        }
    }

    func removeTag(_ item: KeyValueItem) {
        service.removeTag(item.key)
        tags.removeAll { $0.id == item.id }
    }

    func removeSelectedTags(_ keys: [String]) {
        guard !keys.isEmpty else { return }
        service.removeTags(keys)
        tags.removeAll { keys.contains($0.key) }
    }

    // MARK: - Outcomes

    func sendOutcome(_ name: String) {
        service.sendOutcome(name)
        print("[OneSignal] Outcome sent: \(name)")
    }

    func sendUniqueOutcome(_ name: String) {
        service.sendUniqueOutcome(name)
        print("[OneSignal] Unique outcome sent: \(name)")
    }

    func sendOutcome(_ name: String, value: Double) {
        service.sendOutcome(name, value: NSNumber(value: value))
        print("[OneSignal] Outcome sent: \(name) = \(value)")
    }

    // MARK: - In-App

    func setIamPaused(_ paused: Bool) {
        isInAppMessagesPaused = paused
        service.isInAppMessagesPaused = paused
    }

    func sendIamTrigger(_ type: InAppMessageType) {
        service.addTrigger(key: "iam_type", value: type.triggerValue)
        triggers.removeAll { $0.key == "iam_type" }
        triggers.append(KeyValueItem(key: "iam_type", value: type.triggerValue))
    }

    // MARK: - Triggers

    func addTrigger(key: String, value: String) {
        service.addTrigger(key: key, value: value)
        triggers.removeAll { $0.key == key }
        triggers.append(KeyValueItem(key: key, value: value))
    }

    func addTriggers(_ pairs: [(String, String)]) {
        let dict = Dictionary(pairs, uniquingKeysWith: { _, last in last })
        service.addTriggers(dict)
        for (key, value) in pairs {
            triggers.removeAll { $0.key == key }
            triggers.append(KeyValueItem(key: key, value: value))
        }
    }

    func removeTrigger(_ item: KeyValueItem) {
        service.removeTrigger(item.key)
        triggers.removeAll { $0.id == item.id }
    }

    func removeSelectedTriggers(_ keys: [String]) {
        guard !keys.isEmpty else { return }
        service.removeTriggers(keys)
        triggers.removeAll { keys.contains($0.key) }
    }

    func clearTriggers() {
        service.clearTriggers()
        triggers.removeAll()
    }

    // MARK: - Custom Events

    func trackEvent(name: String, properties: [String: Any]?) {
        service.trackEvent(name: name, properties: properties)
        print("[OneSignal] Event tracked: \(name)")
    }

    // MARK: - Location

    func setLocationShared(_ shared: Bool) {
        isLocationShared = shared
        service.isLocationShared = shared
    }

    func promptLocation() {
        service.requestLocationPermission()
    }

    func checkLocationShared() -> Bool {
        let shared = service.isLocationShared
        print("[OneSignal] Location shared: \(shared)")
        return shared
    }

    // MARK: - Notifications

    func clearAllNotifications() {
        service.clearAllNotifications()
    }

    func sendNotification(_ type: NotificationType) {
        guard let subscriptionId = service.pushSubscriptionId, !subscriptionId.isEmpty else { return }
        NotificationSender.shared.sendNotification(type, appId: appId, subscriptionId: subscriptionId) { _ in }
    }

    func sendCustomNotification(title: String, body: String) {
        guard let subscriptionId = service.pushSubscriptionId, !subscriptionId.isEmpty else { return }
        NotificationSender.shared.sendCustomNotification(title: title, body: body, appId: appId, subscriptionId: subscriptionId) { _ in }
    }

    // MARK: - Live Activities

    func startLiveActivity(activityId: String, orderNumber: String, status: LiveActivityStatus) {
        let trimmedId = activityId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedId.isEmpty else { return }
        if #available(iOS 16.1, *) {
            LiveActivityController.start(
                activityId: trimmedId,
                orderNumber: orderNumber,
                status: status
            )
        }
    }

    func updateLiveActivity(activityId: String, status: LiveActivityStatus) {
        let trimmedId = activityId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedId.isEmpty else { return }
        Task {
            _ = await LiveActivityController.update(
                appId: appId,
                activityId: trimmedId,
                status: status
            )
        }
    }

    func endLiveActivity(activityId: String) {
        let trimmedId = activityId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedId.isEmpty else { return }
        Task {
            _ = await LiveActivityController.end(
                appId: appId,
                activityId: trimmedId
            )
        }
    }

    // MARK: - Tooltips

    func showTooltip(for key: String) {
        if let tooltip = TooltipService.shared.tooltip(for: key) {
            activeTooltip = tooltip
        }
    }

    func dismissTooltip() {
        activeTooltip = nil
    }

    // MARK: - Observers

    private func setupObservers() {
        observers.viewModel = self
        service.addPushSubscriptionObserver(observers)
        service.addUserObserver(observers)
        service.addPermissionObserver(observers)
    }
}

// MARK: - Observer Bridge

private final class Observers: NSObject, OSPushSubscriptionObserver, OSUserStateObserver, OSNotificationPermissionObserver {
    weak var viewModel: OneSignalViewModel?

    func onPushSubscriptionDidChange(state: OSPushSubscriptionChangedState) {
        Task { @MainActor in
            viewModel?.pushSubscriptionId = state.current.id
            viewModel?.isPushEnabled = state.current.optedIn
        }
    }

    func onUserStateDidChange(state: OSUserChangedState) {
        Task { @MainActor in
            await viewModel?.fetchUserDataFromApi()
        }
    }

    func onNotificationPermissionDidChange(_ permission: Bool) {
        Task { @MainActor in
            viewModel?.hasNotificationPermission = permission
            viewModel?.isPushEnabled = OneSignal.User.pushSubscription.optedIn
        }
    }
}
