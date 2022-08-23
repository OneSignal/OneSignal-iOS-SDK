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
    let name = "OSUpdatePropertyDelta"
    let deltaId: UUID
    let timestamp: Date
    let model: OSModel
    let property: String
    let value: Any?
    
    // TODO: Extract these same init()'s across OSOperations to a superclass:
    init(model: OSPropertiesModel, property: String, value: Any?) {
        self.deltaId = UUID()
        self.timestamp = Date()
        self.model = model
        self.property = property
        self.value = value
    }
    
    func encode(with coder: NSCoder) {
        coder.encode(deltaId, forKey: "operationId")
        coder.encode(timestamp, forKey: "timestamp")
        coder.encode(model, forKey: "model")
        coder.encode(property, forKey: "property")
        coder.encode(value, forKey: "value")
    }
    
    required init?(coder: NSCoder) {
        deltaId = coder.decodeObject(forKey: "operationId") as! UUID
        timestamp = coder.decodeObject(forKey: "timestamp") as! Date
        model = coder.decodeObject(forKey: "model") as! OSModel
        property = coder.decodeObject(forKey: "property") as! String
        value = coder.decodeObject(forKey: "value")
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
