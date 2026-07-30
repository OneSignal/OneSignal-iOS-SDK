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
        let id = self.id ?? ""
        let token = self.token ?? ""
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
    /**
     The stored properties of this model, accessed only while holding `stateLock`.
     */
    private struct State {
        var type: OSSubscriptionType
        var address: String?
        var subscriptionId: String?
        var reachable: Bool
        var isDisabled: Bool
        var notificationTypes: Int
        var testType: Int?
        var deviceOs: String
        var sdk: String
        var deviceModel: String?
        var appVersion: String?
        var netType: Int?
    }

    /**
     Guards `state` only. Held just for raw reads and writes of the stored values (never while firing
     change events, notifying observers, or writing to UserDefaults) so the re-entrant archive path
     (setter -> model store save -> `encode` on the same thread) and callouts into app code cannot deadlock.
     */
    private let stateLock = NSLock()
    private var state: State

    /// An atomic copy of the full state.
    private func snapshot() -> State {
        stateLock.withLock { state }
    }

    /// Atomically writes `newValue` and returns the value it replaced.
    private func swapValue<Value>(_ keyPath: WritableKeyPath<State, Value>, to newValue: Value) -> Value {
        stateLock.withLock {
            let oldValue = state[keyPath: keyPath]
            state[keyPath: keyPath] = newValue
            return oldValue
        }
    }

    var type: OSSubscriptionType {
        get { stateLock.withLock { state.type } }
        set { stateLock.withLock { state.type = newValue } }
    }

    var address: String? { // This is token on push subs so must remain Optional
        get { stateLock.withLock { state.address } }
        set {
            let oldValue = swapValue(\.address, to: newValue)
            guard newValue != oldValue else {
                return
            }
            self.set(property: "address", newValue: newValue)

            guard self.type == .push else {
                return
            }

            updateNotificationTypes()

            firePushSubscriptionChanged(.address(oldValue))
        }
    }

    /**
     Typically, the subscription ID is set via server response, so don't trigger a server update call when it changes.
     It can also be set to null by the SDK when the user or subscription is detected as missing.
     Setting the subscription ID to null will serve as a "reset" and will later hydrate a value from a user create rquest.
     */
    var subscriptionId: String? {
        get { stateLock.withLock { state.subscriptionId } }
        set {
            let oldValue = swapValue(\.subscriptionId, to: newValue)
            guard newValue != oldValue else {
                return
            }

            // If the ID has changed, don't trigger a server call, since it can be set to null
            self.set(property: "subscriptionId", newValue: newValue, preventServerUpdate: true)

            guard self.type == .push else {
                return
            }

            // Cache the subscriptionId to UserDefaults for routine reads, and the OSResilientStorage mirror 
            OneSignalUserDefaults.initShared().saveString(forKey: OSUD_PUSH_SUBSCRIPTION_ID, withValue: newValue)
            OSResilientStorage.setString(newValue ?? "", forKey: OSResilientStorage.keySubscriptionId)

            firePushSubscriptionChanged(.subscriptionId(oldValue))
        }
    }

    // Internal property to send to server, not meant for outside access
    var enabled: Bool { // Does not consider subscription_id in the calculation
        get {
            let state = snapshot()
            return calculateIsEnabled(address: state.address, reachable: state.reachable, isDisabled: state.isDisabled)
        }
    }

    var optedIn: Bool {
        // optedIn = permission + userPreference
        get {
            let state = snapshot()
            return calculateIsOptedIn(reachable: state.reachable, isDisabled: state.isDisabled)
        }
    }

    // Push Subscription Only
    // Initialize to be -1, so not to deal with unwrapping every time, and simplifies caching
    var notificationTypes: Int {
        get { stateLock.withLock { state.notificationTypes } }
        set {
            let (oldValue, isDisabled) = stateLock.withLock {
                let oldValue = state.notificationTypes
                state.notificationTypes = newValue
                return (oldValue, state.isDisabled)
            }
            guard self.type == .push && newValue != oldValue else {
                return
            }

            // If _isDisabled is set, this supersedes as the value to send to server.
            // Pin to -2 without firing a change event, matching the didSet-within-didSet behavior this replaced.
            if isDisabled && newValue != -2 {
                stateLock.withLock { state.notificationTypes = -2 }
                return
            }
            _reachable = newValue > 0
            self.set(property: "notificationTypes", newValue: newValue)
        }
    }

    // swiftlint:disable identifier_name
    /**
     This is set by the permission state changing.
     Defaults to true for email & SMS, defaults to false for push.
     Note that this property reflects the `reachable` property of a permission state. As provisional permission is considered to be `optedIn` and `enabled`.
     */
    var _reachable: Bool {
        get { stateLock.withLock { state.reachable } }
        set {
            let oldValue = swapValue(\.reachable, to: newValue)
            guard self.type == .push && newValue != oldValue else {
                return
            }
            firePushSubscriptionChanged(.reachable(oldValue))
        }
    }

    // Set by the app developer when they call User.pushSubscription.optOut()
    var _isDisabled: Bool { // Default to false for all subscriptions
        get { stateLock.withLock { state.isDisabled } }
        set {
            let oldValue = swapValue(\.isDisabled, to: newValue)
            guard self.type == .push && newValue != oldValue else {
                return
            }
            firePushSubscriptionChanged(.isDisabled(oldValue))
            notificationTypes = -2
        }
    }

    // Properties for push subscription
    var testType: Int? {
        get { stateLock.withLock { state.testType } }
        set {
            let oldValue = swapValue(\.testType, to: newValue)
            guard newValue != oldValue else {
                return
            }
            self.set(property: "testType", newValue: newValue)
        }
    }

    var deviceOs: String {
        get { stateLock.withLock { state.deviceOs } }
        set {
            let oldValue = swapValue(\.deviceOs, to: newValue)
            guard newValue != oldValue else {
                return
            }
            self.set(property: "deviceOs", newValue: newValue)
        }
    }

    var sdk: String {
        get { stateLock.withLock { state.sdk } }
        set {
            let oldValue = swapValue(\.sdk, to: newValue)
            guard newValue != oldValue else {
                return
            }
            self.set(property: "sdk", newValue: newValue)
        }
    }

    var deviceModel: String? {
        get { stateLock.withLock { state.deviceModel } }
        set {
            let oldValue = swapValue(\.deviceModel, to: newValue)
            guard newValue != oldValue else {
                return
            }
            self.set(property: "deviceModel", newValue: newValue)
        }
    }

    var appVersion: String? {
        get { stateLock.withLock { state.appVersion } }
        set {
            let oldValue = swapValue(\.appVersion, to: newValue)
            guard newValue != oldValue else {
                return
            }
            self.set(property: "appVersion", newValue: newValue)
        }
    }

    var netType: Int? {
        get { stateLock.withLock { state.netType } }
        set {
            let oldValue = swapValue(\.netType, to: newValue)
            guard newValue != oldValue else {
                return
            }
            self.set(property: "netType", newValue: newValue)
        }
    }

    // When a Subscription is initialized, it may not have a subscriptionId until a request to the backend is made.
    init(type: OSSubscriptionType,
         address: String?,
         subscriptionId: String?,
         reachable: Bool,
         isDisabled: Bool,
         changeNotifier: OSEventProducer<OSModelChangedHandler>) {
        var testType: Int?
        var notificationTypes = -1

        // Set test_type if subscription model is PUSH, and update notificationTypes
        if type == .push {
            let releaseMode: OSUIApplicationReleaseMode = OneSignalMobileProvision.releaseMode()
            #if targetEnvironment(simulator)
            if releaseMode == OSUIApplicationReleaseMode.UIApplicationReleaseUnknown {
                testType = OSUIApplicationReleaseMode.UIApplicationReleaseDev.rawValue
            }
            #endif
            // Workaround to unsure how to extract the Int value in 1 step...
            if releaseMode == .UIApplicationReleaseDev {
                testType = OSUIApplicationReleaseMode.UIApplicationReleaseDev.rawValue
            }
            if releaseMode == .UIApplicationReleaseAdHoc {
                testType = OSUIApplicationReleaseMode.UIApplicationReleaseAdHoc.rawValue
            }
            if releaseMode == .UIApplicationReleaseWildcard {
                testType = OSUIApplicationReleaseMode.UIApplicationReleaseWildcard.rawValue
            }
            notificationTypes = Int(OSNotificationsManager.getNotificationTypes(isDisabled))
        }

        self.state = State(
            type: type,
            address: address,
            subscriptionId: subscriptionId,
            reachable: reachable,
            isDisabled: isDisabled,
            notificationTypes: notificationTypes,
            testType: testType,
            deviceOs: UIDevice.current.systemVersion,
            sdk: ONESIGNAL_VERSION,
            deviceModel: OSDeviceUtils.getDeviceVariant(),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
            netType: OSNetworkingUtils.getNetType() as? Int
        )

        super.init(changeNotifier: changeNotifier)
    }

    override func encode(with coder: NSCoder) {
        // Encode from one consistent snapshot; other threads may mutate this model mid-archive.
        let state = snapshot()
        super.encode(with: coder)
        coder.encode(state.type.rawValue, forKey: "type") // Encodes as String
        coder.encode(state.address, forKey: "address")
        coder.encode(state.subscriptionId, forKey: "subscriptionId")
        coder.encode(state.reachable, forKey: "_reachable")
        coder.encode(state.isDisabled, forKey: "_isDisabled")
        coder.encode(state.notificationTypes, forKey: "notificationTypes")
        coder.encode(state.testType, forKey: "testType")
        coder.encode(state.deviceOs, forKey: "deviceOs")
        coder.encode(state.sdk, forKey: "sdk")
        coder.encode(state.deviceModel, forKey: "deviceModel")
        coder.encode(state.appVersion, forKey: "appVersion")
        coder.encode(state.netType, forKey: "netType")
    }

    required init?(coder: NSCoder) {
        guard
            let rawType = coder.decodeObject(forKey: "type") as? String,
            let type = OSSubscriptionType(rawValue: rawType)
        else {
            // Log error
            return nil
        }
        self.state = State(
            type: type,
            address: coder.decodeObject(forKey: "address") as? String,
            subscriptionId: coder.decodeObject(forKey: "subscriptionId") as? String,
            reachable: coder.decodeBool(forKey: "_reachable"),
            isDisabled: coder.decodeBool(forKey: "_isDisabled"),
            notificationTypes: coder.decodeInteger(forKey: "notificationTypes"),
            testType: coder.decodeObject(forKey: "testType") as? Int,
            deviceOs: coder.decodeObject(forKey: "deviceOs") as? String ?? UIDevice.current.systemVersion,
            sdk: coder.decodeObject(forKey: "sdk") as? String ?? ONESIGNAL_VERSION,
            deviceModel: coder.decodeObject(forKey: "deviceModel") as? String,
            appVersion: coder.decodeObject(forKey: "appVersion") as? String,
            netType: coder.decodeObject(forKey: "netType") as? Int
        )

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
        let state = snapshot()
        var json: [String: Any] = [:]
        json["id"] = state.subscriptionId
        json["type"] = state.type.rawValue
        json["token"] = state.address
        json["enabled"] = calculateIsEnabled(address: state.address, reachable: state.reachable, isDisabled: state.isDisabled)
        json["test_type"] = state.testType
        json["device_os"] = state.deviceOs
        json["sdk"] = state.sdk
        json["device_model"] = state.deviceModel
        json["app_version"] = state.appVersion
        json["net_type"] = state.netType
        // notificationTypes defaults to -1 instead of nil, don't send if it's -1
        if state.notificationTypes != -1 {
            json["notification_types"] = state.notificationTypes
        }
        return json
    }
}

// Push Subscription related
extension OSSubscriptionModel {
    // Only used for the push subscription model
    var currentPushSubscriptionState: OSPushSubscriptionState {
        let state = snapshot()
        return OSPushSubscriptionState(id: state.subscriptionId,
                                       token: state.address,
                                       optedIn: calculateIsOptedIn(reachable: state.reachable, isDisabled: state.isDisabled)
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
