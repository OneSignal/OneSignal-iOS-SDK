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

class OSUpdatePropertyOperation: OSOperation {
    
    let name = "OSUpdatePropertyOperation"
    // TODO: Extract this out to the protocol have these same properties:
    var operationId = UUID()
    let timestamp = Date()
    
    var model: OSModel = OSPropertiesModel(id: "testtest", changeNotifier: OSEventProducer()) // TODO: Implement NSCoding for OSModel

    let modelId: String
    let property: String
    let value: Any?
    
    func encode(with coder: NSCoder) {
        coder.encode(name, forKey: "name")
        coder.encode(operationId, forKey: "operationId")
        coder.encode(timestamp, forKey: "timestamp")
        coder.encode(modelId, forKey: "modelId")
        coder.encode(property, forKey: "property")
        coder.encode(value, forKey: "value")
        // TODO: Encode the model
    }
    
    required init?(coder: NSCoder) {
        modelId = coder.decodeObject(forKey: "modelId") as! String
        property = coder.decodeObject(forKey: "property") as! String
        value = coder.decodeObject(forKey: "value")
        // ...
    }
    
    init(model: OSPropertiesModel, property: String, value: Any?) {
        self.model = model
        self.modelId = model.id
        self.property = property
        self.value = value
    }
}

// MARK: - Model Store Listener

class OSPropertiesModelStoreListener: OSModelStoreListener {
    var store: OSModelStore<OSPropertiesModel>
 
    required init(store: OSModelStore<OSPropertiesModel>) {
        self.store = store
    }
    
    func getAddOperation(_ model: OSPropertiesModel) -> OSOperation? {
        return nil
    }
    
    func getRemoveOperation(_ model: OSPropertiesModel) -> OSOperation? {
        return nil
    }
    
    func getUpdateOperation(_ args: OSModelChangedArgs) -> OSOperation? {
        // TODO: Implementation
        return OSUpdatePropertyOperation(
            model: args.model as! OSPropertiesModel,
            property: args.property,
            value: args.newValue
        )
    }
    
}
