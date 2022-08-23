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
import OneSignalOSCore

// MARK: - Property Operations

class OSUpdatePropertyDelta: OSDelta {
    // TODO: Best practice for overriding a stored property in subclass?
    init(model: OSModel, property: String, value: Any?) {
        super.init(name: "OSUpdatePropertyDelta", model: model, property: property, value: value)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}

// MARK: - Properties Model Store Listener

class OSPropertiesModelStoreListener: OSModelStoreListener {
    var store: OSModelStore<OSPropertiesModel>
 
    required init(store: OSModelStore<OSPropertiesModel>) {
        self.store = store
    }
    
    func getAddDelta(_ model: OSPropertiesModel) -> OSDelta? {
        return nil
    }
    
    func getRemoveDelta(_ model: OSPropertiesModel) -> OSDelta? {
        return nil
    }
    
    func getUpdateDelta(_ args: OSModelChangedArgs) -> OSDelta? {
        // TODO: Implementation
        return OSUpdatePropertyDelta(
            model: args.model as! OSPropertiesModel,
            property: args.property,
            value: args.newValue
        )
    }
}
