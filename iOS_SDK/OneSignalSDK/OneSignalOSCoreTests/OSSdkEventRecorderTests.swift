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
@testable import OneSignalOSCore
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
private final class EventRecorderSpy: OSSdkEventRecorderAttaching {
    private(set) var attached: [ILogTelemetry] = []
    private(set) var detachCount = 0

    func attach(_ telemetry: ILogTelemetry) {
        attached.append(telemetry)
    }

    func detach() {
        detachCount += 1
    }
}

final class OSSdkEventRecorderTests: XCTestCase {
    func testRecordShipsAnInfoRecordNamedAfterTheEvent() throws {
        let telemetry = TelemetrySpy()
        telemetry.emitExpectation = expectation(description: "emits the event")
        var askedKeys: [String] = []
        let recorder = OSSdkEventRecorder(isFeatureEnabled: { key in
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
        let recorder = OSSdkEventRecorder(isFeatureEnabled: { _ in false })
        recorder.attach(telemetry)

        recorder.record(event: .deviceGesture, attributes: [:])

        wait(for: [telemetry.emitExpectation!], timeout: 0.2)
        XCTAssertTrue(telemetry.records.isEmpty)
    }

    func testEventsRecordedBeforeAttachFlushOnAttach() {
        let telemetry = TelemetrySpy()
        telemetry.emitExpectation = expectation(description: "flushes the queue")
        let recorder = OSSdkEventRecorder(isFeatureEnabled: { _ in true })

        recorder.record(event: .deviceGesture, attributes: ["n": "1"])
        recorder.attach(telemetry)

        wait(for: [telemetry.emitExpectation!], timeout: 2)
        XCTAssertEqual(telemetry.records.map { $0.attributes["n"] }, ["1"])
    }

    func testDetachHoldsEventsUntilTheNextAttach() {
        let first = TelemetrySpy()
        first.emitExpectation = expectation(description: "the detached telemetry stays silent")
        first.emitExpectation?.isInverted = true
        let second = TelemetrySpy()
        second.emitExpectation = expectation(description: "the next telemetry receives the held event")
        let recorder = OSSdkEventRecorder(isFeatureEnabled: { _ in true })
        recorder.attach(first)
        recorder.detach()

        recorder.record(event: .deviceGesture, attributes: [:])
        recorder.attach(second)

        wait(for: [first.emitExpectation!, second.emitExpectation!], timeout: 2)
        XCTAssertTrue(first.records.isEmpty)
        XCTAssertEqual(second.records.count, 1)
    }

    func testRemoteLoggerAttachesOnStartAndDetachesOnShutdown() {
        let recorder = EventRecorderSpy()
        let logger = OSRemoteLogger(
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

        logger.start()
        XCTAssertEqual(recorder.attached.count, 1)
        XCTAssertEqual(recorder.detachCount, 0)

        logger.shutdown()
        XCTAssertEqual(recorder.detachCount, 1)
        XCTAssertEqual(recorder.attached.count, 1)
    }

    func testRemoteLoggerDetachesOnlyOncePerShutdown() {
        let recorder = EventRecorderSpy()
        let logger = OSRemoteLogger(
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
        logger.start()

        logger.shutdown()
        logger.shutdown()
        logger.start()

        XCTAssertEqual(recorder.detachCount, 1)
        XCTAssertEqual(recorder.attached.count, 1)
    }
}
