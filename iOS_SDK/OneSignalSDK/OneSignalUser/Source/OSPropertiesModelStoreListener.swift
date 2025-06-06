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

class OSPropertiesModelStoreListener: OSModelStoreListener {
    var store: OSModelStore<OSPropertiesModel>

    required init(store: OSModelStore<OSPropertiesModel>) {
        self.store = store
    }

    func getAddModelDelta(_ model: OSPropertiesModel) -> OSDelta? {
        return nil
    }

    func getRemoveModelDelta(_ model: OSPropertiesModel) -> OSDelta? {
        return nil
    }

    func getUpdateModelDelta(_ args: OSModelChangedArgs) -> OSDelta? {
        guard let _ = OSPropertiesSupportedProperty(rawValue: args.property),
              let userInstance = OneSignalUserManagerImpl.sharedInstance._user
        else {
            OneSignalLog.onesignalLog(.LL_ERROR, message: "OSPropertiesModelStoreListener.getUpdateModelDelta encountered unsupported property: \(args.property) or no user instance")
            return nil
        }
        return OSDelta(
            name: OS_UPDATE_PROPERTIES_DELTA,
            identityModelId: userInstance.identityModel.modelId,
            model: args.model,
            property: args.property,
            value: args.newValue
        )
    }
}
