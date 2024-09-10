//
//  OSConsistencyManager.swift
//  OneSignalOSCore
//
//  Created by Rodrigo Gomez-Palacio on 9/10/24.
//  Copyright © 2024 OneSignal. All rights reserved.
//

import Foundation

@objc public class OSConsistencyManager: NSObject {
    // Singleton instance
    @objc public static let shared = OSConsistencyManager()

    private let queue = DispatchQueue(label: "com.consistencyManager.queue")
    private var indexedTokens: [String: [NSNumber: OSReadYourWriteData]] = [:]
    private var indexedConditions: [String: [(OSCondition, DispatchSemaphore)]] = [:] // Index conditions by condition id

    // Private initializer to prevent multiple instances
    private override init() {}
    
    // Used for testing
    public func reset() {
        indexedTokens = [:]
        indexedConditions = [:]
    }

    // Function to set the token in a thread-safe manner
    public func setRywTokenAndDelay(id: String, key: any OSConsistencyKeyEnum, value: OSReadYourWriteData) {
        queue.sync {
            let nsKey = NSNumber(value: key.rawValue)
            if self.indexedTokens[id] == nil {
                self.indexedTokens[id] = [:]
            }
            self.indexedTokens[id]?[nsKey] = value
            self.checkConditionsAndComplete(forId: id) // Only check conditions for this specific ID
        }
    }

    // Register a condition and block the caller until the condition is met
    @objc public func getRywTokenFromAwaitableCondition(_ condition: OSCondition, forId id: String) -> OSReadYourWriteData? {
        let semaphore = DispatchSemaphore(value: 0)
        queue.sync {
            if self.conditions[id] == nil {
                self.conditions[id] = []
            }
            self.conditions[id]?.append((condition, semaphore))
            self.checkConditionsAndComplete(forId: id)
        }
        semaphore.wait() // Block until the condition is met
        return queue.sync {
            return condition.getNewestToken(indexedTokens: self.indexedTokens)
        }
    }
    
    // Method to resolve conditions by condition ID (e.g. OSIamFetchReadyCondition.ID)
    @objc public func resolveConditionsWithID(id: String) {
        guard let conditionList = conditions[id] else { return }
        var completedConditions: [(OSCondition, DispatchSemaphore)] = []
        for (condition, semaphore) in conditionList {
            if (condition.conditionId == id) {
                semaphore.signal()
                completedConditions.append((condition, semaphore))
            }
        }
        conditions[id]?.removeAll { condition, semaphore in
            completedConditions.contains(where: { $0.0 === condition && $0.1 == semaphore })
        }
    }

    // Private method to check conditions for a specific id (unique ID like onesignalId)
    private func checkConditionsAndComplete(forId id: String) {
        guard let conditionList = conditions[id] else { return }
        var completedConditions: [(OSCondition, DispatchSemaphore)] = []
        for (condition, semaphore) in conditionList {
            if condition.isMet(indexedTokens: indexedTokens) {
                print("Condition met for id: \(id)")
                semaphore.signal()
                completedConditions.append((condition, semaphore))
            } else {
                print("Condition not met for id: \(id)")
            }
        }
        conditions[id]?.removeAll { condition, semaphore in
            completedConditions.contains(where: { $0.0 === condition && $0.1 == semaphore })
        }
    }
}
