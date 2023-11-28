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
    func sendPurchases(_ purchases: [[String: AnyObject]])
}

/**
 This is the user interface exposed to the public.
 */
@objc public protocol OSUser {
    var pushSubscription: OSPushSubscription { get }
    var onesignalId: String? { get }
    var externalId: String? { get }
    // Aliases
    func addAlias(label: String, id: String)
    func addAliases(_ aliases: [String: String])
    func removeAlias(_ label: String)
    func removeAliases(_ labels: [String])
    // Tags
    func addTag(key: String, value: String)
    func addTags(_ tags: [String: String])
    func removeTag(_ tag: String)
    func removeTags(_ tags: [String])
    func getTags() -> [String: String]
    // Email
    func addEmail(_ email: String)
    func removeEmail(_ email: String)
    // SMS
    func addSms(_ number: String)
    func removeSms(_ number: String)
    // Language
    func setLanguage(_ language: String)
    // JWT Token Expire
    typealias OSJwtCompletionBlock = (_ newJwtToken: String) -> Void
    typealias OSJwtExpiredHandler =  (_ externalId: String, _ completion: OSJwtCompletionBlock) -> Void
    func onJwtExpired(expiredHandler: @escaping OSJwtExpiredHandler)
}

/**
 This is the push subscription interface exposed to the public.
 */
@objc public protocol OSPushSubscription {
    var id: String? { get }
    var token: String? { get }
    var optedIn: Bool { get }

    func optIn()
    func optOut()
    func addObserver(_ observer: OSPushSubscriptionObserver)
    func removeObserver(_ observer: OSPushSubscriptionObserver)
}

@objc
public class OneSignalUserManagerImpl: NSObject, OneSignalUserManager {
    @objc public static let sharedInstance = OneSignalUserManagerImpl()

    /**
     Convenience accessor. We access the push subscription model via the model store instead of via`user.pushSubscriptionModel`.
     If privacy consent is set in a wrong order, we may have sent requests, but hydrate on a mock user.
     However, we want to set tokens and subscription ID on the actual push subscription model.
     */
    var pushSubscriptionModel: OSSubscriptionModel? {
        return pushSubscriptionModelStore.getModel(key: OS_PUSH_SUBSCRIPTION_MODEL_KEY)
    }
    
    @objc public var pushSubscriptionId: String? {
        return _user?.pushSubscriptionModel.subscriptionId
    }

    @objc public var language: String? {
        return _user?.propertiesModel.language
    }
    
    @objc public let pushSubscriptionImpl: OSPushSubscriptionImpl

    private var hasCalledStart = false

