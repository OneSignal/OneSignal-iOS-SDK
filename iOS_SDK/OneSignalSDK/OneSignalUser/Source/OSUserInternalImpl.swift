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
protocol OSUserInternal {
    var pushSubscription: OSPushSubscriptionInterface { get }
    var identityModel: OSIdentityModel { get }
    var propertiesModel: OSPropertiesModel { get }
    // Aliases
    func addAlias(label: String, id: String)
    func addAliases(_ aliases: [String: String])
    func removeAlias(_ label: String)
    func removeAliases(_ labels: [String])
    // Tags
    func setTag(key: String, value: String)
    func setTags(_ tags: [String: String])
    func removeTag(_ tag: String)
    func removeTags(_ tags: [String])
    func getTag(_ tag: String)
    // Outcomes
    func setOutcome(_ name: String)
    func setUniqueOutcome(_ name: String)
    func setOutcome(name: String, value: Float)
    // Email
    func addEmail(_ email: String)
    func removeEmail(_ email: String)
    // SMS
    func addSmsNumber(_ number: String)
    func removeSmsNumber(_ number: String)
    // Triggers
    func setTrigger(key: String, value: String)
    func setTriggers(_ triggers: [String: String])
    func removeTrigger(_ trigger: String)
    func removeTriggers(_ triggers: [String])

    // TODO: UM This is a temporary function to create a push subscription for testing
    func testCreatePushSubscription(subscriptionId: UUID, token: UUID, enabled: Bool)
}

/**
 Internal user object that implements the OSUserInternal protocol.
 */
class OSUserInternalImpl: NSObject, OSUserInternal {
    var triggers: [String: String] = [:] // TODO: update to include bool, number...

    var identityModel: OSIdentityModel
    var propertiesModel: OSPropertiesModel
    var pushSubscription: OSPushSubscriptionInterface
    // TODO: email, sms subscriptions

    // Sessions will be outside this?


    // TODO: UM This is a temporary function to create a push subscription for testing
    func testCreatePushSubscription(subscriptionId: UUID, token: UUID, enabled: Bool) {
        pushSubscription = OSPushSubscriptionModel(token: token, enabled: enabled)
        print("🔥 OSUserInternalImpl has set pushSubcription for testing")
    }

    init(identityModel: OSIdentityModel, propertiesModel: OSPropertiesModel, pushSubscription: OSPushSubscriptionModel) {
        self.identityModel = identityModel
        self.propertiesModel = propertiesModel
        self.pushSubscription = pushSubscription
    }

    // MARK: - Aliases

    
    func addAlias(label: String, id: String) {
        // Don't let them use `onesignal_id` as an alias label
        // Don't let them use `external_id` either??
        print("🔥 OSUserInternalImpl addAlias() called")
        identityModel.addAlias(label: label, id: id)
    }

    func addAliases(_ aliases: [String: String]) {
        // Don't let them use `onesignal_id` as an alias label
        // Don't let them use `external_id` either??
        print("🔥 OSUserInternalImpl addAliases() called")
        // Don't make separate calls resulting in many deltas
        for alias in aliases {
            addAlias(label: alias.key, id: alias.value)
        }
    }

    func removeAlias(_ label: String) {
        print("🔥 OSUserInternalImpl removeAlias() called")
        self.identityModel.removeAlias(label)
    }

    func removeAliases(_ labels: [String]) {
        print("🔥 OSUserInternalImpl removeAliases() called")
        for label in labels {
            removeAlias(label)
        }
    }

    // MARK: - Tags
    
    func setTag(key: String, value: String) {
        print("🔥 OSUserInternalImpl sendTag() called")
        self.propertiesModel.tags[key] = value
    }

    func setTags(_ tags: [String: String]) {
        print("🔥 OSUserInternalImpl sendTags() called")
        // TODO: Implementation
    }

    func removeTag(_ tag: String) {
        print("🔥 OSUserInternalImpl removeTag() called")
        // TODO: Implementation
    }

    func removeTags(_ tags: [String]) {
        print("🔥 OSUserInternalImpl removeTags() called")
        // TODO: Implementation
    }

    func getTag(_ tag: String) {
        print("🔥 OSUserInternalImpl getTag() called")
    }

    // MARK: - Outcomes

    func setOutcome(_ name: String) {
        print("🔥 OSUserInternalImpl sendOutcome() called")
    }

    func setUniqueOutcome(_ name: String) {
        print("🔥 OSUserInternalImpl setUniqueOutcome() called")
    }

    func setOutcome(name: String, value: Float) {
        print("🔥 OSUserInternalImpl setOutcomeWithValue() called")
    }

    // MARK: - Email

    func addEmail(_ email: String) {
        print("🔥 OSUserInternalImpl addEmail() called")
    }

    func removeEmail(_ email: String) {
        print("🔥 OSUserInternalImpl removeEmail() called")
    }

    // MARK: - SMS

    func addSmsNumber(_ number: String) {
        print("🔥 OSUserInternalImpl addSmsNumber() called")
    }

    func removeSmsNumber(_ number: String) {
        print("🔥 OSUserInternalImpl removeSmsNumber() called")
    }

    // MARK: - Triggers

    func setTrigger(key: String, value: String) {
        // TODO: UM Value for trigger can be non-string
        print("🔥 OSUserInternalImpl setTrigger() called")
    }

    func setTriggers(_ triggers: [String: String]) {
        print("🔥 OSUserInternalImpl setTriggers() called")
    }

    func removeTrigger(_ trigger: String) {
        print("🔥 OSUserInternalImpl removeTrigger() called")
    }

    func removeTriggers(_ triggers: [String]) {
        print("🔥 OSUserInternalImpl removeTriggers() called")
    }
}
