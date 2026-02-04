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
import OneSignalInAppMessages
import OneSignalLocation

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
    
    // UI State
    @Published var showingAddSheet: Bool = false
    @Published var addItemType: AddItemType = .email
    @Published var toastMessage: String?
    
    // MARK: - Private Properties
    
    private let service: OneSignalService
    private var observers = Observers()
    
    // MARK: - Initialization
    
    init(service: OneSignalService = .shared) {
        self.service = service
        self.appId = service.appId
        
        // Initial state sync
        refreshState()
        
        // Set up observers
        setupObservers()
    }
    
    // MARK: - State Management
    
    func refreshState() {
        pushSubscriptionId = service.pushSubscriptionId
        isPushEnabled = service.isPushEnabled
        isInAppMessagesPaused = service.isInAppMessagesPaused
        isLocationShared = service.isLocationShared
        
        // Sync tags from SDK
        let sdkTags = service.getTags()
        tags = sdkTags.map { KeyValueItem(key: $0.key, value: $0.value) }
    }
    
    // MARK: - Consent
    
    func revokeConsent() {
        service.revokeConsent()
        showToast("Consent revoked")
    }
    
    // MARK: - User Management
    
    func login(externalId: String) {
        service.login(externalId: externalId)
        externalUserId = externalId
        showToast("Logged in as \(externalId)")
    }
    
    func logout() {
        service.logout()
        externalUserId = nil
        aliases.removeAll()
        emails.removeAll()
        smsNumbers.removeAll()
        tags.removeAll()
        triggers.removeAll()
        showToast("Logged out")
    }
    
    // MARK: - Aliases
    
    func addAlias(label: String, id: String) {
        service.addAlias(label: label, id: id)
        aliases.append(KeyValueItem(key: label, value: id))
        showToast("Alias added")
    }
    
    func removeAlias(_ item: KeyValueItem) {
        service.removeAlias(item.key)
        aliases.removeAll { $0.id == item.id }
        showToast("Alias removed")
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
                self?.isPushEnabled = accepted
                self?.showToast(accepted ? "Push permission granted" : "Push permission denied")
            }
        }
    }
    
    // MARK: - Email
    
    func addEmail(_ email: String) {
        service.addEmail(email)
        emails.append(email)
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
        smsNumbers.append(number)
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
        // Remove existing tag with same key if present
        tags.removeAll { $0.key == key }
        tags.append(KeyValueItem(key: key, value: value))
        showToast("Tag added")
    }
    
    func removeTag(_ item: KeyValueItem) {
        service.removeTag(item.key)
        tags.removeAll { $0.id == item.id }
        showToast("Tag removed")
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
        showToast(isInAppMessagesPaused ? "In-app messages paused" : "In-app messages resumed")
    }
    
    func addTrigger(key: String, value: String) {
        service.addTrigger(key: key, value: value)
        // Remove existing trigger with same key if present
        triggers.removeAll { $0.key == key }
        triggers.append(KeyValueItem(key: key, value: value))
        showToast("Trigger added")
    }
    
    func removeTrigger(_ item: KeyValueItem) {
        service.removeTrigger(item.key)
        triggers.removeAll { $0.id == item.id }
        showToast("Trigger removed")
    }
    
    // MARK: - Location
    
    func toggleLocationShared() {
        isLocationShared.toggle()
        service.isLocationShared = isLocationShared
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
    
    func sendTestNotification(_ type: NotificationType) {
        // In a real app, this would trigger a notification via your backend
        // For demo purposes, we just show a toast
        showToast("Test '\(type.rawValue)' notification triggered")
    }
    
    func sendTestInAppMessage(_ type: InAppMessageType) {
        // In a real app, this would trigger an IAM via your backend
        // For demo purposes, we just show a toast
        showToast("Test '\(type.rawValue)' in-app message triggered")
    }
    
    // MARK: - Add Sheet
    
    func showAddSheet(for type: AddItemType) {
        addItemType = type
        showingAddSheet = true
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
        showingAddSheet = false
    }
    
    // MARK: - Toast
    
    private func showToast(_ message: String) {
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
            // User state changed - could refresh aliases, etc.
            print("User state changed: \(state.jsonRepresentation())")
        }
    }
    
    func onNotificationPermissionDidChange(_ permission: Bool) {
        Task { @MainActor in
            viewModel?.isPushEnabled = permission && (viewModel?.isPushEnabled ?? false)
        }
    }
}
