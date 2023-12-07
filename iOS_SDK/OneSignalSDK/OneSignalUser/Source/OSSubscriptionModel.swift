/*
 Modified MIT License

 Copyright 2022 OneSignal

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

import Foundation
import OneSignalCore
import OneSignalOSCore
import OneSignalNotifications

// MARK: - Push Subscription Specific

@objc public protocol OSPushSubscriptionObserver { // TODO: weak reference?
    @objc func onPushSubscriptionDidChange(state: OSPushSubscriptionChangedState)
}

@objc
public class OSPushSubscriptionState: NSObject {
    @objc public let id: String?
    @objc public let token: String?
    @objc public let optedIn: Bool

    @objc public override var description: String {
        return "<OSPushSubscriptionState: id: \(id ?? "nil"), token: \(token ?? "nil"), optedIn: \(optedIn)>"
    }

    init(id: String?, token: String?, optedIn: Bool) {
        self.id = id
        self.token = token
        self.optedIn = optedIn
    }

    @objc public func jsonRepresentation() -> NSDictionary {
        let id = self.id ?? "nil"
        let token = self.token ?? "nil"
        return [
            "id": id,
            "token": token,
            "optedIn": optedIn
        ]
    }

    func equals(_ state: OSPushSubscriptionState) -> Bool {
        return self.id == state.id && self.token ==  state.token && self.optedIn == state.optedIn
    }
}

@objc
public class OSPushSubscriptionChangedState: NSObject {
    @objc public let current: OSPushSubscriptionState
    @objc public let previous: OSPushSubscriptionState

    @objc public override var description: String {
        return "<OSPushSubscriptionChangedState:\nprevious: \(self.previous),\ncurrent:   \(self.current)\n>"
    }

    init(current: OSPushSubscriptionState, previous: OSPushSubscriptionState) {
        self.current = current
        self.previous = previous
    }

    @objc public func jsonRepresentation() -> NSDictionary {
        return ["previous": previous.jsonRepresentation(), "current": current.jsonRepresentation()]
    }
}

// MARK: - Subscription Model

enum OSSubscriptionType: String {
    case push = "iOSPush"
    case email = "Email"
    case sms = "SMS"
}

/**
 Internal subscription model.
 */
class OSSubscriptionModel: OSModel {
    var type: OSSubscriptionType

    var address: String? { // This is token on push subs so must remain Optional
        didSet {
            guard address != oldValue else {
                return
            }
            self.set(property: "address", newValue: address)

            guard self.type == .push else {
                return
            }

            updateNotificationTypes()

            firePushSubscriptionChanged(.address(oldValue))
        }
    }

    // Set via server response
    var subscriptionId: String? {
        didSet {
            guard subscriptionId != oldValue else {
                return
            }
            self.set(property: "subscriptionId", newValue: subscriptionId)

            guard self.type == .push else {
                return
            }

            // Cache the subscriptionId as it persists across users on the device??
            OneSignalUserDefaults.initShared().saveString(forKey: OSUD_PUSH_SUBSCRIPTION_ID, withValue: subscriptionId)

            firePushSubscriptionChanged(.subscriptionId(oldValue))
        }
    }

    // Internal property to send to server, not meant for outside access
    var enabled: Bool { // Does not consider subscription_id in the calculation
        get {
            return calculateIsEnabled(address: address, reachable: _reachable, isDisabled: _isDisabled)
        }
    }

    var optedIn: Bool {
        // optedIn = permission + userPreference
        get {
            return calculateIsOptedIn(reachable: _reachable, isDisabled: _isDisabled)
        }
    }

    // Push Subscription Only
    // Initialize to be -1, so not to deal with unwrapping every time, and simplifies caching
    var notificationTypes = -1 {
        didSet {
            guard self.type == .push && notificationTypes != oldValue else {
                return
            }

            // If _isDisabled is set, this supersedes as the value to send to server.
            if _isDisabled && notificationTypes != -2 {
                notificationTypes = -2
                return
            }
            _reachable = notificationTypes > 0
            self.set(property: "notificationTypes", newValue: notificationTypes)
        }
    }

