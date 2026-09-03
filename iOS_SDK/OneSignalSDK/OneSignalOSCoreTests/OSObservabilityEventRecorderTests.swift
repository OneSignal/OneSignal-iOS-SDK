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
import OneSignalCore
import OneSignalKMP
@_spi(OneSignalInternal) @testable import OneSignalOSCore
import XCTest

/// Stands in for the remote telemetry and records what the shared KMP recorder emits.
private final class TelemetrySpy: ILogTelemetry {
    private let lock = NSLock()
    var emitExpectation: XCTestExpectation?
    private var storedRecords: [LogRecord] = []

    var records: [LogRecord] {
        lock.lock()
        defer { lock.unlock() }
        return storedRecords
    }

    func emit(record: LogRecord, completionHandler: @escaping (Error?) -> Void) {
        lock.lock()
        storedRecords.append(record)
        lock.unlock()
        emitExpectation?.fulfill()
        completionHandler(nil)
    }

    func forceFlush(completionHandler: @escaping (Error?) -> Void) {
        completionHandler(nil)
    }

    func shutdown() {}
}

/// Observes the seam `OSRemoteLogger` drives.
private final class EventRecorderSpy: OSObservabilityEventRecorderAttaching {
    private(set) var attached: [ILogTelemetry] = []
    private(set) var detached: [ILogTelemetry] = []

    func attach(_ telemetry: ILogTelemetry) {
        attached.append(telemetry)
    }

    func detach(_ telemetry: ILogTelemetry) {
        detached.append(telemetry)
    }
}

final class OSObservabilityEventRecorderTests: XCTestCase {
    override func tearDown() {
        OSFeatureManager.didConstructForTesting = nil
        OSFeatureManager.reset()
        OSFeatureFlagsStore.shared.clear()
        super.tearDown()
    }

    private func makeRemoteLogger(recorder: EventRecorderSpy) -> OSRemoteLogger {
        OSRemoteLogger(
            installIdProvider: { "install-id" },
            onesignalIdProvider: { nil },
            pushSubscriptionIdProvider: { nil },
            appStateProvider: { "foreground" },
            featureFlagsProvider: { [] },
            remoteLogLevelProvider: { nil },
            exporterLoggingEnabledProvider: { false },
            requestSenderOverride: { _, completion in completion(nil, nil, nil) },
            eventRecorder: recorder
        )
    }

    // MARK: - Recording through the shared KMP recorder

    func testRecordShipsAnInfoRecordNamedAfterTheEvent() throws {
        let telemetry = TelemetrySpy()
        telemetry.emitExpectation = expectation(description: "emits the event")
        var askedKeys: [String] = []
        let recorder = OSObservabilityEventRecorder(isFeatureEnabled: { key in
            askedKeys.append(key)
            return true
        })
        recorder.attach(telemetry)

        recorder.record(event: .deviceGesture, attributes: ["gesture.result": "copied"])

        wait(for: [telemetry.emitExpectation!], timeout: 2)
        let record = try XCTUnwrap(telemetry.records.first)
        XCTAssertEqual(record.severity, LogSeverity.info)
        XCTAssertEqual(record.body, "sdk.device_gesture")
        XCTAssertEqual(record.attributes["event.name"], "sdk.device_gesture")
        XCTAssertEqual(record.attributes["gesture.result"], "copied")
        XCTAssertEqual(askedKeys, ["sdk_event_device_gesture_enabled"])
    }

    func testRecordDropsWhenTheEventFlagIsOff() {
        let telemetry = TelemetrySpy()
        telemetry.emitExpectation = expectation(description: "does not emit")
        telemetry.emitExpectation?.isInverted = true
        let recorder = OSObservabilityEventRecorder(isFeatureEnabled: { _ in false })
        recorder.attach(telemetry)

        recorder.record(event: .deviceGesture, attributes: [:])

        wait(for: [telemetry.emitExpectation!], timeout: 0.2)
        XCTAssertTrue(telemetry.records.isEmpty)
    }

    func testEventsRecordedBeforeAttachFlushOnAttach() {
        let telemetry = TelemetrySpy()
        telemetry.emitExpectation = expectation(description: "flushes the queue")
        let recorder = OSObservabilityEventRecorder(isFeatureEnabled: { _ in true })

        recorder.record(event: .deviceGesture, attributes: ["n": "1"])
        recorder.attach(telemetry)

        wait(for: [telemetry.emitExpectation!], timeout: 2)
        XCTAssertEqual(telemetry.records.map { $0.attributes["n"] }, ["1"])
    }

