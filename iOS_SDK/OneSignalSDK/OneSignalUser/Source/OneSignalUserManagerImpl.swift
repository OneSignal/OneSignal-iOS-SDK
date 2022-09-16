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
    static func login(externalId: String?, withToken: String?)
    static func logout()
}

/**
 This is the user interface exposed to the public.
 */
@objc public protocol OSUser {
    static var pushSubscription: OSPushSubscriptionInterface { get }
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
    static func getTag(_ tag: String)
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
    static func testCreatePushSubscription(subscriptionId: UUID, token: UUID, enabled: Bool)
}

@objc
public class OneSignalUserManagerImpl: NSObject, OneSignalUserManager {
    static var user: OSUserInternal {
        if let user = _user {
            return user
        }

        let user = _login(externalId: nil, withToken: nil)
        _user = user
        return user
    }

    private static var _user: OSUserInternal?

    // has Identity and Properties Model Stores
    static let identityModelStore = OSModelStore<OSIdentityModel>(changeSubscription: OSEventProducer(), storeKey: OS_IDENTITY_MODEL_STORE_KEY)
    static let propertiesModelStore = OSModelStore<OSPropertiesModel>(changeSubscription: OSEventProducer(), storeKey: OS_PROPERTIES_MODEL_STORE_KEY)

    // TODO: UM, and Model Store Listeners: where do they live? Here for now.
    static let identityModelStoreListener = OSIdentityModelStoreListener(store: identityModelStore)
    static let propertiesModelStoreListener = OSPropertiesModelStoreListener(store: propertiesModelStore)

    // has Property and Identity operation executors
    static let propertyExecutor = OSPropertyOperationExecutor()
    static let identityExecutor = OSIdentityOperationExecutor()

    static func start() {
        // TODO: Finish implementation
        // startModelStoreListenersAndExecutors() moves here after this start() method is hooked up.
        loadUserFromCache() // TODO: Revisit when to load user from the cache.
    }

    static func startModelStoreListenersAndExecutors() {
        // Model store listeners subscribe to their models. TODO: Where should these live?
        identityModelStoreListener.start()
        propertiesModelStoreListener.start()

        // Setup the executors
        OSOperationRepo.sharedInstance.addExecutor(identityExecutor)
        OSOperationRepo.sharedInstance.addExecutor(propertyExecutor)
    }

    @objc
    public static func login(externalId: String?, withToken: String?) {
       _ = _login(externalId: externalId, withToken: withToken)
    }

    private static func _login(externalId: String?, withToken: String?) -> OSUserInternal {
        print("🔥 OneSignalUserManagerImpl login() called")
        startModelStoreListenersAndExecutors()

        // If have token, validate token. Account for this being a requirement.

        // Check if the existing user is the same one being logged in. If so, return.
        if let user = _user {
            guard (user.identityModel.externalId != externalId) || externalId == nil else {
                return user
            }
        }

        // Create new user
        // TODO: Remove/take care of the old user's information.

        let identityModel = OSIdentityModel(externalId: externalId, changeNotifier: OSEventProducer())
        self.identityModelStore.add(id: OS_IDENTITY_MODEL_KEY, model: identityModel)

        let propertiesModel = OSPropertiesModel(changeNotifier: OSEventProducer())
        self.propertiesModelStore.add(id: OS_PROPERTIES_MODEL_KEY, model: propertiesModel)

        let pushSubscription = OSPushSubscriptionModel(token: nil, enabled: false)
        // TODO: Add push subscription to store

        self._user = OSUserInternalImpl(identityModel: identityModel, propertiesModel: propertiesModel, pushSubscription: pushSubscription)
        return self.user
    }

    @objc
    public static func logout() {
        // TODO: Clear the models cache
        _user = nil
    }

    static func loadUserFromCache() {
        // Corrupted state if one exists without the other.
        guard !identityModelStore.getModels().isEmpty &&
                !propertiesModelStore.getModels().isEmpty // TODO: Check pushSubscriptionModel as well.
        else {
            return
        }

        // TODO: Need to load any SMS and emails subs too

        // There is a user in the cache
        let identityModel = identityModelStore.getModels().first!.value
        let propertiesModel = propertiesModelStore.getModels().first!.value
        let pushSubscription = OSPushSubscriptionModel(token: nil, enabled: false) // TODO: Modify to get from cache.

        _user = OSUserInternalImpl(identityModel: identityModel, propertiesModel: propertiesModel, pushSubscription: pushSubscription)
    }

}

extension OneSignalUserManagerImpl: OSUser {
    public static var User: OSUser.Type {
        return self
    }

    public static var pushSubscription: OSPushSubscriptionInterface {
        return user.pushSubscription
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

    // TODO: No tag getter?
    public static func getTag(_ tag: String) {
        user.getTag(tag)
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
        user.addEmail(email)
    }

    public static func removeEmail(_ email: String) {
        user.removeEmail(email)
    }

    public static func addSmsNumber(_ number: String) {
        user.addSmsNumber(number)
    }

    public static func removeSmsNumber(_ number: String) {
        user.removeSmsNumber(number)
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

    public static func testCreatePushSubscription(subscriptionId: UUID, token: UUID, enabled: Bool) {
        user.testCreatePushSubscription(subscriptionId: subscriptionId, token: token, enabled: enabled)
    }
}
