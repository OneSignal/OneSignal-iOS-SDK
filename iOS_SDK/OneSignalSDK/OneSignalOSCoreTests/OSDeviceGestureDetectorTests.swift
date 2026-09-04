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

import OneSignalKMP
import UIKit
import XCTest
@_spi(OneSignalInternal) @testable import OneSignalOSCore

private let subscriptionId = "aaaabbbb-cccc-dddd-eeee-ffff00001111"
private let expectedWrite = OSDeviceGestureDetector.clipText(subscriptionId: subscriptionId)

/// Runs queued work inline so pasteboard writes are observable synchronously.
private final class InlineQueue: OSDispatchQueue {
    func async(execute work: @escaping @convention(block) () -> Void) {
        work()
    }

    func asyncAfterTime(deadline: DispatchTime, execute work: @escaping @Sendable @convention(block) () -> Void) {
        work()
    }
}

/// Captures queued work so a test can tear the detector down before the write runs.
private final class DeferringQueue: OSDispatchQueue {
    private(set) var pending: [() -> Void] = []

    func async(execute work: @escaping @convention(block) () -> Void) {
        pending.append(work)
    }

    func asyncAfterTime(deadline: DispatchTime, execute work: @escaping @Sendable @convention(block) () -> Void) {
        pending.append(work)
    }

    func drain() {
        let work = pending
        pending.removeAll()
        work.forEach { $0() }
    }
}

/// Counts live observer registrations so tests can assert teardown.
private final class ObserverTrackingCenter: NotificationCenter {
    private(set) var liveObservers = 0

    override func addObserver(
        forName name: NSNotification.Name?,
        object obj: Any?,
        queue: OperationQueue?,
        using block: @escaping (Notification) -> Void
    ) -> NSObjectProtocol {
        liveObservers += 1
        return super.addObserver(forName: name, object: obj, queue: queue, using: block)
    }

    override func removeObserver(_ observer: Any) {
        liveObservers -= 1
        super.removeObserver(observer)
    }
}

/// Captures what the detector records so tests can assert the event and its attributes.
private final class EventRecorderSpy: OSObservabilityEventRecorderProtocol {
    private(set) var events: [OSObservabilityEvent] = []
    private(set) var attributes: [[String: String]] = []

    func record(event: OSObservabilityEvent, attributes: [String: String]) {
        events.append(event)
        self.attributes.append(attributes)
    }
}

/// Owns a detector driven through an injected notification center, a fake monotonic clock,
/// a writer that records instead of touching the real pasteboard, and a recorder spy.
private final class Harness {
    let center: NotificationCenter
    var now: TimeInterval = 1_000
    var killSwitchOn = false
    var currentSubscriptionId: String? = subscriptionId
    var shouldAwait = false
    private(set) var writes: [String] = []
    let recorder = EventRecorderSpy()
    private(set) var detector: OSDeviceGestureDetector!

    init(center: NotificationCenter = NotificationCenter(), queue: OSDispatchQueue = InlineQueue()) {
        self.center = center
        detector = OSDeviceGestureDetector(
            notificationCenter: center,
            mainQueue: queue,
            nowProvider: { [unowned self] in self.now },
            isDisabledRemotelyProvider: { [unowned self] in self.killSwitchOn },
            subscriptionIdProvider: { [unowned self] in self.currentSubscriptionId },
            shouldAwaitProvider: { [unowned self] in self.shouldAwait },
            pasteboardWriter: { [unowned self] in self.writes.append($0) },
            eventRecorder: recorder
        )
        detector.registerLifecycleObserversIfNeeded()
    }

    /// One foreground-dwell + background-dwell cycle, 2s in total by default, so six of
    /// them sit well inside the 30s window.
    func cycle(backgroundDwell: TimeInterval = 1.0, foregroundDwell: TimeInterval = 1.0) {
        now += foregroundDwell
        center.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        now += backgroundDwell
        center.post(name: UIApplication.didBecomeActiveNotification, object: nil)
    }
}

final class OSDeviceGestureDetectorTests: XCTestCase {
    func testSixRapidCyclesWriteThePrefixedSubscriptionId() {
        let harness = Harness()

        for _ in 1...6 {
            harness.cycle()
        }

        XCTAssertEqual(harness.writes, [expectedWrite])
        XCTAssertEqual(expectedWrite, "os: \(subscriptionId)")
    }

