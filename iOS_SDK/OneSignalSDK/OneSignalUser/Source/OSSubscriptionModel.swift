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

    // Serializes a complete state mutation and its notifications without blocking snapshots used for archiving.
    private let mutationLock: NSLocking
    private let stateLock = NSLock()
    private var state: State

    private func withMutationLock<Result>(_ body: () throws -> Result) rethrows -> Result {
        mutationLock.lock()
        defer { mutationLock.unlock() }
        return try body()
    }

    private func snapshot() -> State {
        stateLock.withLock {
            state
        }
    }

    private func update<Value: Equatable>(
        _ keyPath: WritableKeyPath<State, Value>,
        to newValue: Value
    ) -> (oldValue: Value, type: OSSubscriptionType)? {
        stateLock.withLock {
            let oldValue = state[keyPath: keyPath]
            guard oldValue != newValue else {
                return nil
            }
            state[keyPath: keyPath] = newValue
            return (oldValue, state.type)
        }
    }

    var type: OSSubscriptionType {
        get {
            stateLock.withLock {
                state.type
            }
        }
        set {
            withMutationLock {
                stateLock.withLock {
                    state.type = newValue
                }
            }
        }
    }

    var address: String? { // This is token on push subs so must remain Optional
        get {
            stateLock.withLock {
                state.address
            }
        }
        set {
            withMutationLock {
                guard let change = update(\.address, to: newValue) else {
                    return
                }
                self.set(property: "address", newValue: newValue)

                guard change.type == .push else {
                    return
                }

                updateNotificationTypes()

                var previousState = snapshot()
                let currentState = previousState
                previousState.address = change.oldValue
                firePushSubscriptionChanged(previous: previousState, current: currentState)
            }
        }
    }

    /**
     Typically, the subscription ID is set via server response, so don't trigger a server update call when it changes.
     It can also be set to null by the SDK when the user or subscription is detected as missing.
     Setting the subscription ID to null will serve as a "reset" and will later hydrate a value from a user create rquest.
     */
    var subscriptionId: String? {
        get {
            stateLock.withLock {
                state.subscriptionId
            }
        }
        set {
            withMutationLock {
                guard let change = update(\.subscriptionId, to: newValue) else {
                    return
                }

                // If the ID has changed, don't trigger a server call, since it can be set to null
                self.set(property: "subscriptionId", newValue: newValue, preventServerUpdate: true)

                guard change.type == .push else {
                    return
                }

                // Cache the subscriptionId to UserDefaults for routine reads, and the OSResilientStorage mirror
                OneSignalUserDefaults.initShared().saveString(forKey: OSUD_PUSH_SUBSCRIPTION_ID, withValue: newValue)
                OSResilientStorage.setString(newValue ?? "", forKey: OSResilientStorage.keySubscriptionId)

                var previousState = snapshot()
                let currentState = previousState
                previousState.subscriptionId = change.oldValue
                firePushSubscriptionChanged(previous: previousState, current: currentState)
            }
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
        get {
            stateLock.withLock {
                state.notificationTypes
            }
        }
        set {
            withMutationLock {
                let change = stateLock.withLock { () -> (oldReachable: Bool, reachableChanged: Bool)? in
                    let oldValue = state.notificationTypes
                    state.notificationTypes = newValue

                    guard state.type == .push && newValue != oldValue else {
                        return nil
                    }

                    // If isDisabled is set, this supersedes as the value to send to server.
                    if state.isDisabled && newValue != -2 {
                        state.notificationTypes = -2
                        return nil
                    }

                    let oldReachable = state.reachable
                    state.reachable = newValue > 0
                    return (oldReachable, oldReachable != state.reachable)
                }

                guard let change else {
                    return
                }

                if change.reachableChanged {
                    var previousState = snapshot()
                    let currentState = previousState
                    previousState.reachable = change.oldReachable
                    firePushSubscriptionChanged(previous: previousState, current: currentState)
                }
                self.set(property: "notificationTypes", newValue: newValue)
            }
        }
    }

    // swiftlint:disable identifier_name
    /**
     This is set by the permission state changing.
     Defaults to true for email & SMS, defaults to false for push.
     Note that this property reflects the `reachable` property of a permission state. As provisional permission is considered to be `optedIn` and `enabled`.
     */
    var _reachable: Bool {
        get {
            stateLock.withLock {
                state.reachable
            }
        }
        set {
            withMutationLock {
                guard let change = update(\.reachable, to: newValue), change.type == .push else {
                    return
                }
                var previousState = snapshot()
                let currentState = previousState
                previousState.reachable = change.oldValue
                firePushSubscriptionChanged(previous: previousState, current: currentState)
            }
        }
    }

    // Set by the app developer when they call User.pushSubscription.optOut()
    var _isDisabled: Bool { // Default to false for all subscriptions
        get {
            stateLock.withLock {
                state.isDisabled
            }
        }
        set {
            withMutationLock {
                guard let change = update(\.isDisabled, to: newValue), change.type == .push else {
                    return
                }
                var previousState = snapshot()
                let currentState = previousState
                previousState.isDisabled = change.oldValue
                firePushSubscriptionChanged(previous: previousState, current: currentState)
                notificationTypes = -2
            }
        }
    }

    // Properties for push subscription
    var testType: Int? {
        get {
            stateLock.withLock {
                state.testType
            }
        }
        set {
            withMutationLock {
                guard update(\.testType, to: newValue) != nil else {
                    return
                }
                self.set(property: "testType", newValue: newValue)
            }
        }
    }

    var deviceOs: String {
        get {
            stateLock.withLock {
                state.deviceOs
            }
        }
        set {
            withMutationLock {
                guard update(\.deviceOs, to: newValue) != nil else {
                    return
                }
                self.set(property: "deviceOs", newValue: newValue)
            }
        }
    }

    var sdk: String {
        get {
            stateLock.withLock {
                state.sdk
            }
        }
        set {
            withMutationLock {
                guard update(\.sdk, to: newValue) != nil else {
                    return
                }
                self.set(property: "sdk", newValue: newValue)
            }
        }
    }

    var deviceModel: String? {
        get {
            stateLock.withLock {
                state.deviceModel
            }
        }
        set {
            withMutationLock {
                guard update(\.deviceModel, to: newValue) != nil else {
                    return
                }
                self.set(property: "deviceModel", newValue: newValue)
            }
        }
    }

    var appVersion: String? {
        get {
            stateLock.withLock {
                state.appVersion
            }
        }
        set {
            withMutationLock {
                guard update(\.appVersion, to: newValue) != nil else {
                    return
                }
                self.set(property: "appVersion", newValue: newValue)
            }
        }
    }

    var netType: Int? {
        get {
            stateLock.withLock {
                state.netType
            }
        }
        set {
            withMutationLock {
                guard update(\.netType, to: newValue) != nil else {
                    return
                }
                self.set(property: "netType", newValue: newValue)
            }
        }
    }

    // When a Subscription is initialized, it may not have a subscriptionId until a request to the backend is made.
    init(type: OSSubscriptionType,
         address: String?,
         subscriptionId: String?,
         reachable: Bool,
         isDisabled: Bool,
         changeNotifier: OSEventProducer<OSModelChangedHandler>,
         mutationLock: NSLocking = NSRecursiveLock()) {
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

        self.mutationLock = mutationLock
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
        self.mutationLock = NSRecursiveLock()
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
        json["enabled"] = calculateIsEnabled(
            address: state.address,
            reachable: state.reachable,
            isDisabled: state.isDisabled
        )
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
                                       optedIn: calculateIsOptedIn(
                                           reachable: state.reachable,
                                           isDisabled: state.isDisabled
                                       )
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
        let state = snapshot()
        if state.type == .push && !(state.subscriptionId ?? "").isEmpty {
            OneSignalUserDefaults.initShared().saveString(
                forKey: OSUD_PUSH_SUBSCRIPTION_ID,
                withValue: state.subscriptionId
            )
        }
    }

    private func firePushSubscriptionChanged(previous: State, current: State) {
        let prevIsEnabled = calculateIsEnabled(
            address: previous.address,
            reachable: previous.reachable,
            isDisabled: previous.isDisabled
        )
        let prevIsOptedIn = calculateIsOptedIn(
            reachable: previous.reachable,
            isDisabled: previous.isDisabled
        )
        let prevSubscriptionState = OSPushSubscriptionState(
            id: previous.subscriptionId,
            token: previous.address,
            optedIn: prevIsOptedIn
        )

        let newIsOptedIn = calculateIsOptedIn(
            reachable: current.reachable,
            isDisabled: current.isDisabled
        )
        let newIsEnabled = calculateIsEnabled(
            address: current.address,
            reachable: current.reachable,
            isDisabled: current.isDisabled
        )

        if prevIsEnabled != newIsEnabled {
            self.set(property: "enabled", newValue: newIsEnabled)
        }

        let newSubscriptionState = OSPushSubscriptionState(
            id: current.subscriptionId,
            token: current.address,
            optedIn: newIsOptedIn
        )

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
