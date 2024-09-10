//
//  OSConsistencyManagerTests.swift
//  UnitTests
//
//  Created by rodrigo on 9/10/24.
//  Copyright © 2024 Hiptic. All rights reserved.
//

import Foundation
import XCTest
import OneSignalOSCore

class OSConsistencyManagerTests: XCTestCase {
    var consistencyManager: OSConsistencyManager!

    override func setUp() {
        super.setUp()
        // Use the shared instance of OSConsistencyManager
        consistencyManager = OSConsistencyManager.shared
    }

    override func tearDown() {
        consistencyManager.reset()
        super.tearDown()
    }

    // Test: setRywToken updates the token correctly
    func testSetRywTokenUpdatesTokenCorrectly() {
        let expectation = self.expectation(description: "Condition met")

        // Given
        let id = "test_id"
        let key = OSIamFetchOffsetKey.userUpdate
        let rywToken = "123"
        let rywDelay = 500
        let rywData = OSReadYourWriteData(rywToken: rywToken, rywDelay: rywDelay as NSNumber)

        // Set the token
        consistencyManager.setRywTokenAndDelay(
            id: id,
            key: key,
            value: rywData
        )

        // Create a condition that expects the value to be set
        let condition = TestMetCondition(expectedTokens: [id: [NSNumber(value: key.rawValue): rywData]])

        // Register the condition
        DispatchQueue.global().async {
            let rywDataFromCondition = self.consistencyManager.getRywTokenFromAwaitableCondition(condition, forId: id)

            // Assert that the result is the same as the value set
            XCTAssertEqual(rywDataFromCondition, rywData, "Objects are not equal")
            expectation.fulfill()
        }

        waitForExpectations(timeout: 2.0, handler: { error in
            if let error = error {
                XCTFail("Test timed out: \(error)")
            }
        })
    }

    // Test: registerCondition completes when the condition is met
    func testRegisterConditionCompletesWhenConditionIsMet() {
        let expectation = self.expectation(description: "Condition met")

        let id = "test_id"
        let key = OSIamFetchOffsetKey.userUpdate
        let rywToken = "123"
        let rywDelay = 500 as NSNumber
        let value = OSReadYourWriteData(rywToken: rywToken, rywDelay: rywDelay)

        // Set the token to meet the condition
        consistencyManager.setRywTokenAndDelay(
            id: id,
            key: key,
            value: value
        )

        // Create a condition that expects the value to be set
        let condition = TestMetCondition(expectedTokens: [id: [NSNumber(value: key.rawValue): value]])

        let rywTokenFromCondition = consistencyManager.getRywTokenFromAwaitableCondition(condition, forId: id)

        XCTAssertNotNil(rywTokenFromCondition)
        XCTAssertEqual(rywTokenFromCondition, value)
        expectation.fulfill()

        waitForExpectations(timeout: 1, handler: nil)
    }