    func testFiveCyclesWriteNothing() {
        let harness = Harness()

        for _ in 1...5 {
            harness.cycle()
        }

        XCTAssertEqual(harness.writes, [])
    }

    func testCyclesSlowerThanTheWindowNeverAccumulateSix() {
        let harness = Harness()

        // 7 seconds per round trip caps the window at five cycles, so a user who
        // backgrounds the app all day at a normal pace can never fire this.
        for _ in 1...8 {
            harness.cycle(backgroundDwell: 3.0, foregroundDwell: 4.0)
        }

        XCTAssertEqual(harness.writes, [])
    }

    func testPauseMidGestureDoesNotResetProgress() {
        let harness = Harness()

        for _ in 1...3 {
            harness.cycle()
        }
        // A pause costs time, not accumulated cycles; all six still land inside the window.
        harness.cycle(foregroundDwell: 10.0)
        for _ in 1...2 {
            harness.cycle()
        }

        XCTAssertEqual(harness.writes, [expectedWrite])
    }

    func testSubHumanBackgroundBlipDoesNotCountAsACycle() {
        let harness = Harness()

        for _ in 1...5 {
            harness.cycle()
        }
        // Faster than any human app switch: it does not count, so one more real cycle
        // completes the gesture.
        harness.cycle(backgroundDwell: 0.001)
        XCTAssertEqual(harness.writes, [])

        harness.cycle()
        XCTAssertEqual(harness.writes, [expectedWrite])
    }

    func testRepeatedActivationsWithoutABackgroundDoNotCount() {
        let harness = Harness()

        for _ in 1...5 {
            harness.cycle()
        }
        // UIKit can post didBecomeActive repeatedly with no background event in between.
        for _ in 1...6 {
            harness.now += 0.5
            harness.center.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        }
        XCTAssertEqual(harness.writes, [])

        harness.cycle()
        XCTAssertEqual(harness.writes, [expectedWrite])
    }

    func testColdStartActivationDoesNotCount() {
        let harness = Harness()

        harness.center.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        for _ in 1...5 {
            harness.cycle()
        }
        XCTAssertEqual(harness.writes, [])

        harness.cycle()
        XCTAssertEqual(harness.writes, [expectedWrite])
    }

    func testDetectorReArmsAfterFiring() {
        let harness = Harness()

        for _ in 1...12 {
            harness.cycle()
        }

        XCTAssertEqual(harness.writes, [expectedWrite, expectedWrite])
    }

    func testKillSwitchSuppressesTheWrite() {
        let harness = Harness()
        harness.killSwitchOn = true

        for _ in 1...6 {
            harness.cycle()
        }

        XCTAssertEqual(harness.writes, [])
    }

    func testKillSwitchKeyMatchesTheCatalog() {
        // The feature manager only answers for catalog keys, so a drift here would silently
        // turn the switch into a no-op.
        XCTAssertEqual(OSDeviceGestureDetector.killSwitchKey, FeatureFlag.sdkDeviceGestureDisabled.key)
    }

    func testNotReadySdkSuppressesTheWrite() {
        let harness = Harness()
        harness.shouldAwait = true

        for _ in 1...6 {
            harness.cycle()
        }

        XCTAssertEqual(harness.writes, [])
    }

    func testMissingSubscriptionIdWritesThePlaceholder() {
        // Someone following the docs gets a visible result that says why there is no ID.
        let harness = Harness()
        harness.currentSubscriptionId = nil

        for _ in 1...6 {
            harness.cycle()
        }

        XCTAssertEqual(harness.writes, ["os: no subscription ID yet"])
    }

    func testEmptySubscriptionIdWritesThePlaceholder() {
        let harness = Harness()
        harness.currentSubscriptionId = ""

        for _ in 1...6 {
            harness.cycle()
        }

        XCTAssertEqual(harness.writes, ["os: no subscription ID yet"])
    }

    func testRegistrationIsIdempotent() {
        let center = ObserverTrackingCenter()
        let harness = Harness(center: center)

        harness.detector.registerLifecycleObserversIfNeeded()

        XCTAssertEqual(center.liveObservers, 2)
    }

    func testTearDownLeavesNoLifecycleObserversBehind() {
        let center = ObserverTrackingCenter()
        let harness = Harness(center: center)
        XCTAssertEqual(center.liveObservers, 2)

        harness.detector.tearDown()
        XCTAssertEqual(center.liveObservers, 0)
    }