    // swiftlint:disable identifier_name
    /**
     This is set by the permission state changing.
     Defaults to true for email & SMS, defaults to false for push.
     Note that this property reflects the `reachable` property of a permission state. As provisional permission is considered to be `optedIn` and `enabled`.
     */
    var _reachable: Bool {
        didSet {
            guard self.type == .push && _reachable != oldValue else {
                return
            }
            firePushSubscriptionChanged(.reachable(oldValue))
        }
    }

    // Set by the app developer when they call User.pushSubscription.optOut()
    var _isDisabled: Bool { // Default to false for all subscriptions
        didSet {
            guard self.type == .push && _isDisabled != oldValue else {
                return
            }
            firePushSubscriptionChanged(.isDisabled(oldValue))
            notificationTypes = -2
        }
    }

    // Properties for push subscription
    var testType: Int? {
        didSet {
            guard testType != oldValue else {
                return
            }
            self.set(property: "testType", newValue: testType)
        }
    }

    var deviceOs = UIDevice.current.systemVersion {
        didSet {
            guard deviceOs != oldValue else {
                return
            }
            self.set(property: "deviceOs", newValue: deviceOs)
        }
    }

    var sdk = ONESIGNAL_VERSION {
        didSet {
            guard sdk != oldValue else {
                return
            }
            self.set(property: "sdk", newValue: sdk)
        }
    }

    var deviceModel: String? = OSDeviceUtils.getDeviceVariant() {
        didSet {
            guard deviceModel != oldValue else {
                return
            }
            self.set(property: "deviceModel", newValue: deviceModel)
        }
    }

