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

open class OSModelStore<TModel: OSModel>: NSObject {
    let changeSubscription: OSEventProducer<OSModelStoreChangedHandler>
    var models: [String : TModel] = [:]
    
    public init(changeSubscription: OSEventProducer<OSModelStoreChangedHandler>) {
        self.changeSubscription = changeSubscription
    }
    
    public func add(id: String, model: TModel) {
        print("🔥 OSModelStore add with model \(model)")

        models[id] = model
        
        // TODO: Persist the new model to storage.
        // OneSignalUserDefaults.initStandard().saveCodeableData(forKey: model.id, withValue: model)
        
        // listen for changes to this model
        model.changeNotifier.subscribe(self)
        
        self.changeSubscription.fire { modelStoreListener in
            modelStoreListener.onAdded(model)
        }
    }
    
    func remove(_ id: String) {
        print("🔥 OSModelStore remove with model \(id)")
        if let model = models[id] {
            models.removeValue(forKey: id)

            // Remove the model from storage
            OneSignalUserDefaults.initShared().removeValue(forKey: model.id)
            
            // no longer listen for changes to this model
            model.changeNotifier.unsubscribe(self)
            
            self.changeSubscription.fire { modelStoreListener in
                modelStoreListener.onRemoved(model)
            }
        }
    }
}

extension OSModelStore: OSModelChangedHandler {
    public func onChanged(args: OSModelChangedArgs) {
        print("🔥 OSModelStore.onChanged() with args \(args)")
        
        // TODO: Persist the changed model to storage. TODO: Consider batching.
        // OneSignalUserDefaults.initStandard().saveCodeableData(forKey: args.model.id, withValue: args.model)

        self.changeSubscription.fire { modelStoreListener in
            modelStoreListener.onUpdated(args)
        }
    }
}

