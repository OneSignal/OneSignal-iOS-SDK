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
    case push = "iOSPush"
    case email = "Email"
    case sms = "SMS"
}

/**
 Internal subscription model.
 */
class OSSubscriptionModel: OSModel {
    var type: OSSubscriptionType
    var address: String? { // This is token on push subs so must remain Optional
        didSet {
            guard address != oldValue else {
                return
            }
            self.set(property: "address", newValue: address)
            
            guard self.type == .push else {
                return
            }
            
            // Cache the push token as it persists across users on the device?
            OneSignalUserDefaults.initShared().saveString(forKey: OSUD_PUSH_TOKEN_TO, withValue: address)

            // TODO: When token changes, notification_types does too
            // OSNotificationsManager.recalculateNotificationTypes()
            firePushSubscriptionChanged(.address(oldValue))
        }
    }
    
    // Set via server response
    var subscriptionId: String? {
        didSet {
            guard subscriptionId != oldValue else {
                return
            }
            self.set(property: "subscriptionId", newValue: subscriptionId)
            
            guard self.type == .push else {
                return
            }

            // Cache the subscriptionId as it persists across users on the device??
            OneSignalUserDefaults.initShared().saveString(forKey: OSUD_PLAYER_ID_TO, withValue: subscriptionId)
            
            // TODO: update notification_types here?

            firePushSubscriptionChanged(.subscriptionId(oldValue))
        }
    }

    var enabled: Bool { // Note: This behaves like the current `isSubscribed`
        get {
            return calculateIsSubscribed(subscriptionId: subscriptionId, address: address, accepted: _accepted, isDisabled: _isDisabled)
        }
    }
    
    // Push Subscription Only
    var notificationTypes: Int?
    
    // This is set by the permission state changing
    // Defaults to true for email & SMS, defaults to false for push
    var _accepted: Bool {
        didSet {
            guard self.type == .push && _accepted != oldValue else {
                return
            }
            
            // TODO: update notification_types here?

            firePushSubscriptionChanged(.accepted(oldValue))
        }
    }
    
    // Set by the app developer when they set User.pushSubscription.enabled
    // TODO: update notification_types here?
    var _isDisabled: Bool { // Default to false for all subscriptions
        didSet {
            guard self.type == .push && _isDisabled != oldValue else {
                return
            }
            firePushSubscriptionChanged(.isDisabled(oldValue))
        }
    }
    
    // When a Subscription is initialized, it may not have a subscriptionId until a request to the backend is made.
    init(type: OSSubscriptionType,
         address: String?,
         subscriptionId: String?,
         accepted: Bool,
         isDisabled: Bool,
         changeNotifier: OSEventProducer<OSModelChangedHandler>)
    {
        self.type = type
        self.address = address
        self.subscriptionId = subscriptionId
        _accepted = accepted
        _isDisabled = isDisabled
        super.init(changeNotifier: changeNotifier)
    }

    override func encode(with coder: NSCoder) {
        super.encode(with: coder)
        coder.encode(type.rawValue, forKey: "type") // Encodes as String
        coder.encode(address, forKey: "address")
        coder.encode(subscriptionId, forKey: "subscriptionId")
        coder.encode(_accepted, forKey: "_accepted")
        coder.encode(_isDisabled, forKey: "_isDisabled")
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
        self._accepted = coder.decodeBool(forKey: "_accepted")
        self._isDisabled = coder.decodeBool(forKey: "_isDisabled")
        super.init(coder: coder)
    }

    public override func hydrateModel(_ response: [String: String]) {
        print("🔥 OSSubscriptionModel hydrateModel()")
        // TODO: Update Model properties with the response
    }
}

// Push Subscription related
extension OSSubscriptionModel {
    // Only used for the push subscription model
    var currentPushSubscriptionState: OSPushSubscriptionState {
        return OSPushSubscriptionState(subscriptionId: self.subscriptionId,
                                       token: self.address,
                                       enabled: self.enabled
        )
    }
    
    func calculateIsSubscribed(subscriptionId: String?, address: String?, accepted: Bool, isDisabled: Bool) -> Bool {
        return (self.subscriptionId != nil) && (self.address != nil) && _accepted && _isDisabled
    }
    
    enum OSPushPropertyChanged {
        case subscriptionId(String?)
        case accepted(Bool)
        case isDisabled(Bool)
        case address(String?)
    }
}
