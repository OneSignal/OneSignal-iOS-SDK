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
    // swiftlint:disable identifier_name
    var User: OSUser { get }
    func login(externalId: String, token: String?)
    func logout()
    // Location
    func setLocation(latitude: Float, longitude: Float)
    // Purchase Tracking
    func sendPurchases(_ purchases:[[String:AnyObject]])
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
    // Email
    func addEmail(_ email: String)
    func removeEmail(_ email: String) -> Bool
    // SMS
    func addSmsNumber(_ number: String)
    func removeSmsNumber(_ number: String) -> Bool

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
    func addObserver(_ observer: OSPushSubscriptionObserver) -> OSPushSubscriptionState?
    func removeObserver(_ observer: OSPushSubscriptionObserver)
}

@objc
public class OneSignalUserManagerImpl: NSObject, OneSignalUserManager {
    @objc public static let sharedInstance = OneSignalUserManagerImpl()

    @objc public var onesignalId: String? {
        return _user?.identityModel.onesignalId
    }

    private var hasCalledStart = false

    var user: OSUserInternal {
        guard !OneSignalConfigManager.shouldAwaitAppIdAndLogMissingPrivacyConsent(forMethod: nil) else {
            return _mockUser
        }
        start()
        if let user = _user {
            return user
        }

        // There is no user instance, initialize a "guest user"
        let user = _login(externalId: nil, token: nil)
        _user = user
        return user
    }

    private var _user: OSUserInternal?

    // This is a user instance to operate on when there is no app_id and/or privacy consent yet, effectively no-op.
    // The models are not added to any model stores.
    private let _mockUser = OSUserInternalImpl(
        identityModel: OSIdentityModel(aliases: nil, changeNotifier: OSEventProducer()),
        propertiesModel: OSPropertiesModel(changeNotifier: OSEventProducer()),
        pushSubscriptionModel: OSSubscriptionModel(type: .push, address: nil, subscriptionId: nil, accepted: false, isDisabled: true, changeNotifier: OSEventProducer()))

    @objc public var requiresUserAuth = false

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

    // TODO: This method is called A LOT, check if all calls are needed.
    @objc
    public func start() {
        guard !OneSignalConfigManager.shouldAwaitAppIdAndLogMissingPrivacyConsent(forMethod: nil) else {
            return
        }
        guard !hasCalledStart else {
            return
        }

        hasCalledStart = true
        print("🔥 OneSignalUserManagerImpl start()")

        OSNotificationsManager.delegate = self

        // Load user from cache, if any
        // Corrupted state if any of these models exist without the others
        if let identityModel = identityModelStore.getModels()[OS_IDENTITY_MODEL_KEY],
           let propertiesModel = propertiesModelStore.getModels()[OS_PROPERTIES_MODEL_KEY],
           let pushSubscription = subscriptionModelStore.getModels()[OS_PUSH_SUBSCRIPTION_MODEL_KEY] {
            _user = OSUserInternalImpl(identityModel: identityModel, propertiesModel: propertiesModel, pushSubscriptionModel: pushSubscription)

            // TODO: Pull user data here in init or on every new session?
        }

        // Creates an anonymous user if there isn't one in the cache
        createUserIfNil()

        // Model store listeners subscribe to their models
        identityModelStoreListener.start()
        propertiesModelStoreListener.start()
        subscriptionModelStoreListener.start()

        // Setup the executors
        OSUserExecutor.start()
        OSOperationRepo.sharedInstance.start()
        OSOperationRepo.sharedInstance.addExecutor(identityExecutor)
        OSOperationRepo.sharedInstance.addExecutor(propertyExecutor)
        OSOperationRepo.sharedInstance.addExecutor(subscriptionExecutor)
    }

    @objc
    public func login(externalId: String, token: String?) {
        guard !OneSignalConfigManager.shouldAwaitAppIdAndLogMissingPrivacyConsent(forMethod: nil) else {
            return
        }
        start()
        guard externalId != "" else {
            // Log error
            return
        }
        print("🔥 OneSignalUserManagerImpl login(\(externalId)) called")
        _ = _login(externalId: externalId, token: token)
    }

