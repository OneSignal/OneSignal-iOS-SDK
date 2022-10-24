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

import OneSignalCore
import OneSignalOSCore

/**
 This is the user interface exposed to the public.
 */
protocol OSUserInternal {
    var isAnonymous: Bool { get }
    var pushSubscriptionModel: OSSubscriptionModel { get }
    var identityModel: OSIdentityModel { get }
    var propertiesModel: OSPropertiesModel { get }
    // Aliases
    func addAliases(_ aliases: [String: String])
    func removeAliases(_ labels: [String])
    // Tags
    func setTags(_ tags: [String: String])
    func removeTags(_ tags: [String])
    // Outcomes
    func setOutcome(_ name: String)
    func setUniqueOutcome(_ name: String)
    func setOutcome(name: String, value: Float)
    // Email and SMS are handled by the UserManager
    // Triggers
    func setTrigger(key: String, value: String)
    func setTriggers(_ triggers: [String: String])
    func removeTrigger(_ trigger: String)
    func removeTriggers(_ triggers: [String])

    // TODO: UM This is a temporary function to create a push subscription for testing
    func testCreatePushSubscription(subscriptionId: String, token: String, enabled: Bool) -> OSSubscriptionModel
}

/**
 Internal user object that implements the OSUserInternal protocol.
 */
class OSUserInternalImpl: NSObject, OSUserInternal {
    // TODO: Determine if having any alias should return true
    // Is an anon user who has added aliases, still an anon user?
    var isAnonymous: Bool {
        return identityModel.externalId == nil
    }

    var triggers: [String: String] = [:] // TODO: update to include bool, number...

    var identityModel: OSIdentityModel
    var propertiesModel: OSPropertiesModel
    var pushSubscriptionModel: OSSubscriptionModel

    // Sessions will be outside this?

    // TODO: UM This is a temporary function to create a push subscription for testing
    func testCreatePushSubscription(subscriptionId: String, token: String, enabled: Bool) -> OSSubscriptionModel {
        pushSubscriptionModel = OSSubscriptionModel(type: .push, address: token, enabled: enabled, changeNotifier: OSEventProducer())
        print("🔥 OSUserInternalImpl has set pushSubcription for testing")
        return pushSubscriptionModel
    }

    init(identityModel: OSIdentityModel, propertiesModel: OSPropertiesModel, pushSubscriptionModel: OSSubscriptionModel) {
        self.identityModel = identityModel
        self.propertiesModel = propertiesModel
        self.pushSubscriptionModel = pushSubscriptionModel
    }

    // MARK: - Aliases

    /**
     Prohibit the use of `onesignal_id` and `external_id`as alias label.
     Prohibit the setting of aliases to the empty string (users should use `removeAlias` methods instead).
     */
    func addAliases(_ aliases: [String: String]) {
        // Decide if the non-offending aliases should still be added.
        print("🔥 OSUserInternalImpl addAliases() called")
        guard aliases[OS_ONESIGNAL_ID] == nil,
              aliases[OS_EXTERNAL_ID] == nil,
              !aliases.values.contains("")
        else {
            // log error
            print("🔥 OSUserInternal addAliases: Cannot use \(OS_ONESIGNAL_ID) or \(OS_EXTERNAL_ID) as a alias label. Or, cannot use empty string as an alias ID.")
            return
        }
        identityModel.addAliases(aliases)
    }

    /**
     Prohibit the removal of `onesignal_id` and `external_id`.
     */
    func removeAliases(_ labels: [String]) {
        print("🔥 OSUserInternalImpl removeAliases() called")
        guard !labels.contains(OS_ONESIGNAL_ID),
              !labels.contains(OS_EXTERNAL_ID)
        else {
            // log error
            print("🔥 OSUserInternal removeAliases: Cannot use \(OS_ONESIGNAL_ID) or \(OS_EXTERNAL_ID) as a alias label.")
            return
        }
        identityModel.removeAliases(labels)
    }

    // MARK: - Tags

    func setTags(_ tags: [String: String]) {
        print("🔥 OSUserInternalImpl setTags() called")
        propertiesModel.setTags(tags)
    }

    func removeTags(_ tags: [String]) {
        print("🔥 OSUserInternalImpl removeTags() called")
        propertiesModel.removeTags(tags)
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
