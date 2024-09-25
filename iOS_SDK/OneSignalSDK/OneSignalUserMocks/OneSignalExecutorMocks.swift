/*
 Modified MIT License
 
 Copyright 2024 OneSignal
 
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
import OneSignalCoreMocks
import OneSignalOSCoreMocks
@testable import OneSignalUser

@objc
open class OneSignalExecutorMocks: NSObject {
    public let client = MockOneSignalClient()
    public let newRecordsState = MockNewRecordsState()
    public let jwtConfig = OSUserJwtConfig()

    override public init() {
        super.init()
        OneSignalCoreImpl.setSharedClient(client)
    }

    @objc
    open func setAuthRequired(_ required: Bool) {
        // Set User Manager's JWT to off, or it blocks requests in prepareForExecution
        OneSignalUserManagerImpl.sharedInstance.jwtConfig.isRequired = required
        jwtConfig.isRequired = required
    }

    open func createUserInstance(externalId: String) -> OSUserInternal {
        let identityModel = OSIdentityModel(aliases: [OS_EXTERNAL_ID: externalId], changeNotifier: OSEventProducer())
        let propertiesModel = OSPropertiesModel(changeNotifier: OSEventProducer())
        let pushModel = OSSubscriptionModel(type: .push, address: "", subscriptionId: nil, reachable: false, isDisabled: false, changeNotifier: OSEventProducer())
        return OSUserInternalImpl(identityModel: identityModel, propertiesModel: propertiesModel, pushSubscriptionModel: pushModel)
    }

    open func setUserManagerInternalUser(externalId: String, onesignalId: String? = nil) -> OSUserInternal {
        let user = OneSignalUserManagerImpl.sharedInstance.setNewInternalUser(
            externalId: externalId,
            pushSubscriptionModel: OSSubscriptionModel(type: .push, address: "", subscriptionId: testPushSubId, reachable: false, isDisabled: false, changeNotifier: OSEventProducer()))
        if let onesignalId = onesignalId {
            // Setting the OSID directly avoids generating a Delta
            user.identityModel.aliases[OS_ONESIGNAL_ID] = onesignalId
        }
        return user
    }
}