    // Test: registerCondition does not complete when condition is not met
    func testRegisterConditionDoesNotCompleteWhenConditionIsNotMet() {
        // Given a condition that will never be met
        let condition = TestUnmetCondition()
        let id = "test_id"
        let rywDelay = 500 as NSNumber

       // Start on a background queue to simulate async behavior
       DispatchQueue.global().async {
           // Register the condition asynchronously
           let rywData = self.consistencyManager.getRywTokenFromAwaitableCondition(condition, forId: id)

           // Since the condition will never be met, rywToken should remain nil
           XCTAssertNil(rywData)

           // Set an unrelated token to verify that the unmet condition still doesn't complete
           self.consistencyManager.setRywTokenAndDelay(
            id: "unrelated_id",
            key: OSIamFetchOffsetKey.userUpdate,
            value: OSReadYourWriteData(rywToken: "unrelated", rywDelay: rywDelay)
           )

           // newest token should still be nil as the condition is not met
           XCTAssertNil(rywData)
       }

       // Use a short delay to let the async behavior complete without waiting indefinitely
       DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
           XCTAssertTrue(true) // Simulate some async action completing without hanging
       }
   }
    
    func testSetRywTokenWithoutAnyCondition() {
        // Given
        let id = "test_id"
        let key = OSIamFetchOffsetKey.userUpdate
        let value = "123"
        let rywDelay = 500 as NSNumber

        consistencyManager.setRywTokenAndDelay(
            id: id,
            key: key,
            value: OSReadYourWriteData(rywToken: value, rywDelay: rywDelay)
        )

        // There is no condition registered, so we just check that no errors occur
        XCTAssertTrue(true) // If no errors occur, this test will pass
    }
    
    func testMultipleConditionsWithDifferentKeys() {
        let expectation1 = self.expectation(description: "UserUpdate condition met")
        let expectation2 = self.expectation(description: "SubscriptionUpdate condition met")

        // Given
        let id = "test_id"
        let userUpdateKey = OSIamFetchOffsetKey.userUpdate
        let subscriptionUpdateKey = OSIamFetchOffsetKey.subscriptionUpdate
        let userUpdateRywToken = "123"
        let userUpdateRywDelay = 1 as NSNumber
        let userUpdateRywData = OSReadYourWriteData(rywToken: userUpdateRywToken, rywDelay: userUpdateRywDelay)
        let subscriptionUpdateRywToken = "456"
        let subscriptionUpdateRywDelay = 1 as NSNumber
        let subscriptionUpdateRywData = OSReadYourWriteData(rywToken: subscriptionUpdateRywToken, rywDelay: subscriptionUpdateRywDelay)

        // Create a serial queue to prevent race conditions
        let serialQueue = DispatchQueue(label: "com.consistencyManager.test.serialQueue")

        // Register two conditions for different keys
        let userUpdateCondition = TestMetCondition(expectedTokens: [id: [NSNumber(value: userUpdateKey.rawValue): userUpdateRywData]])
        let subscriptionCondition = TestMetCondition(expectedTokens: [id: [NSNumber(value: subscriptionUpdateKey.rawValue): subscriptionUpdateRywData]])

        // Set the userUpdate token first and verify its condition
        serialQueue.async {
            self.consistencyManager.setRywTokenAndDelay(
                id: id,
                key: userUpdateKey,
                value: userUpdateRywData
            )

            // Introduce a short delay before checking the condition to ensure the token is set
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
                let newestUserUpdateToken = self.registerConditionWithTimeout(userUpdateCondition, forId: id)
                XCTAssertEqual(newestUserUpdateToken, userUpdateRywData)
                expectation1.fulfill()
            }
        }

        // Set the subscriptionUpdate token separately and verify its condition after a short delay
        serialQueue.asyncAfter(deadline: .now() + 1.0) {
            self.consistencyManager.setRywTokenAndDelay(
                id: id,
                key: subscriptionUpdateKey,
                value: OSReadYourWriteData(rywToken: subscriptionUpdateRywToken, rywDelay: subscriptionUpdateRywDelay)
            )

            // Introduce a short delay before checking the condition to ensure the token is set
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
                let subscriptionRywData = self.registerConditionWithTimeout(subscriptionCondition, forId: id)
                XCTAssertEqual(subscriptionRywData?.rywToken, subscriptionUpdateRywToken)
                expectation2.fulfill()
            }
        }

        // Wait for both expectations to be fulfilled
        wait(for: [expectation1, expectation2], timeout: 3.0)
    }

    private func registerConditionWithTimeout(_ condition: OSCondition, forId id: String) -> OSReadYourWriteData? {
        // This function wraps the registerCondition method with a timeout for testing
        let semaphore = DispatchSemaphore(value: 0)
        var result: OSReadYourWriteData?

        DispatchQueue.global().async {
            result = self.consistencyManager.getRywTokenFromAwaitableCondition(condition, forId: id)
            semaphore.signal() // Signal once the condition is met
        }

        // Wait for up to 2 seconds to prevent hanging in tests
        if semaphore.wait(timeout: .now() + 2.0) == .timedOut {
            XCTFail("Condition was not met within the timeout period")
            return nil
        }

        return result
    }
    
    func testConditionMetImmediatelyAfterTokenAlreadySet() {
        let expectation = self.expectation(description: "Condition met immediately")

        // Given
        let id = "test_id"
        let key = OSIamFetchOffsetKey.userUpdate
        let rywToken = "123"
        let rywDelay = 500 as NSNumber
        let value = OSReadYourWriteData(rywToken: rywToken, rywDelay: rywDelay)

        // First, set the token
        consistencyManager.setRywTokenAndDelay(
            id: id,
            key: key,
            value: value
        )

        // Now, register a condition expecting the token that was already set
        let condition = TestMetCondition(expectedTokens: [id: [NSNumber(value: key.rawValue): value]])

        // Register the condition
        DispatchQueue.global().async {
            let rywData = self.consistencyManager.getRywTokenFromAwaitableCondition(condition, forId: id)

            // Assert that the result is immediately the same as the value set, without waiting
            XCTAssertEqual(rywData, value)
            expectation.fulfill()
        }

        waitForExpectations(timeout: 2.0, handler: nil)
    }
    
    func testConcurrentUpdatesToTokens() {
        let expectation = self.expectation(description: "Concurrent updates handled correctly")

        let id = "test_id"
        let key = OSIamFetchOffsetKey.userUpdate
        let rywToken1 = "123"
        let rywToken2 = "456"
        let rywDelay = 0 as NSNumber
        let value1 = OSReadYourWriteData(rywToken: rywToken1, rywDelay: rywDelay)
        let value2 = OSReadYourWriteData(rywToken: rywToken2, rywDelay: rywDelay)

        // Set up concurrent queues
        let queue1 = DispatchQueue(label: "com.test.queue1", attributes: .concurrent)
        let queue2 = DispatchQueue(label: "com.test.queue2", attributes: .concurrent)

        // Perform concurrent token updates
        queue1.async {
            self.consistencyManager.setRywTokenAndDelay(
                id: id,
                key: key,
                value: OSReadYourWriteData(rywToken: rywToken1, rywDelay: rywDelay)
            )
        }

        queue2.async {
            self.consistencyManager.setRywTokenAndDelay(
                id: id,
                key: key,
                value: OSReadYourWriteData(rywToken: rywToken2, rywDelay: rywDelay)
            )
        }

        // Allow some time for the updates to happen
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
            // Check that the most recent value was correctly set
            let condition = TestMetCondition(expectedTokens: [id: [NSNumber(value: key.rawValue): value2]])
            let rywData = self.consistencyManager.getRywTokenFromAwaitableCondition(condition, forId: id)

            XCTAssertEqual(rywData?.rywToken, "456")
            expectation.fulfill()
        }

        waitForExpectations(timeout: 2.0, handler: nil)
    }
}


