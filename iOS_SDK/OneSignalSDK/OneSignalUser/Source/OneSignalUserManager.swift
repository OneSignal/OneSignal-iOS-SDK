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
    static var identityModelStore = OSModelStore<OSIdentityModel>(changeSubscription: OSEventProducer())
    static var propertiesModelStore = OSModelStore<OSPropertiesModel>(changeSubscription: OSEventProducer())
    
    // TODO: UM, and Model Store Listeners: where do they live? Here for now.
    static var identityModelStoreListener = OSIdentityModelStoreListener(identityModelStore)
    static var propertiesModelStoreListener = OSPropertiesModelStoreListener(propertiesModelStore)
    
    static func startModelStoreListeners() {
        // Model store listeners subscribe to their models
        // Where should these live?
        OneSignalUserManager.identityModelStoreListener.start()
        OneSignalUserManager.propertiesModelStoreListener.start()
    }

    @objc
    public static func login(_ externalId: String) -> OSUserInternal {
        print("🔥 OneSignalUserManager login() called")
        startModelStoreListeners()
        var identityModel: OSIdentityModel?
        var propertiesModel: OSPropertiesModel?
        
        // 1. Attempt to retrieve user from backend?
        // 2. Attempt to retrieve user from cache or stores?
        
        // 3. Create new user
        identityModel = OSIdentityModel(id: externalId, changeNotifier: OSEventProducer())
        self.identityModelStore.add(id: externalId, model: identityModel!)
        identityModel!.externalId = externalId

        propertiesModel = OSPropertiesModel(id: externalId, changeNotifier: OSEventProducer())
        self.propertiesModelStore.add(id: externalId, model: propertiesModel!)
        propertiesModel!.id = identityModel!.id

        return createAndSetUser(identityModel: identityModel!, propertiesModel: propertiesModel!)
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
        startModelStoreListeners()
        
        // TODO: model logic for guest users
        let identityModel = OSIdentityModel(id: UUID().uuidString, changeNotifier: OSEventProducer())
        let propertiesModel = OSPropertiesModel(id: identityModel.id, changeNotifier: OSEventProducer())

        return createAndSetUser(identityModel: identityModel, propertiesModel: propertiesModel)
    }
    
    static func createAndSetUser(identityModel: OSIdentityModel, propertiesModel: OSPropertiesModel) -> OSUserInternal {
        // do stuff
        self.user = OSUserInternal(
            onesignalId: UUID(),
            pushSubscription: OSPushSubscriptionModel(subscriptionId: UUID(), token: nil, enabled: false),
            identityModel: identityModel,
            propertiesModel: propertiesModel)
        
        return self.user!
    }
}
