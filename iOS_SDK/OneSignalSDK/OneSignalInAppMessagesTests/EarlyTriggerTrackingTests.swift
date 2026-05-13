/*
 Modified MIT License
 
 Copyright 2025 OneSignal
 
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
import OneSignalOSCore
import OneSignalCoreMocks
import OneSignalOSCoreMocks
import OneSignalUserMocks
import OneSignalInAppMessagesMocks
// @testable import OneSignalUser
// @testable import OneSignalInAppMessages

/**
 Tests for early trigger tracking functionality.

 These tests verify that in-app messages can be displayed on cold starts when their
 triggers are added very early (before IAM fetch completes).
 */
final class EarlyTriggerTrackingTests: XCTestCase {

    private let testSubscriptionId = "test-subscription-id-12345"
    private let testOneSignalId = "test-onesignal-id-12345"
    private let testAppId = "test-app-id"

    override func setUpWithError() throws {
        OneSignalCoreMocks.clearUserDefaults()
        OneSignalUserMocks.reset()
        OSConsistencyManager.shared.reset()
        OSMessagingController.removeInstance()

        // Set up basic configuration
        OneSignalConfigManager.setAppId(testAppId)
        OneSignalLog.setLogLevel(.LL_VERBOSE)
    }

    override func tearDownWithError() throws {
        OSMessagingController.removeInstance()
    }

    /**
     Test that hasCompletedFirstFetch is set to true after the first fetch completes.

     Scenario:
     - Fresh start with no previous fetch
     - First IAM fetch completes

     Expected:
     - hasCompletedFirstFetch changes from false to true
     */
    func testHasCompletedFirstFetch_isSetAfterFirstFetch() throws {
        /* Setup */
        let client = MockOneSignalClient()
        OneSignalCoreImpl.setSharedClient(client)
        OSMessagingController.start()
        let controller = OSMessagingController.sharedInstance()

        // Verify initial state
        XCTAssertFalse(controller.hasCompletedFirstFetch)

        // Set up mock responses
        MockUserRequests.setDefaultCreateAnonUserResponses(with: client, onesignalId: testOneSignalId, subscriptionId: testSubscriptionId)
        ConsistencyManagerTestHelpers.setDefaultRywToken(id: testOneSignalId)

        let response = IAMTestHelpers.testFetchMessagesResponse(messages: [])
        client.setMockResponseForRequest(
            request: "<OSRequestGetInAppMessages from apps/\(testAppId)/subscriptions/\(testSubscriptionId)/iams>",
            response: response)

        /* Execute */
        OneSignalUserManagerImpl.sharedInstance.start()
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)

