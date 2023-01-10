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

        // listen for changes to the models
        for model in self.models.values {
            model.changeNotifier.subscribe(self)
        }
    }

    public func registerAsUserObserver() -> OSModelStore {
        // This method was taken out of the initializer as the push subscription model store should not be clearing its user defaults
        NotificationCenter.default.addObserver(self, selector: #selector(self.removeModelsFromUserDefaults),
                                               name: Notification.Name(OS_ON_USER_WILL_CHANGE), object: nil)
        return self
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: Notification.Name(OS_ON_USER_WILL_CHANGE), object: nil)
    }

    /**
     Uses the ID that is used as the key to store models in the store's models dictionary.
     Examples:  "person@example.com" for a subscription model or `OS_IDENTITY_MODEL_KEY` for an identity model.
     */
    public func getModel(key: String) -> TModel? {
        return self.models[key]
    }

    /**
     Uses the `modelId` to get the corresponding model in the store's models dictionary.
     */
    public func getModel(modelId: String) -> TModel? {
        for model in models.values {
            if model.modelId == modelId {
                return model
            }
        }
        return nil
    }

    public func getModels() -> [String: TModel] {
        return self.models
    }

    public func add(id: String, model: TModel, hydrating: Bool) {
        OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OSModelStore add() called with model \(model)")
        // TODO: Check if we are adding the same model? Do we replace?
            // For example, calling addEmail multiple times with the same email
            // Check API endpoint for behavior
        models[id] = model

        // persist the models (including new model) to storage
        OneSignalUserDefaults.initShared().saveCodeableData(forKey: self.storeKey, withValue: self.models)

        // listen for changes to this model
        model.changeNotifier.subscribe(self)

        guard !hydrating else {
            return
        }

        self.changeSubscription.fire { modelStoreListener in
            modelStoreListener.onAdded(model)
        }
    }

    /**
     Returns false if this model does not exist in the store.
     This can happen if remove email or SMS is called and it doesn't exist in the store.
     */
    public func remove(_ id: String) -> Bool {
        OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OSModelStore remove() called with model \(id)")
        // TODO: Nothing will happen if model doesn't exist in the store
        if let model = models[id] {
            models.removeValue(forKey: id)

            // persist the models (with removed model) to storage
            OneSignalUserDefaults.initShared().saveCodeableData(forKey: self.storeKey, withValue: self.models)

            // no longer listen for changes to this model
            model.changeNotifier.unsubscribe(self)

            self.changeSubscription.fire { modelStoreListener in
                modelStoreListener.onRemoved(model)
            }
            return true
        }
        return false
    }

    /**
     We remove this store's models from UserDefaults but not from the store itself.
     We may still need references to model(s) in this store!
     */
    @objc func removeModelsFromUserDefaults() {
        // Clear the UserDefaults models cache when OS_ON_USER_WILL_CHANGEclearModelsFromStore() called
        OneSignalUserDefaults.initShared().removeValue(forKey: self.storeKey)
    }

    /**
     We clear this store's models but not from the UserDefaults cache.
     When the User changes, the Subscription Model Store must remove all models.
     In contrast, it is not necessary for the Identity or Properties Model Stores to do so.
     */
    public func clearModelsFromStore() {
        self.models = [:]
    }
}

extension OSModelStore: OSModelChangedHandler {
    public func onModelUpdated(args: OSModelChangedArgs, hydrating: Bool) {
        OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OSModelStore.onChanged() called with OSModelChangedArgs: \(args)")

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