    private var jwtExpiredHandler: OSJwtExpiredHandler?

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
        pushSubscriptionModel: OSSubscriptionModel(type: .push, address: nil, subscriptionId: nil, reachable: false, isDisabled: true, changeNotifier: OSEventProducer()))

    @objc public var requiresUserAuth = false

    // Model Stores
    let identityModelStore = OSModelStore<OSIdentityModel>(changeSubscription: OSEventProducer(), storeKey: OS_IDENTITY_MODEL_STORE_KEY).registerAsUserObserver()
    let propertiesModelStore = OSModelStore<OSPropertiesModel>(changeSubscription: OSEventProducer(), storeKey: OS_PROPERTIES_MODEL_STORE_KEY).registerAsUserObserver()
    // Holds email and sms subscription models
    let subscriptionModelStore = OSModelStore<OSSubscriptionModel>(changeSubscription: OSEventProducer(), storeKey: OS_SUBSCRIPTION_MODEL_STORE_KEY).registerAsUserObserver()
    // Holds a single push subscription model
    let pushSubscriptionModelStore = OSModelStore<OSSubscriptionModel>(changeSubscription: OSEventProducer(), storeKey: OS_PUSH_SUBSCRIPTION_MODEL_STORE_KEY)

    // These must be initialized in init()
    let identityModelStoreListener: OSIdentityModelStoreListener
    let propertiesModelStoreListener: OSPropertiesModelStoreListener
    let subscriptionModelStoreListener: OSSubscriptionModelStoreListener
    let pushSubscriptionModelStoreListener: OSSubscriptionModelStoreListener

    // Executors must be initialize after sharedInstance is initialized
    var propertyExecutor: OSPropertyOperationExecutor?
    var identityExecutor: OSIdentityOperationExecutor?
    var subscriptionExecutor: OSSubscriptionOperationExecutor?

    private override init() {
        self.identityModelStoreListener = OSIdentityModelStoreListener(store: identityModelStore)
        self.propertiesModelStoreListener = OSPropertiesModelStoreListener(store: propertiesModelStore)
        self.subscriptionModelStoreListener = OSSubscriptionModelStoreListener(store: subscriptionModelStore)
        self.pushSubscriptionModelStoreListener = OSSubscriptionModelStoreListener(store: pushSubscriptionModelStore)
        self.pushSubscriptionImpl = OSPushSubscriptionImpl(pushSubscriptionModelStore: pushSubscriptionModelStore)
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
        OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OneSignalUserManager calling start")

        OSNotificationsManager.delegate = self

        var hasCachedUser = false
        
        // Path 1. Load user from cache, if any
        // Corrupted state if any of these models exist without the others
        if let identityModel = identityModelStore.getModels()[OS_IDENTITY_MODEL_KEY],
           let propertiesModel = propertiesModelStore.getModels()[OS_PROPERTIES_MODEL_KEY],
           let pushSubscription = pushSubscriptionModelStore.getModels()[OS_PUSH_SUBSCRIPTION_MODEL_KEY] {
            hasCachedUser = true
            _user = OSUserInternalImpl(identityModel: identityModel, propertiesModel: propertiesModel, pushSubscriptionModel: pushSubscription)
            OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OneSignalUserManager.start called, loaded the user from cache.")
        }

        // TODO: Update the push sub model with any new state from NotificationsManager

        // Setup the executors
        OSUserExecutor.start()
        OSOperationRepo.sharedInstance.start()

        // Cannot initialize these executors in `init` as they reference the sharedInstance
        let propertyExecutor = OSPropertyOperationExecutor()
        let identityExecutor = OSIdentityOperationExecutor()
        let subscriptionExecutor = OSSubscriptionOperationExecutor()
        self.propertyExecutor = propertyExecutor
        self.identityExecutor = identityExecutor
        self.subscriptionExecutor = subscriptionExecutor
        OSOperationRepo.sharedInstance.addExecutor(identityExecutor)
        OSOperationRepo.sharedInstance.addExecutor(propertyExecutor)
        OSOperationRepo.sharedInstance.addExecutor(subscriptionExecutor)

        // Path 2. There is a legacy player to migrate
        if let legacyPlayerId = OneSignalUserDefaults.initShared().getSavedString(forKey: OSUD_LEGACY_PLAYER_ID, defaultValue: nil) {
            OneSignalLog.onesignalLog(.LL_DEBUG, message: "OneSignalUserManager: creating user linked to legacy subscription \(legacyPlayerId)")
            createUserFromLegacyPlayer(legacyPlayerId)
            OneSignalUserDefaults.initShared().saveString(forKey: OSUD_PUSH_SUBSCRIPTION_ID, withValue: legacyPlayerId)
            OneSignalUserDefaults.initStandard().removeValue(forKey: OSUD_LEGACY_PLAYER_ID)
            OneSignalUserDefaults.initShared().removeValue(forKey: OSUD_LEGACY_PLAYER_ID)
        } else {
            // Path 3. Creates an anonymous user if there isn't one in the cache nor a legacy player
            createUserIfNil()
        }

        // Model store listeners subscribe to their models
        identityModelStoreListener.start()
        propertiesModelStoreListener.start()
        subscriptionModelStoreListener.start()
        pushSubscriptionModelStoreListener.start()
        if hasCachedUser {
            _user?.pushSubscriptionModel.update()
        }
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
        OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OneSignal.User login called with externalId: \(externalId)")
        _ = _login(externalId: externalId, token: token)
    }

    /**
     Converting a 3.x player to a 5.x user. There is a cached legacy player, so we will create the user based on the legacy player ID.
     */
    private func createUserFromLegacyPlayer(_ playerId: String) {
        // 1. Create the Push Subscription Model
        let pushSubscriptionModel = createDefaultPushSubscription(subscriptionId: playerId)
        
        // 2. Set the internal user
        let newUser = setNewInternalUser(externalId: nil, pushSubscriptionModel: pushSubscriptionModel)

        // 3. Make the request
        OSUserExecutor.fetchIdentityBySubscription(newUser)
    }
    
    private func createNewUser(externalId: String?, token: String?) -> OSUserInternal {
        guard !OneSignalConfigManager.shouldAwaitAppIdAndLogMissingPrivacyConsent(forMethod: nil) else {
            return _mockUser
        }

        // Check if the existing user is the same one being logged in. If so, return.
        if let user = _user {
            guard user.identityModel.externalId != externalId || externalId == nil else {
                OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OneSignalUserManager.createNewUser: not creating new user due to logging into the same user.)")
                return user
            }
        }

        let pushSubscriptionModel = pushSubscriptionModelStore.getModel(key: OS_PUSH_SUBSCRIPTION_MODEL_KEY)

        // prepareForNewUser may be already called by logout, so we don't want to call it again. Also, there should be no need to call this method if there is no user.
        if _user != nil {
            prepareForNewUser()
        }

        let newUser = setNewInternalUser(externalId: externalId, pushSubscriptionModel: pushSubscriptionModel)
        newUser.identityModel.jwtBearerToken = token
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
        let pushSubscriptionModel = pushSubscriptionModelStore.getModel(key: OS_PUSH_SUBSCRIPTION_MODEL_KEY)
        prepareForNewUser()
        let newUser = setNewInternalUser(externalId: externalId, pushSubscriptionModel: pushSubscriptionModel)

        // Now proceed to identify the previous user
        OSUserExecutor.identifyUser(
            externalId: externalId,
            identityModelToIdentify: identityModelToIdentify,
            identityModelToUpdate: newUser.identityModel
        )
    }

    /**
     Returns if the OSIdentityModel passed in belongs to the current user. This method is used in deciding whether or not to hydrate via a server response, for example.
     */
    func isCurrentUser(_ identityModel: OSIdentityModel) -> Bool {
        return self.identityModelStore.getModel(modelId: identityModel.modelId) != nil
    }
    
    /**
     Clears the existing user's data in preparation for hydration via a fetch user call.
     */
    func clearUserData() {
        // Identity and property models should still be the same instances, but with data cleared
        _user?.identityModel.clearData()
        _user?.propertiesModel.clearData()

        // Subscription model store should be cleared completely
        OneSignalUserManagerImpl.sharedInstance.subscriptionModelStore.clearModelsFromStore()
    }

    private func _login(externalId: String?, token: String?) -> OSUserInternal {
        guard !OneSignalConfigManager.shouldAwaitAppIdAndLogMissingPrivacyConsent(forMethod: nil) else {
            return _mockUser
        }
        OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OneSignalUserManager internal _login called with externalId: \(externalId ?? "nil")")

        // If have token, validate token. Account for this being a requirement.
        // Logging into an identified user from an anonymous user
        if let externalId = externalId,
           let user = _user,
           user.isAnonymous {
            user.identityModel.jwtBearerToken = token
            identifyUser(externalId: externalId, currentUser: user)
            return self.user
        }

        // Logging into anon -> anon, identified -> anon, identified -> identified, or nil -> any user
        return createNewUser(externalId: externalId, token: token)
    }

    /**
     The SDK needs to have a user at all times, so this method will create a new anonymous user. If the current user is already anonymous, calling `logout` results in a no-op.
     */
    @objc
    public func logout() {
        guard user.identityModel.externalId != nil else {
            OneSignalLog.onesignalLog(.LL_DEBUG, message: "OneSignal.User logout called, but the user is currently anonymous, so not logging out.")
            return
        }
        _logout()
    }

    public func _logout() {
        prepareForNewUser()
        _user = nil
        createUserIfNil()
    }

    @objc
    public func clearAllModelsFromStores() {
        prepareForNewUser()
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
        OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OneSignalUserManagerImpl prepareForNewUser called")
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
        self.identityModelStore.add(id: OS_IDENTITY_MODEL_KEY, model: identityModel, hydrating: false)

        let propertiesModel = OSPropertiesModel(changeNotifier: OSEventProducer())
        self.propertiesModelStore.add(id: OS_PROPERTIES_MODEL_KEY, model: propertiesModel, hydrating: false)

        // TODO: We will have to save subscription_id and push_token to user defaults when we get them

        let pushSubscription = pushSubscriptionModel ?? createDefaultPushSubscription(subscriptionId: nil)

        // Add pushSubscription to store if not present
        if !pushSubscriptionModelStore.getModels().keys.contains(OS_PUSH_SUBSCRIPTION_MODEL_KEY) {
            pushSubscriptionModelStore.add(id: OS_PUSH_SUBSCRIPTION_MODEL_KEY, model: pushSubscription, hydrating: false)
        }

        _user = OSUserInternalImpl(identityModel: identityModel, propertiesModel: propertiesModel, pushSubscriptionModel: pushSubscription)
        return self.user
    }

    /**
     Creates a default Push Subscription Model using the optionally passed in subscriptionId. An scenario where the subscriptionId will be passed in is when we are converting a legacy player's information from 3.x  into a Push Subscription Model.
     */
    func createDefaultPushSubscription(subscriptionId: String?) -> OSSubscriptionModel {
        let sharedUserDefaults = OneSignalUserDefaults.initShared()
        let reachable = OSNotificationsManager.currentPermissionState.reachable
        let token = sharedUserDefaults.getSavedString(forKey: OSUD_PUSH_TOKEN, defaultValue: nil)
        let subscriptionId = subscriptionId ?? sharedUserDefaults.getSavedString(forKey: OSUD_PUSH_SUBSCRIPTION_ID, defaultValue: nil)

        return OSSubscriptionModel(type: .push,
                                   address: token,
                                   subscriptionId: subscriptionId,
                                   reachable: reachable,
                                   isDisabled: false,
                                   changeNotifier: OSEventProducer())
    }

    func createPushSubscriptionRequest() {
        // subscriptionExecutor should exist as this should be called after `start()` has been called
        if let subscriptionExecutor = self.subscriptionExecutor,
        let subscriptionModel = pushSubscriptionModel
        {
            subscriptionExecutor.createPushSubscription(subscriptionModel: subscriptionModel, identityModel: user.identityModel)
        } else {
            OneSignalLog.onesignalLog(.LL_ERROR, message: "OneSignalUserManagerImpl.createPushSubscriptionRequest cannot be executed due to missing subscriptionExecutor.")
        }
    }
    
    @objc
    public func getTagsInternal() -> [String: String]? {
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
    public func sendPurchases(_ purchases: [[String: AnyObject]]) {
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

        // propertyExecutor should exist as this should be called after `start()` has been called
        if let propertyExecutor = self.propertyExecutor {
            propertyExecutor.updateProperties(
                propertiesDeltas: propertiesDeltas,
                refreshDeviceMetadata: false,
                propertiesModel: propertiesModel,
                identityModel: identityModel
            )
        } else {
            OneSignalLog.onesignalLog(.LL_ERROR, message: "OneSignalUserManagerImpl.sendPurchases with purchases: \(purchases) cannot be executed due to missing property executor.")
        }
    }

    private func fireJwtExpired() {
        guard let externalId = user.identityModel.externalId, let jwtExpiredHandler = self.jwtExpiredHandler else {
            return
        }
        jwtExpiredHandler(externalId) { [self] (newToken) -> Void in
            guard user.identityModel.externalId == externalId else {
                return
            }
            user.identityModel.jwtBearerToken = newToken
        }
    }
}