    func testTearDownDropsAWriteAlreadyQueued() {
        // A gesture can complete just before a reset lands. The write is on the main queue by
        // then, so the block itself has to notice the instance is gone.
        let queue = DeferringQueue()
        let harness = Harness(queue: queue)

        for _ in 1...6 {
            harness.cycle()
        }
        XCTAssertEqual(queue.pending.count, 1)
        XCTAssertEqual(harness.writes, [])

        harness.detector.tearDown()
        queue.drain()

        XCTAssertEqual(harness.writes, [])
        XCTAssertEqual(harness.recorder.events, [])
    }

    func testTwoHundredFortyNineMillisecondsIsABlipAndTwoHundredFiftyIsACycle() {
        // The floor is inclusive: exactly the minimum counts. Six blips leave the window empty,
        // so the six real cycles right after still need all six.
        let harness = Harness()

        for _ in 1...6 {
            harness.cycle(backgroundDwell: 0.249)
        }
        XCTAssertEqual(harness.writes, [])

        for _ in 1...6 {
            harness.cycle(backgroundDwell: 0.25)
        }
        XCTAssertEqual(harness.writes, [expectedWrite])
    }

    func testWindowIsInclusiveAtExactlyThirtySeconds() {
        // Five 2s cycles complete at +2s..+10s. A sixth completing exactly 30s after the first
        // still counts; one millisecond later the first has aged out and only five remain.
        let exact = Harness()
        for _ in 1...5 {
            exact.cycle()
        }
        exact.cycle(backgroundDwell: 1.0, foregroundDwell: 21.0)
        XCTAssertEqual(exact.writes, [expectedWrite])

        let late = Harness()
        for _ in 1...5 {
            late.cycle()
        }
        late.cycle(backgroundDwell: 1.0, foregroundDwell: 21.001)
        XCTAssertEqual(late.writes, [])
    }

    // MARK: - Observability event

    // Every recognised gesture records deviceGesture with its outcome, whether or not an ID was
    // copied, so the backend can answer how often the gesture happens and how often it pays off.

    func testCompletedGestureRecordsACopiedEventCarryingTheSubscriptionId() {
        let harness = Harness()

        // Progress is silent: the event fires on recognition, not per cycle.
        for _ in 1...5 {
            harness.cycle()
        }
        XCTAssertEqual(harness.recorder.events, [])

        harness.cycle()

        XCTAssertEqual(harness.recorder.events, [.deviceGesture])
        XCTAssertEqual(harness.recorder.attributes, [[
            "gesture.result": "copied",
            "gesture.push_subscription_id": subscriptionId
        ]])
    }

    func testKillSwitchRecordsADisabledResultWithoutAnId() {
        let harness = Harness()
        harness.killSwitchOn = true

        for _ in 1...6 {
            harness.cycle()
        }

        XCTAssertEqual(harness.recorder.events, [.deviceGesture])
        XCTAssertEqual(harness.recorder.attributes, [["gesture.result": "disabled"]])
    }

    func testMissingOrEmptySubscriptionIdRecordsANoIdResult() {
        // Both shapes mean the same thing to the backend: the gesture ran before the device had
        // anything worth pasting.
        for missingId in [nil, ""] {
            let harness = Harness()
            harness.currentSubscriptionId = missingId

            for _ in 1...6 {
                harness.cycle()
            }

            XCTAssertEqual(harness.recorder.events, [.deviceGesture])
            XCTAssertEqual(harness.recorder.attributes, [["gesture.result": "no_id"]])
        }
    }

    func testNotReadySdkRecordsNothing() {
        // The event would ship to the backend, and nothing may leave the device before the app id
        // and consent are in place.
        let harness = Harness()
        harness.shouldAwait = true

        for _ in 1...6 {
            harness.cycle()
        }

        XCTAssertEqual(harness.recorder.events, [])
    }

    func testEachRecognitionRecordsItsOwnEvent() {
        let harness = Harness()

        for _ in 1...12 {
            harness.cycle()
        }

        XCTAssertEqual(harness.recorder.events, [.deviceGesture, .deviceGesture])
        XCTAssertEqual(harness.recorder.attributes.map { $0["gesture.result"] }, ["copied", "copied"])
    }
}
