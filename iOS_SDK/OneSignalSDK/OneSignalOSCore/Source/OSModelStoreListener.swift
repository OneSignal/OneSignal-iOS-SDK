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
    // TODO: UM Operation Repo
    // var opRepo: OSOperationRepo {get}
    
    init(_ store: OSModelStore<TModel>)
    
    func getAddOperation(_ model: TModel) -> OSOperation?
    
    func getRemoveOperation(_ model: TModel) -> OSOperation?
    
    func getUpdateOperation(_ args: OSModelChangedArgs) -> OSOperation?
}

extension OSModelStoreListener {
    public func start() {
        store.changeSubscription.subscribe(self)
    }
    
    func close() {
        store.changeSubscription.unsubscribe(self)
    }

    public func added(_ model: OSModel) {
        print("🔥 OSModelStoreListener.added() with model \(model)")
        if let operation = getAddOperation(model as! Self.TModel) {
            // opRepo.enqueue(operation)
        }
    }

    public func updated(_ args: OSModelChangedArgs) {
        print("🔥 OSModelStoreListener.updated() with args \(args)")
        if let operation = getUpdateOperation(args) {
            // opRepo.enqueue(operation)
        }
    }
    
    public func removed(_ model: OSModel) {
        print("🔥 OSModelStoreListener.removed() with model \(model)")
        if let operation = getRemoveOperation(model as! Self.TModel) {
            // opRepo.enqueue(operation)
        }
    }
}