// MARK: - Sessions

extension OneSignalUserManagerImpl {
    @objc
    public func startNewSession() {
        OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OneSignalUserManagerImpl starting new session")
        guard !OneSignalConfigManager.shouldAwaitAppIdAndLogMissingPrivacyConsent(forMethod: nil) else {
            return
        }
        start()
        
        OSUserExecutor.executePendingRequests()
        OSOperationRepo.sharedInstance.paused = false
        updateSession(sessionCount: 1, sessionTime: nil, refreshDeviceMetadata: true)

        // Fetch the user's data if there is a onesignal_id
        // TODO: What if onesignal_id is missing, because we may init a user from cache but it may be missing onesignal_id. Is this ok.
        if let onesignalId = onesignalId {
            OSUserExecutor.fetchUser(aliasLabel: OS_ONESIGNAL_ID, aliasId: onesignalId, identityModel: user.identityModel, onNewSession: true)
        }
    }

    @objc
    public func updateSession(sessionCount: NSNumber?, sessionTime: NSNumber?, refreshDeviceMetadata: Bool, sendImmediately: Bool = false, onSuccess: (() -> Void)? = nil, onFailure: (() -> Void)? = nil) {
        guard !OneSignalConfigManager.shouldAwaitAppIdAndLogMissingPrivacyConsent(forMethod: nil) else {
            if let onFailure = onFailure {
                onFailure()
            }
            return
        }

        // Get the identity and properties model of the current user
        let identityModel = user.identityModel
        let propertiesModel = user.propertiesModel
        let propertiesDeltas = OSPropertiesDeltas(sessionTime: sessionTime, sessionCount: sessionCount, amountSpent: nil, purchases: nil)

        // propertyExecutor should exist as this should be called after `start()` has been called
        if let propertyExecutor = self.propertyExecutor {
            propertyExecutor.updateProperties(
                propertiesDeltas: propertiesDeltas,
                refreshDeviceMetadata: refreshDeviceMetadata,
                propertiesModel: propertiesModel,
                identityModel: identityModel,
                sendImmediately: sendImmediately,
                onSuccess: onSuccess,
                onFailure: onFailure
            )
        } else {
            OneSignalLog.onesignalLog(.LL_ERROR, message: "OneSignalUserManagerImpl.updateSession with sessionCount: \(String(describing: sessionCount)) sessionTime: \(String(describing: sessionTime)) cannot be executed due to missing property executor.")
            if let onFailure = onFailure {
                onFailure()
            }
        }
    }

