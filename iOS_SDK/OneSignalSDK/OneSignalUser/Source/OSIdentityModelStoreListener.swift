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

// MARK: - Identity Operations

/**
 An OSUpdateIdentityOperation includes operations for adding, removing, and updating an alias.
 It may also include adding, removing, and updating an external_id.
 */
class OSUpdateIdentityOperation: OSOperation {
    // Operation Information
    let name = "OSUpdateIdentityOperation"
    let operationId = UUID()
    let timestamp = Date()

    // Model Information
    var model: OSModel = OSIdentityModel(id: "testtest", changeNotifier: OSEventProducer()) // TODO: Implement NSCoding for OSModel
    let property: String
    let value: Any?
    
    init(model: OSIdentityModel, property: String, value: Any?) {
        self.model = model
        self.property = property
        self.value = value
    }
    
    func encode(with coder: NSCoder) {
        //
    }
    
    required init?(coder: NSCoder) {
        // model = coder.decodeObject(forKey: "model") as! String
        property = coder.decodeObject(forKey: "property") as! String
        value = coder.decodeObject(forKey: "value")
    }
}

// MARK: - Model Store Listener

class OSIdentityModelStoreListener: OSModelStoreListener {
    var store: OSModelStore<OSIdentityModel>
    
    required init(store: OSModelStore<OSIdentityModel>) {
        self.store = store
    }
    
    func getAddOperation(_ model: OSIdentityModel) -> OSOperation? {
        return nil
    }
    
    func getRemoveOperation(_ model: OSIdentityModel) -> OSOperation? {
        return nil
    }
    
    func getUpdateOperation(_ args: OSModelChangedArgs) -> OSOperation? {
        return OSUpdateIdentityOperation(
            model: args.model as! OSIdentityModel,
            property: args.property,
            value: args.newValue
        )
    }
    
}