    var appVersion: String? = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
        didSet {
            guard appVersion != oldValue else {
                return
            }
            self.set(property: "appVersion", newValue: appVersion)
        }
    }

    var netType: Int? = OSNetworkingUtils.getNetType() as? Int {
        didSet {
            guard netType != oldValue else {
                return
            }
            self.set(property: "netType", newValue: netType)
        }
    }

    // When a Subscription is initialized, it may not have a subscriptionId until a request to the backend is made.
    init(type: OSSubscriptionType,
         address: String?,
         subscriptionId: String?,
         reachable: Bool,
         isDisabled: Bool,
         changeNotifier: OSEventProducer<OSModelChangedHandler>) {
        self.type = type
        self.address = address
        self.subscriptionId = subscriptionId
        _reachable = reachable
        _isDisabled = isDisabled

        // Set test_type if subscription model is PUSH, and update notificationTypes
        if type == .push {
            let releaseMode: OSUIApplicationReleaseMode = OneSignalMobileProvision.releaseMode()
            #if targetEnvironment(simulator)
            if releaseMode == OSUIApplicationReleaseMode.UIApplicationReleaseUnknown {
                self.testType = OSUIApplicationReleaseMode.UIApplicationReleaseDev.rawValue
            }
            #endif
            // Workaround to unsure how to extract the Int value in 1 step...
            if releaseMode == .UIApplicationReleaseDev {
                self.testType = OSUIApplicationReleaseMode.UIApplicationReleaseDev.rawValue
            }
            if releaseMode == .UIApplicationReleaseAdHoc {
                self.testType = OSUIApplicationReleaseMode.UIApplicationReleaseAdHoc.rawValue
            }
            if releaseMode == .UIApplicationReleaseWildcard {
                self.testType = OSUIApplicationReleaseMode.UIApplicationReleaseWildcard.rawValue
            }
            notificationTypes = Int(OSNotificationsManager.getNotificationTypes(_isDisabled))
        }

        super.init(changeNotifier: changeNotifier)
    }

    override func encode(with coder: NSCoder) {
        super.encode(with: coder)
        coder.encode(type.rawValue, forKey: "type") // Encodes as String
        coder.encode(address, forKey: "address")
        coder.encode(subscriptionId, forKey: "subscriptionId")
        coder.encode(_reachable, forKey: "_reachable")
        coder.encode(_isDisabled, forKey: "_isDisabled")
        coder.encode(notificationTypes, forKey: "notificationTypes")
        coder.encode(testType, forKey: "testType")
        coder.encode(deviceOs, forKey: "deviceOs")
        coder.encode(sdk, forKey: "sdk")
        coder.encode(deviceModel, forKey: "deviceModel")
        coder.encode(appVersion, forKey: "appVersion")
        coder.encode(netType, forKey: "netType")
    }

    required init?(coder: NSCoder) {
        guard
            let rawType = coder.decodeObject(forKey: "type") as? String,
            let type = OSSubscriptionType(rawValue: rawType)
        else {
            // Log error
            return nil
        }
        self.type = type
        self.address = coder.decodeObject(forKey: "address") as? String
        self.subscriptionId = coder.decodeObject(forKey: "subscriptionId") as? String
        self._reachable = coder.decodeBool(forKey: "_reachable")
        self._isDisabled = coder.decodeBool(forKey: "_isDisabled")
        self.notificationTypes = coder.decodeInteger(forKey: "notificationTypes")
        self.testType = coder.decodeObject(forKey: "testType") as? Int
        self.deviceOs = coder.decodeObject(forKey: "deviceOs") as? String ?? UIDevice.current.systemVersion
        self.sdk = coder.decodeObject(forKey: "sdk") as? String ?? ONESIGNAL_VERSION
        self.deviceModel = coder.decodeObject(forKey: "deviceModel") as? String
        self.appVersion = coder.decodeObject(forKey: "appVersion") as? String
        self.netType = coder.decodeObject(forKey: "netType") as? Int

        super.init(coder: coder)
    }

    public override func hydrateModel(_ response: [String: Any]) {
        OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OSSubscriptionModel hydrateModel()")
        for property in response {
            switch property.key {
            case "id":
                self.subscriptionId = property.value as? String
            case "type":
                if let type = OSSubscriptionType(rawValue: property.value as? String ?? "") {
                    self.type = type
                }
            // case "token":
                // TODO: For now, don't hydrate token
                // self.address = property.value as? String
            case "enabled":
                if let enabled = property.value as? Bool {
                    if self.enabled != enabled { // TODO: Is this right?
                        _isDisabled = !enabled
                    }
                }
            case "notification_types":
                if let notificationTypes = property.value as? Int {
                    self.notificationTypes = notificationTypes
                }
            default:
                OneSignalLog.onesignalLog(.LL_DEBUG, message: "Unused property on subscription model")
            }
        }
    }

    // Using snake_case so we can use this in request bodies
    public func jsonRepresentation() -> [String: Any] {
        var json: [String: Any] = [:]
        json["id"] = self.subscriptionId
        json["type"] = self.type.rawValue
        json["token"] = self.address
        json["enabled"] = self.enabled
        json["test_type"] = self.testType
        json["device_os"] = self.deviceOs
        json["sdk"] = self.sdk
        json["device_model"] = self.deviceModel
        json["app_version"] = self.appVersion
        json["net_type"] = self.netType
        // notificationTypes defaults to -1 instead of nil, don't send if it's -1
        if self.notificationTypes != -1 {
            json["notification_types"] = self.notificationTypes
        }
        return json
    }
}

// Push Subscription related
extension OSSubscriptionModel {
    // Only used for the push subscription model
    var currentPushSubscriptionState: OSPushSubscriptionState {
        return OSPushSubscriptionState(id: self.subscriptionId,
                                       token: self.address,
                                       optedIn: self.optedIn
        )
    }

    // Calculates if the device is opted in to push notification.
    // Must have permission and not be opted out.
    func calculateIsOptedIn(reachable: Bool, isDisabled: Bool) -> Bool {
        return reachable && !isDisabled
    }

    // Calculates if push notifications are enabled on the device.
    // Does not consider the existence of the subscription_id, as we send this in the request to create a push subscription.
    func calculateIsEnabled(address: String?, reachable: Bool, isDisabled: Bool) -> Bool {
        return address != nil && reachable && !isDisabled
    }

    func updateNotificationTypes() {
        notificationTypes = Int(OSNotificationsManager.getNotificationTypes(_isDisabled))
    }