    func testDetachHoldsEventsUntilTheNextAttach() {
        let first = TelemetrySpy()
        let second = TelemetrySpy()
        second.emitExpectation = expectation(description: "the next telemetry receives the held event")
        let recorder = OSObservabilityEventRecorder(isFeatureEnabled: { _ in true })
        recorder.attach(first)
        recorder.detach(first)

        recorder.record(event: .deviceGesture, attributes: [:])
        recorder.attach(second)

        wait(for: [second.emitExpectation!], timeout: 2)
        XCTAssertTrue(first.records.isEmpty)
        XCTAssertEqual(second.records.count, 1)
    }

    func testDetachOfTelemetryThatIsNotAttachedIsIgnored() {
        let winner = TelemetrySpy()
        winner.emitExpectation = expectation(description: "the attached telemetry still receives the event")
        let loser = TelemetrySpy()
        let recorder = OSObservabilityEventRecorder(isFeatureEnabled: { _ in true })
        recorder.attach(winner)

        recorder.detach(loser)
        recorder.record(event: .deviceGesture, attributes: [:])

        wait(for: [winner.emitExpectation!], timeout: 2)
        XCTAssertEqual(winner.records.count, 1)
        XCTAssertTrue(loser.records.isEmpty)
    }

    func testResetDropsTheQueue() {
        let telemetry = TelemetrySpy()
        telemetry.emitExpectation = expectation(description: "nothing from before the reset")
        telemetry.emitExpectation?.isInverted = true
        let recorder = OSObservabilityEventRecorder(isFeatureEnabled: { _ in true })
        recorder.record(event: .deviceGesture, attributes: ["n": "old app"])

        recorder.reset()
        recorder.attach(telemetry)

        wait(for: [telemetry.emitExpectation!], timeout: 0.2)
        XCTAssertTrue(telemetry.records.isEmpty)
    }

    // MARK: - The flag read

    func testTheFlagReadDoesNotConstructTheFeatureManager() {
        OSFeatureManager.reset()
        var constructed = false
        OSFeatureManager.didConstructForTesting = { constructed = true }

        let enabled = OSObservabilityEventRecorder.featureIsEnabledIfInitialized(FeatureFlag.sdkEventDeviceGesture.key)

        XCTAssertFalse(enabled)
        XCTAssertFalse(constructed)
    }

    func testTheFlagReadSeesTheBuiltFeatureManager() {
        OSFeatureManager.reset()
        OSFeatureFlagsStore.shared.applyRemoteFlags([FeatureFlag.sdkEventDeviceGesture.key], metadata: nil)
        _ = OSFeatureManager.shared

        XCTAssertTrue(OSObservabilityEventRecorder.featureIsEnabledIfInitialized(FeatureFlag.sdkEventDeviceGesture.key))
        XCTAssertFalse(OSObservabilityEventRecorder.featureIsEnabledIfInitialized(FeatureFlag.sdkIdentityVerification.key))
    }

    // MARK: - The mirror enum

    func testTheMirrorEnumMatchesTheKmpCatalog() {
        // A KMP event added without a Swift case, or the reverse, fails here instead of compiling silently.
        XCTAssertEqual(
            Set(OSObservabilityEvent.allCases.map { $0.eventName }),
            Set(ObservabilityEvent.entries.map { $0.eventName })
        )
        XCTAssertEqual(OSObservabilityEvent.allCases.count, ObservabilityEvent.entries.count)
    }

    // MARK: - The remote logger seam

    func testRemoteLoggerAttachesOnStartAndDetachesTheSameTelemetryOnShutdown() {
        let recorder = EventRecorderSpy()
        let logger = makeRemoteLogger(recorder: recorder)

        logger.start()
        XCTAssertEqual(recorder.attached.count, 1)
        XCTAssertTrue(recorder.detached.isEmpty)

        logger.shutdown()
        XCTAssertEqual(recorder.detached.count, 1)
        XCTAssertTrue((recorder.detached.first as AnyObject?) === (recorder.attached.first as AnyObject?))
    }

    func testRemoteLoggerDetachesOnlyOncePerShutdown() {
        let recorder = EventRecorderSpy()
        let logger = makeRemoteLogger(recorder: recorder)
        logger.start()

        logger.shutdown()
        logger.shutdown()
        logger.start()

        XCTAssertEqual(recorder.detached.count, 1)
        XCTAssertEqual(recorder.attached.count, 1)
    }

    func testRemoteLoggerThatNeverStartedDoesNotDetachOnShutdown() {
        // The controller shuts down a logger that lost the install race without starting it,
        // while the winner is attached to the shared recorder.
        let recorder = EventRecorderSpy()
        let logger = makeRemoteLogger(recorder: recorder)

        logger.shutdown()

        XCTAssertTrue(recorder.attached.isEmpty)
        XCTAssertTrue(recorder.detached.isEmpty)
    }
}
