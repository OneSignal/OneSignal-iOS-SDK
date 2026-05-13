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

import XCTest
import OneSignalCore
import OneSignalOSCore
import OneSignalCoreMocks
import OneSignalOSCoreMocks
import OneSignalUserMocks
@testable import OneSignalUser

final class CustomEventsIntegrationTests: XCTestCase {

    override func setUpWithError() throws {
        OneSignalCoreMocks.clearUserDefaults()
        OneSignalUserMocks.reset()
        OneSignalConfigManager.setAppId("test-app-id")
        OneSignalLog.setLogLevel(.LL_VERBOSE)
    }

    override func tearDownWithError() throws {
        OneSignalCoreMocks.clearUserDefaults()
    }

    // MARK: - Public API Tests

    func testTrackEvent_withValidProperties_enqueuesdelta() {
        /* Setup */
        let client = MockOneSignalClient()
        OneSignalCoreImpl.setSharedClient(client)
        client.fireSuccessForAllRequests = true

        let userManager = OneSignalUserManagerImpl.sharedInstance

        _ = OneSignalUserMocks.setUserManagerInternalUser(externalId: userA_EUID, onesignalId: userA_OSID)

        let properties = ["string_key": "value", "number_key": 42, "bool_key": true] as [String: Any]

        /* When */
        userManager.trackEvent(name: "test_event", properties: properties)
        OSOperationRepo.sharedInstance.addFlushDeltaQueueToDispatchQueue()
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)