    /**
     App has been backgrounded. Run background tasks such to flush  the operation repo and hydrating models.
     Need to consider app killed vs app backgrounded and handle gracefully.
     */
    @objc
    public func runBackgroundTasks() {
        OSOperationRepo.sharedInstance.flushDeltaQueue(inBackground: true)
    }
}

extension OneSignalUserManagerImpl: OSUser {
    public func onJwtExpired(expiredHandler: @escaping OSJwtExpiredHandler) {
        jwtExpiredHandler = expiredHandler
    }

    public var User: OSUser {
        start()
        return self
    }

    public var pushSubscription: OSPushSubscription {
        start()
        return pushSubscriptionImpl
    }
    
    public var externalId: String? {
        guard !OneSignalConfigManager.shouldAwaitAppIdAndLogMissingPrivacyConsent(forMethod: "externalId") else {
            return nil
        }
        return _user?.identityModel.externalId
    }
    
    public var onesignalId: String? {
        guard !OneSignalConfigManager.shouldAwaitAppIdAndLogMissingPrivacyConsent(forMethod: "onesignalId") else {
            return nil
        }
        return _user?.identityModel.onesignalId
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

    public func addTag(key: String, value: String) {
        guard !OneSignalConfigManager.shouldAwaitAppIdAndLogMissingPrivacyConsent(forMethod: "addTag") else {
            return
        }
        user.addTags([key: value])
    }

    public func addTags(_ tags: [String: String]) {
        guard !OneSignalConfigManager.shouldAwaitAppIdAndLogMissingPrivacyConsent(forMethod: "addTags") else {
            return
        }
        user.addTags(tags)
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

    public func getTags() -> [String: String] {
        guard !OneSignalConfigManager.shouldAwaitAppIdAndLogMissingPrivacyConsent(forMethod: "getTags") else {
            return [:]
        }
        return user.propertiesModel.tags
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
            reachable: true,
            isDisabled: false,
            changeNotifier: OSEventProducer()
        )
        self.subscriptionModelStore.add(id: email, model: model, hydrating: false)
    }

    /**
     If this email doesn't already exist on the user, it cannot be removed.
     This will be a no-op and no request will be made.
     Error handling needs to be implemented in the future.
     */
    public func removeEmail(_ email: String) {
        guard !OneSignalConfigManager.shouldAwaitAppIdAndLogMissingPrivacyConsent(forMethod: "removeEmail") else {
            return
        }
        // Check if is valid email?
        createUserIfNil()
        self.subscriptionModelStore.remove(email)
    }

    public func addSms(_ number: String) {
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
            reachable: true,
            isDisabled: false,
            changeNotifier: OSEventProducer()
        )
        self.subscriptionModelStore.add(id: number, model: model, hydrating: false)
    }