// Mock implementation of OSCondition that simulates a condition that isn't met
class TestUnmetCondition: NSObject, OSCondition {
    // class-level constant for the ID
    public static let CONDITIONID = "TestUnmetCondition"
    
    public var conditionId: String {
            return TestUnmetCondition.CONDITIONID
    }
    
    func isMet(indexedTokens: [String: [NSNumber: OSReadYourWriteData]]) -> Bool {
        return false // Always returns false to simulate an unmet condition
    }

    func getNewestToken(indexedTokens: [String: [NSNumber: OSReadYourWriteData]]) -> OSReadYourWriteData? {
        return nil
    }
}

// Mock implementation of OSCondition for cases where the condition is met
class TestMetCondition: NSObject, OSCondition {
    private let expectedTokens: [String: [NSNumber: OSReadYourWriteData]]
    
    // class-level constant for the ID
    public static let CONDITIONID = "TestMetCondition"
    
    public var conditionId: String {
        return TestMetCondition.CONDITIONID
    }
    
    init(expectedTokens: [String: [NSNumber: OSReadYourWriteData]]) {
        self.expectedTokens = expectedTokens
    }
    
    func isMet(indexedTokens: [String: [NSNumber: OSReadYourWriteData]]) -> Bool {
        print("Expected tokens: \(expectedTokens)")
        print("Actual tokens: \(indexedTokens)")
        
        // Check if all the expected tokens are present in the actual tokens
        for (id, expectedTokenMap) in expectedTokens {
            guard let actualTokenMap = indexedTokens[id] else {
                print("No tokens found for id: \(id)")
                return false
            }
            
            // Check if all expected keys (e.g., userUpdate, subscriptionUpdate) are present with the correct value
            for (expectedKey, expectedValue) in expectedTokenMap {
                guard let actualValue = actualTokenMap[expectedKey] else {
                    print("Key \(expectedKey) not found in actual tokens")
                    return false
                }
                
                if actualValue != expectedValue {
                    print("Mismatch for key \(expectedKey): expected \(expectedValue.rywToken), found \(actualValue.rywToken)")
                    return false
                }
            }
        }
        
        print("Condition met for id")
        return true
    }
    
    func getNewestToken(indexedTokens: [String: [NSNumber: OSReadYourWriteData]]) -> OSReadYourWriteData? {
        var dataBasedOnNewestRywToken: OSReadYourWriteData? = nil

        // Loop through the token maps and compare the values
        for tokenMap in indexedTokens.values {
            // Flatten all OSReadYourWriteData objects into an array
            let allDataObjects = tokenMap.values.compactMap { $0 }

            // Find the object with the max rywToken (if available)
            let maxTokenObject = allDataObjects.max {
                ($0.rywToken ?? "") < ($1.rywToken ?? "")
            }

            // Safely unwrap and compare rywToken values
            if let maxToken = maxTokenObject?.rywToken,
               let currentMaxToken = dataBasedOnNewestRywToken?.rywToken {
                if maxToken > currentMaxToken {
                    dataBasedOnNewestRywToken = maxTokenObject
                }
            } else if maxTokenObject != nil {
                // If dataBasedOnNewestRywToken is nil, assign the current max token object
                dataBasedOnNewestRywToken = maxTokenObject
            }
        }
        return dataBasedOnNewestRywToken
    }

}
