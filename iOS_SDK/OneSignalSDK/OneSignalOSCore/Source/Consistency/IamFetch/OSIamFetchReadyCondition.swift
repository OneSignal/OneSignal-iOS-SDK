/*
 Modified MIT License

 Copyright 2024 OneSignal

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

@objc public class OSIamFetchReadyCondition: NSObject, OSCondition {
    // the id used to index the token map (e.g. onesignalId)
    private let id: String

    private let stateLock = NSLock()
    private var hasSubscriptionUpdatePending: Bool = false

    private static let instancesLock = NSLock()
    private static var instances: [String: OSIamFetchReadyCondition] = [:]

    /**
     One condition per id, so a fetch waits on the same object the subscription listener armed, and a
     fetch for a user who just switched in is not answered by the previous user's tokens.
     */
    @objc public static func sharedInstance(withId id: String) -> OSIamFetchReadyCondition {
        return instancesLock.withLock {
            if let existing = instances[id] {
                return existing
            }
            let condition = OSIamFetchReadyCondition(id: id)
            instances[id] = condition
            return condition
        }
    }

    /// Test seam; the instances otherwise live as long as the process.
    @objc public static func reset() {
        instancesLock.withLock { instances = [:] }
    }

    // Private initializer to prevent external instantiation
    private init(id: String) {
        self.id = id
    }

    // Expose the constant to Objective-C
    @objc public static let CONDITIONID: String = "OSIamFetchReadyCondition"

    public var conditionId: String {
        return OSIamFetchReadyCondition.CONDITIONID
    }

    /// Raises the bar for the next fetch: an in-session subscription change is only readable once its
    /// own token arrives, so waiting on the user token alone would fetch before the server can see it.
    public func setSubscriptionUpdatePending(value: Bool) {
        stateLock.withLock { hasSubscriptionUpdatePending = value }
    }

    /// The fetch this was raised for has been released, so later fetches stop waiting on a subscription
    /// token that has no update behind it.
    @objc public func onConditionSatisfied() {
        setSubscriptionUpdatePending(value: false)
    }

    public func isMet(indexedTokens: [String: [NSNumber: OSReadYourWriteData]]) -> Bool {
        guard let tokenMap = indexedTokens[id] else { return false }

        // We track user create tokens as well because on fresh installs, we don't have a user or subscription
        // to update, which would lead to a 5 second delay until the subsequent user & subscription update calls
        // give us RYW tokens
        let userCreateTokenSet = tokenMap[NSNumber(value: OSIamFetchOffsetKey.userCreate.rawValue)] != nil
        let userUpdateTokenSet = tokenMap[NSNumber(value: OSIamFetchOffsetKey.userUpdate.rawValue)] != nil
        let subscriptionTokenSet = tokenMap[NSNumber(value: OSIamFetchOffsetKey.subscriptionUpdate.rawValue)] != nil

        if userCreateTokenSet {
            return true
        }

        if stateLock.withLock({ hasSubscriptionUpdatePending }) {
            return userUpdateTokenSet && subscriptionTokenSet
        }
        return userUpdateTokenSet
    }

    public func getNewestToken(indexedTokens: [String: [NSNumber: OSReadYourWriteData]]) -> OSReadYourWriteData? {
        // Check if the token map for the given `id` exists
        guard let tokenMap = indexedTokens[id] else { return nil }

        // Flatten all OSReadYourWriteData objects into an array
        let allDataObjects = tokenMap.values.compactMap { $0 }

        // Find the object with the max rywToken (if available)
        let maxTokenObject = allDataObjects.max {
            ($0.rywToken ?? "") < ($1.rywToken ?? "")
        }

        return maxTokenObject
    }

}
