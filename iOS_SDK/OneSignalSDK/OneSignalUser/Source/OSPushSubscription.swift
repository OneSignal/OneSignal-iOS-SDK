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

@objc public protocol OSPushSubscriptionObserver { //  weak reference?
    @objc func onOSPushSubscriptionChanged(previous: OSPushSubscriptionState, current: OSPushSubscriptionState)
}

@objc
public class OSPushSubscriptionState: NSObject {
    @objc public let token: UUID?
    @objc public let enabled: Bool
    
    init(token: UUID?, enabled: Bool) {
        self.token = token
        self.enabled = enabled
    }
}

protocol OSPushSubscriptionInterface {
    var id: UUID? { get }
    var token: UUID? { get }
    var enabled: Bool { get set }

    func addObserver(_ observer: OSPushSubscriptionObserver)
    func removeObserver(_ observer: OSPushSubscriptionObserver)
}

@objc
public class OSPushSubscription: NSObject, OSPushSubscriptionInterface {
    @objc public let id: UUID?
    @objc public let token: UUID?
    @objc public var enabled = true {
        didSet {
            didSetEnabledHelper(oldValue: oldValue, newValue: enabled)
        }
    }
    
    var subscriptionObservers: [OSPushSubscriptionObserver] = []

    func didSetEnabledHelper(oldValue: Bool, newValue: Bool) {
        // TODO: UM name and scope of function
        // TODO: UM update model, add operation to backend
        print("🔥 didSet pushSubscription.enabled from \(oldValue) to \(newValue)")
        let oldState = OSPushSubscriptionState(token: self.token, enabled: oldValue)
        let newState = OSPushSubscriptionState(token: self.token, enabled: newValue)
        for observer in subscriptionObservers {
            observer.onOSPushSubscriptionChanged(previous: oldState, current: newState)
        }
    }
    
    init(id: UUID, token: UUID) {
        self.id = id
        self.token = token
    }
    
    @objc public func addObserver(_ observer: OSPushSubscriptionObserver) {
        self.subscriptionObservers.append(observer) // TODO: UM we do want to synchronize on observers
        print("🔥 OSPushSubscription addObserver(), subscriptionObservers now: \(subscriptionObservers)")
    }
    
    @objc public func removeObserver(_ observer: OSPushSubscriptionObserver) {
        // TODO: UM we do want to synchronize on observers
        subscriptionObservers.removeAll(where: { $0 === observer })
        print("🔥 OSPushSubscription removeObserver(), subscriptionObservers now: \(subscriptionObservers)")
    }
}
