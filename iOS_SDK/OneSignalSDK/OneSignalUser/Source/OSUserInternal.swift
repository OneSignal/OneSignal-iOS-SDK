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

/**
 This is the user interface exposed to the public.
 */
@objc public protocol OSUser {
    var pushSubscription: OSPushSubscriptionInterface { get } // TODO: static var
    // Aliases
    static func addAlias(label: String, id: String)
    static func addAliases(_ aliases: [String: String])
    static func removeAlias(_ label: String)
    static func removeAliases(_ labels: [String])
    // Tags
    static func setTag(key: String, value: String)
    static func setTags(_ tags: [String: String])
    static func removeTag(_ tag: String)
    static func removeTags(_ tags: [String])
    static func getTag(_ tag: String)
    // Outcomes
    static func setOutcome(_ name: String)
    static func setUniqueOutcome(_ name: String)
    static func setOutcome(name: String, value: Float)
    // Email
    static func addEmail(_ email: String)
    static func removeEmail(_ email: String)
    // SMS
    static func addSmsNumber(_ number: String)
    static func removeSmsNumber(_ number: String)
    // Triggers
    static func setTrigger(key: String, value: String)
    static func setTriggers(_ triggers: [String: String])
    static func removeTrigger(_ trigger: String)
    static func removeTriggers(_ triggers: [String])

    // TODO: UM This is a temporary function to create a push subscription for testing
    func testCreatePushSubscription(subscriptionId: UUID, token: UUID, enabled: Bool) // TODO: static
}

/**
 Internal user object that implements the public-facing OSUser protocol.
 Class made public because it is used in OneSignalUserManager which is public.
 */
public class OSUserInternal: NSObject, OSUser {
    // TODO: make properties static
    var triggers: [String: String] = [:] // update to include bool, number

    // email, sms, subscriptions todo

    @objc public var pushSubscription: OSPushSubscriptionInterface

    // Sessions will be outside this?

    // Owns an Identity Model and Properties Model
    var identityModel: OSIdentityModel
    var propertiesModel: OSPropertiesModel

    // TODO: UM This is a temporary function to create a push subscription for testing
    @objc public func testCreatePushSubscription(subscriptionId: UUID, token: UUID, enabled: Bool) { // TODO: static
        self.pushSubscription = OSPushSubscriptionModel(token: token, enabled: enabled)
        print("🔥 OSUser has set pushSubcription for testing")
    }

    init(pushSubscription: OSPushSubscriptionModel, identityModel: OSIdentityModel, propertiesModel: OSPropertiesModel) { // TODO: don't init instances
        self.pushSubscription = pushSubscription
        self.identityModel = identityModel
        self.propertiesModel = propertiesModel
        // workaround for didSet: call initializeProperties(...)
    }

    // MARK: - Aliases

    @objc
    public static func addAlias(label: String, id: String) {
        // Don't let them use `onesignal_id` as an alias label
        // Don't let them use `external_id` either??
        print("🔥 OSUser addAlias() called")
        // identityModel.setAlias(label: label, id: id) // TODO: Uncomment
    }

    @objc
    public static func addAliases(_ aliases: [String: String]) {
        // Don't let them use `onesignal_id` as an alias label
        // Don't let them use `external_id` either??
        print("🔥 OSUser addAliases() called")
        // Don't make separate calls resulting in many deltas
        for alias in aliases {
            addAlias(label: alias.key, id: alias.value)
        }
    }

    @objc
    public static func removeAlias(_ label: String) {
        print("🔥 OSUser removeAlias() called")
        // self.identityModel.removeAlias(label) // TODO: Uncomment
    }

    @objc
    public static func removeAliases(_ labels: [String]) {
        print("🔥 OSUser removeAliases() called")
        for label in labels {
            removeAlias(label)
        }
    }

    // MARK: - Tags

    @objc
    public static func setTag(key: String, value: String) {
        print("🔥 OSUser sendTag() called")
        // self.propertiesModel.tags[key] = value // TODO: Uncomment
    }

    @objc
    public static func setTags(_ tags: [String: String]) {
        print("🔥 OSUser sendTags() called")
        // TODO: Implementation
    }

    @objc
    public static func removeTag(_ tag: String) {
        print("🔥 OSUser removeTag() called")
        // TODO: Implementation
    }

    @objc
    public static func removeTags(_ tags: [String]) {
        print("🔥 OSUser removeTags() called")
        // TODO: Implementation
    }

    @objc
    public static func getTag(_ tag: String) {
        print("🔥 OSUser getTag() called")
    }

    // MARK: - Outcomes

    @objc
    public static func setOutcome(_ name: String) {
        print("🔥 OSUser sendOutcome() called")
    }

    @objc
    public static func setUniqueOutcome(_ name: String) {
        print("🔥 OSUser setUniqueOutcome() called")
    }

    @objc
    public static func setOutcome(name: String, value: Float) {
        print("🔥 OSUser setOutcomeWithValue() called")
    }

    // MARK: - Email

    @objc
    public static func addEmail(_ email: String) {
        print("🔥 OSUser addEmail() called")
    }

    @objc
    public static func removeEmail(_ email: String) {
        print("🔥 OSUser removeEmail() called")
    }

    // MARK: - SMS

    @objc
    public static func addSmsNumber(_ number: String) {
        print("🔥 OSUser addSmsNumber() called")
    }

    @objc
    public static func removeSmsNumber(_ number: String) {
        print("🔥 OSUser removeSmsNumber() called")
    }

    // MARK: - Triggers

    @objc
    public static func setTrigger(key: String, value: String) {
        // TODO: UM Value for trigger can be non-string
        print("🔥 OSUser setTrigger() called")
    }

    @objc
    public static func setTriggers(_ triggers: [String: String]) {
        print("🔥 OSUser setTriggers() called")
    }

    @objc
    public static func removeTrigger(_ trigger: String) {
        print("🔥 OSUser removeTrigger() called")
    }

    @objc
    public static func removeTriggers(_ triggers: [String]) {
        print("🔥 OSUser removeTriggers() called")
    }
}
