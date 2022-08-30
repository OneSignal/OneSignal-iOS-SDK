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

@objc
public class OSUser: NSObject {

    let onesignalId: UUID
    var externalId: String?
    var language: String?
    var aliases: [String: String] = [:]
    var tags: [String: String] = [:]
    var triggers: [String: String] = [:] // update to include bool, number

    // email, sms, subscriptions todo

    @objc public var pushSubscription: OSPushSubscription

    // TODO: UM This is a temporary function to create a push subscription for testing
    @objc public func testCreatePushSubscription(subscriptionId: UUID, token: UUID, enabled: Bool) {
        self.pushSubscription = OSPushSubscription(subscriptionId: subscriptionId, token: token, enabled: enabled)
        print("🔥 OSUser has set pushSubcription for testing")
    }

    @objc public init(onesignalId: UUID, pushSubscription: OSPushSubscription) {
        self.onesignalId = onesignalId
        self.pushSubscription = pushSubscription
    }

    // Aliases

    @objc
    public func addAlias(label: String, id: String) {
        print("🔥 OSUser addAlias() called")
    }

    @objc
    public func addAliases(_ aliases: [String: String]) {
        print("🔥 OSUser addAliases() called")
    }

    @objc
    public func removeAlias(_ label: String) {
        print("🔥 OSUser removeAlias() called")
    }

    @objc
    public func removeAliases(_ labels: [String]) {
        print("🔥 OSUser removeAliases() called")
    }

    // Tags

    @objc
    public func setTag(key: String, value: String) {
        print("🔥 OSUser sendTag() called")
    }

    @objc
    public func setTags(_ tags: [String: String]) {
        print("🔥 OSUser sendTags() called")
    }

    @objc
    public func removeTag(_ tag: String) {
        print("🔥 OSUser removeTag() called")
    }

    @objc
    public func removeTags(_ tags: [String]) {
        print("🔥 OSUser removeTags() called")
    }

    @objc
    public func getTag(_ tag: String) {
        print("🔥 OSUser getTag() called")
    }

    // Outcomes

    @objc
    public func setOutcome(_ name: String) {
        print("🔥 OSUser sendOutcome() called")
    }

    @objc
    public func setUniqueOutcome(_ name: String) {
        print("🔥 OSUser setUniqueOutcome() called")
    }

    @objc
    public func setOutcome(name: String, value: Float) {
        print("🔥 OSUser setOutcomeWithValue() called")
    }

    // Email

    @objc
    public func addEmail(_ email: String) {
        print("🔥 OSUser addEmail() called")
    }

    @objc
    public func removeEmail(_ email: String) {
        print("🔥 OSUser removeEmail() called")
    }

    // SMS

    @objc
    public func addSmsNumber(_ number: String) {
        print("🔥 OSUser addPhoneNumber() called")
    }

    @objc
    public func removeSmsNumber(_ number: String) {
        print("🔥 OSUser removePhoneNumber() called")
    }

    // Triggers

    @objc
    public func setTrigger(key: String, value: String) {
        // TODO: UM Value for trigger can be non-string
        print("🔥 OSUser setTrigger() called")
    }

    @objc
    public func setTriggers(_ triggers: [String: String]) {
        print("🔥 OSUser setTriggers() called")
    }

    @objc
    public func removeTrigger(_ trigger: String) {
        print("🔥 OSUser removeTrigger() called")
    }

    @objc
    public func removeTriggers(_ triggers: [String]) {
        print("🔥 OSUser removeTriggers() called")
    }
}
