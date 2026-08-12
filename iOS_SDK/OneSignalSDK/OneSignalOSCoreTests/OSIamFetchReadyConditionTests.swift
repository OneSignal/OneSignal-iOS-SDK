/*
 Modified MIT License

 Copyright 2026 OneSignal

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
import XCTest
@testable import OneSignalOSCore

/// Covers what an IAM fetch waits for, and for whom.
final class OSIamFetchReadyConditionTests: XCTestCase {

    private let userA = "onesignal-id-a"
    private let userB = "onesignal-id-b"
    private var defaultWaitTimeout: DispatchTimeInterval!

    override func setUp() {
        super.setUp()
        defaultWaitTimeout = OSConsistencyManager.waitTimeout
        OSConsistencyManager.shared.reset()
        OSIamFetchReadyCondition.reset()
    }

    override func tearDown() {
        OSConsistencyManager.waitTimeout = defaultWaitTimeout
        OSConsistencyManager.shared.reset()
        OSIamFetchReadyCondition.reset()
        super.tearDown()
    }

    // MARK: - One condition per id

    func testTheSameIdGetsTheSameCondition() {
        let first = OSIamFetchReadyCondition.sharedInstance(withId: userA)
        let second = OSIamFetchReadyCondition.sharedInstance(withId: userA)

        XCTAssertTrue(first === second, "the fetch has to wait on the object the listener armed")
    }

    /// A user switch must not be answered by the previous user's condition, which reads their tokens.
    func testADifferentIdGetsItsOwnCondition() {
        let forUserA = OSIamFetchReadyCondition.sharedInstance(withId: userA)
        let forUserB = OSIamFetchReadyCondition.sharedInstance(withId: userB)

        XCTAssertFalse(forUserA === forUserB)
        XCTAssertTrue(forUserA.isMet(indexedTokens: [userA: userCreateToken()]))
        XCTAssertFalse(forUserB.isMet(indexedTokens: [userA: userCreateToken()]),
                       "the new user's fetch must not be released by the previous user's token")
    }

    // MARK: - What the condition waits for

    func testAUserUpdateTokenIsEnoughWithNoSubscriptionUpdatePending() {
        let condition = OSIamFetchReadyCondition.sharedInstance(withId: userA)

        XCTAssertTrue(condition.isMet(indexedTokens: [userA: userUpdateToken()]))
    }

    func testAPendingSubscriptionUpdateAlsoWaitsForItsToken() {
        let condition = OSIamFetchReadyCondition.sharedInstance(withId: userA)
        condition.setSubscriptionUpdatePending(value: true)

        XCTAssertFalse(condition.isMet(indexedTokens: [userA: userUpdateToken()]))
        XCTAssertTrue(condition.isMet(indexedTokens: [userA: userUpdateToken().merging(subscriptionToken()) { current, _ in current }]))
    }

    /// The raised bar belongs to the fetch it was raised for; leaving it up makes every later fetch
    /// wait on a subscription token that has no update behind it.
    func testTheSubscriptionBarComesBackDownOnceTheFetchIsReleased() {
        let condition = OSIamFetchReadyCondition.sharedInstance(withId: userA)
        condition.setSubscriptionUpdatePending(value: true)

        condition.onConditionSatisfied()

        XCTAssertTrue(condition.isMet(indexedTokens: [userA: userUpdateToken()]))
    }

    // MARK: - Through the Consistency Manager

    func testTheManagerLowersTheBarWhenItReleasesTheWaiter() {
        let manager = OSConsistencyManager.shared
        OSIamFetchReadyCondition.sharedInstance(withId: userA).setSubscriptionUpdatePending(value: true)

        let firstReturned = expectation(description: "first fetch released")
        DispatchQueue.global().async {
            _ = manager.getRywTokenFromAwaitableCondition(OSIamFetchReadyCondition.sharedInstance(withId: self.userA), forId: self.userA)
            firstReturned.fulfill()
        }
        waitUntil("first fetch waiting") { manager.waiterCount == 1 }

        manager.setRywTokenAndDelay(id: userA, key: OSIamFetchOffsetKey.userUpdate, value: token("100"))
        XCTAssertEqual(manager.waiterCount, 1, "a pending subscription update still owes a token")

        manager.setRywTokenAndDelay(id: userA, key: OSIamFetchOffsetKey.subscriptionUpdate, value: token("200"))
        wait(for: [firstReturned], timeout: 2.0)

        // The next fetch has no subscription update behind it, so the user token alone releases it.
        let secondReturned = expectation(description: "second fetch released")
        DispatchQueue.global().async {
            _ = manager.getRywTokenFromAwaitableCondition(OSIamFetchReadyCondition.sharedInstance(withId: self.userA), forId: self.userA)
            secondReturned.fulfill()
        }
        wait(for: [secondReturned], timeout: 2.0)
    }

    /// The `ryw_token`-missing fallback the executors call for that user.
    func testResolvingTheConditionReleasesTheFetch() {
        let manager = OSConsistencyManager.shared
        let returned = expectation(description: "fetch released")
        DispatchQueue.global().async {
            _ = manager.getRywTokenFromAwaitableCondition(OSIamFetchReadyCondition.sharedInstance(withId: self.userA), forId: self.userA)
            returned.fulfill()
        }
        waitUntil("fetch waiting") { manager.waiterCount == 1 }

        manager.resolveConditions(conditionId: OSIamFetchReadyCondition.CONDITIONID, forId: userA)

        wait(for: [returned], timeout: 2.0)
    }

    /// A missing token for one user must not clear another user's raised subscription bar.
    func testResolvingOneUserDoesNotLowerAnotherUsersSubscriptionBar() {
        let manager = OSConsistencyManager.shared
        let conditionA = OSIamFetchReadyCondition.sharedInstance(withId: userA)
        let conditionB = OSIamFetchReadyCondition.sharedInstance(withId: userB)
        conditionA.setSubscriptionUpdatePending(value: true)
        conditionB.setSubscriptionUpdatePending(value: true)

        let bReturned = expectation(description: "user B fetch released")
        DispatchQueue.global().async {
            _ = manager.getRywTokenFromAwaitableCondition(conditionB, forId: self.userB)
            bReturned.fulfill()
        }
        waitUntil("user B waiting") { manager.waiterCount == 1 }

        manager.resolveConditions(conditionId: OSIamFetchReadyCondition.CONDITIONID, forId: userB)
        wait(for: [bReturned], timeout: 2.0)

        XCTAssertFalse(conditionA.isMet(indexedTokens: [userA: userUpdateToken()]),
                       "user A's subscription bar must still be up")
        XCTAssertTrue(conditionB.isMet(indexedTokens: [userB: userUpdateToken()]),
                      "user B's bar comes down with its own resolve")
    }

    /// Timing out must lower the bar, or every later fetch for that id pays another full wait.
    func testTimingOutLowersTheSubscriptionBar() {
        OSConsistencyManager.waitTimeout = .milliseconds(200)
        let manager = OSConsistencyManager.shared
        let condition = OSIamFetchReadyCondition.sharedInstance(withId: userA)
        condition.setSubscriptionUpdatePending(value: true)

        let firstReturned = expectation(description: "first fetch timed out")
        DispatchQueue.global().async {
            _ = manager.getRywTokenFromAwaitableCondition(condition, forId: self.userA)
            firstReturned.fulfill()
        }
        wait(for: [firstReturned], timeout: 2.0)

        manager.setRywTokenAndDelay(id: userA, key: OSIamFetchOffsetKey.userUpdate, value: token("100"))

        let secondReturned = expectation(description: "second fetch released by user token alone")
        DispatchQueue.global().async {
            _ = manager.getRywTokenFromAwaitableCondition(condition, forId: self.userA)
            secondReturned.fulfill()
        }
        wait(for: [secondReturned], timeout: 2.0)
    }

    // MARK: - Helpers

    private func token(_ value: String) -> OSReadYourWriteData {
        return OSReadYourWriteData(rywToken: value, rywDelay: 0)
    }

    private func userCreateToken() -> [NSNumber: OSReadYourWriteData] {
        return [NSNumber(value: OSIamFetchOffsetKey.userCreate.rawValue): token("create")]
    }

    private func userUpdateToken() -> [NSNumber: OSReadYourWriteData] {
        return [NSNumber(value: OSIamFetchOffsetKey.userUpdate.rawValue): token("update")]
    }

    private func subscriptionToken() -> [NSNumber: OSReadYourWriteData] {
        return [NSNumber(value: OSIamFetchOffsetKey.subscriptionUpdate.rawValue): token("subscription")]
    }
}
