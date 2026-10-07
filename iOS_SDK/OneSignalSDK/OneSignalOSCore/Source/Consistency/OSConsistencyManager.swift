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

    // Serial, and the only place `indexedTokens` and `indexedConditions` may be touched.
    // Neither is private, so test helpers can read them through it.
    let queue = DispatchQueue(label: "com.consistencyManager.queue")
    var indexedTokens: [String: [NSNumber: OSReadYourWriteData]] = [:]
    // Waiters, indexed by the id passed to getRywTokenFromAwaitableCondition.
    var indexedConditions: [String: [(OSCondition, DispatchSemaphore)]] = [:]

    /**
     How long a waiter blocks before proceeding with whatever token it has. A response that never arrives —
     the device is offline, or the endpoint stopped returning `ryw_token` and has no call that resolves the
     condition — would otherwise hold the calling thread for the life of the process.
     Non-private so tests can shorten it.
     */
    static var waitTimeout: DispatchTimeInterval = .seconds(30)

    // Private initializer to prevent multiple instances
    private override init() {}

    // Used for testing
    public func reset() {
        queue.sync {
            self.indexedTokens = [:]
            self.indexedConditions = [:]
        }
    }

    /**
     Records the outcome of a write for `id` under the caller's key, and releases any waiter it satisfies.
     A response with no `ryw_token` is filed as a blank entry: the write still completed, and a condition
     that only needs it to have completed is met by the entry being there. A fetch that registers later
     finds it on file, instead of waiting the full timeout for a token that is never coming.
     */
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

    /// Blocks the caller until the condition is met or `waitTimeout` elapses, then returns the newest
    /// token the condition accepts, which is nil when it was released without one.
    @objc public func getRywTokenFromAwaitableCondition(_ condition: OSCondition, forId id: String) -> OSReadYourWriteData? {
        // The timeout in force when the waiter registers is the one it waits.
        let timeout = OSConsistencyManager.waitTimeout
        let semaphore = DispatchSemaphore(value: 0)
        queue.sync {
            self.indexedConditions[id, default: []].append((condition, semaphore))
            self.checkConditionsAndComplete(forId: id)
        }
        if semaphore.wait(timeout: .now() + timeout) == .timedOut {
            OneSignalLog.onesignalLog(.LL_WARN, message: "OSConsistencyManager timed out waiting on \(condition.conditionId) for id: \(id)")
            queue.sync {
                // Skip if a met-path release already removed this waiter.
                guard self.indexedConditions[id]?.contains(where: { $0.1 === semaphore }) == true else {
                    return
                }
                // Deregister first, so the re-check below cannot release this waiter a second time.
                self.indexedConditions[id]?.removeAll { $0.1 === semaphore }
                // Clear so later fetches for this id are not held to a subscription token that never arrives.
                condition.onConditionSatisfied?()
                // The lowered bar can be all a sibling waiter on this id was missing, so measure the rest
                // against it now instead of leaving them to sit out their own timeouts.
                self.checkConditionsAndComplete(forId: id)
            }
        }
        return queue.sync {
            return condition.getNewestToken(indexedTokens: self.indexedTokens)
        }
    }

    // Private method to check conditions for a specific id (unique ID like onesignalId)
    private func checkConditionsAndComplete(forId id: String) {
        guard let waiters = indexedConditions[id] else { return }
        var stillWaiting: [(OSCondition, DispatchSemaphore)] = []
        for (condition, semaphore) in waiters {
            if condition.isMet(indexedTokens: indexedTokens) {
                OneSignalLog.onesignalLog(.LL_INFO, message: "Condition met for id: \(id)")
                release(condition, semaphore)
            } else {
                OneSignalLog.onesignalLog(.LL_INFO, message: "Condition not met for id: \(id)")
                stillWaiting.append((condition, semaphore))
            }
        }
        indexedConditions[id] = stillWaiting
    }

    private func release(_ condition: OSCondition, _ semaphore: DispatchSemaphore) {
        condition.onConditionSatisfied?()
        semaphore.signal()
    }
}
