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

/// Thin wrapper that funnels demo calls through a single OneSignal entry point.
/// Caching for state we restore across cold launches lives in `PreferencesService`.
final class OneSignalService {

    static let shared = OneSignalService()

    private let prefs: PreferencesService

    private init(prefs: PreferencesService = .shared) {
        self.prefs = prefs
    }

    // MARK: - App ID

    /// Read once at init from `Secrets.plist` (or the hard-coded fallback) so
    /// the running session uses a stable value even if the bundle changes.
    let appId: String = SecretsConfig.appId

    // MARK: - Initialization

    /// Mirrors the Capacitor demo's `useOneSignal` init order: feed cached
    /// consent into the SDK BEFORE `initialize`, then restore IAM-paused,
    /// location-shared, and a previously-logged-in external user id once the
    /// SDK is ready. Without this, toggles flip back to defaults on every
    /// cold launch.
    func initialize(launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        OneSignal.Debug.setLogLevel(.LL_VERBOSE)

        OneSignal.setConsentRequired(prefs.getConsentRequired())
        OneSignal.setConsentGiven(prefs.getConsentGiven())

        OneSignal.initialize(appId, withLaunchOptions: launchOptions)

        OneSignal.InAppMessages.paused = prefs.getIamPaused()
        OneSignal.Location.isShared = prefs.getLocationShared()

        if let storedExternalId = prefs.getExternalUserId() {
            OneSignal.login(storedExternalId)
        }
    }

    // MARK: - Identity

    var onesignalId: String? { OneSignal.User.onesignalId }
    var externalId: String? { OneSignal.User.externalId }

    // MARK: - Consent

    /// Read-through cache. `set` writes the value to `PreferencesService` and
    /// forwards to the SDK so the next cold launch can restore it.
    var consentRequired: Bool {
        get { prefs.getConsentRequired() }
        set {
            prefs.setConsentRequired(newValue)
            OneSignal.setConsentRequired(newValue)
        }
    }

    var consentGiven: Bool {
        get { prefs.getConsentGiven() }
        set {
            prefs.setConsentGiven(newValue)
            OneSignal.setConsentGiven(newValue)
        }
    }

    // MARK: - User

    func login(externalId: String, token: String? = nil) {
        prefs.setExternalUserId(externalId)
        OneSignal.login(externalId: externalId, token: token)
    }

    func updateUserJwt(externalId: String, token: String) {
        OneSignal.updateUserJwt(externalId: externalId, token: token)
    }

    func logout() {
        prefs.setExternalUserId(nil)
        OneSignal.logout()
    }

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
    func sendOutcome(_ name: String, value: NSNumber) { OneSignal.Session.addOutcome(name, value) }
    func sendUniqueOutcome(_ name: String) { OneSignal.Session.addUniqueOutcome(name) }

    // MARK: - In-App Messages

    var isInAppMessagesPaused: Bool {
        get { prefs.getIamPaused() }
        set {
            prefs.setIamPaused(newValue)
            OneSignal.InAppMessages.paused = newValue
        }
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
        get { prefs.getLocationShared() }
        set {
            prefs.setLocationShared(newValue)
            OneSignal.Location.isShared = newValue
        }
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
