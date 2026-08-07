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

public class OSEventProducer<THandler>: NSObject {
    private var subscribers: [String: THandler] = [:]
    private let lock = NSLock()

    /// Subscribing under a key another observer already holds replaces it, so each observer of a
    /// producer needs a key of its own or it will silently displace the other.
    public func subscribe(_ handler: THandler, key: String) {
        lock.withLock {
            subscribers[key] = handler
        }
    }

    public func unsubscribe(_ handler: THandler, key: String) {
        OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OSEventProducer.unsubscribe() called with handler: \(handler)")
        lock.withLock {
            subscribers.removeValue(forKey: key)
        }
    }

    /// Callbacks run outside the lock, so a handler is free to subscribe, unsubscribe, or fire
    /// again; the trade is that it sees the subscriber set as of the start of this fire.
    public func fire(callback: (THandler) -> Void) {
        let handlers = lock.withLock { Array(subscribers.values) }
        for handler in handlers {
            callback(handler)
        }
    }
}