        /* Then */
        XCTAssertTrue(client.hasExecutedRequestOfType(OSRequestCustomEvents.self))
    }

    func testTrackEvent_withNilProperties_enqueuesdelta() {
        /* Setup */
        let client = MockOneSignalClient()
        OneSignalCoreImpl.setSharedClient(client)
        client.fireSuccessForAllRequests = true

        let userManager = OneSignalUserManagerImpl.sharedInstance
        _ = OneSignalUserMocks.setUserManagerInternalUser(externalId: userA_EUID, onesignalId: userA_OSID)

        /* When */
        userManager.trackEvent(name: "test_event", properties: nil)
        OSOperationRepo.sharedInstance.addFlushDeltaQueueToDispatchQueue()
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)

        /* Then */
        XCTAssertTrue(client.hasExecutedRequestOfType(OSRequestCustomEvents.self))
    }

    func testTrackEvent_withEmptyProperties_enqueuesdelta() {
        /* Setup */
        let client = MockOneSignalClient()
        OneSignalCoreImpl.setSharedClient(client)
        client.fireSuccessForAllRequests = true

        let userManager = OneSignalUserManagerImpl.sharedInstance
        _ = OneSignalUserMocks.setUserManagerInternalUser(externalId: userA_EUID, onesignalId: userA_OSID)

        /* When */
        userManager.trackEvent(name: "test_event", properties: [:])
        OSOperationRepo.sharedInstance.addFlushDeltaQueueToDispatchQueue()
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)

        /* Then */
        XCTAssertTrue(client.hasExecutedRequestOfType(OSRequestCustomEvents.self))
    }

    func testTrackEvent_withInvalidProperties_doesNotEnqueueDelta() {
        /* Setup */
        let client = MockOneSignalClient()
        OneSignalCoreImpl.setSharedClient(client)
        client.fireSuccessForAllRequests = true

        let userManager = OneSignalUserManagerImpl.sharedInstance
        _ = OneSignalUserMocks.setUserManagerInternalUser(externalId: userA_EUID, onesignalId: userA_OSID)

        // Create an invalid property (Date is not JSON serializable)
        let invalidProperties = ["date": Date()] as [String: Any]

        /* When */
        userManager.trackEvent(name: "test_event", properties: invalidProperties)
        OSOperationRepo.sharedInstance.addFlushDeltaQueueToDispatchQueue()
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)

        /* Then - No request should be made */
        XCTAssertFalse(client.hasExecutedRequestOfType(OSRequestCustomEvents.self))
        XCTAssertEqual(client.executedRequests.count, 0)
    }

    // MARK: - Property Validation Tests

    func testTrackEvent_withComplexNestedStructure_sendsCorrectly() {
        /* Setup */
        let client = MockOneSignalClient()
        OneSignalCoreImpl.setSharedClient(client)
        client.fireSuccessForAllRequests = true

        let userManager = OneSignalUserManagerImpl.sharedInstance
        _ = OneSignalUserMocks.setUserManagerInternalUser(externalId: userA_EUID, onesignalId: userA_OSID)

        let complexProperties = [
            "level1": "string_value",
            "level1_number": 123,
            "level1_bool": false,
            "level1_nested": [
                "level2_key": "level2_value",
                "level2_number": 456,
                "level2_nested": [
                    "level3_key": "level3_value",
                    "level3_array": [1, 2, 3]
                ]
            ]
        ] as [String: Any]

        /* When */
        userManager.trackEvent(name: "complex_event", properties: complexProperties)
        OSOperationRepo.sharedInstance.addFlushDeltaQueueToDispatchQueue()
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)

        /* Then */
        XCTAssertTrue(client.hasExecutedRequestOfType(OSRequestCustomEvents.self))

        guard let request = client.executedRequests.first as? OSRequestCustomEvents,
              let events = request.parameters!["events"] as? [[String: Any]],
              let event = events.first,
              let payload = event["payload"] as? [String: Any] else {
            XCTFail("Expected valid payload")
            return
        }

        // Verify event-level fields
        XCTAssertEqual(event["name"] as? String, "complex_event")
        XCTAssertEqual(event["onesignal_id"] as? String, userA_OSID)

        // Verify level 1 properties
        XCTAssertEqual(payload["level1"] as? String, "string_value")
        XCTAssertEqual(payload["level1_number"] as? Int, 123)
        XCTAssertEqual(payload["level1_bool"] as? Bool, false)

        // Verify level 1 nested object exists and has correct structure
        guard let level1Nested = payload["level1_nested"] as? [String: Any] else {
            XCTFail("Expected level1_nested object")
            return
        }

        // Verify level 2 properties
        XCTAssertEqual(level1Nested["level2_key"] as? String, "level2_value")
        XCTAssertEqual(level1Nested["level2_number"] as? Int, 456)

        // Verify level 2 nested object exists
        guard let level2Nested = level1Nested["level2_nested"] as? [String: Any] else {
            XCTFail("Expected level2_nested object")
            return
        }

        // Verify level 3 properties
        XCTAssertEqual(level2Nested["level3_key"] as? String, "level3_value")

        // Verify level 3 array
        guard let level3Array = level2Nested["level3_array"] as? [Int] else {
            XCTFail("Expected level3_array as array of Int")
            return
        }
        XCTAssertEqual(level3Array.count, 3)
    }

    func testTrackEvent_withArrayProperties_sendsCorrectly() {
        /* Setup */
        let client = MockOneSignalClient()
        OneSignalCoreImpl.setSharedClient(client)
        client.fireSuccessForAllRequests = true

        let userManager = OneSignalUserManagerImpl.sharedInstance
        _ = OneSignalUserMocks.setUserManagerInternalUser(externalId: userA_EUID, onesignalId: userA_OSID)

        let properties = [
            "items": ["item1", "item2", "item3"],
            "numbers": [1, 2, 3, 4, 5]
        ] as [String: Any]

        /* When */
        userManager.trackEvent(name: "array_event", properties: properties)
        OSOperationRepo.sharedInstance.addFlushDeltaQueueToDispatchQueue()
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)

        /* Then */
        XCTAssertTrue(client.hasExecutedRequestOfType(OSRequestCustomEvents.self))

        guard let request = client.executedRequests.first as? OSRequestCustomEvents,
              let events = request.parameters!["events"] as? [[String: Any]],
              let event = events.first,
              let payload = event["payload"] as? [String: Any] else {
            XCTFail("Expected valid request structure")
            return
        }

        XCTAssertNotNil(payload["items"] as? [String])
        XCTAssertNotNil(payload["numbers"] as? [Int])
    }
}
