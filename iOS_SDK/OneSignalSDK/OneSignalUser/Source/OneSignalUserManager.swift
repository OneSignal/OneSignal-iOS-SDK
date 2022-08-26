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
@objc protocol OneSignalUserManagerInterface {
    static var user: OSUserInternal? { get set }
    static func login(_ externalId: String) -> OSUserInternal
    static func login(externalId: String, withToken: String) -> OSUserInternal
    static func loginGuest() -> OSUserInternal
}

@objc
public class OneSignalUserManager: NSObject, OneSignalUserManagerInterface {
    @objc public static var user: OSUserInternal?
    
    // has Identity and Properties Model Stores
    static var identityModelStore = OSModelStore<OSIdentityModel>(changeSubscription: OSEventProducer(), storeKey: "OS_IDENTITY_MODEL") // TODO: Don't hardcode
    static var propertiesModelStore = OSModelStore<OSPropertiesModel>(changeSubscription: OSEventProducer(), storeKey: "OS_PROPERTIES_MODEL") // TODO: Don't hardcode
    
    // TODO: UM, and Model Store Listeners: where do they live? Here for now.
    static var identityModelStoreListener = OSIdentityModelStoreListener(store: identityModelStore)
    static var propertiesModelStoreListener = OSPropertiesModelStoreListener(store: propertiesModelStore)
    
    // has Property and Identity operation executors
    static let propertyExecutor = OSPropertyOperationExecutor()
    static let identityExecutor = OSIdentityOperationExecutor()

    static func start() {
        // TODO: Finish implementation
        // Read from cache, set stuff up
        // Read the models from User Defaults
        
        // startModelStoreListenersAndExecutors() moves here after this start() method is hooked up.
        self.user = loadUserFromCache() // TODO: Revisit when to load user from the cache.
    }
    
    static func startModelStoreListenersAndExecutors() {
        // Model store listeners subscribe to their models. TODO: Where should these live?
        OneSignalUserManager.identityModelStoreListener.start()
        OneSignalUserManager.propertiesModelStoreListener.start()
        
        // Setup the executors
        OSOperationRepo.sharedInstance.addExecutor(identityExecutor)
        OSOperationRepo.sharedInstance.addExecutor(propertyExecutor)
    }
    
    @objc
    public static func login(_ externalId: String) -> OSUserInternal {
        print("🔥 OneSignalUserManager login() called")
        startModelStoreListenersAndExecutors()

        // Check if the existing user is the same one being logged in. If so, return.
        if let user = self.user {
            guard user.identityModel.externalId != externalId else {
                return user
            }
        }
        
        // 1. Attempt to retrieve user from backend?
        // 2. Attempt to retrieve user from cache or stores? (No, done in start() method for now)
        
        // 3. Create new user
        // TODO: Remove/take care of the old user's information.
        let identityModel = OSIdentityModel(id: externalId, changeNotifier: OSEventProducer()) // TODO: Change id?
        self.identityModelStore.add(id: externalId, model: identityModel)
        identityModel.externalId = externalId // TODO: Don't fire this change.

        let propertiesModel = OSPropertiesModel(id: externalId, changeNotifier: OSEventProducer()) // TODO: Change id?
        self.propertiesModelStore.add(id: externalId, model: propertiesModel)

        let pushSubscription = OSPushSubscriptionModel(token: nil, enabled: false)
        
        let user = createUser(identityModel: identityModel, propertiesModel: propertiesModel, pushSubscription: pushSubscription)
        self.user = user
        return user
    }
    
    @objc
    public static func login(externalId: String, withToken: String) -> OSUserInternal {
        print("🔥 OneSignalUser loginwithBearerToken() called")
        // validate the token
        return login(externalId)
    }
    
    @objc
    public static func loginGuest() -> OSUserInternal {
        print("🔥 OneSignalUserManager loginGuest() called")
        startModelStoreListenersAndExecutors()
        
        // TODO: Another user in cache? Remove old user's info?
        
        // TODO: model logic for guest users
        let identityModel = OSIdentityModel(id: UUID().uuidString, changeNotifier: OSEventProducer())
        let propertiesModel = OSPropertiesModel(id: identityModel.id, changeNotifier: OSEventProducer())
        let pushSubscription = OSPushSubscriptionModel(token: nil, enabled: false)
        
        let user = createUser(identityModel: identityModel, propertiesModel: propertiesModel, pushSubscription: pushSubscription)
        self.user = user
        return user
    }
    
    static func loadUserFromCache() -> OSUserInternal? {
        // Corrupted state if one exists without the other.
        guard !identityModelStore.getModels().isEmpty &&
                !propertiesModelStore.getModels().isEmpty // TODO: Check pushSubscriptionModel as well.
        else {
            return nil
        }
        
        // TODO: Need to load any SMS and emails subs too
        
        // There is a user in the cache
        let identityModel = identityModelStore.getModels().first!.value
        let propertiesModel = propertiesModelStore.getModels().first!.value
        let pushSubscription = OSPushSubscriptionModel(token: nil, enabled: false) // Modify to get from cache.

        let user = OSUserInternal(
            pushSubscription: pushSubscription,
            identityModel: identityModel,
            propertiesModel: propertiesModel)
        
        return user
    }
    
    static func createUser(identityModel: OSIdentityModel, propertiesModel: OSPropertiesModel, pushSubscription: OSPushSubscriptionModel) -> OSUserInternal {
        let user = OSUserInternal(
            pushSubscription: pushSubscription,
            identityModel: identityModel,
            propertiesModel: propertiesModel)
        return user
    }
}
