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

private class CustomEventsMocks {
    let client = MockOneSignalClient()
    let newRecordsState = MockNewRecordsState()
    let customEventsExecutor: OSCustomEventsExecutor

    init() {
        OneSignalCoreImpl.setSharedClient(client)
        customEventsExecutor = OSCustomEventsExecutor(newRecordsState: newRecordsState)
    }
}

final class OSCustomEventsExecutorTests: XCTestCase {
    func createCustomEventDelta(
        name: String,
        properties: [String: Any]?,
        identityModel: OSIdentityModel
    ) -> OSDelta {
        return OSDelta(
            name: OS_CUSTOM_EVENT_DELTA,
            identityModelId: identityModel.modelId,
            model: identityModel,
            property: name,
            value: properties ?? [:]
        )
    }

    override func setUpWithError() throws {
        OneSignalCoreMocks.clearUserDefaults()
        OneSignalUserMocks.reset()
        OneSignalConfigManager.setAppId("test-app-id")
        OneSignalLog.setLogLevel(.LL_VERBOSE)
    }

    override func tearDownWithError() throws {
        OneSignalCoreMocks.clearUserDefaults()
    }

    // MARK: - Basic Event Tracking Tests

    func testTrackEvent_withProperties_sendsRequest() {
        /* Setup */
        let mocks = CustomEventsMocks()
        let user = OneSignalUserMocks.setUserManagerInternalUser(onesignalId: userA_OSID)

        let properties = ["key1": "value1", "key2": 123, "key3": true] as [String: Any]
        let delta = createCustomEventDelta(name: "test_event", properties: properties, identityModel: user.identityModel)

        mocks.client.fireSuccessForAllRequests = true

        /* When */
        mocks.customEventsExecutor.enqueueDelta(delta)
        mocks.customEventsExecutor.processDeltaQueue(inBackground: false)
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)

        /* Then */
        XCTAssertTrue(mocks.client.hasExecutedRequestOfType(OSRequestCustomEvents.self))
        XCTAssertEqual(mocks.client.executedRequests.count, 1)

        guard let request = mocks.client.executedRequests.first as? OSRequestCustomEvents else {
            XCTFail("Expected OSRequestCustomEvents")
            return
        }

        // Verify the request contains the event with correct structure
        guard let events = request.parameters!["events"] as? [[String: Any]],
              let event = events.first else {
            XCTFail("Expected events array in request parameters")
            return
        }

        // Verify event-level fields
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(event["name"] as! String, "test_event")
        XCTAssertEqual(event["onesignal_id"] as! String, userA_OSID)

        // Verify timestamp exists and is a valid ISO8601 formatted string
        guard let timestampString = event["timestamp"] as? String else {
            XCTFail("Expected timestamp as String")
            return
        }

        // Verify it can be parsed as ISO8601
        let iso8601Formatter = ISO8601DateFormatter()
        guard let parsedDate = iso8601Formatter.date(from: timestampString) else {
            XCTFail("Expected timestamp to be valid ISO8601 format, got: \(timestampString)")
            return
        }
        XCTAssertNotNil(parsedDate)

        // Verify payload contains user properties and os_sdk metadata
        guard let payload = event["payload"] as? [String: Any] else {
            XCTFail("Expected payload in event")
            return
        }

        // Verify user-provided properties
        XCTAssertEqual(payload["key1"] as! String, "value1")
        XCTAssertEqual(payload["key2"] as! Int, 123)
        XCTAssertEqual(payload["key3"] as! Bool, true)

