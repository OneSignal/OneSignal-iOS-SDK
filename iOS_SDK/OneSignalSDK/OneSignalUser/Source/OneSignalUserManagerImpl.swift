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

/**
 Public-facing API to access the User Manager.
 */
@objc protocol OneSignalUserManager {
    static var User: OSUser.Type { get }
    static func login(externalId: String, token: String?)
    static func logout()
}

/**
 This is the user interface exposed to the public.
 */
@objc public protocol OSUser {
    static var pushSubscription: OSPushSubscription.Type { get }
    // Aliases
    static func addAlias(label: String, id: String)
    static func addAliases(_ aliases: [String: String])
    static func removeAlias(_ label: String)
    static func removeAliases(_ labels: [String])
    // Tags
    static func setTag(key: String, value: String)
    static func setTags(_ tags: [String: String])
    static func removeTag(_ tag: String)
    static func removeTags(_ tags: [String])
    // Outcomes
    static func setOutcome(_ name: String)
    static func setUniqueOutcome(_ name: String)
    static func setOutcome(name: String, value: Float)
    // Email
    static func addEmail(_ email: String)
    static func removeEmail(_ email: String) -> Bool
    // SMS
    static func addSmsNumber(_ number: String)
    static func removeSmsNumber(_ number: String) -> Bool
    // Triggers
    static func setTrigger(key: String, value: String)
    static func setTriggers(_ triggers: [String: String])
    static func removeTrigger(_ trigger: String)
    static func removeTriggers(_ triggers: [String])

    // TODO: UM This is a temporary function to create a push subscription for testing
    static func testCreatePushSubscription(subscriptionId: String, token: String, enabled: Bool)
}

/**
 This is the push subscription interface exposed to the public.
 */
@objc public protocol OSPushSubscription {
    static var subscriptionId: String? { get }
    static var token: String? { get }
    static var enabled: Bool { get set }
}

@objc
public class OneSignalUserManagerImpl: NSObject, OneSignalUserManager {
    static var user: OSUserInternal {
        if !hasCalledStart {
            start()
        }

        if let user = _user {
            return user
        }

        // There is no user instance, initialize a "guest user"
        let user = _login(externalId: nil, token: nil)
        _user = user
        return user
    }

    private static var _user: OSUserInternal?

    // Track if start() has been called because it should only be called once.
    private static var hasCalledStart = false

    // has Identity, Properties, and Subscription Model Stores
    static let identityModelStore = OSModelStore<OSIdentityModel>(changeSubscription: OSEventProducer(), storeKey: OS_IDENTITY_MODEL_STORE_KEY)
    static let propertiesModelStore = OSModelStore<OSPropertiesModel>(changeSubscription: OSEventProducer(), storeKey: OS_PROPERTIES_MODEL_STORE_KEY)
    static let subscriptionModelStore = OSModelStore<OSSubscriptionModel>(changeSubscription: OSEventProducer(), storeKey: OS_SUBSCRIPTION_MODEL_STORE_KEY)

    static let identityModelStoreListener = OSIdentityModelStoreListener(store: identityModelStore)
    static let propertiesModelStoreListener = OSPropertiesModelStoreListener(store: propertiesModelStore)
    static let subscriptionModelStoreListener = OSSubscriptionModelStoreListener(store: subscriptionModelStore)

    // has Property and Identity operation executors
    static let propertyExecutor = OSPropertyOperationExecutor()
    static let identityExecutor = OSIdentityOperationExecutor()
    static let subscriptionExecutor = OSSubscriptionOperationExecutor()

    // TODO: Call this function around app init
    /**
     This method is called around app init, and should only be called once. Use flag `hasCalledStart` to track.
     If `.user` is accessed and we have not called this method yet, we will call this method first.
     */
    public static func start() {
        guard !hasCalledStart else {
            return
        }
        hasCalledStart = true

        print("🔥 OneSignalUserManagerImpl start()")

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
    }

    @objc
    public static func login(externalId: String, token: String?) {
        guard externalId != "" else {
            // Log error
            return
        }
        print("🔥 OneSignalUserManagerImpl login(\(externalId)) called")
        _ = _login(externalId: externalId, token: token)
    }

