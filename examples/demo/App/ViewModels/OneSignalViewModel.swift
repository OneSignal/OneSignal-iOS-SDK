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
    @Published var consentRequired: Bool = UserDefaults.standard.bool(forKey: "CachedConsentRequired")
    @Published var consentGiven: Bool = UserDefaults.standard.bool(forKey: "CachedPrivacyConsent")

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

    @Published var isLoading: Bool = false
    @Published var toastMessage: String?

    @Published var showingAddDialog: Bool = false
    @Published var addItemType: AddItemType = .email

    @Published var showingMultiAddDialog: Bool = false
    @Published var multiAddType: MultiAddItemType = .tags

    @Published var showingRemoveMultiDialog: Bool = false
    @Published var removeMultiType: RemoveMultiItemType = .tags

    @Published var showingOutcomeDialog: Bool = false
    @Published var showingCustomNotificationDialog: Bool = false
    @Published var showingTrackEventDialog: Bool = false

    @Published var activeTooltip: TooltipData?

    // MARK: - Computed

    var isLoggedIn: Bool {
        guard let id = externalUserId else { return false }
        return !id.isEmpty
    }

    var loginButtonTitle: String { isLoggedIn ? "SWITCH USER" : "LOGIN USER" }

    var removeMultiItems: [KeyValueItem] {
        switch removeMultiType {
        case .tags: return tags
        case .triggers: return triggers
        }
    }

    // MARK: - Private

    private let service: OneSignalService
    private var observers = Observers()

    // MARK: - Init

    init(service: OneSignalService = .shared) {
        self.service = service
        self.appId = service.appId
        self.consentRequired = service.consentRequired
        self.consentGiven = service.consentGiven
        self.externalUserId = service.externalId
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
        isLoading = true
        defer { isLoading = false }

        if let userData = await UserFetchService.shared.fetchUser(appId: appId, onesignalId: onesignalId) {
            aliases = userData.aliases.map { KeyValueItem(key: $0.key, value: $0.value) }
            tags = userData.tags.map { KeyValueItem(key: $0.key, value: $0.value) }
            emails = userData.emails
            smsNumbers = userData.smsNumbers
            if let extId = userData.externalId, !extId.isEmpty {
                externalUserId = extId
            }
        }
        try? await Task.sleep(nanoseconds: 100_000_000)
    }

    // MARK: - Consent

    func setConsentRequired(_ required: Bool) {
        consentRequired = required
        service.consentRequired = required
        UserDefaults.standard.set(required, forKey: "CachedConsentRequired")
        if !required {
            consentGiven = true
            service.consentGiven = true
            UserDefaults.standard.set(true, forKey: "CachedPrivacyConsent")
        }
        showToast(required ? "Consent required enabled" : "Consent required disabled")
    }

    func setConsentGiven(_ granted: Bool) {
        consentGiven = granted
        service.consentGiven = granted
        UserDefaults.standard.set(granted, forKey: "CachedPrivacyConsent")
        showToast(granted ? "Consent given" : "Consent revoked")
    }

    // MARK: - User

    func login(externalId: String) {
        let trimmed = externalId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isLoading = true
        service.login(externalId: trimmed)
        externalUserId = trimmed
        clearUserData()
        showToast("Logged in as \(trimmed)")
    }

    func logout() {
        service.logout()
        externalUserId = nil
        clearUserData()
        showToast("Logged out")
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
        showToast("Alias added")
    }

    func addAliases(_ pairs: [(String, String)]) {
        let dict = Dictionary(pairs, uniquingKeysWith: { _, last in last })
        service.addAliases(dict)
        for (key, value) in pairs {
            aliases.removeAll { $0.key == key }
            aliases.append(KeyValueItem(key: key, value: value))
        }
        showToast("\(pairs.count) alias(es) added")
    }

    func removeAlias(_ item: KeyValueItem) {
        service.removeAlias(item.key)
        aliases.removeAll { $0.id == item.id }
        showToast("Alias removed")
    }

    // MARK: - Push

    func setPushEnabled(_ enabled: Bool) {
        if enabled {
            service.optInPush()
            isPushEnabled = true
            showToast("Push enabled")
        } else {
            service.optOutPush()
            isPushEnabled = false
            showToast("Push disabled")
        }
    }

    func promptPushPermission() {
        service.requestPushPermission { [weak self] accepted in
            Task { @MainActor in
                self?.hasNotificationPermission = accepted
                self?.isPushEnabled = accepted
                self?.showToast(accepted ? "Push permission granted" : "Push permission denied")
            }
        }
    }

    // MARK: - Email

    func addEmail(_ email: String) {
        service.addEmail(email)
        if !emails.contains(email) { emails.append(email) }
        showToast("Email added")
    }

    func removeEmail(_ email: String) {
        service.removeEmail(email)
        emails.removeAll { $0 == email }
        showToast("Email removed")
    }

    // MARK: - SMS

    func addSms(_ number: String) {
        service.addSms(number)
        if !smsNumbers.contains(number) { smsNumbers.append(number) }
        showToast("SMS added")
    }

    func removeSms(_ number: String) {
        service.removeSms(number)
        smsNumbers.removeAll { $0 == number }
        showToast("SMS removed")
    }

    // MARK: - Tags

    func addTag(key: String, value: String) {
        service.addTag(key: key, value: value)
        tags.removeAll { $0.key == key }
        tags.append(KeyValueItem(key: key, value: value))
        showToast("Tag added")
    }

    func addTags(_ pairs: [(String, String)]) {
        let dict = Dictionary(pairs, uniquingKeysWith: { _, last in last })
        service.addTags(dict)
        for (key, value) in pairs {
            tags.removeAll { $0.key == key }
            tags.append(KeyValueItem(key: key, value: value))
        }
        showToast("\(pairs.count) tag(s) added")
    }

    func removeTag(_ item: KeyValueItem) {
        service.removeTag(item.key)
        tags.removeAll { $0.id == item.id }
        showToast("Tag removed")
    }

    func removeSelectedTags(_ keys: [String]) {
        guard !keys.isEmpty else { return }
        service.removeTags(keys)
        tags.removeAll { keys.contains($0.key) }
        showToast("\(keys.count) tag(s) removed")
    }

    // MARK: - Outcomes

    func sendOutcome(_ name: String) {
        service.sendOutcome(name)
        showToast("Outcome sent: \(name)")
    }

    func sendUniqueOutcome(_ name: String) {
        service.sendUniqueOutcome(name)
        showToast("Unique outcome sent: \(name)")
    }

    func sendOutcome(_ name: String, value: Double) {
        service.sendOutcome(name, value: NSNumber(value: value))
        showToast("Outcome sent: \(name) = \(value)")
    }

    // MARK: - In-App

    func setIamPaused(_ paused: Bool) {
        isInAppMessagesPaused = paused
        service.isInAppMessagesPaused = paused
        showToast(paused ? "In-app messages paused" : "In-app messages resumed")
    }

    func sendIamTrigger(_ type: InAppMessageType) {
        service.addTrigger(key: "iam_type", value: type.triggerValue)
        triggers.removeAll { $0.key == "iam_type" }
        triggers.append(KeyValueItem(key: "iam_type", value: type.triggerValue))
        showToast("Sent IAM trigger: \(type.rawValue)")
    }

    // MARK: - Triggers

    func addTrigger(key: String, value: String) {
        service.addTrigger(key: key, value: value)
        triggers.removeAll { $0.key == key }
        triggers.append(KeyValueItem(key: key, value: value))
        showToast("Trigger added")
    }

    func addTriggers(_ pairs: [(String, String)]) {
        let dict = Dictionary(pairs, uniquingKeysWith: { _, last in last })
        service.addTriggers(dict)
        for (key, value) in pairs {
            triggers.removeAll { $0.key == key }
            triggers.append(KeyValueItem(key: key, value: value))
        }
        showToast("\(pairs.count) trigger(s) added")
    }

    func removeTrigger(_ item: KeyValueItem) {
        service.removeTrigger(item.key)
        triggers.removeAll { $0.id == item.id }
        showToast("Trigger removed")
    }

    func removeSelectedTriggers(_ keys: [String]) {
        guard !keys.isEmpty else { return }
        service.removeTriggers(keys)
        triggers.removeAll { keys.contains($0.key) }
        showToast("\(keys.count) trigger(s) removed")
    }

    func clearTriggers() {
        service.clearTriggers()
        triggers.removeAll()
        showToast("All triggers cleared")
    }

    // MARK: - Custom Events

    func trackEvent(name: String, properties: [String: Any]?) {
        service.trackEvent(name: name, properties: properties)
        showToast("Event tracked: \(name)")
    }

    // MARK: - Location

    func setLocationShared(_ shared: Bool) {
        isLocationShared = shared
        service.isLocationShared = shared
        showToast(shared ? "Location sharing enabled" : "Location sharing disabled")
    }

    func promptLocation() {
        service.requestLocationPermission()
        showToast("Location permission requested")
    }

    func checkLocationShared() {
        let shared = service.isLocationShared
        showToast("Location shared: \(shared)")
    }

    // MARK: - Notifications

    func clearAllNotifications() {
        service.clearAllNotifications()
        showToast("All notifications cleared")
    }

    func sendNotification(_ type: NotificationType) {
        guard let subscriptionId = service.pushSubscriptionId, !subscriptionId.isEmpty else {
            showToast("No push subscription")
            return
        }
        showToast("Sending \(type.rawValue) notification...")
        NotificationSender.shared.sendNotification(type, appId: appId, subscriptionId: subscriptionId) { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success:
                    self?.showToast("\(type.rawValue) sent!")
                case .failure(let error):
                    self?.showToast("Send failed: \(error.localizedDescription)")
                }
            }
        }
    }

    func sendCustomNotification(title: String, body: String) {
        guard let subscriptionId = service.pushSubscriptionId, !subscriptionId.isEmpty else {
            showToast("No push subscription")
            return
        }
        NotificationSender.shared.sendCustomNotification(title: title, body: body, appId: appId, subscriptionId: subscriptionId) { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success:
                    self?.showToast("Custom notification sent")
                case .failure(let error):
                    self?.showToast("Send failed: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Live Activities

    func startLiveActivity(activityId: String, orderNumber: String, status: LiveActivityStatus) {
        let trimmedId = activityId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedId.isEmpty else {
            showToast("Activity ID required")
            return
        }
        if #available(iOS 16.1, *) {
            LiveActivityController.start(
                activityId: trimmedId,
                orderNumber: orderNumber,
                status: status
            )
            showToast("Live Activity '\(trimmedId)' started")
        } else {
            showToast("Live Activities require iOS 16.1+")
        }
    }

    func updateLiveActivity(activityId: String, status: LiveActivityStatus) {
        let trimmedId = activityId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedId.isEmpty else { return }
        showToast("Updating Live Activity...")
        Task {
            let success = await LiveActivityController.update(
                appId: appId,
                activityId: trimmedId,
                status: status
            )
            await MainActor.run {
                showToast(success ? "Live Activity updated" : "Update failed")
            }
        }
    }

    func endLiveActivity(activityId: String) {
        let trimmedId = activityId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedId.isEmpty else { return }
        showToast("Ending Live Activity...")
        Task {
            let success = await LiveActivityController.end(
                appId: appId,
                activityId: trimmedId
            )
            await MainActor.run {
                showToast(success ? "Live Activity ended" : "End failed")
            }
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

    // MARK: - Dialog handling

    func showAddDialog(for type: AddItemType) {
        addItemType = type
        showingAddDialog = true
    }

    func showMultiAddDialog(for type: MultiAddItemType) {
        multiAddType = type
        showingMultiAddDialog = true
    }

    func showRemoveMultiDialog(for type: RemoveMultiItemType) {
        removeMultiType = type
        showingRemoveMultiDialog = true
    }

    func handleAddItem(key: String, value: String) {
        switch addItemType {
        case .alias:
            addAlias(label: key, id: value)
        case .email:
            addEmail(value)
        case .sms:
            addSms(value)
        case .tag:
            addTag(key: key, value: value)
        case .trigger:
            addTrigger(key: key, value: value)
        case .externalUserId:
            login(externalId: value)
        }
        showingAddDialog = false
    }

    func handleMultiAdd(_ pairs: [(String, String)]) {
        switch multiAddType {
        case .aliases: addAliases(pairs)
        case .tags: addTags(pairs)
        case .triggers: addTriggers(pairs)
        }
        showingMultiAddDialog = false
    }

    func handleRemoveMulti(_ keys: [String]) {
        switch removeMultiType {
        case .tags: removeSelectedTags(keys)
        case .triggers: removeSelectedTriggers(keys)
        }
        showingRemoveMultiDialog = false
    }

    // MARK: - Toast

    func showToast(_ message: String) {
        toastMessage = message
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if toastMessage == message { toastMessage = nil }
        }
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