        // Verify payload contains exactly the expected keys (user properties + os_sdk)
        let expectedKeys = Set(["key1", "key2", "key3", "os_sdk"])
        let actualKeys = Set(payload.keys)
        XCTAssertEqual(actualKeys, expectedKeys, "Payload should contain only user properties and os_sdk")
    }

    func testTrackEvent_withEmptyProperties_sendsRequestWithEmptyPayload() {
        /* Setup */
        let mocks = CustomEventsMocks()
        let user = OneSignalUserMocks.setUserManagerInternalUser(onesignalId: userA_OSID)

        let delta = createCustomEventDelta(name: "event_empty_props", properties: [:], identityModel: user.identityModel)

        mocks.client.fireSuccessForAllRequests = true

        /* When */
        mocks.customEventsExecutor.enqueueDelta(delta)
        mocks.customEventsExecutor.processDeltaQueue(inBackground: false)
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)

        /* Then */
        XCTAssertTrue(mocks.client.hasExecutedRequestOfType(OSRequestCustomEvents.self))

        guard let request = mocks.client.executedRequests.first as? OSRequestCustomEvents,
              let events = request.parameters!["events"] as? [[String: Any]],
              let event = events.first,
              let payload = event["payload"] as? [String: Any] else {
            XCTFail("Expected valid request structure")
            return
        }

        // Should only contain os_sdk metadata
        XCTAssertNotNil(payload["os_sdk"])
        XCTAssertEqual(payload.count, 1)
    }

    func testTrackEvent_withNestedProperties_sendsRequestWithNestedStructure() {
        /* Setup */
        let mocks = CustomEventsMocks()
        let user = OneSignalUserMocks.setUserManagerInternalUser(onesignalId: userA_OSID)

        let properties = [
            "topLevel": "value",
            "nested": [
                "foo": "bar",
                "booleanVal": true,
                "number": 3.14
            ]
        ] as [String: Any]

        let delta = createCustomEventDelta(name: "nested_event", properties: properties, identityModel: user.identityModel)

        mocks.client.fireSuccessForAllRequests = true

        /* When */
        mocks.customEventsExecutor.enqueueDelta(delta)
        mocks.customEventsExecutor.processDeltaQueue(inBackground: false)
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)

        /* Then */
        XCTAssertTrue(mocks.client.hasExecutedRequestOfType(OSRequestCustomEvents.self))
        XCTAssertEqual(mocks.client.executedRequests.count, 1)

        guard let request = mocks.client.executedRequests.first as? OSRequestCustomEvents,
              let events = request.parameters!["events"] as? [[String: Any]],
              let event = events.first,
              let payload = event["payload"] as? [String: Any],
              let nested = payload["nested"] as? [String: Any] else {
            XCTFail("Expected valid nested structure")
            return
        }

        XCTAssertEqual(payload["topLevel"] as? String, "value")
        XCTAssertEqual(nested["foo"] as? String, "bar")
        XCTAssertEqual(nested["booleanVal"] as? Bool, true)
        XCTAssertEqual(nested["number"] as? Double, 3.14)
    }

    // MARK: - Multiple Events Tests (No Batching)

    func testProcessDeltaQueue_withMultipleEventsForSameUser_createsSeparateRequests() {
        /* Setup */
        let mocks = CustomEventsMocks()
        let user = OneSignalUserMocks.setUserManagerInternalUser(onesignalId: userA_OSID)

        let delta1 = createCustomEventDelta(name: "event1", properties: ["key": "value1"], identityModel: user.identityModel)
        let delta2 = createCustomEventDelta(name: "event2", properties: ["key": "value2"], identityModel: user.identityModel)
        let delta3 = createCustomEventDelta(name: "event3", properties: nil, identityModel: user.identityModel)

        mocks.client.fireSuccessForAllRequests = true

        /* When */
        mocks.customEventsExecutor.enqueueDelta(delta1)
        mocks.customEventsExecutor.enqueueDelta(delta2)
        mocks.customEventsExecutor.enqueueDelta(delta3)
        mocks.customEventsExecutor.processDeltaQueue(inBackground: false)
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)

        /* Then */
        // Should have 3 separate requests, one per event (no batching)
        XCTAssertEqual(mocks.client.executedRequests.count, 3)

        let requests = mocks.client.executedRequests.compactMap { $0 as? OSRequestCustomEvents }
        XCTAssertEqual(requests.count, 3)

        // Verify each request has exactly 1 event
        for request in requests {
            guard let events = request.parameters!["events"] as? [[String: Any]] else {
                XCTFail("Expected events array in request")
                return
            }
            XCTAssertEqual(events.count, 1, "Each request should contain exactly 1 event")
        }

        // Verify all event names are present
        let eventNames = requests.compactMap { request -> String? in
            guard let events = request.parameters!["events"] as? [[String: Any]],
                  let event = events.first else {
                return nil
            }
            return event["name"] as? String
        }.sorted()

        XCTAssertEqual(eventNames, ["event1", "event2", "event3"])
    }

    func testProcessDeltaQueue_withEventsForMultipleUsers_createsSeparateRequestsPerEvent() {
        /* Setup */
        let mocks = CustomEventsMocks()
        let userA = OneSignalUserMocks.setUserManagerInternalUser(onesignalId: userA_OSID)
        let userB = OneSignalUserMocks.setUserManagerInternalUser(onesignalId: userB_OSID)

        let deltaUserA1 = createCustomEventDelta(name: "userA_event1", properties: ["user": "A"], identityModel: userA.identityModel)
        let deltaUserA2 = createCustomEventDelta(name: "userA_event2", properties: ["user": "A"], identityModel: userA.identityModel)
        let deltaUserB1 = createCustomEventDelta(name: "userB_event1", properties: ["user": "B"], identityModel: userB.identityModel)

        mocks.client.fireSuccessForAllRequests = true

        /* When */
        mocks.customEventsExecutor.enqueueDelta(deltaUserA1)
        mocks.customEventsExecutor.enqueueDelta(deltaUserA2)
        mocks.customEventsExecutor.enqueueDelta(deltaUserB1)
        mocks.customEventsExecutor.processDeltaQueue(inBackground: false)
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)

        /* Then */
        // Should have 3 separate requests, one per event (no batching)
        XCTAssertEqual(mocks.client.executedRequests.count, 3)

        let requests = mocks.client.executedRequests.compactMap { $0 as? OSRequestCustomEvents }
        XCTAssertEqual(requests.count, 3)

        // Verify each request has exactly 1 event
        for request in requests {
            guard let events = request.parameters!["events"] as? [[String: Any]] else {
                XCTFail("Expected events array in request")
                return
            }
            XCTAssertEqual(events.count, 1, "Each request should contain exactly 1 event")
        }

        // Count events by user
        let eventsByUser = requests.reduce(into: [String: Int]()) { counts, request in
            guard let events = request.parameters!["events"] as? [[String: Any]],
                  let event = events.first,
                  let onesignalId = event["onesignal_id"] as? String else {
                return
            }
            counts[onesignalId, default: 0] += 1
        }

        XCTAssertEqual(eventsByUser[userA_OSID], 2, "Should have 2 events for userA")
        XCTAssertEqual(eventsByUser[userB_OSID], 1, "Should have 1 event for userB")
    }

    // MARK: - Missing OneSignal ID Tests

    func testProcessDeltaQueue_withoutOnesignalId_doesNotSendRequest() {
        /* Setup */
        let mocks = CustomEventsMocks()
        let user = OneSignalUserMocks.setUserManagerInternalUser(onesignalId: nil)

        let delta = createCustomEventDelta(name: "blocked_event", properties: ["key": "value"], identityModel: user.identityModel)

        mocks.client.fireSuccessForAllRequests = true

        /* When */
        mocks.customEventsExecutor.enqueueDelta(delta)
        mocks.customEventsExecutor.processDeltaQueue(inBackground: false)
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)

        /* Then */
        // No request should be made
        XCTAssertFalse(mocks.client.hasExecutedRequestOfType(OSRequestCustomEvents.self))
        XCTAssertEqual(mocks.client.executedRequests.count, 0)
    }

    // MARK: - Caching Tests

    func testCacheDeltaQueue_persistsDeltasToStorage() {
        /* Setup */
        let mocks = CustomEventsMocks()
        let user = OneSignalUserMocks.setUserManagerInternalUser(onesignalId: userA_OSID)

        let delta = createCustomEventDelta(name: "cached_event", properties: ["key": "value"], identityModel: user.identityModel)

        /* When */
        mocks.customEventsExecutor.enqueueDelta(delta)
        mocks.customEventsExecutor.cacheDeltaQueue()
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.3)

        /* Then - Verify delta is cached */
        let cachedDeltas = OneSignalUserDefaults.initShared().getSavedCodeableData(
            forKey: OS_CUSTOM_EVENTS_EXECUTOR_DELTA_QUEUE_KEY,
            defaultValue: []
        ) as? [OSDelta]

        XCTAssertEqual(cachedDeltas?.count, 1)
        XCTAssertEqual(cachedDeltas?.first?.property, "cached_event")
    }

    func testUncacheDeltas_restoresDeltasFromStorage() {
        /* Setup */
        let user = OneSignalUserMocks.setUserManagerInternalUser(onesignalId: userA_OSID)
        let delta = createCustomEventDelta(name: "restored_event", properties: ["key": "value1"], identityModel: user.identityModel)

        OneSignalUserDefaults.initShared().saveCodeableData(
            forKey: OS_CUSTOM_EVENTS_EXECUTOR_DELTA_QUEUE_KEY,
            withValue: [delta]
        )

        /* When - Create new executor which uncaches deltas in init */
        let mocks = CustomEventsMocks()
        mocks.client.fireSuccessForAllRequests = true

        mocks.customEventsExecutor.processDeltaQueue(inBackground: false)
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)

        /* Then */
        XCTAssertTrue(mocks.client.hasExecutedRequestOfType(OSRequestCustomEvents.self))

        guard let request = mocks.client.executedRequests.first as? OSRequestCustomEvents,
              let events = request.parameters?["events"] as? [[String: Any]],
              let event = events.first else {
            XCTFail("Expected valid request")
            return
        }

        XCTAssertEqual(event["name"] as? String, "restored_event")
    }

    // MARK: - SDK Metadata Tests

    func testTrackEvent_includesSdkMetadata() {
        /* Setup */
        let mocks = CustomEventsMocks()
        let user = OneSignalUserMocks.setUserManagerInternalUser(onesignalId: userA_OSID)

        let delta = createCustomEventDelta(name: "metadata_event", properties: ["user_key": "user_value"], identityModel: user.identityModel)

        mocks.client.fireSuccessForAllRequests = true

        /* When */
        mocks.customEventsExecutor.enqueueDelta(delta)
        mocks.customEventsExecutor.processDeltaQueue(inBackground: false)
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)

        /* Then */
        guard let request = mocks.client.executedRequests.first as? OSRequestCustomEvents,
              let events = request.parameters!["events"] as? [[String: Any]],
              let event = events.first,
              let payload = event["payload"] as? [String: Any],
              let osSdk = payload["os_sdk"] as? [String: Any] else {
            XCTFail("Expected valid request with os_sdk metadata")
            return
        }

        // Verify os_sdk metadata fields
        XCTAssertEqual(osSdk["device_type"] as? String, "ios")
        XCTAssertEqual(osSdk["type"] as? String, "iOSPush")
        XCTAssertNotNil(osSdk["sdk"])
        XCTAssertNotNil(osSdk["device_os"])
        XCTAssertNotNil(osSdk["device_model"])
        XCTAssertNotNil(osSdk["app_version"])

        // Verify user properties are still present
        XCTAssertEqual(payload["user_key"] as? String, "user_value")
    }
}
