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
import OneSignalFramework
import OneSignalInAppMessages
import OneSignalLocation

/// Thin wrapper that funnels demo calls through a single OneSignal entry point
final class OneSignalService {

    static let shared = OneSignalService()

    private init() {}

    // MARK: - App ID

    private let appIdKey = "OneSignalAppId"
    private let defaultAppId = "77e32082-ea27-42e3-a898-c72e141824ef"

    var appId: String {
        get { UserDefaults.standard.string(forKey: appIdKey) ?? defaultAppId }
        set { UserDefaults.standard.set(newValue, forKey: appIdKey) }
    }

    // MARK: - Initialization

    func initialize(launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        OneSignal.Debug.setLogLevel(.LL_VERBOSE)
        OneSignal.initialize(appId, withLaunchOptions: launchOptions)
    }

    // MARK: - Identity

    var onesignalId: String? { OneSignal.User.onesignalId }
    var externalId: String? { OneSignal.User.externalId }

    // MARK: - Consent

    var consentRequired: Bool {
        get { OneSignal.privacyConsentRequired }
        set { OneSignal.setConsentRequired(newValue) }
    }

    var consentGiven: Bool {
        get { OneSignal.privacyConsentGiven }
        set { OneSignal.setConsentGiven(newValue) }
    }

    // MARK: - User

    func login(externalId: String) { OneSignal.login(externalId) }
    func logout() { OneSignal.logout() }

    // MARK: - Aliases

    func addAlias(label: String, id: String) { OneSignal.User.addAlias(label: label, id: id) }
    func addAliases(_ aliases: [String: String]) { OneSignal.User.addAliases(aliases) }
    func removeAlias(_ label: String) { OneSignal.User.removeAlias(label) }
    func removeAliases(_ labels: [String]) { OneSignal.User.removeAliases(labels) }

    // MARK: - Push Subscription

    var pushSubscriptionId: String? { OneSignal.User.pushSubscription.id }
    var isPushEnabled: Bool { OneSignal.User.pushSubscription.optedIn }
    var hasNotificationPermission: Bool { OneSignal.Notifications.permission }

    func optInPush() { OneSignal.User.pushSubscription.optIn() }
    func optOutPush() { OneSignal.User.pushSubscription.optOut() }

    func requestPushPermission(completion: @escaping (Bool) -> Void) {
        OneSignal.Notifications.requestPermission({ accepted in
            completion(accepted)
        }, fallbackToSettings: true)
    }

    // MARK: - Email

    func addEmail(_ email: String) { OneSignal.User.addEmail(email) }
    func removeEmail(_ email: String) { OneSignal.User.removeEmail(email) }

    // MARK: - SMS

    func addSms(_ number: String) { OneSignal.User.addSms(number) }
    func removeSms(_ number: String) { OneSignal.User.removeSms(number) }

    // MARK: - Tags

    func addTag(key: String, value: String) { OneSignal.User.addTag(key: key, value: value) }
    func addTags(_ tags: [String: String]) { OneSignal.User.addTags(tags) }
    func removeTag(_ key: String) { OneSignal.User.removeTag(key) }
    func removeTags(_ keys: [String]) { OneSignal.User.removeTags(keys) }
    func getTags() -> [String: String] { OneSignal.User.getTags() }

    // MARK: - Outcomes

    func sendOutcome(_ name: String) { OneSignal.Session.addOutcome(name) }
    func sendOutcome(_ name: String, value: NSNumber) { OneSignal.Session.addOutcome(name, value: value) }
    func sendUniqueOutcome(_ name: String) { OneSignal.Session.addUniqueOutcome(name) }

    // MARK: - In-App Messages

    var isInAppMessagesPaused: Bool {
        get { OneSignal.InAppMessages.paused }
        set { OneSignal.InAppMessages.paused = newValue }
    }

    func addTrigger(key: String, value: String) {
        OneSignal.InAppMessages.addTrigger(key, withValue: value)
    }

    func addTriggers(_ triggers: [String: String]) {
        OneSignal.InAppMessages.addTriggers(triggers)
    }

    func removeTrigger(_ key: String) {
        OneSignal.InAppMessages.removeTrigger(key)
    }

    func removeTriggers(_ keys: [String]) {
        OneSignal.InAppMessages.removeTriggers(keys)
    }

    func clearTriggers() {
        OneSignal.InAppMessages.clearTriggers()
    }

    // MARK: - Location

    var isLocationShared: Bool {
        get { OneSignal.Location.isShared }
        set { OneSignal.Location.isShared = newValue }
    }

    func requestLocationPermission() {
        OneSignal.Location.requestPermission()
    }

    // MARK: - Notifications

    func clearAllNotifications() {
        OneSignal.Notifications.clearAll()
    }

    // MARK: - Custom Events

    func trackEvent(name: String, properties: [String: Any]?) {
        OneSignal.User.trackEvent(name: name, properties: properties)
    }

    // MARK: - Observers

    func addPushSubscriptionObserver(_ observer: OSPushSubscriptionObserver) {
        OneSignal.User.pushSubscription.addObserver(observer)
    }

    func addUserObserver(_ observer: OSUserStateObserver) {
        OneSignal.User.addObserver(observer)
    }

    func addPermissionObserver(_ observer: OSNotificationPermissionObserver) {
        OneSignal.Notifications.addPermissionObserver(observer)
    }

    func addNotificationClickListener(_ listener: OSNotificationClickListener) {
        OneSignal.Notifications.addClickListener(listener)
    }

    func addNotificationLifecycleListener(_ listener: OSNotificationLifecycleListener) {
        OneSignal.Notifications.addForegroundLifecycleListener(listener)
    }

    func addInAppMessageClickListener(_ listener: OSInAppMessageClickListener) {
        OneSignal.InAppMessages.addClickListener(listener)
    }

    func addInAppMessageLifecycleListener(_ listener: OSInAppMessageLifecycleListener) {
        OneSignal.InAppMessages.addLifecycleListener(listener)
    }
}
