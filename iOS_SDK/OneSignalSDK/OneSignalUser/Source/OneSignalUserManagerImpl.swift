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

import OneSignalCore
import OneSignalOSCore
import OneSignalNotifications

/**
 Public-facing API to access the User Manager.
 */
@objc protocol OneSignalUserManager {
    var User: OSUser { get }
    func login(externalId: String, token: String?)
    func logout()
}

/**
 This is the user interface exposed to the public.
 */
@objc public protocol OSUser {
    var pushSubscription: OSPushSubscription { get }
    // Aliases
    func addAlias(label: String, id: String)
    func addAliases(_ aliases: [String: String])
    func removeAlias(_ label: String)
    func removeAliases(_ labels: [String])
    // Tags
    func setTag(key: String, value: String)
    func setTags(_ tags: [String: String])
    func removeTag(_ tag: String)
    func removeTags(_ tags: [String])
    // Outcomes
    func setOutcome(_ name: String)
    func setUniqueOutcome(_ name: String)
    func setOutcome(name: String, value: Float)
    // Email
    func addEmail(_ email: String)
    func removeEmail(_ email: String) -> Bool
    // SMS
    func addSmsNumber(_ number: String)
    func removeSmsNumber(_ number: String) -> Bool
    // TODO: Remove triggers from User Module
    // Triggers
    func setTrigger(key: String, value: String)
    func setTriggers(_ triggers: [String: String])
    func removeTrigger(_ trigger: String)
    func removeTriggers(_ triggers: [String])

    // TODO: UM This is a temporary function to create a push subscription for testing
    func testCreatePushSubscription(subscriptionId: String, token: String, enabled: Bool)
    // TODO: Add setLanguage
}

/**
 This is the push subscription interface exposed to the public.
 */
@objc public protocol OSPushSubscription {
    var subscriptionId: String? { get }
    var token: String? { get }
    var enabled: Bool { get }
    func enable(_ enable: Bool) -> Bool
    func addObserver(_ observer: OSPushSubscriptionObserver) -> OSPushSubscriptionState
    func removeObserver(_ observer: OSPushSubscriptionObserver)
}

@objc
public class OneSignalUserManagerImpl: NSObject, OneSignalUserManager {
    @objc public static let sharedInstance = OneSignalUserManagerImpl().start()
    var user: OSUserInternal {
        if let user = _user {
            return user
        }

        // There is no user instance, initialize a "guest user"
        let user = _login(externalId: nil, token: nil)
        _user = user
        return user
    }

    private var _user: OSUserInternal?