    private static func createNewUser(externalId: String?, token: String?) -> OSUserInternal {
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
    private static func identifyUser(externalId: String, currentUser: OSUserInternal) {
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

    private static func _login(externalId: String?, token: String?) -> OSUserInternal {
        print("🔥 OneSignalUserManagerImpl private _login(\(externalId)) called")

        // If have token, validate token. Account for this being a requirement.

        // Logging into an identified user from an anonymous user
        if let externalId = externalId,
           let user = _user,
           user.isAnonymous {
            identifyUser(externalId: externalId, currentUser: user)
            return self.user
        }

        // Logging into anon -> anon, identified -> anon, or identified -> identified
        return createNewUser(externalId: externalId, token: token)
    }

    /**
     The SDK needs to have a user at all times, so this method will create a new anonymous user.
     */
    @objc
    public static func logout() {
        _user = nil
        createUserIfNil()
    }

    private static func createUserIfNil() {
        _ = self.user
    }

    /**
     Notifies observers that the user will be changed. Responses include model stores clearing their User Defaults
     and the operation repo flushing the current (soon to be old) user's operations.
     */
    private static func prepareForNewUser() {
        NotificationCenter.default.post(name: Notification.Name(OS_ON_USER_WILL_CHANGE), object: nil)

        // This store MUST be cleared, Identity and Properties do not.
        subscriptionModelStore.clearModelsFromStore()
    }

    /**
     Creates and sets a blank new SDK user with the provided externalId, if any.
     */
    private static func setNewInternalUser(_ externalId: String?) -> OSUserInternal {
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

        let pushSubscription = OSSubscriptionModel(type: .push, address: nil, enabled: false, changeNotifier: OSEventProducer())

        _user = OSUserInternalImpl(identityModel: identityModel, propertiesModel: propertiesModel, pushSubscriptionModel: pushSubscription)
        return self.user
    }
}

extension OneSignalUserManagerImpl: OSUser {
    public static var User: OSUser.Type {
        return self
    }

    public static var pushSubscription: OSPushSubscription.Type {
        return self
    }

    public static func addAlias(label: String, id: String) {
        user.addAliases([label: id])
    }

    public static func addAliases(_ aliases: [String: String]) {
        user.addAliases(aliases)
    }

    public static func removeAlias(_ label: String) {
        user.removeAliases([label])
    }

    public static func removeAliases(_ labels: [String]) {
        user.removeAliases(labels)
    }

    public static func setTag(key: String, value: String) {
        user.setTags([key: value])
    }

    public static func setTags(_ tags: [String: String]) {
        user.setTags(tags)
    }

    public static func removeTag(_ tag: String) {
        user.removeTags([tag])
    }

    public static func removeTags(_ tags: [String]) {
        user.removeTags(tags)
    }

    public static func setOutcome(_ name: String) {
        user.setOutcome(name)
    }

    public static func setUniqueOutcome(_ name: String) {
        user.setUniqueOutcome(name)
    }

    public static func setOutcome(name: String, value: Float) {
        user.setOutcome(name: name, value: value)
    }

    public static func addEmail(_ email: String) {
        // Check if is valid email?
        // Check if this email already exists on this User?
        createUserIfNil()
        let model = OSSubscriptionModel(
            type: .email,
            address: email,
            enabled: true,
            changeNotifier: OSEventProducer()
        )
        self.subscriptionModelStore.add(id: email, model: model)
    }

    /**
     If this email doesn't already exist on the user, it cannot be removed.
     This will be a no-op and no request will be made.
     Error handling needs to be implemented in the future.
     */
    public static func removeEmail(_ email: String) -> Bool {
        // Check if is valid email?
        createUserIfNil()
        return self.subscriptionModelStore.remove(email)
    }

    public static func addSmsNumber(_ number: String) {
        // Check if is valid SMS?
        // Check if this SMS already exists on this User?
        createUserIfNil()
        let model = OSSubscriptionModel(
            type: .sms,
            address: number,
            enabled: true,
            changeNotifier: OSEventProducer()
        )
        self.subscriptionModelStore.add(id: number, model: model)
    }

    /**
     If this email doesn't already exist on the user, it cannot be removed.
     This will be a no-op and no request will be made.
     Error handling needs to be implemented in the future.
     */
    public static func removeSmsNumber(_ number: String) -> Bool {
        // Check if is valid SMS?
        createUserIfNil()
        return self.subscriptionModelStore.remove(number)
    }

    public static func setTrigger(key: String, value: String) {
        user.setTrigger(key: key, value: value)
    }

    public static func setTriggers(_ triggers: [String: String]) {
        user.setTriggers(triggers)
    }

    public static func removeTrigger(_ trigger: String) {
        user.removeTrigger(trigger)
    }

    public static func removeTriggers(_ triggers: [String]) {
        user.removeTriggers(triggers)
    }

    static func testCreatePushSubscription(subscriptionId: String, token: String, enabled: Bool) -> OSSubscriptionModel {
        return user.testCreatePushSubscription(subscriptionId: subscriptionId, token: token, enabled: enabled)
    }
}

extension OneSignalUserManagerImpl: OSPushSubscription {
    public static var subscriptionId: String? {
        user.pushSubscriptionModel.subscriptionId
    }

    public static var token: String? {
        user.pushSubscriptionModel.address
    }

    public static var enabled: Bool {
        get {
            user.pushSubscriptionModel.enabled
        }
        set {
            user.pushSubscriptionModel.enabled = newValue
        }
    }

    static func setPushToken(_ token: String) {
        createUserIfNil()
        user.pushSubscriptionModel.address = token
        // Communicate to OSUserExecutor to make any pending CreateUser requests waiting on token
        OSUserExecutor.executePendingRequests()
    }
}