        /* Verify */
        XCTAssertTrue(controller.hasCompletedFirstFetch)
    }

    /**
     Test that triggers added before the first fetch completes are tracked in earlySessionTriggers.

     Scenario:
     - Cold start, no IAM fetch has completed yet
     - Triggers are added very early in the app lifecycle

     Expected:
     - hasCompletedFirstFetch is false
     - Triggers are added to earlySessionTriggers
     */
    func testTriggersAddedBeforeFirstFetch_areTrackedInEarlySessionTriggers() throws {
        /* Setup */
        let client = MockOneSignalClient()
        OneSignalCoreImpl.setSharedClient(client)
        OSMessagingController.start()
        let controller = OSMessagingController.sharedInstance()

        // Verify initial state
        XCTAssertFalse(controller.hasCompletedFirstFetch)
        XCTAssertEqual(controller.earlySessionTriggers.count, 0)

        /* Execute */
        // Add triggers before first fetch completes
        controller.addTriggers(["trigger1": "value1", "trigger2": "value2"])

        /* Verify */
        XCTAssertFalse(controller.hasCompletedFirstFetch)
        XCTAssertEqual(controller.earlySessionTriggers.count, 2)
        XCTAssertTrue(controller.earlySessionTriggers.contains("trigger1"))
        XCTAssertTrue(controller.earlySessionTriggers.contains("trigger2"))
    }

    /**
     Test that multiple calls to addTriggers before first fetch accumulate in earlySessionTriggers.

     Scenario:
     - Multiple trigger additions before first fetch completes

     Expected:
     - All trigger keys are accumulated in earlySessionTriggers
     */
    func testMultipleTriggersAddedBeforeFirstFetch_areAllTracked() throws {
        /* Setup */
        let client = MockOneSignalClient()
        OneSignalCoreImpl.setSharedClient(client)
        OSMessagingController.start()
        let controller = OSMessagingController.sharedInstance()

        /* Execute */
        // Add triggers in multiple calls
        controller.addTriggers(["trigger1": "value1"])
        controller.addTriggers(["trigger2": "value2"])
        controller.addTriggers(["trigger3": "value3"])

        /* Verify */
        XCTAssertFalse(controller.hasCompletedFirstFetch, )
        XCTAssertEqual(controller.earlySessionTriggers.count, 3)
        XCTAssertTrue(controller.earlySessionTriggers.contains("trigger1"))
        XCTAssertTrue(controller.earlySessionTriggers.contains("trigger2"))
        XCTAssertTrue(controller.earlySessionTriggers.contains("trigger3"))
    }

    /**
     Test that triggers added after the first fetch completes are NOT tracked in earlySessionTriggers.

     Scenario:
     - First IAM fetch has completed
     - New triggers are added

     Expected:
     - hasCompletedFirstFetch is true
     - Triggers are NOT added to earlySessionTriggers
     */
    func testTriggersAddedAfterFirstFetch_areNotTrackedInEarlySessionTriggers() throws {
        /* Setup */
        let client = MockOneSignalClient()
        OneSignalCoreImpl.setSharedClient(client)
        OSMessagingController.start()
        let controller = OSMessagingController.sharedInstance()

        // Set up mock responses
        MockUserRequests.setDefaultCreateAnonUserResponses(with: client, onesignalId: testOneSignalId, subscriptionId: testSubscriptionId)
        ConsistencyManagerTestHelpers.setDefaultRywToken(id: testOneSignalId)

        // Set up IAM fetch response with an empty message list
        let response = IAMTestHelpers.testFetchMessagesResponse(messages: [])
        client.setMockResponseForRequest(
            request: "<OSRequestGetInAppMessages from apps/\(testAppId)/subscriptions/\(testSubscriptionId)/iams>",
            response: response)

        // Start the SDK and trigger first fetch
        OneSignalUserManagerImpl.sharedInstance.start()
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 2.0)

        // Verify first fetch completed
        XCTAssertTrue(controller.hasCompletedFirstFetch)
        XCTAssertEqual(controller.earlySessionTriggers.count, 0)

        /* Execute */
        // Add triggers after first fetch
        controller.addTriggers(["lateAction": "value"])

        /* Verify */
        XCTAssertTrue(controller.hasCompletedFirstFetch)
        XCTAssertEqual(controller.earlySessionTriggers.count, 0)

        // Verify the triggers were still added to the trigger controller
        XCTAssertTrue(controller.triggerController.messageMatchesTriggers(
            OSInAppMessageInternal.instance(withJson: IAMTestHelpers.testMessageJsonWithTrigger(
                kind: OS_DYNAMIC_TRIGGER_KIND_CUSTOM,
                property: "lateAction",
                triggerId: "test_id",
                type: 2, // equal
                value: "value"
            ))!
        ))
    }

    /**
     Test that messages matching early triggers get isTriggerChanged flag set when received from server.

     Scenario:
     - Triggers are added before first fetch
     - IAM fetch completes with messages that were previously shown (in redisplayedInAppMessages)
     - Some messages match the early triggers

     Expected:
     - Messages matching early triggers have isTriggerChanged = true
     - Messages not matching early triggers have isTriggerChanged = false
     - earlySessionTriggers is cleared after processing
     - hasCompletedFirstFetch is true after fetch
     */
    func testMessagesMatchingEarlyTriggers_getIsTriggerChangedFlag() throws {
        /* Setup */
        let client = MockOneSignalClient()
        OneSignalCoreImpl.setSharedClient(client)
        OSMessagingController.start()
        let controller = OSMessagingController.sharedInstance()

        // Add triggers before first fetch
        controller.addTriggers(["loginAction": "complete", "sessionStart": "true"])

        // Verify triggers were tracked
        XCTAssertEqual(controller.earlySessionTriggers.count, 2)
        XCTAssertFalse(controller.hasCompletedFirstFetch)

        // Set up mock responses
        MockUserRequests.setDefaultCreateAnonUserResponses(with: client, onesignalId: testOneSignalId, subscriptionId: testSubscriptionId)
        ConsistencyManagerTestHelpers.setDefaultRywToken(id: testOneSignalId)

        // Create test messages:
        // Message 1: Matches early trigger "loginAction"
        let message1Json = IAMTestHelpers.testMessageJsonWithTrigger(
            kind: OS_DYNAMIC_TRIGGER_KIND_CUSTOM,
            property: "loginAction",
            triggerId: "trigger1",
            type: 2, // equal
            value: "complete"
        )
        let message1 = OSInAppMessageInternal.instance(withJson: message1Json)!

        // Message 2: Matches early trigger "sessionStart"
        let message2Json = IAMTestHelpers.testMessageJsonWithTrigger(
            kind: OS_DYNAMIC_TRIGGER_KIND_CUSTOM,
            property: "sessionStart",
            triggerId: "trigger2",
            type: 2, // equal
            value: "true"
        )
        let message2 = OSInAppMessageInternal.instance(withJson: message2Json)!

        // Message 3: Does not match any early trigger
        let message3Json = IAMTestHelpers.testMessageJsonWithTrigger(
            kind: OS_DYNAMIC_TRIGGER_KIND_CUSTOM,
            property: "otherAction",
            triggerId: "trigger3",
            type: 2, // equal
            value: "something"
        )
        let message3 = OSInAppMessageInternal.instance(withJson: message3Json)!

        // Mark messages 1 and 2 as previously displayed (so they're in redisplayedInAppMessages)
        controller.redisplayedInAppMessages[message1.messageId] = message1
        controller.redisplayedInAppMessages[message2.messageId] = message2

        // Set up IAM fetch response
        let response = IAMTestHelpers.testFetchMessagesResponse(messages: [message1Json, message2Json, message3Json])
        client.setMockResponseForRequest(
            request: "<OSRequestGetInAppMessages from apps/\(testAppId)/subscriptions/\(testSubscriptionId)/iams>",
            response: response)

        /* Execute */
        // Start the SDK and trigger first fetch
        OneSignalUserManagerImpl.sharedInstance.start()
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 2.0)

        /* Verify */
        // First fetch should have completed
        XCTAssertTrue(controller.hasCompletedFirstFetch)

        // Early triggers should be cleared
        XCTAssertEqual(controller.earlySessionTriggers.count, 0)

        // Messages should be received
        XCTAssertEqual(controller.messages.count, 3)

        // Cast to properly typed array and find the messages
        let messages = controller.messages as! [OSInAppMessageInternal]
        let receivedMessage1 = messages.first { $0.messageId == message1.messageId }
        let receivedMessage2 = messages.first { $0.messageId == message2.messageId }
        let receivedMessage3 = messages.first { $0.messageId == message3.messageId }

        XCTAssertNotNil(receivedMessage1)
        XCTAssertNotNil(receivedMessage2)
        XCTAssertNotNil(receivedMessage3)

        // Messages matching early triggers and in redisplayedInAppMessages should have isTriggerChanged = true
        XCTAssertTrue(receivedMessage1!.isTriggerChanged)
        XCTAssertTrue(receivedMessage2!.isTriggerChanged)

        // Message 3 does not match early triggers (even though not in redisplayedInAppMessages anyway)
        XCTAssertFalse(receivedMessage3!.isTriggerChanged)
    }

    /**
     Test that messages NOT in redisplayedInAppMessages don't get isTriggerChanged flag, even if they match early triggers.

     Scenario:
     - Triggers are added before first fetch
     - IAM fetch completes with messages that were NOT previously shown
     - Messages match the early triggers

     Expected:
     - Messages should NOT have isTriggerChanged = true (because they weren't in redisplayedInAppMessages)
     */
    func testMessagesNotInRedisplayed_dontGetIsTriggerChangedFlag() throws {
        /* Setup */
        let client = MockOneSignalClient()
        OneSignalCoreImpl.setSharedClient(client)
        OSMessagingController.start()
        let controller = OSMessagingController.sharedInstance()

        // Add triggers before first fetch
        controller.addTriggers(["newTrigger": "value"])

        // Set up mock responses
        MockUserRequests.setDefaultCreateAnonUserResponses(with: client, onesignalId: testOneSignalId, subscriptionId: testSubscriptionId)
        ConsistencyManagerTestHelpers.setDefaultRywToken(id: testOneSignalId)

        // Create a test message that matches the early trigger
        let messageJson = IAMTestHelpers.testMessageJsonWithTrigger(
            kind: OS_DYNAMIC_TRIGGER_KIND_CUSTOM,
            property: "newTrigger",
            triggerId: "trigger1",
            type: 2, // equal
            value: "value"
        )
        let message = OSInAppMessageInternal.instance(withJson: messageJson)!

        // Do NOT add this message to redisplayedInAppMessages

        // Set up IAM fetch response
        let response = IAMTestHelpers.testFetchMessagesResponse(messages: [messageJson])
        client.setMockResponseForRequest(
            request: "<OSRequestGetInAppMessages from apps/\(testAppId)/subscriptions/\(testSubscriptionId)/iams>",
            response: response)

        /* Execute */
        // Start the SDK and trigger first fetch
        OneSignalUserManagerImpl.sharedInstance.start()
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 1.0)

        /* Verify */
        XCTAssertTrue(controller.hasCompletedFirstFetch)
        XCTAssertEqual(controller.messages.count, 1)

        let messages = controller.messages as! [OSInAppMessageInternal]
        let receivedMessage = messages.first { $0.messageId == message.messageId }
        XCTAssertNotNil(receivedMessage)

        // Message should NOT have isTriggerChanged because it's not in redisplayedInAppMessages
        XCTAssertFalse(receivedMessage!.isTriggerChanged)
    }

    /**
     Test that earlySessionTriggers only applies to messages with shared trigger keys.

     Scenario:
     - Multiple triggers added early
     - Messages with different trigger combinations

     Expected:
     - Only messages with matching trigger keys get isTriggerChanged
     */
    func testIsTriggerChanged_onlyAppliedToMessagesWithMatchingTriggerKeys() throws {
        /* Setup */
        let client = MockOneSignalClient()
        OneSignalCoreImpl.setSharedClient(client)
        OSMessagingController.start()
        let controller = OSMessagingController.sharedInstance()

        // Add specific triggers before first fetch
        controller.addTriggers(["action_a": "value1"])

        // Set up mock responses
        MockUserRequests.setDefaultCreateAnonUserResponses(with: client, onesignalId: testOneSignalId, subscriptionId: testSubscriptionId)
        ConsistencyManagerTestHelpers.setDefaultRywToken(id: testOneSignalId)

        // Message 1: Uses trigger "action_a" (matches early triggers)
        let message1Json = IAMTestHelpers.testMessageJsonWithTrigger(
            kind: OS_DYNAMIC_TRIGGER_KIND_CUSTOM,
            property: "action_a",
            triggerId: "trigger1",
            type: 2,
            value: "value1"
        )
        let message1 = OSInAppMessageInternal.instance(withJson: message1Json)!

        // Message 2: Uses trigger "action_b" (does NOT match early triggers)
        let message2Json = IAMTestHelpers.testMessageJsonWithTrigger(
            kind: OS_DYNAMIC_TRIGGER_KIND_CUSTOM,
            property: "action_b",
            triggerId: "trigger2",
            type: 2,
            value: "value2"
        )
        let message2 = OSInAppMessageInternal.instance(withJson: message2Json)!

        // Mark both as previously displayed
        controller.redisplayedInAppMessages[message1.messageId] = message1
        controller.redisplayedInAppMessages[message2.messageId] = message2

        // Set up IAM fetch response
        let response = IAMTestHelpers.testFetchMessagesResponse(messages: [message1Json, message2Json])
        client.setMockResponseForRequest(
            request: "<OSRequestGetInAppMessages from apps/\(testAppId)/subscriptions/\(testSubscriptionId)/iams>",
            response: response)

        /* Execute */
        OneSignalUserManagerImpl.sharedInstance.start()
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 1.0)

        /* Verify */
        let messages = controller.messages as! [OSInAppMessageInternal]
        let receivedMessage1 = messages.first { $0.messageId == message1.messageId }
        let receivedMessage2 = messages.first { $0.messageId == message2.messageId }

        XCTAssertNotNil(receivedMessage1)
        XCTAssertNotNil(receivedMessage2)

        // Only message 1 should have isTriggerChanged (it has shared trigger "action_a")
        XCTAssertTrue(receivedMessage1!.isTriggerChanged)
        XCTAssertFalse(receivedMessage2!.isTriggerChanged)
    }
}