    private func createNewUser(externalId: String?, token: String?) -> OSUserInternal {
        guard !OneSignalConfigManager.shouldAwaitAppIdAndLogMissingPrivacyConsent(forMethod: nil) else {
            return _mockUser
        }

        // Check if the existing user is the same one being logged in. If so, return.
        if let user = _user {
            guard user.identityModel.externalId != externalId || externalId == nil else {
                return user
            }
        }

        let pushSubscriptionModel = subscriptionModelStore.getModel(key: OS_PUSH_SUBSCRIPTION_MODEL_KEY)
        prepareForNewUser()

        let newUser = setNewInternalUser(externalId: externalId, pushSubscriptionModel: pushSubscriptionModel)

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
        guard !OneSignalConfigManager.shouldAwaitAppIdAndLogMissingPrivacyConsent(forMethod: nil) else {
            return
        }

        // Get the identity model of the current user
        let identityModelToIdentify = currentUser.identityModel

        // Immediately drop the old user and set a new user in the SDK
        let pushSubscriptionModel = subscriptionModelStore.getModel(key: OS_PUSH_SUBSCRIPTION_MODEL_KEY)
        prepareForNewUser()
        let newUser = setNewInternalUser(externalId: externalId, pushSubscriptionModel: pushSubscriptionModel)

        // Now proceed to identify the previous user
        OSUserExecutor.identifyUser(
            externalId: externalId,
            identityModelToIdentify: identityModelToIdentify,
            identityModelToUpdate: newUser.identityModel
        )
    }

    private func _login(externalId: String?, token: String?) -> OSUserInternal {
        guard !OneSignalConfigManager.shouldAwaitAppIdAndLogMissingPrivacyConsent(forMethod: nil) else {
            return _mockUser
        }

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
        guard !OneSignalConfigManager.shouldAwaitAppIdAndLogMissingPrivacyConsent(forMethod: nil) else {
            return
        }
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
    private func setNewInternalUser(externalId: String?, pushSubscriptionModel: OSSubscriptionModel?) -> OSUserInternal {
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

        // TODO: We will have to save subscription_id and push_token to user defaults when we get them

        var pushSubscription = pushSubscriptionModel ?? createDefaultPushSubscription()

        subscriptionModelStore.add(id: OS_PUSH_SUBSCRIPTION_MODEL_KEY, model: pushSubscription)

        _user = OSUserInternalImpl(identityModel: identityModel, propertiesModel: propertiesModel, pushSubscriptionModel: pushSubscription)
        return self.user
    }

    func createDefaultPushSubscription() -> OSSubscriptionModel {
        let sharedUserDefaults = OneSignalUserDefaults.initShared()
        let accepted = OSNotificationsManager.currentPermissionState.accepted
        let token = sharedUserDefaults.getSavedString(forKey: OSUD_PUSH_TOKEN_TO, defaultValue: nil)
        let subscriptionId = sharedUserDefaults.getSavedString(forKey: OSUD_PLAYER_ID_TO, defaultValue: nil)

        return OSSubscriptionModel(type: .push,
                                   address: token,
                                   subscriptionId: subscriptionId,
                                   accepted: accepted,
                                   isDisabled: false,
                                   changeNotifier: OSEventProducer())
    }
    
    @objc
    public func getTags() -> [String:String]? {
        guard let user = _user else {
            return nil
        }
        return user.propertiesModel.tags
    }
    
    @objc
    public func setLocation(latitude: Float, longitude: Float) {
        guard !OneSignalConfigManager.shouldAwaitAppIdAndLogMissingPrivacyConsent(forMethod: "setLocation") else {
            return
        }
        guard let user = _user else {
            OneSignalLog.onesignalLog(ONE_S_LOG_LEVEL.LL_DEBUG, message: "Failed to set location because User is nil")
            return
        }
        user.setLocation(lat: latitude, long: longitude)
    }
    
    @objc
    public func sendPurchases(_ purchases: [[String : AnyObject]]) {
        guard !OneSignalConfigManager.shouldAwaitAppIdAndLogMissingPrivacyConsent(forMethod: "sendPurchases") else {
            return
        }
        guard let user = _user else {
            OneSignalLog.onesignalLog(ONE_S_LOG_LEVEL.LL_DEBUG, message: "Failed to send purchases because User is nil")
            return
        }
        // Get the identity and properties model of the current user
        let identityModel = user.identityModel
        let propertiesModel = user.propertiesModel
        let propertiesDeltas = OSPropertiesDeltas(sessionTime: nil, sessionCount: nil, amountSpent: nil, purchases: purchases)
        propertyExecutor.updateProperties(
            propertiesDeltas: propertiesDeltas,
            refreshDeviceMetadata: false,
            propertiesModel: propertiesModel,
            identityModel: identityModel
        )
    }
}

// MARK: - Sessions

extension OneSignalUserManagerImpl {
    @objc
    public func updateSession(sessionCount: NSNumber?, sessionTime: NSNumber?, refreshDeviceMetadata: Bool) {
        guard !OneSignalConfigManager.shouldAwaitAppIdAndLogMissingPrivacyConsent(forMethod: nil) else {
            return
        }

        // Get the identity and properties model of the current user
        let identityModel = user.identityModel
        let propertiesModel = user.propertiesModel
        let propertiesDeltas = OSPropertiesDeltas(sessionTime: sessionTime, sessionCount: sessionCount, amountSpent: nil, purchases: nil)
        propertyExecutor.updateProperties(
            propertiesDeltas: propertiesDeltas,
            refreshDeviceMetadata: refreshDeviceMetadata,
            propertiesModel: propertiesModel,
            identityModel: identityModel
        )
    }

