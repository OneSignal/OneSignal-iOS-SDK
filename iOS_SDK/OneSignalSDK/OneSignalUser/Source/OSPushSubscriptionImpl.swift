/*
 Modified MIT License

 Copyright 2023 OneSignal

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 1. The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.

 2. All copies of substantial portions of the Software may only be used in connection
 with services provided by OneSignal.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
 */

import OneSignalCore
import OneSignalOSCore
import OneSignalNotifications

/**
 Implements the push subscription namespace. Lives on `OneSignalUserManagerImpl` so User and Push
 Subscription can both expose `addObserver` without colliding on one type.
 */
@objc
public class OSPushSubscriptionImpl: NSObject, OSPushSubscription {

    let pushSubscriptionModelStore: OSModelStore<OSSubscriptionModel>

    private var _pushSubscriptionStateChangesObserver: OSObservable<OSPushSubscriptionObserver, OSPushSubscriptionChangedState>?
    var pushSubscriptionStateChangesObserver: OSObservable<OSPushSubscriptionObserver, OSPushSubscriptionChangedState> {
        if let observer = _pushSubscriptionStateChangesObserver {
            return observer
        }
        let pushSubscriptionStateChangesObserver = OSObservable<OSPushSubscriptionObserver, OSPushSubscriptionChangedState>(change: #selector(OSPushSubscriptionObserver.onPushSubscriptionDidChange(state:)))
        _pushSubscriptionStateChangesObserver = pushSubscriptionStateChangesObserver

        return pushSubscriptionStateChangesObserver
    }

    init(pushSubscriptionModelStore: OSModelStore<OSSubscriptionModel>) {
        self.pushSubscriptionModelStore = pushSubscriptionModelStore
    }

    public func addObserver(_ observer: OSPushSubscriptionObserver) {
        // Push Subscription namespace; does not require privacy consent first.
        self.pushSubscriptionStateChangesObserver.addObserver(observer)
    }

    public func removeObserver(_ observer: OSPushSubscriptionObserver) {
        self.pushSubscriptionStateChangesObserver.removeObserver(observer)
    }

    public var id: String? {
        guard !OneSignalConfig.shouldAwaitAppIdAndLogMissingPrivacyConsent(forMethod: "pushSubscription.id") else {
            return nil
        }
        return pushSubscriptionModelStore.getModel(key: OS_PUSH_SUBSCRIPTION_MODEL_KEY)?.subscriptionId
    }

    public var token: String? {
        guard !OneSignalConfig.shouldAwaitAppIdAndLogMissingPrivacyConsent(forMethod: "pushSubscription.token") else {
            return nil
        }
        return pushSubscriptionModelStore.getModel(key: OS_PUSH_SUBSCRIPTION_MODEL_KEY)?.address
    }

    public var optedIn: Bool {
        guard !OneSignalConfig.shouldAwaitAppIdAndLogMissingPrivacyConsent(forMethod: "pushSubscription.optedIn") else {
            return false
        }
        return pushSubscriptionModelStore.getModel(key: OS_PUSH_SUBSCRIPTION_MODEL_KEY)?.optedIn ?? false
    }

    /**
     Enable the push subscription, and prompts if needed. `optedIn` can still be `false` after `optIn()` is called if permission is not granted.
     */
    public func optIn() {
        guard !OneSignalConfig.shouldAwaitAppIdAndLogMissingPrivacyConsent(forMethod: "pushSubscription.optIn") else {
            return
        }
        pushSubscriptionModelStore.getModel(key: OS_PUSH_SUBSCRIPTION_MODEL_KEY)?._isDisabled = false
        OSNotificationsManager.requestPermission(nil, fallbackToSettings: true)
    }

    public func optOut() {
        guard !OneSignalConfig.shouldAwaitAppIdAndLogMissingPrivacyConsent(forMethod: "pushSubscription.optOut") else {
            return
        }
        pushSubscriptionModelStore.getModel(key: OS_PUSH_SUBSCRIPTION_MODEL_KEY)?._isDisabled = true
    }
}