    // Push Subscription
    private var _pushSubscriptionStateChangesObserver: OSObservable<OSPushSubscriptionObserver, OSPushSubscriptionStateChanges>?
    var pushSubscriptionStateChangesObserver: OSObservable<OSPushSubscriptionObserver, OSPushSubscriptionStateChanges> {
        if let observer = _pushSubscriptionStateChangesObserver {
            return observer
        }
        let pushSubscriptionStateChangesObserver = OSObservable<OSPushSubscriptionObserver, OSPushSubscriptionStateChanges>(change: #selector(OSPushSubscriptionObserver.onOSPushSubscriptionChanged(stateChanges:)))
        _pushSubscriptionStateChangesObserver = pushSubscriptionStateChangesObserver

        // TODO: What's going on, fix this.
        return pushSubscriptionStateChangesObserver ?? OSObservable<OSPushSubscriptionObserver, OSPushSubscriptionStateChanges>(change: #selector(OSPushSubscriptionObserver.onOSPushSubscriptionChanged(stateChanges:)))
    }

    // has Identity, Properties, and Subscription Model Stores
    let identityModelStore = OSModelStore<OSIdentityModel>(changeSubscription: OSEventProducer(), storeKey: OS_IDENTITY_MODEL_STORE_KEY)
    let propertiesModelStore = OSModelStore<OSPropertiesModel>(changeSubscription: OSEventProducer(), storeKey: OS_PROPERTIES_MODEL_STORE_KEY)
    let subscriptionModelStore = OSModelStore<OSSubscriptionModel>(changeSubscription: OSEventProducer(), storeKey: OS_SUBSCRIPTION_MODEL_STORE_KEY)

    // These must be initialized in init()
    let identityModelStoreListener: OSIdentityModelStoreListener
    let propertiesModelStoreListener: OSPropertiesModelStoreListener
    let subscriptionModelStoreListener: OSSubscriptionModelStoreListener

    // has Property and Identity operation executors
    let propertyExecutor = OSPropertyOperationExecutor()
    let identityExecutor = OSIdentityOperationExecutor()
    let subscriptionExecutor = OSSubscriptionOperationExecutor()

    private override init() {
        self.identityModelStoreListener = OSIdentityModelStoreListener(store: identityModelStore)
        self.propertiesModelStoreListener = OSPropertiesModelStoreListener(store: propertiesModelStore)
        self.subscriptionModelStoreListener = OSSubscriptionModelStoreListener(store: subscriptionModelStore)
    }

    private func start() -> OneSignalUserManagerImpl {
        print("🔥 OneSignalUserManagerImpl start()")

        OSNotificationsManager.delegate = self

        // Load user from cache, if any
        // Corrupted state if any of these models exist without the others
        if let identityModel = identityModelStore.getModels()[OS_IDENTITY_MODEL_KEY],
           let propertiesModel = propertiesModelStore.getModels()[OS_PROPERTIES_MODEL_KEY],
           let pushSubscription = subscriptionModelStore.getModels()[OS_PUSH_SUBSCRIPTION_MODEL_KEY] {
            _user = OSUserInternalImpl(identityModel: identityModel, propertiesModel: propertiesModel, pushSubscriptionModel: pushSubscription)
        }

        // Model store listeners subscribe to their models
        identityModelStoreListener.start()
        propertiesModelStoreListener.start()
        subscriptionModelStoreListener.start()

        // Setup the executors
        OSUserExecutor.start()
        OSOperationRepo.sharedInstance.addExecutor(identityExecutor)
        OSOperationRepo.sharedInstance.addExecutor(propertyExecutor)
        OSOperationRepo.sharedInstance.addExecutor(subscriptionExecutor)
        return self
    }

    @objc
    public func login(externalId: String, token: String?) {
        guard externalId != "" else {
            // Log error
            return
        }
        print("🔥 OneSignalUserManagerImpl login(\(externalId)) called")
        _ = _login(externalId: externalId, token: token)
    }

    private func createNewUser(externalId: String?, token: String?) -> OSUserInternal {
        // Check if the existing user is the same one being logged in. If so, return.
        if let user = _user {
            guard user.identityModel.externalId != externalId || externalId == nil else {
                return user
            }
        }

        prepareForNewUser()

        let newUser = setNewInternalUser(externalId)

        OSUserExecutor.createUser(newUser)
        return self.user
    }

    /**
     The current user in the SDK is an anonymous user, and we are logging in with an externalId.
     
     There are two scenarios addressed:
     1. This externalId already exists on another user. We create a new SDK user and fetch that user's information.
     2. This externalId doesn't exist on any users. We successfully identify the user, but we still create a new SDK user and fetch to update it.
     */
    private func identifyUser(externalId: String, currentUser: OSUserInternal) {
        // Get the identity model of the current user
        let identityModelToIdentify = user.identityModel

        // Immediately drop the old user and set a new user in the SDK
        prepareForNewUser()
        let newUser = setNewInternalUser(externalId)

        // Now proceed to identify the previous user
        OSUserExecutor.identifyUser(
            externalId: externalId,
            identityModelToIdentify: identityModelToIdentify,
            identityModelToUpdate: newUser.identityModel
        )
    }

    private func _login(externalId: String?, token: String?) -> OSUserInternal {
        print("🔥 OneSignalUserManagerImpl private _login(\(externalId)) called")

        // If have token, validate token. Account for this being a requirement.

        // Logging into an identified user from an anonymous user
        if let externalId = externalId,
           let user = _user,
           user.isAnonymous {
            identifyUser(externalId: externalId, currentUser: user)
            return self.user
        }

        // Logging into anon -> anon, identified -> anon, identified -> identified, or nil -> any user
        return createNewUser(externalId: externalId, token: token)
    }

    /**
     The SDK needs to have a user at all times, so this method will create a new anonymous user.
     */
    @objc
    public func logout() {
        _user = nil
        createUserIfNil()
    }

    private func createUserIfNil() {
        _ = self.user
    }

    /**
     Notifies observers that the user will be changed. Responses include model stores clearing their User Defaults
     and the operation repo flushing the current (soon to be old) user's operations.
     */
    private func prepareForNewUser() {
        NotificationCenter.default.post(name: Notification.Name(OS_ON_USER_WILL_CHANGE), object: nil)

        // This store MUST be cleared, Identity and Properties do not.
        subscriptionModelStore.clearModelsFromStore()
    }

    /**
     Creates and sets a blank new SDK user with the provided externalId, if any.
     */
    private func setNewInternalUser(_ externalId: String?) -> OSUserInternal {
        let aliases: [String: String]?
        if let externalIdToUse = externalId {
            aliases = [OS_EXTERNAL_ID: externalIdToUse]
        } else {
            aliases = nil
        }

        let identityModel = OSIdentityModel(aliases: aliases, changeNotifier: OSEventProducer())
        self.identityModelStore.add(id: OS_IDENTITY_MODEL_KEY, model: identityModel)

        let propertiesModel = OSPropertiesModel(changeNotifier: OSEventProducer())
        self.propertiesModelStore.add(id: OS_PROPERTIES_MODEL_KEY, model: propertiesModel)

        // TODO: Push Subscription logic
        // Should we set it up with push sub information we already know
        // Or start with a blank push sub (no subscription_id) and hydrate subscription_id from server response
        // TODO: We will have to save subscription_id and push_token to user defaults when we get them
        let sharedUserDefaults = OneSignalUserDefaults.initShared()
        let _accepted = OSNotificationsManager.currentPermissionState.accepted
        let subscriptionId = sharedUserDefaults.getSavedString(forKey: OSUD_PLAYER_ID_TO, defaultValue: nil)
        let token = sharedUserDefaults.getSavedString(forKey: OSUD_PUSH_TOKEN_TO, defaultValue: nil)
        // let _isPushDisabled = standardUserDefaults.keyExists(OSUD_USER_SUBSCRIPTION_TO)

        let pushSubscription = OSSubscriptionModel(type: .push,
                                                      address: token,
                                                      subscriptionId: subscriptionId,
                                                      accepted: _accepted,
                                                      isDisabled: false,
                                                      changeNotifier: OSEventProducer())

        _user = OSUserInternalImpl(identityModel: identityModel, propertiesModel: propertiesModel, pushSubscriptionModel: pushSubscription)
        return self.user
    }
}

extension OneSignalUserManagerImpl: OSUser {
    public var User: OSUser {
        return self
    }

    public var pushSubscription: OSPushSubscription {
        return self
    }

    public func addAlias(label: String, id: String) {
        user.addAliases([label: id])
    }

    public func addAliases(_ aliases: [String: String]) {
        user.addAliases(aliases)
    }

    public func removeAlias(_ label: String) {
        user.removeAliases([label])
    }

    public func removeAliases(_ labels: [String]) {
        user.removeAliases(labels)
    }

    public func setTag(key: String, value: String) {
        user.setTags([key: value])
    }

    public func setTags(_ tags: [String: String]) {
        user.setTags(tags)
    }

    public func removeTag(_ tag: String) {
        user.removeTags([tag])
    }

    public func removeTags(_ tags: [String]) {
        user.removeTags(tags)
    }

    public func setOutcome(_ name: String) {
        user.setOutcome(name)
    }

    public func setUniqueOutcome(_ name: String) {
        user.setUniqueOutcome(name)
    }

    public func setOutcome(name: String, value: Float) {
        user.setOutcome(name: name, value: value)
    }

    public func addEmail(_ email: String) {
        // Check if is valid email?
        // Check if this email already exists on this User?
        createUserIfNil()
        let model = OSSubscriptionModel(
            type: .email,
            address: email,
            subscriptionId: nil,
            accepted: true,
            isDisabled: false,
            changeNotifier: OSEventProducer()
        )
        self.subscriptionModelStore.add(id: email, model: model)
    }

    /**
     If this email doesn't already exist on the user, it cannot be removed.
     This will be a no-op and no request will be made.
     Error handling needs to be implemented in the future.
     */
    public func removeEmail(_ email: String) -> Bool {
        // Check if is valid email?
        createUserIfNil()
        return self.subscriptionModelStore.remove(email)
    }

    public func addSmsNumber(_ number: String) {
        // Check if is valid SMS?
        // Check if this SMS already exists on this User?
        createUserIfNil()
        let model = OSSubscriptionModel(
            type: .sms,
            address: number,
            subscriptionId: nil,
            accepted: true,
            isDisabled: false,
            changeNotifier: OSEventProducer()
        )
        self.subscriptionModelStore.add(id: number, model: model)
    }

    /**
     If this email doesn't already exist on the user, it cannot be removed.
     This will be a no-op and no request will be made.
     Error handling needs to be implemented in the future.
     */
    public func removeSmsNumber(_ number: String) -> Bool {
        // Check if is valid SMS?
        createUserIfNil()
        return self.subscriptionModelStore.remove(number)
    }

    public func setTrigger(key: String, value: String) {
        user.setTrigger(key: key, value: value)
    }

    public func setTriggers(_ triggers: [String: String]) {
        user.setTriggers(triggers)
    }

    public func removeTrigger(_ trigger: String) {
        user.removeTrigger(trigger)
    }

    public func removeTriggers(_ triggers: [String]) {
        user.removeTriggers(triggers)
    }

    public func testCreatePushSubscription(subscriptionId: String, token: String, enabled: Bool) {
        user.testCreatePushSubscription(subscriptionId: subscriptionId, token: token, enabled: enabled)
    }
}

extension OneSignalUserManagerImpl: OSPushSubscription {

    public func addObserver(_ observer: OSPushSubscriptionObserver) -> OSPushSubscriptionState {
        self.pushSubscriptionStateChangesObserver.addObserver(observer)
        return user.pushSubscriptionModel.currentPushSubscriptionState
    }

    public func removeObserver(_ observer: OSPushSubscriptionObserver) {
        self.pushSubscriptionStateChangesObserver.removeObserver(observer)
    }

    public var subscriptionId: String? {
        user.pushSubscriptionModel.subscriptionId
    }

    public var token: String? {
        user.pushSubscriptionModel.address
    }

    /**
     Get the `enabled` state.
     */
    public var enabled: Bool {
        get {
            user.pushSubscriptionModel.enabled
        }
    }

    /**
     Set the `enabled` state. After being set, we return the `enabled` state, as one can attempt to set `enabled` to `true` but push is not actually enabled on the device. This can be due to system level permissions or missing push token, etc.
     */
    public func enable(_ enable: Bool) -> Bool {
        user.pushSubscriptionModel._isDisabled = !enable
        return user.pushSubscriptionModel.enabled
    }
}

extension OneSignalUserManagerImpl: OneSignalNotificationsDelegate {
    // doesnt need to live on push sub model, only sent to backend
    // check if this affects the subscription observers or permission observers
    public func setNotificationTypes(_ notificationTypes: Int32) {
        user.pushSubscriptionModel.notificationTypes = Int(notificationTypes)
    }

    public func setPushToken(_ pushToken: String) {
        user.pushSubscriptionModel.address = pushToken
    }

    public func setAccepted(_ inAccepted: Bool) {
        user.pushSubscriptionModel._accepted = inAccepted
    }
}