    /**
     App has been backgrounded. Run background tasks such to flush  the operation repo and hydrating models.
     Need to consider app killed vs app backgrounded and handle gracefully.
     */
    @objc
    public func runBackgroundTasks() {
        // TODO: Test background behavior
        // Can't end background task until the server calls return
        OSBackgroundTaskManager.beginBackgroundTask(USER_MANAGER_BACKGROUND_TASK)
        // dispatch_async ?
        OSOperationRepo.sharedInstance.flushDeltaQueue()
        OSBackgroundTaskManager.endBackgroundTask(USER_MANAGER_BACKGROUND_TASK)
    }
}

extension OneSignalUserManagerImpl: OSUser {
    public var User: OSUser {
        start()
        return self
    }

    public var pushSubscription: OSPushSubscription {
        start()
        return self
    }

    public func addAlias(label: String, id: String) {
        guard !OneSignalConfigManager.shouldAwaitAppIdAndLogMissingPrivacyConsent(forMethod: "addAlias") else {
            return
        }
        user.addAliases([label: id])
    }

    public func addAliases(_ aliases: [String: String]) {
        guard !OneSignalConfigManager.shouldAwaitAppIdAndLogMissingPrivacyConsent(forMethod: "addAliases") else {
            return
        }
        user.addAliases(aliases)
    }

    public func removeAlias(_ label: String) {
        guard !OneSignalConfigManager.shouldAwaitAppIdAndLogMissingPrivacyConsent(forMethod: "removeAlias") else {
            return
        }
        user.removeAliases([label])
    }

    public func removeAliases(_ labels: [String]) {
        guard !OneSignalConfigManager.shouldAwaitAppIdAndLogMissingPrivacyConsent(forMethod: "removeAliases") else {
            return
        }
        user.removeAliases(labels)
    }

    public func setTag(key: String, value: String) {
        guard !OneSignalConfigManager.shouldAwaitAppIdAndLogMissingPrivacyConsent(forMethod: "setTag") else {
            return
        }
        user.setTags([key: value])
    }

    public func setTags(_ tags: [String: String]) {
        guard !OneSignalConfigManager.shouldAwaitAppIdAndLogMissingPrivacyConsent(forMethod: "setTags") else {
            return
        }
        user.setTags(tags)
    }

    public func removeTag(_ tag: String) {
        guard !OneSignalConfigManager.shouldAwaitAppIdAndLogMissingPrivacyConsent(forMethod: "removeTag") else {
            return
        }
        user.removeTags([tag])
    }

    public func removeTags(_ tags: [String]) {
        guard !OneSignalConfigManager.shouldAwaitAppIdAndLogMissingPrivacyConsent(forMethod: "removeTags") else {
            return
        }
        user.removeTags(tags)
    }

