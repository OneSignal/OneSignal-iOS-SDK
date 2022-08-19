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
import OneSignalOSCore

@objc public protocol OSPushSubscriptionObserver { //  weak reference?
    @objc func onOSPushSubscriptionChanged(previous: OSPushSubscriptionState, current: OSPushSubscriptionState)
}

@objc
public class OSPushSubscriptionState: NSObject {
    @objc public let subscriptionId: UUID
    @objc public let token: UUID?
    @objc public let enabled: Bool

    init(subscriptionId: UUID, token: UUID?, enabled: Bool) {
        self.subscriptionId = subscriptionId
        self.token = token
        self.enabled = enabled
    }
}

/**
 This is the push subscription interface exposed to the public.
 */
@objc public protocol OSPushSubscriptionInterface {
    var subscriptionId: UUID { get }
    var token: UUID? { get }
    var enabled: Bool { get set }
}

/**
 Internal push subscription model that implements the public-facing OSUser protocol.
 */
class OSPushSubscriptionModel: OSModel, OSPushSubscriptionInterface {
    @objc public let subscriptionId: UUID
    @objc public private(set) var token: UUID?
    @objc public var enabled = false { // this should default to false when first created
        didSet {
            didSetEnabledHelper(oldValue: oldValue, newValue: enabled)
        }
    }

    func didSetEnabledHelper(oldValue: Bool, newValue: Bool) {
        // TODO: UM name and scope of function
        // TODO: UM update model, add operation to backend
        let _ = OSPushSubscriptionState(subscriptionId: self.subscriptionId, token: self.token, enabled: oldValue)
        let _ = OSPushSubscriptionState(subscriptionId: self.subscriptionId, token: self.token, enabled: newValue)
        
        // use hydrating bool to determine calling self.set
        self.set(property: "enabled", oldValue: oldValue, newValue: newValue)
        // TODO: UM trigger observers.onOSPushSubscriptionChanged(previous: oldState, current: newState)
        print("🔥 didSet pushSubscription.enabled from \(oldValue) to \(newValue)")
    }

    init(subscriptionId: UUID, token: UUID?, enabled: Bool?) {
        self.subscriptionId = subscriptionId
        self.token = token
        self.enabled = enabled ?? false
        super.init(id: subscriptionId.uuidString, changeNotifier: OSEventProducer())
    }
}
