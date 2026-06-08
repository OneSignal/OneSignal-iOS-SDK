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
import OneSignalInAppMessagesMocks

final class TriggerTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    /**
     Test that NotEqualTo trigger does NOT match non-existent properties.
     */
    func testNotEqualToTrigger_doesNotMatchNonExistentProperty() throws {
        /* Setup */
        let triggerController = OSTriggerController()

        // Create a message with NotEqualTo trigger
        let messageJson = IAMTestHelpers.testMessageJsonWithTrigger(
            kind: OS_DYNAMIC_TRIGGER_KIND_CUSTOM,
            property: "prop",
            triggerId: "test_trigger",
            type: 3, // OSTriggerOperatorTypeNotEqualTo
            value: "value"
        )
        let message = OSInAppMessageInternal.instance(withJson: messageJson)
        XCTAssertNotNil(message, "Message should be created successfully")

        // Test 1: NotEqualTo should NOT match when property doesn't exist
        XCTAssertFalse(triggerController.messageMatchesTriggers(message!))

        // Test 2: NotEqualTo SHOULD match when property exists with different value
        triggerController.addTriggers(["prop": "other"])
        XCTAssertTrue(triggerController.messageMatchesTriggers(message!))

        // Test 3: NotEqualTo should NOT match when property exists with same value
        triggerController.addTriggers(["prop": "value"])
        XCTAssertFalse(triggerController.messageMatchesTriggers(message!))
    }

    /**
     Test that NotExists trigger correctly matches non-existent properties.
     */
    func testNotExistsTrigger_matchesNonExistentProperty() throws {
        /* Setup */
        let triggerController = OSTriggerController()

        // Create a message with NotExists trigger
        let messageJson = IAMTestHelpers.testMessageJsonWithTrigger(
            kind: OS_DYNAMIC_TRIGGER_KIND_CUSTOM,
            property: "prop",
            triggerId: "test_trigger",
            type: 7, // OSTriggerOperatorTypeNotExists
            value: "value"
        )
        let message = OSInAppMessageInternal.instance(withJson: messageJson)
        XCTAssertNotNil(message, "Message should be created successfully")

        // Test 1: NotExists SHOULD match when property doesn't exist
        XCTAssertTrue(triggerController.messageMatchesTriggers(message!))

        // Test 2: NotExists should NOT match when property exists
        triggerController.addTriggers(["prop": "other"])
        XCTAssertFalse(triggerController.messageMatchesTriggers(message!))
    }

    /**
     Test that Exists trigger correctly matches existing properties.
     */
    func testExistsTrigger_matchesExistingProperty() throws {
        /* Setup */
        let triggerController = OSTriggerController()

        // Create a message with Exists trigger
        let messageJson = IAMTestHelpers.testMessageJsonWithTrigger(
            kind: OS_DYNAMIC_TRIGGER_KIND_CUSTOM,
            property: "prop",
            triggerId: "test_trigger",
            type: 6, // OSTriggerOperatorTypeExists
            value: "value"
        )
        let message = OSInAppMessageInternal.instance(withJson: messageJson)
        XCTAssertNotNil(message, "Message should be created successfully")

        // Test 1: Exists should NOT match when property doesn't exist
        XCTAssertFalse(triggerController.messageMatchesTriggers(message!))

        // Test 2: Exists SHOULD match when property exists
        triggerController.addTriggers(["prop": "other"])
        XCTAssertTrue(triggerController.messageMatchesTriggers(message!))
    }
}
