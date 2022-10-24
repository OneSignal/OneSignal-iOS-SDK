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

// MARK: - Push Subscription Specific

@objc public protocol OSPushSubscriptionObserver { //  weak reference?
    @objc func onOSPushSubscriptionChanged(previous: OSPushSubscriptionState, current: OSPushSubscriptionState)
}

@objc
public class OSPushSubscriptionState: NSObject {
    @objc public let subscriptionId: String?
    @objc public let token: String?
    @objc public let enabled: Bool

    init(subscriptionId: String?, token: String?, enabled: Bool) {
        self.subscriptionId = subscriptionId
        self.token = token
        self.enabled = enabled
    }
}

// MARK: - Subscription Model

enum OSSubscriptionType: String {
    case push, email, sms
}

/**
 Internal subscription model.
 */
class OSSubscriptionModel: OSModel {
    var type: OSSubscriptionType
    var address: String? // This is token on push subs so must remain Optional
    var subscriptionId: String? // Where from
    var enabled: Bool {
        didSet { // TODO: Revisit this
            didSetEnabledHelper(oldValue: oldValue, newValue: enabled)
        }
    }

    /**
     This helper function is for the enabled property of push subscriptions, in order to address observers.
     */
    func didSetEnabledHelper(oldValue: Bool, newValue: Bool) {
        // TODO: UM name and scope of function
        // TODO: UM update model, add operation to backend
        _ = OSPushSubscriptionState(subscriptionId: self.subscriptionId, token: self.address, enabled: oldValue)
        _ = OSPushSubscriptionState(subscriptionId: self.subscriptionId, token: self.address, enabled: newValue)

        // use hydrating bool to determine calling self.set
        self.set(property: "enabled", newValue: newValue)
        // TODO: UM trigger observers.onOSPushSubscriptionChanged(previous: oldState, current: newState)
        print("🔥 didSet pushSubscription.enabled from \(oldValue) to \(newValue)")
    }

    // When a Subscription is initialized, it will not have a subscriptionId until a request to the backend is made.
    init(type: OSSubscriptionType, address: String?, enabled: Bool, changeNotifier: OSEventProducer<OSModelChangedHandler>) {
        self.type = type
        self.address = address
        self.enabled = enabled
        super.init(changeNotifier: changeNotifier)
    }

    override func encode(with coder: NSCoder) {
        super.encode(with: coder)
        coder.encode(type.rawValue, forKey: "type") // Encodes as String
        coder.encode(address, forKey: "address")
        coder.encode(subscriptionId, forKey: "subscriptionId")
        coder.encode(enabled, forKey: "enabled")
    }

    required init?(coder: NSCoder) {
        guard
            let rawType = coder.decodeObject(forKey: "type") as? String,
            let type = OSSubscriptionType(rawValue: rawType)
        else {
            // Log error
            return nil
        }
        self.type = type
        self.address = coder.decodeObject(forKey: "address") as? String
        self.subscriptionId = coder.decodeObject(forKey: "subscriptionId") as? String
        self.enabled = coder.decodeBool(forKey: "enabled")
        super.init(coder: coder)
    }

    public override func hydrateModel(_ response: [String: String]) {
        print("🔥 OSSubscriptionModel hydrateModel()")
        // TODO: Update Model properties with the response
        // What does it look like to hydrate an email or SMS model
    }
}
