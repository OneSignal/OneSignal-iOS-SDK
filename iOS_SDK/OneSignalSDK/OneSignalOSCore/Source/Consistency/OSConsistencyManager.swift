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

import Foundation
import OneSignalCore

@objc public class OSConsistencyManager: NSObject {
    // Singleton instance
    @objc public static let shared = OSConsistencyManager()

    private let queue = DispatchQueue(label: "com.consistencyManager.queue")
    private var indexedTokens: [String: [NSNumber: String]] = [:]
    private var indexedConditions: [String: [(OSCondition, DispatchSemaphore)]] = [:] // Index conditions by condition id

    // Private initializer to prevent multiple instances
    private override init() {}

    // Function to set the token in a thread-safe manner
    public func setRywToken(id: String, key: any OSConsistencyKeyEnum, value: String?) {
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
    @objc public func getRywTokenFromAwaitableCondition(_ condition: OSCondition, forId id: String) -> String? {
        let semaphore = DispatchSemaphore(value: 0)
        queue.sync {
            if self.indexedConditions[id] == nil {
                self.indexedConditions[id] = []
            }
            self.indexedConditions[id]?.append((condition, semaphore))
            self.checkConditionsAndComplete(forId: id)
        }
        semaphore.wait() // Block until the condition is met
        return queue.sync {
            return condition.getNewestToken(indexedTokens: self.indexedTokens)
        }
    }
    
    // Method to resolve conditions by condition ID (e.g. OSIamFetchReadyCondition.ID)
    @objc public func resolveConditionsWithID(id: String) {
        guard let conditionList = indexedConditions[id] else { return }
        var completedConditions: [(OSCondition, DispatchSemaphore)] = []
        for (condition, semaphore) in conditionList {
            if (condition.conditionId == id) {
                semaphore.signal()
                completedConditions.append((condition, semaphore))
            }
        }
        indexedConditions[id]?.removeAll { condition, semaphore in
            completedConditions.contains(where: { $0.0 === condition && $0.1 == semaphore })
        }
    }

    // Private method to check conditions for a specific id (unique ID like onesignalId)
    private func checkConditionsAndComplete(forId id: String) {
        guard let conditionList = indexedConditions[id] else { return }
        var completedConditions: [(OSCondition, DispatchSemaphore)] = []
        for (condition, semaphore) in conditionList {
            if condition.isMet(indexedTokens: indexedTokens) {
                OneSignalLog.onesignalLog(.LL_INFO, message: "Condition met for id: \(id)")
                semaphore.signal()
                completedConditions.append((condition, semaphore))
            } else {
                OneSignalLog.onesignalLog(.LL_INFO, message: "Condition not met for id: \(id)")
            }
        }
        indexedConditions[id]?.removeAll { condition, semaphore in
            completedConditions.contains(where: { $0.0 === condition && $0.1 == semaphore })
        }
    }
}
