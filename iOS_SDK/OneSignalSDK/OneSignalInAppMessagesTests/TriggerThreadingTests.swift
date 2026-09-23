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
import OneSignalOSCore
import OneSignalCoreMocks
import OneSignalOSCoreMocks
import OneSignalUserMocks
import OneSignalInAppMessagesMocks

/**
 The trigger and pause entry points accept calls from any thread, while the controller's message
 state lives on the main queue. Each test drives an entry point from a background queue with the
 main thread held, then lets the main queue drain and checks where the work ran.
 */
final class TriggerThreadingTests: XCTestCase {

    /// Records the thread each call arrives on. Matching and sharing always fail so evaluation stops there.
    private final class RecordingTriggerController: OSTriggerController {
        var addCallsOnMain: [Bool] = []
        var removeCallsOnMain: [Bool] = []
        var matchCallsOnMain: [Bool] = []
        var sharedTriggerCallsOnMain: [Bool] = []

        override func addTriggers(_ triggers: [String: Any]) {
            addCallsOnMain.append(Thread.isMainThread)
            super.addTriggers(triggers)
        }

        override func removeTriggers(forKeys keys: [String]) {
            removeCallsOnMain.append(Thread.isMainThread)
            super.removeTriggers(forKeys: keys)
        }

        override func messageMatchesTriggers(_ message: OSInAppMessageInternal) -> Bool {
            matchCallsOnMain.append(Thread.isMainThread)
            return false
        }

        override func hasSharedTriggers(_ message: OSInAppMessageInternal, newTriggersKeys: [String]) -> Bool {
            sharedTriggerCallsOnMain.append(Thread.isMainThread)
            return false
        }
    }

    private var controller: OSMessagingController!
    private var triggerController: RecordingTriggerController!

    override func setUpWithError() throws {
        OneSignalCoreMocks.clearUserDefaults()
        OneSignalUserMocks.reset()
        OSMessagingController.removeInstance()
        OneSignalIdentifiers.currentAppId = "test-app-id"

        controller = OSMessagingController.sharedInstance()
        triggerController = RecordingTriggerController()
        triggerController.delegate = controller
        controller.triggerController = triggerController

        // One message with redisplay state so trigger changes reach the redisplay check
        let message = OSInAppMessageInternal.instance(withJson: IAMTestHelpers.testDefaultMessageJson())!
        controller.messages = NSMutableArray(array: [message])
        controller.redisplayedInAppMessages[message.messageId] = message
    }

    override func tearDownWithError() throws {
        OSMessagingController.removeInstance()
    }

    /// Runs `work` on a background queue while the main thread waits, so nothing handed to the
    /// main queue can run until `drainMainQueue` is called.
    private func runOffMain(_ work: @escaping () -> Void) {
        let finished = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            work()
            finished.signal()
        }
        XCTAssertEqual(finished.wait(timeout: .now() + 5), .success, "background call did not return")
    }

    private func drainMainQueue() {
        let drained = expectation(description: "main queue drained")
        DispatchQueue.main.async { drained.fulfill() }
        wait(for: [drained], timeout: 5)
    }

    func testAddTriggersOffMainRunsOnMainQueue() {
        runOffMain { self.controller.addTriggers(["key": "value"]) }

        XCTAssertEqual(triggerController.sharedTriggerCallsOnMain, [], "redisplay state was read on the calling thread")
        XCTAssertEqual(triggerController.addCallsOnMain, [], "trigger state was touched on the calling thread")

        drainMainQueue()

        XCTAssertEqual(triggerController.sharedTriggerCallsOnMain, [true])
        XCTAssertEqual(triggerController.addCallsOnMain, [true])
        XCTAssertEqual(triggerController.getTriggers()["key"] as? String, "value")
        XCTAssertTrue(controller.earlySessionTriggers.contains("key"))
    }

    func testRemoveTriggersOffMainRunsOnMainQueue() {
        controller.addTriggers(["key": "value"])
        triggerController.sharedTriggerCallsOnMain.removeAll()

        runOffMain { self.controller.removeTriggers(forKeys: ["key"]) }

        XCTAssertEqual(triggerController.sharedTriggerCallsOnMain, [], "redisplay state was read on the calling thread")
        XCTAssertEqual(triggerController.removeCallsOnMain, [], "trigger state was touched on the calling thread")

        drainMainQueue()

        XCTAssertEqual(triggerController.sharedTriggerCallsOnMain, [true])
        XCTAssertEqual(triggerController.removeCallsOnMain, [true])
        XCTAssertNil(triggerController.getTriggers()["key"])
    }

    func testClearTriggersOffMainRunsOnMainQueueAndClearsATriggerQueuedBefore() {
        runOffMain {
            self.controller.addTriggers(["key": "value"])
            self.controller.clearTriggers()
        }

        XCTAssertEqual(triggerController.removeCallsOnMain, [], "trigger state was touched on the calling thread")

        drainMainQueue()

        XCTAssertEqual(triggerController.removeCallsOnMain, [true])
        XCTAssertTrue(triggerController.getTriggers().isEmpty)
    }

    func testUnpausingOffMainEvaluatesOnMainQueueAndFlagIsImmediate() {
        var pausedSeenByCaller = false

        runOffMain {
            self.controller.setInAppMessagingPaused(true)
            pausedSeenByCaller = self.controller.isInAppMessagingPaused()
            self.controller.setInAppMessagingPaused(false)
        }

        XCTAssertTrue(pausedSeenByCaller)
        XCTAssertEqual(triggerController.matchCallsOnMain, [], "messages were evaluated on the calling thread")

        drainMainQueue()

        XCTAssertEqual(triggerController.matchCallsOnMain, [true])
    }
}
