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

public protocol OSModelStoreListener: OSModelStoreChangedHandler {
    associatedtype TModel: OSModel
    
    var store: OSModelStore<TModel> { get }
    
    init(store: OSModelStore<TModel>)
    
    func getAddModelDelta(_ model: TModel) -> OSDelta?
    
    func getRemoveModelDelta(_ model: TModel) -> OSDelta?
    
    func getUpdateModelDelta(_ args: OSModelChangedArgs) -> OSDelta?
}

extension OSModelStoreListener {
    public func start() {
        store.changeSubscription.subscribe(self)
    }
    
    func close() {
        store.changeSubscription.unsubscribe(self)
    }

    public func onAdded(_ model: OSModel) {
        print("🔥 OSModelStoreListener.onAdded() with model \(model)")
        if let delta = getAddModelDelta(model as! Self.TModel) {
            OSOperationRepo.sharedInstance.enqueueDelta(delta)
        }
    }

    public func onUpdated(_ args: OSModelChangedArgs) {
        print("🔥 OSModelStoreListener.onUpdated() with args \(args)")
        if let delta = getUpdateModelDelta(args) {
            OSOperationRepo.sharedInstance.enqueueDelta(delta)
        }
    }
    
    public func onRemoved(_ model: OSModel) {
        print("🔥 OSModelStoreListener.onRemoved() with model \(model)")
        if let delta = getRemoveModelDelta(model as! Self.TModel) {
            OSOperationRepo.sharedInstance.enqueueDelta(delta)
        }
    }
}
