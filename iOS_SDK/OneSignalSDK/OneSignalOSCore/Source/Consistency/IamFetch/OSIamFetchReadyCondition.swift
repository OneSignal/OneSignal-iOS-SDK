//
//  OSIamFetchReadyCondition.swift
//  OneSignalOSCore
//
//  Created by Rodrigo Gomez-Palacio on 10/10/24.
//  Copyright © 2024 OneSignal. All rights reserved.

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

        let userTokenSet = tokenMap[NSNumber(value: OSIamFetchOffsetKey.user.rawValue)] != nil
        let subscriptionTokenSet = tokenMap[NSNumber(value: OSIamFetchOffsetKey.subscription.rawValue)] != nil

        if (hasSubscriptionUpdatePending) {
            return userTokenSet && subscriptionTokenSet
        }
        return userTokenSet
    }

    public func getNewestToken(indexedTokens: [String: [NSNumber: String]]) -> String? {
        guard let tokenMap = indexedTokens[id] else { return nil }

        self.setSubscriptionUpdatePending(value: false)

        return [tokenMap[NSNumber(value: OSIamFetchOffsetKey.user.rawValue)],
                tokenMap[NSNumber(value: OSIamFetchOffsetKey.subscription.rawValue)]
               ].compactMap { $0 }.max()
    }
}
