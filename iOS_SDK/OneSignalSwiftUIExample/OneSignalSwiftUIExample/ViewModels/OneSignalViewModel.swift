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

/// Main ViewModel managing all OneSignal SDK state and interactions
@MainActor
final class OneSignalViewModel: ObservableObject {

    // MARK: - Published Properties

    // App Info
    @Published var appId: String

    // User
    @Published var externalUserId: String?
    @Published var aliases: [KeyValueItem] = []

    // Push Subscription
    @Published var pushSubscriptionId: String?
    @Published var isPushEnabled: Bool = false
    @Published var notificationPermissionGranted: Bool = false

    // Email & SMS
    @Published var emails: [String] = []
    @Published var smsNumbers: [String] = []

    // Tags
    @Published var tags: [KeyValueItem] = []

    // In-App Messaging
    @Published var isInAppMessagesPaused: Bool = true
    @Published var triggers: [KeyValueItem] = []

    // Location
    @Published var isLocationShared: Bool = false

    // Consent
    @Published var consentRequired: Bool = UserDefaults.standard.bool(forKey: "CachedConsentRequired")
    @Published var consentGiven: Bool = UserDefaults.standard.bool(forKey: "CachedPrivacyConsent")

    // Loading
    @Published var isLoading: Bool = false

    // UI State
    @Published var showingAddSheet: Bool = false
    @Published var addItemType: AddItemType = .email
    @Published var showingMultiAddSheet: Bool = false
    @Published var multiAddType: MultiAddItemType = .tags
    @Published var showingRemoveMultiSheet: Bool = false
    @Published var removeMultiType: RemoveMultiItemType = .tags
    @Published var showingCustomNotificationSheet: Bool = false
    @Published var showingTrackEventSheet: Bool = false
    @Published var toastMessage: String?

    // MARK: - Computed Properties

    var isLoggedIn: Bool {
        externalUserId != nil && !(externalUserId?.isEmpty ?? true)
    }

    var loginButtonTitle: String {
        isLoggedIn ? "Switch User" : "Login User"
    }

    /// Items for remove-multi dialog based on current type
    var removeMultiItems: [KeyValueItem] {
        switch removeMultiType {
        case .aliases: return aliases
        case .tags: return tags
        case .triggers: return triggers
        }
    }

    // MARK: - Private Properties

    private let service: OneSignalService
    private var observers = Observers()

    // MARK: - Initialization

    init(service: OneSignalService = .shared) {
        self.service = service
        self.appId = service.appId
        self.notificationPermissionGranted = service.hasNotificationPermission

        // Load external user ID from SDK
        self.externalUserId = service.externalId

        // Initial state sync
        refreshState()

        // Set up observers
        setupObservers()

        // Fetch user data if we have a onesignalId
        if service.onesignalId != nil {
            Task {
                await fetchUserDataFromApi()
            }
        }
    }

    // MARK: - State Management

    func refreshState() {
        pushSubscriptionId = service.pushSubscriptionId
        isPushEnabled = service.isPushEnabled
        isInAppMessagesPaused = service.isInAppMessagesPaused
        isLocationShared = service.isLocationShared
        notificationPermissionGranted = service.hasNotificationPermission
        externalUserId = service.externalId

        // Sync tags from SDK
        let sdkTags = service.getTags()
        tags = sdkTags.map { KeyValueItem(key: $0.key, value: $0.value) }
    }

    // MARK: - User Data Fetching

    func fetchUserDataFromApi() async {
        guard let onesignalId = service.onesignalId else { return }

        isLoading = true

        if let userData = await UserFetchService.shared.fetchUser(appId: appId, onesignalId: onesignalId) {
            aliases = userData.aliases.map { KeyValueItem(key: $0.key, value: $0.value) }
            tags = userData.tags.map { KeyValueItem(key: $0.key, value: $0.value) }
            emails = userData.emails
            smsNumbers = userData.smsNumbers
            if let extId = userData.externalId, !extId.isEmpty {
                externalUserId = extId
            }
        }

        // Small delay to ensure UI populates before dismissing loading
        try? await Task.sleep(nanoseconds: 100_000_000)
        isLoading = false
    }