    /**
     If this email doesn't already exist on the user, it cannot be removed.
     This will be a no-op and no request will be made.
     Error handling needs to be implemented in the future.
     */
    public func removeSms(_ number: String) {
        guard !OneSignalConfigManager.shouldAwaitAppIdAndLogMissingPrivacyConsent(forMethod: "removeSmsNumber") else {
            return
        }
        // Check if is valid SMS?
        createUserIfNil()
        self.subscriptionModelStore.remove(number)
    }

    public func setLanguage(_ language: String) {
        guard !OneSignalConfigManager.shouldAwaitAppIdAndLogMissingPrivacyConsent(forMethod: "setLanguage") else {
            return
        }

        if language == "" {
            OneSignalLog.onesignalLog(.LL_ERROR, message: "OneSignal.User.setLanguage cannot be called with an empty language code.")
            return
        }

        user.setLanguage(language)
    }
}

extension OneSignalUserManagerImpl {
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
            // This is a method in the User namespace that doesn't require privacy consent first
            self.pushSubscriptionStateChangesObserver.addObserver(observer)
        }
        
        public func removeObserver(_ observer: OSPushSubscriptionObserver) {
            self.pushSubscriptionStateChangesObserver.removeObserver(observer)
        }

        public var id: String? {
            guard !OneSignalConfigManager.shouldAwaitAppIdAndLogMissingPrivacyConsent(forMethod: "pushSubscription.id") else {
                return nil
            }
            return pushSubscriptionModelStore.getModel(key: OS_PUSH_SUBSCRIPTION_MODEL_KEY)?.subscriptionId
        }

        public var token: String? {
            guard !OneSignalConfigManager.shouldAwaitAppIdAndLogMissingPrivacyConsent(forMethod: "pushSubscription.token") else {
                return nil
            }
            return pushSubscriptionModelStore.getModel(key: OS_PUSH_SUBSCRIPTION_MODEL_KEY)?.address
        }

        public var optedIn: Bool {
            guard !OneSignalConfigManager.shouldAwaitAppIdAndLogMissingPrivacyConsent(forMethod: "pushSubscription.optedIn") else {
                return false
            }
            return pushSubscriptionModelStore.getModel(key: OS_PUSH_SUBSCRIPTION_MODEL_KEY)?.optedIn ?? false
        }
        
        /**
         Enable the push subscription, and prompts if needed. `optedIn` can still be `false` after `optIn()` is called if permission is not granted.
         */
        public func optIn() {
            guard !OneSignalConfigManager.shouldAwaitAppIdAndLogMissingPrivacyConsent(forMethod: "pushSubscription.optIn") else {
                return
            }
            pushSubscriptionModelStore.getModel(key: OS_PUSH_SUBSCRIPTION_MODEL_KEY)?._isDisabled = false
            OSNotificationsManager.requestPermission(nil, fallbackToSettings: true)
        }

        public func optOut() {
            guard !OneSignalConfigManager.shouldAwaitAppIdAndLogMissingPrivacyConsent(forMethod: "pushSubscription.optOut") else {
                return
            }
            pushSubscriptionModelStore.getModel(key: OS_PUSH_SUBSCRIPTION_MODEL_KEY)?._isDisabled = true
        }
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
}
