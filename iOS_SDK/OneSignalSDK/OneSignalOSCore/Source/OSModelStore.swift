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
    let storeKey: String
    let changeSubscription: OSEventProducer<OSModelStoreChangedHandler>
    var models: [String: TModel]

    public init(changeSubscription: OSEventProducer<OSModelStoreChangedHandler>, storeKey: String) {
        self.storeKey = storeKey
        self.changeSubscription = changeSubscription

        // read models from cache, if any
        if let models = OneSignalUserDefaults.initShared().getSavedCodeableData(forKey: self.storeKey, defaultValue: [:]) as? [String: TModel] {
            self.models = models
        } else {
            // log error
            self.models = [:]
        }
        super.init()

        // register as user observer
        NotificationCenter.default.addObserver(self, selector: #selector(self.clearModelsFromCache),
                                               name: Notification.Name(OS_ON_USER_WILL_CHANGE), object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: Notification.Name(OS_ON_USER_WILL_CHANGE), object: nil)
    }

    public func getModels() -> [String: TModel] {
        return self.models
    }

    public func add(id: String, model: TModel) {
        print("🔥 OSModelStore add with model \(model)")
        // TODO: Check if we are adding the same model?
            // For example, calling addEmail multiple times with the same email
        models[id] = model

        // persist the models (including new model) to storage
        OneSignalUserDefaults.initShared().saveCodeableData(forKey: self.storeKey, withValue: self.models)

        // listen for changes to this model
        model.changeNotifier?.subscribe(self)

        self.changeSubscription.fire { modelStoreListener in
            modelStoreListener.onAdded(model)
        }
    }

    public func remove(_ id: String) {
        print("🔥 OSModelStore remove with model \(id)")
        // TODO: Nothing will happen if model doesn't exist in the store
            // Determine if that's correct behavior or if we should still create an Operation
        if let model = models[id] {
            models.removeValue(forKey: id)

            // persist the models (with removed model) to storage
            OneSignalUserDefaults.initShared().saveCodeableData(forKey: self.storeKey, withValue: self.models)

            // no longer listen for changes to this model
            model.changeNotifier?.unsubscribe(self)

            self.changeSubscription.fire { modelStoreListener in
                modelStoreListener.onRemoved(model)
            }
        }
    }

    @objc func clearModelsFromCache() {
        print("🔥 OSModelStore \(self.storeKey): clearModelsFromCache() called.")
        // Clear the models cache when ON_OS_USER_WILL_CHANGE
        OneSignalUserDefaults.initShared().removeValue(forKey: self.storeKey)
    }
}

extension OSModelStore: OSModelChangedHandler {
    public func onModelUpdated(args: OSModelChangedArgs, hydrating: Bool) {
        print("🔥 OSModelStore.onChanged() with args \(args)")

        // persist the changed models to storage
        OneSignalUserDefaults.initShared().saveCodeableData(forKey: self.storeKey, withValue: self.models)

        guard !hydrating else {
            return
        }
        self.changeSubscription.fire { modelStoreListener in
            modelStoreListener.onUpdated(args)
        }
    }
}
