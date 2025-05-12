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

class OSSubscriptionModelStoreListener: OSModelStoreListener {
    var store: OSModelStore<OSSubscriptionModel>

    required init(store: OSModelStore<OSSubscriptionModel>) {
        self.store = store
    }

    func getAddModelDelta(_ model: OSSubscriptionModel) -> OSDelta? {
        guard let userInstance = OneSignalUserManagerImpl.sharedInstance._user else {
            OneSignalLog.onesignalLog(.LL_ERROR, message: "OSSubscriptionModelStoreListener.getAddModelDelta has no user instance")
            return nil
        }
        return OSDelta(
            name: OS_ADD_SUBSCRIPTION_DELTA,
            identityModelId: userInstance.identityModel.modelId,
            model: model,
            property: model.type.rawValue, // push, email, sms
            value: model.address ?? ""
        )
    }

    /**
     The `property` and `value` is not needed for a remove operation, so just pass in some model data as placeholders.
     */
    func getRemoveModelDelta(_ model: OSSubscriptionModel) -> OSDelta? {
        guard let userInstance = OneSignalUserManagerImpl.sharedInstance._user else {
            OneSignalLog.onesignalLog(.LL_ERROR, message: "OSSubscriptionModelStoreListener.getRemoveModelDelta has no user instance")
            return nil
        }
        return OSDelta(
            name: OS_REMOVE_SUBSCRIPTION_DELTA,
            identityModelId: userInstance.identityModel.modelId,
            model: model,
            property: model.type.rawValue, // push, email, sms
            value: model.address ?? ""
        )
    }

    func getUpdateModelDelta(_ args: OSModelChangedArgs) -> OSDelta? {
        // The OSIamFetchReadyCondition needs to know whether there is a subscription update pending
        // If so, we use this to await (in IAM-fetch) on its respective RYW token to be set. This is necessary
        // because we always make a user property update call but we DON'T always make a subscription update call.
        // The user update call increases the session_count while the subscription update would update
        // something like the app_version. If the app_version hasn't changed since the last session, there
        // wouldn't be an update needed (among other system-level properties).
        guard let userInstance = OneSignalUserManagerImpl.sharedInstance._user else {
            OneSignalLog.onesignalLog(.LL_ERROR, message: "OSSubscriptionModelStoreListener.getUpdateModelDelta has no user instance")
            return nil
        }
        if let onesignalId = userInstance.identityModel.onesignalId {
            let condition = OSIamFetchReadyCondition.sharedInstance(withId: onesignalId)
            condition.setSubscriptionUpdatePending(value: true)
        }

        return OSDelta(
            name: OS_UPDATE_SUBSCRIPTION_DELTA,
            identityModelId: userInstance.identityModel.modelId,
            model: args.model,
            property: args.property,
            value: args.newValue
        )
    }
}