    func updateTestType() {
        let releaseMode: OSUIApplicationReleaseMode = OneSignalMobileProvision.releaseMode()
        // Workaround to unsure how to extract the Int value in 1 step...
        if releaseMode == .UIApplicationReleaseDev {
            self.testType = OSUIApplicationReleaseMode.UIApplicationReleaseDev.rawValue
        }
        if releaseMode == .UIApplicationReleaseAdHoc {
            self.testType = OSUIApplicationReleaseMode.UIApplicationReleaseAdHoc.rawValue
        }
        if releaseMode == .UIApplicationReleaseWildcard {
            self.testType = OSUIApplicationReleaseMode.UIApplicationReleaseWildcard.rawValue
        }
    }

    func update() {
        updateTestType()
        deviceOs = UIDevice.current.systemVersion
        sdk = ONESIGNAL_VERSION
        deviceModel = OSDeviceUtils.getDeviceVariant()
        appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        netType = OSNetworkingUtils.getNetType() as? Int
        // sdkType ??
        // isRooted ??
        if type == .push && !(subscriptionId ?? "").isEmpty {
            OneSignalUserDefaults.initShared().saveString(forKey: OSUD_PUSH_SUBSCRIPTION_ID, withValue: subscriptionId)
        }
    }

    enum OSPushPropertyChanged {
        case subscriptionId(String?)
        case reachable(Bool)
        case isDisabled(Bool)
        case address(String?)
    }

    func firePushSubscriptionChanged(_ changedProperty: OSPushPropertyChanged) {
        var prevIsOptedIn = true
        var prevIsEnabled = true
        var prevSubscriptionState = OSPushSubscriptionState(id: "", token: "", optedIn: true)

        switch changedProperty {
        case .subscriptionId(let oldValue):
            prevIsEnabled = calculateIsEnabled(address: address, reachable: _reachable, isDisabled: _isDisabled)
            prevIsOptedIn = calculateIsOptedIn(reachable: _reachable, isDisabled: _isDisabled)
            prevSubscriptionState = OSPushSubscriptionState(id: oldValue, token: address, optedIn: prevIsOptedIn)

        case .reachable(let oldValue):
            prevIsEnabled = calculateIsEnabled(address: address, reachable: oldValue, isDisabled: _isDisabled)
            prevIsOptedIn = calculateIsOptedIn(reachable: oldValue, isDisabled: _isDisabled)
            prevSubscriptionState = OSPushSubscriptionState(id: subscriptionId, token: address, optedIn: prevIsOptedIn)

        case .isDisabled(let oldValue):
            prevIsEnabled = calculateIsEnabled(address: address, reachable: _reachable, isDisabled: oldValue)
            prevIsOptedIn = calculateIsOptedIn(reachable: _reachable, isDisabled: oldValue)
            prevSubscriptionState = OSPushSubscriptionState(id: subscriptionId, token: address, optedIn: prevIsOptedIn)

        case .address(let oldValue):
            prevIsEnabled = calculateIsEnabled(address: oldValue, reachable: _reachable, isDisabled: _isDisabled)
            prevIsOptedIn = calculateIsOptedIn(reachable: _reachable, isDisabled: _isDisabled)
            prevSubscriptionState = OSPushSubscriptionState(id: subscriptionId, token: oldValue, optedIn: prevIsOptedIn)
        }

        let newIsOptedIn = calculateIsOptedIn(reachable: _reachable, isDisabled: _isDisabled)

        let newIsEnabled = calculateIsEnabled(address: address, reachable: _reachable, isDisabled: _isDisabled)

        if prevIsEnabled != newIsEnabled {
            self.set(property: "enabled", newValue: newIsEnabled)
        }

        let newSubscriptionState = OSPushSubscriptionState(id: subscriptionId, token: address, optedIn: newIsOptedIn)

        // TODO: Make this method less hacky, this is a final check before firing push observer
        guard !prevSubscriptionState.equals(newSubscriptionState) else {
            return
        }

        let stateChanges = OSPushSubscriptionChangedState(current: newSubscriptionState, previous: prevSubscriptionState)

        // TODO: Don't fire observer until server is udated
        OneSignalLog.onesignalLog(.LL_VERBOSE, message: "firePushSubscriptionChanged from \(prevSubscriptionState.jsonRepresentation()) to \(newSubscriptionState.jsonRepresentation())")
        OneSignalUserManagerImpl.sharedInstance.pushSubscriptionImpl.pushSubscriptionStateChangesObserver.notifyChange(stateChanges)
    }
}
