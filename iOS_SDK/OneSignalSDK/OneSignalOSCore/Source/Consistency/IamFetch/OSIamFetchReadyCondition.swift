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
    private var hasSubscriptionUpdatePending: Bool = false

    // Singleton shared instance initialized with default empty id
    private static var instance: OSIamFetchReadyCondition?

    // Method to get or initialize the shared instance
    @objc public static func sharedInstance(withId id: String) -> OSIamFetchReadyCondition {
        if instance == nil {
            instance = OSIamFetchReadyCondition(id: id)
        }
        return instance!
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
    
    public func setSubscriptionUpdatePending(value: Bool) {
        hasSubscriptionUpdatePending = value
    }

    public func isMet(indexedTokens: [String: [NSNumber: String]]) -> Bool {
        guard let tokenMap = indexedTokens[id] else { return false }

        let userCreateTokenSet = tokenMap[NSNumber(value: OSIamFetchOffsetKey.userCreate.rawValue)] != nil
        let userUpdateTokenSet = tokenMap[NSNumber(value: OSIamFetchOffsetKey.userUpdate.rawValue)] != nil
        let subscriptionTokenSet = tokenMap[NSNumber(value: OSIamFetchOffsetKey.subscriptionUpdate.rawValue)] != nil
        
        if (userCreateTokenSet) {
            return true;
        }

        if (hasSubscriptionUpdatePending) {
            return userUpdateTokenSet && subscriptionTokenSet
        }
        return userUpdateTokenSet
    }

    public func getNewestToken(indexedTokens: [String: [NSNumber: String]]) -> String? {
        guard let tokenMap = indexedTokens[id] else { return nil }

        return [tokenMap[NSNumber(value: OSIamFetchOffsetKey.userUpdate.rawValue)],
                tokenMap[NSNumber(value: OSIamFetchOffsetKey.subscriptionUpdate.rawValue)]
               ].compactMap { $0 }.max()
    }
}
