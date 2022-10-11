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

/**
 Public-facing API to access the User Manager.
 */
@objc protocol OneSignalUserManager {
    static var User: OSUser.Type { get }
    static func login(aliasLabel: String, aliasId: String, token: String?)
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
    static func removeEmail(_ email: String)
    // SMS
    static func addSmsNumber(_ number: String)
    static func removeSmsNumber(_ number: String)
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
        if let user = _user {
            return user
        }

        // There is no user instance, initialize a "guest user"
        let user = _login(aliasLabel: nil, aliasId: nil, token: nil)
        _user = user
        return user
    }

    private static var _user: OSUserInternal?

    // has Identity, Properties, and Subscription Model Stores
    static let identityModelStore = OSModelStore<OSIdentityModel>(changeSubscription: OSEventProducer(), storeKey: OS_IDENTITY_MODEL_STORE_KEY)
    static let propertiesModelStore = OSModelStore<OSPropertiesModel>(changeSubscription: OSEventProducer(), storeKey: OS_PROPERTIES_MODEL_STORE_KEY)
    static let subscriptionModelStore = OSModelStore<OSSubscriptionModel>(changeSubscription: OSEventProducer(), storeKey: OS_SUBSCRIPTION_MODEL_STORE_KEY)

    // TODO: UM, and Model Store Listeners: where do they live? Here for now.
    static let identityModelStoreListener = OSIdentityModelStoreListener(store: identityModelStore)
    static let propertiesModelStoreListener = OSPropertiesModelStoreListener(store: propertiesModelStore)
    static let subscriptionModelStoreListener = OSSubscriptionModelStoreListener(store: subscriptionModelStore)

    // has Property and Identity operation executors
    static let propertyExecutor = OSPropertyOperationExecutor()
    static let identityExecutor = OSIdentityOperationExecutor()
    static let subscriptionExecutor = OSSubscriptionOperationExecutor()

    static func start() {
        // TODO: Finish implementation
        // startModelStoreListenersAndExecutors() moves here after this start() method is hooked up.
        loadUserFromCache() // TODO: Revisit when to load user from the cache.
    }

    static func startModelStoreListenersAndExecutors() {
        // Model store listeners subscribe to their models. TODO: Where should these live?
        identityModelStoreListener.start()
        propertiesModelStoreListener.start()
        subscriptionModelStoreListener.start()

        // Setup the executors
        OSOperationRepo.sharedInstance.addExecutor(identityExecutor)
        OSOperationRepo.sharedInstance.addExecutor(propertyExecutor)
        OSOperationRepo.sharedInstance.addExecutor(subscriptionExecutor)
    }

    @objc
    public static func login(aliasLabel: String, aliasId: String, token: String?) {
        print("🔥 OneSignalUserManagerImpl login(label: \(aliasLabel), id: \(aliasId)) called")
        _ = _login(aliasLabel: aliasLabel, aliasId: aliasId, token: token)
    }

    private static func _login(aliasLabel: String?, aliasId: String?, token: String?) -> OSUserInternal {
        print("🔥 OneSignalUserManagerImpl private _login(label: \(aliasLabel), id: \(aliasId)) called")
        startModelStoreListenersAndExecutors()

        // If have token, validate token. Account for this being a requirement.

        // Check if the existing user is the same one being logged in. If so, return.
        if let user = _user, let label = aliasLabel {
            guard user.identityModel.aliases[label] != aliasId else {
                return user
            }
        }

        // Create new user

        // Notify that the user will change so model stores, etc can clear their cache.
        NotificationCenter.default.post(name: Notification.Name(OS_ON_USER_WILL_CHANGE), object: nil)

        let identityModel = OSIdentityModel(changeNotifier: OSEventProducer())
        self.identityModelStore.add(id: OS_IDENTITY_MODEL_KEY, model: identityModel)

        let propertiesModel = OSPropertiesModel(changeNotifier: OSEventProducer())
        self.propertiesModelStore.add(id: OS_PROPERTIES_MODEL_KEY, model: propertiesModel)

        // TODO: Push Subscription logic
            // If and how the push subscription moves to the new user?
            // Add the push sub to the store w/o creating a Delta?
        let pushSubscription = OSSubscriptionModel(type: .push, address: nil, enabled: false, changeNotifier: OSEventProducer()
        )

        _user = OSUserInternalImpl(identityModel: identityModel, propertiesModel: propertiesModel, pushSubscriptionModel: pushSubscription)
        return self.user
    }

    @objc
    public static func logout() {
        NotificationCenter.default.post(name: Notification.Name(OS_ON_USER_WILL_CHANGE), object: nil)
        // Login a guest user
        _user = nil
        createUserIfNil()
    }

    static func createUserIfNil() {
        _ = self.user
    }

    static func loadUserFromCache() {
        print("🔥 OneSignalUserManagerImpl loadUserFromCache()")
        // Corrupted state if any exists without the others
        guard let identityModel = identityModelStore.getModels()[OS_IDENTITY_MODEL_KEY],
              let propertiesModel = propertiesModelStore.getModels()[OS_PROPERTIES_MODEL_KEY],
              let pushSubscription = subscriptionModelStore.getModels()[OS_PUSH_SUBSCRIPTION_MODEL_KEY]
        else {
            return
        }

        _user = OSUserInternalImpl(identityModel: identityModel, propertiesModel: propertiesModel, pushSubscriptionModel: pushSubscription)
        startModelStoreListenersAndExecutors()
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
        user.addAlias(label: label, id: id)
    }

    public static func addAliases(_ aliases: [String: String]) {
        user.addAliases(aliases)
    }

    public static func removeAlias(_ label: String) {
        user.removeAlias(label)
    }

    public static func removeAliases(_ labels: [String]) {
        user.removeAliases(labels)
    }

    public static func setTag(key: String, value: String) {
        user.setTag(key: key, value: value)
    }

    public static func setTags(_ tags: [String: String]) {
        user.setTags(tags)
    }

    public static func removeTag(_ tag: String) {
        user.removeTag(tag)
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

    public static func removeEmail(_ email: String) {
        // Check if is valid email?
        createUserIfNil()
        self.subscriptionModelStore.remove(email)
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

    public static func removeSmsNumber(_ number: String) {
        // Check if is valid SMS?
        createUserIfNil()
        self.subscriptionModelStore.remove(number)
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

    public static func testCreatePushSubscription(subscriptionId: String, token: String, enabled: Bool) {
        user.testCreatePushSubscription(subscriptionId: subscriptionId, token: token, enabled: enabled)
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
}