    // MARK: - Consent

    func toggleConsentRequired() {
        consentRequired.toggle()
        service.setConsentRequired(consentRequired)
        UserDefaults.standard.set(consentRequired, forKey: "CachedConsentRequired")
        if !consentRequired {
            // When turning off consent required, also grant consent
            consentGiven = true
            service.setConsentGiven(true)
            UserDefaults.standard.set(true, forKey: "CachedPrivacyConsent")
        }
        showToast(consentRequired ? "Consent required enabled" : "Consent required disabled")
    }

    func toggleConsent() {
        consentGiven.toggle()
        service.setConsentGiven(consentGiven)
        UserDefaults.standard.set(consentGiven, forKey: "CachedPrivacyConsent")
        showToast(consentGiven ? "Consent given" : "Consent revoked")
    }

    // MARK: - User Management

    func login(externalId: String) {
        isLoading = true
        service.login(externalId: externalId)
        externalUserId = externalId

        // Clear old data; will be repopulated by fetchUserDataFromApi when user state changes
        aliases.removeAll()
        emails.removeAll()
        smsNumbers.removeAll()
        tags.removeAll()

        showToast("Logged in as \(externalId)")
    }

    func logout() {
        isLoading = true
        service.logout()
        externalUserId = nil
        aliases.removeAll()
        emails.removeAll()
        smsNumbers.removeAll()
        tags.removeAll()
        triggers.removeAll()
        isLoading = false
        showToast("Logged out")
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

    func removeSelectedAliases(_ keys: [String]) {
        guard !keys.isEmpty else { return }
        service.removeAliases(keys)
        aliases.removeAll { keys.contains($0.key) }
        showToast("\(keys.count) alias(es) removed")
    }

    // MARK: - Push Subscription

    func togglePushEnabled() {
        if isPushEnabled {
            service.optOutPush()
            isPushEnabled = false
            showToast("Push disabled")
        } else {
            service.optInPush()
            isPushEnabled = true
            showToast("Push enabled")
        }
    }

    func requestPushPermission() {
        service.requestPushPermission { [weak self] accepted in
            Task { @MainActor in
                self?.notificationPermissionGranted = accepted
                self?.isPushEnabled = accepted
                self?.showToast(accepted ? "Push permission granted" : "Push permission denied")
            }
        }
    }

    // MARK: - Email

    func addEmail(_ email: String) {
        service.addEmail(email)
        if !emails.contains(email) {
            emails.append(email)
        }
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
        if !smsNumbers.contains(number) {
            smsNumbers.append(number)
        }
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
        showToast("Outcome '\(name)' sent")
    }

    func sendOutcome(_ name: String, value: Double) {
        service.sendOutcome(name, value: NSNumber(value: value))
        showToast("Outcome '\(name)' with value \(value) sent")
    }

    func sendUniqueOutcome(_ name: String) {
        service.sendUniqueOutcome(name)
        showToast("Unique outcome '\(name)' sent")
    }

    // MARK: - In-App Messaging

    func toggleInAppMessagesPaused() {
        isInAppMessagesPaused.toggle()
        service.isInAppMessagesPaused = isInAppMessagesPaused
        UserDefaults.standard.set(isInAppMessagesPaused, forKey: "CachedInAppMessagesPaused")
        showToast(isInAppMessagesPaused ? "In-app messages paused" : "In-app messages resumed")
    }

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

    // MARK: - Track Event

    func trackEvent(name: String, properties: [String: Any]? = nil) {
        OneSignal.User.trackEvent(name: name, properties: properties)
        showToast("Event '\(name)' tracked")
    }

    // MARK: - Location

    func toggleLocationShared() {
        isLocationShared.toggle()
        service.isLocationShared = isLocationShared
        UserDefaults.standard.set(isLocationShared, forKey: "CachedLocationShared")
        showToast(isLocationShared ? "Location sharing enabled" : "Location sharing disabled")
    }

    func promptLocation() {
        service.requestLocationPermission()
        showToast("Location permission requested")
    }

    // MARK: - Notifications

    func clearAllNotifications() {
        service.clearAllNotifications()
        showToast("All notifications cleared")
    }

    func sendSimpleNotification() {
        showToast("Sending simple notification...")
        NotificationSender.shared.sendSimpleNotification(appId: appId) { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success:
                    self?.showToast("Simple notification sent!")
                case .failure(let error):
                    self?.showToast("Failed: \(error.localizedDescription)")
                }
            }
        }
    }

    func sendNotificationWithImage() {
        showToast("Sending image notification...")
        NotificationSender.shared.sendNotificationWithImage(appId: appId) { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success:
                    self?.showToast("Image notification sent!")
                case .failure(let error):
                    self?.showToast("Failed: \(error.localizedDescription)")
                }
            }
        }
    }

    func sendCustomNotification(title: String, body: String) {
        showToast("Sending custom notification...")
        NotificationSender.shared.sendCustomNotification(title: title, body: body, appId: appId) { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success:
                    self?.showToast("Custom notification sent!")
                case .failure(let error):
                    self?.showToast("Failed: \(error.localizedDescription)")
                }
            }
        }
    }

    func sendTestInAppMessage(_ type: InAppMessageType) {
        let triggerValue: String
        switch type {
        case .topBanner: triggerValue = "top_banner"
        case .bottomBanner: triggerValue = "bottom_banner"
        case .centerModal: triggerValue = "center_modal"
        case .fullScreen: triggerValue = "full_screen"
        }
        service.addTrigger(key: "iam_type", value: triggerValue)
        showToast("Sent In-App Message: \(type.rawValue)")
    }

    // MARK: - Add Sheet

    func showAddSheet(for type: AddItemType) {
        addItemType = type
        showingAddSheet = true
    }

    func showMultiAddSheet(for type: MultiAddItemType) {
        multiAddType = type
        showingMultiAddSheet = true
    }

    func showRemoveMultiSheet(for type: RemoveMultiItemType) {
        removeMultiType = type
        showingRemoveMultiSheet = true
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
        case .customNotification:
            sendCustomNotification(title: key, body: value)
        case .trackEvent:
            trackEvent(name: value)
        }
        showingAddSheet = false
    }

    func handleMultiAdd(pairs: [(String, String)]) {
        switch multiAddType {
        case .aliases:
            addAliases(pairs)
        case .tags:
            addTags(pairs)
        case .triggers:
            addTriggers(pairs)
        }
        showingMultiAddSheet = false
    }

    func handleRemoveMulti(keys: [String]) {
        switch removeMultiType {
        case .aliases:
            removeSelectedAliases(keys)
        case .tags:
            removeSelectedTags(keys)
        case .triggers:
            removeSelectedTriggers(keys)
        }
        showingRemoveMultiSheet = false
    }

    // MARK: - Toast

    func showToast(_ message: String) {
        toastMessage = message

        // Auto-dismiss after 2 seconds
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            toastMessage = nil
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

// MARK: - Observer Classes

private class Observers: NSObject, OSPushSubscriptionObserver, OSUserStateObserver, OSNotificationPermissionObserver {
    weak var viewModel: OneSignalViewModel?

    func onPushSubscriptionDidChange(state: OSPushSubscriptionChangedState) {
        Task { @MainActor in
            viewModel?.pushSubscriptionId = state.current.id
            viewModel?.isPushEnabled = state.current.optedIn
        }
    }

    func onUserStateDidChange(state: OSUserChangedState) {
        Task { @MainActor in
            LogManager.shared.i("User", "User state changed: \(state.jsonRepresentation())")
            // Fetch fresh user data from API when user state changes
            await viewModel?.fetchUserDataFromApi()
        }
    }

    func onNotificationPermissionDidChange(_ permission: Bool) {
        Task { @MainActor in
            viewModel?.notificationPermissionGranted = permission
            viewModel?.isPushEnabled = permission && (viewModel?.isPushEnabled ?? false)
        }
    }
}
