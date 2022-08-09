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

public class OSEventProducer<THandler>: NSObject {
    
    var subscribers: [THandler] = []
    
    public func subscribe(_ handler: THandler) {
        print("🔥 OSEventProducer.subscribe() called with handler: \(handler)")
        // TODO: UM do we want to synchronize on subscribers
        subscribers.append(handler) // TODO: UM style, implicit or explicit self?
    }

    public func unsubscribe(_ handler: THandler) {
        print("🔥 OSEventProducer.unsubscribe() called with handler: \(handler)")

        // TODO: UM do we want to synchronize on subscribers
        // subscribers.removeAll(where: { $0 === handler})
    }

    public func fire(callback: (THandler) -> Void) {
        print("🔥 OSEventProducer.fire() called with the following subscribers:")
        dump(subscribers)
        for subscriber in subscribers {
            callback(subscriber)
        }
    }
}