    public func addEmail(_ email: String) {
        guard !OneSignalConfigManager.shouldAwaitAppIdAndLogMissingPrivacyConsent(forMethod: "addEmail") else {
            return
        }
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
        guard !OneSignalConfigManager.shouldAwaitAppIdAndLogMissingPrivacyConsent(forMethod: "removeEmail") else {
            return false
        }
        // Check if is valid email?
        createUserIfNil()
        return self.subscriptionModelStore.remove(email)
    }

    public func addSmsNumber(_ number: String) {
        guard !OneSignalConfigManager.shouldAwaitAppIdAndLogMissingPrivacyConsent(forMethod: "addSmsNumber") else {
            return
        }
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
        guard !OneSignalConfigManager.shouldAwaitAppIdAndLogMissingPrivacyConsent(forMethod: "removeSmsNumber") else {
            return false
        }
        // Check if is valid SMS?
        createUserIfNil()
        return self.subscriptionModelStore.remove(number)
    }

    public func testCreatePushSubscription(subscriptionId: String, token: String, enabled: Bool) {
        guard !OneSignalConfigManager.shouldAwaitAppIdAndLogMissingPrivacyConsent(forMethod: nil) else {
            return
        }
        user.testCreatePushSubscription(subscriptionId: subscriptionId, token: token, enabled: enabled)
    }
}

extension OneSignalUserManagerImpl: OSPushSubscription {

    public func addObserver(_ observer: OSPushSubscriptionObserver) -> OSPushSubscriptionState? {
        guard !OneSignalConfigManager.shouldAwaitAppIdAndLogMissingPrivacyConsent(forMethod: "addObserver") else {
            return nil
        }
        self.pushSubscriptionStateChangesObserver.addObserver(observer)
        return user.pushSubscriptionModel.currentPushSubscriptionState
    }

    public func removeObserver(_ observer: OSPushSubscriptionObserver) {
        self.pushSubscriptionStateChangesObserver.removeObserver(observer)
    }

    public var subscriptionId: String? {
        guard !OneSignalConfigManager.shouldAwaitAppIdAndLogMissingPrivacyConsent(forMethod: "subscriptionId") else {
            return nil
        }
        return user.pushSubscriptionModel.subscriptionId
    }

    public var token: String? {
        guard !OneSignalConfigManager.shouldAwaitAppIdAndLogMissingPrivacyConsent(forMethod: "token") else {
            return nil
        }
        return user.pushSubscriptionModel.address
    }

    /**
     Get the `enabled` state.
     */
    public var enabled: Bool {
        get {
            guard !OneSignalConfigManager.shouldAwaitAppIdAndLogMissingPrivacyConsent(forMethod: "enabled") else {
                return false
            }
            return user.pushSubscriptionModel.enabled
        }
    }

    /**
     Set the `enabled` state. After being set, we return whether this was successful, as one can attempt to set `enabled` to `true` but push is not actually enabled on the device. This can be due to system level permissions or missing push token, etc.
     
     - Returns: A boolean indicating if this method was successful.
     */
    public func enable(_ enable: Bool) -> Bool {
        guard !OneSignalConfigManager.shouldAwaitAppIdAndLogMissingPrivacyConsent(forMethod: "enable") else {
            return false
        }
        user.pushSubscriptionModel._isDisabled = !enable
        return user.pushSubscriptionModel.enabled != enable
    }
}

extension OneSignalUserManagerImpl: OneSignalNotificationsDelegate {
    // While we await app_id and privacy consent, these methods are a no-op
    // Once the UserManager is started in `init`, it calls these to set the state of the pushSubscriptionModel

    public func setNotificationTypes(_ notificationTypes: Int32) {
        guard !OneSignalConfigManager.shouldAwaitAppIdAndLogMissingPrivacyConsent(forMethod: nil) else {
            return
        }
        user.pushSubscriptionModel.notificationTypes = Int(notificationTypes)
    }

    public func setPushToken(_ pushToken: String) {
        guard !OneSignalConfigManager.shouldAwaitAppIdAndLogMissingPrivacyConsent(forMethod: nil) else {
            return
        }
        user.pushSubscriptionModel.address = pushToken
    }

    public func setAccepted(_ inAccepted: Bool) {
        guard !OneSignalConfigManager.shouldAwaitAppIdAndLogMissingPrivacyConsent(forMethod: nil) else {
            return
        }
        user.pushSubscriptionModel._accepted = inAccepted
    }
}
