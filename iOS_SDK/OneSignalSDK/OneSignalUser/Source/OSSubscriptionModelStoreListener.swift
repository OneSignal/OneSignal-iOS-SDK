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
        return OSDelta(
            name: OS_ADD_SUBSCRIPTION_DELTA,
            model: model,
            property: model.type.rawValue, // push, email, sms
            value: model.address
        )
    }

    func getRemoveModelDelta(_ model: OSSubscriptionModel) -> OSDelta? {
        return OSDelta(
            name: OS_REMOVE_SUBSCRIPTION_DELTA,
            model: model,
            property: model.type.rawValue, // push, email, sms
            value: model.address
        )
    }

    func getUpdateModelDelta(_ args: OSModelChangedArgs) -> OSDelta? {
        return nil
    }
}
