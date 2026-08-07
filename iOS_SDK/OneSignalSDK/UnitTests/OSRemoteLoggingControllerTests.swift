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
import OneSignalOSCore
import UIKit
import XCTest

final class OSRemoteLoggingControllerTests: XCTestCase {
    private var controllers: [OSRemoteLoggingController] = []

    override func tearDown() {
        controllers.forEach { $0.shutdown() }
        controllers.removeAll()
        super.tearDown()
    }

    func testConfigurationRequiresFeatureFlagAndRemoteLevel() {
        let levelOnly = OSRemoteLoggingConfiguration(
            remoteParams: ["logging_config": ["log_level": "WARN"]]
        )
        XCTAssertFalse(levelOnly.isRemoteLoggingEnabled)

        let flagOnly = OSRemoteLoggingConfiguration(
            remoteParams: ["sdk_remote_feature_flags": ["sdk_custom_logging"]]
        )
        XCTAssertFalse(flagOnly.isRemoteLoggingEnabled)

        let enabled = OSRemoteLoggingConfiguration(
            remoteParams: [
                "sdk_remote_feature_flags": ["sdk_custom_logging"],
                "logging_config": ["log_level": "warn"]
            ]
        )
        XCTAssertTrue(enabled.isRemoteLoggingEnabled)
        XCTAssertTrue(enabled.allows(.LL_ERROR))
        XCTAssertTrue(enabled.allows(.LL_WARN))
        XCTAssertFalse(enabled.allows(.LL_INFO))

        let invalidLevel = OSRemoteLoggingConfiguration(
            remoteParams: [
                "sdk_remote_feature_flags": ["sdk_custom_logging"],
                "logging_config": ["log_level": "OFF"]
            ]
        )
        XCTAssertFalse(invalidLevel.isRemoteLoggingEnabled)
    }

    func testControllerRoutesLogsAndFlushesOnBackground() {
        let notificationCenter = NotificationCenter()
        let telemetry = RemoteTelemetrySpy()
        telemetry.emitExpectation = expectation(description: "routes matching log")
        telemetry.flushExpectation = expectation(description: "flushes on background")
        let backgroundTaskEnded = expectation(description: "ends background task after flush")
        var startedTask: String?
        var endedTask: String?
        let controller = makeController(
            notificationCenter: notificationCenter,
            beginBackgroundTask: { startedTask = $0 },
            endBackgroundTask: {
                endedTask = $0
                backgroundTaskEnded.fulfill()
            },
            remoteLoggerFactory: { _ in telemetry }
        )

        controller.configure(
            remoteParams: [
                "sdk_remote_feature_flags": ["sdk_custom_logging"],
                "logging_config": ["log_level": "ERROR"]
            ]
        )
        OneSignalLog.onesignalLog(.LL_INFO, message: "not uploaded")
        OneSignalLog.onesignalLog(.LL_ERROR, message: "uploaded")
        notificationCenter.post(name: UIApplication.didEnterBackgroundNotification, object: nil)

        wait(
            for: [telemetry.emitExpectation!, telemetry.flushExpectation!, backgroundTaskEnded],
            timeout: 2
        )

        XCTAssertEqual(telemetry.messages, ["uploaded"])
        XCTAssertEqual(telemetry.levels, ["ERROR"])
        XCTAssertEqual(endedTask, startedTask)
    }

    func testWarnUsesRawMessageWithoutConsolePrefix() {
        let telemetry = RemoteTelemetrySpy()
        telemetry.emitExpectation = expectation(description: "routes warning")
        let controller = makeController(remoteLoggerFactory: { _ in telemetry })
        controller.configure(remoteParams: Self.remoteParams(level: "WARN"))

        OneSignalLog.onesignalLog(.LL_WARN, message: "warning body")

        wait(for: [telemetry.emitExpectation!], timeout: 2)
        XCTAssertEqual(telemetry.messages, ["warning body"])
        XCTAssertEqual(telemetry.levels, ["WARN"])
    }

    func testDisablingConfigurationStopsRemoteLogging() {
        let telemetry = RemoteTelemetrySpy()
        let controller = makeController(remoteLoggerFactory: { _ in telemetry })
        controller.configure(remoteParams: Self.remoteParams(level: "ERROR"))
        controller.configure(remoteParams: [:])
        telemetry.emitExpectation = expectation(description: "does not route after disable")
        telemetry.emitExpectation?.isInverted = true

        OneSignalLog.onesignalLog(.LL_ERROR, message: "not uploaded")

        wait(for: [telemetry.emitExpectation!], timeout: 0.2)
        XCTAssertEqual(telemetry.shutdownCount, 1)
        XCTAssertTrue(telemetry.messages.isEmpty)
    }

    func testTerminationFlushesBeforeShutdown() {
        let notificationCenter = NotificationCenter()
        let telemetry = RemoteTelemetrySpy()
        telemetry.flushExpectation = expectation(description: "flushes on termination")
        telemetry.shutdownExpectation = expectation(description: "shuts down after flush")
        let controller = makeController(
            notificationCenter: notificationCenter,
            remoteLoggerFactory: { _ in telemetry }
        )
        controller.configure(remoteParams: Self.remoteParams(level: "ERROR"))

        notificationCenter.post(name: UIApplication.willTerminateNotification, object: nil)

        wait(for: [telemetry.flushExpectation!, telemetry.shutdownExpectation!], timeout: 2)
        XCTAssertEqual(telemetry.shutdownCount, 1)
    }

    func testSceneAppsObserveOnlySceneLifecycle() {
        let notificationCenter = NotificationCenter()
        let telemetry = RemoteTelemetrySpy()
        let controller = makeController(
            notificationCenter: notificationCenter,
            usesScenes: { true },
            remoteLoggerFactory: { _ in telemetry }
        )
        controller.configure(remoteParams: Self.remoteParams(level: "ERROR"))
        telemetry.flushExpectation = expectation(description: "ignores application background")
        telemetry.flushExpectation?.isInverted = true

        notificationCenter.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        wait(for: [telemetry.flushExpectation!], timeout: 0.2)

        telemetry.flushExpectation = expectation(description: "flushes on scene background")
        notificationCenter.post(name: Notification.Name("UISceneDidEnterBackgroundNotification"), object: nil)
        wait(for: [telemetry.flushExpectation!], timeout: 2)
    }

    func testConstructsRemoteLoggerOnMainWhenConfiguredInBackground() {
        let constructed = expectation(description: "constructs logger on main")
        let configured = expectation(description: "finishes background configuration")
        let telemetry = RemoteTelemetrySpy()
        let controller = makeController { _ in
            XCTAssertTrue(Thread.isMainThread)
            constructed.fulfill()
            return telemetry
        }

        DispatchQueue.global().async {
            controller.configure(remoteParams: Self.remoteParams(level: "ERROR"))
            configured.fulfill()
        }

        wait(for: [constructed, configured], timeout: 2)
    }

    func testStartupDiagnosticCanResetControllerWithoutDeadlock() {
        let reset = expectation(description: "resets from startup diagnostic listener")
        let telemetry = RemoteTelemetrySpy()
        let controller = makeController(remoteLoggerFactory: { _ in telemetry })
        let listener = ReentrantLogListener {
            controller.shutdown()
            reset.fulfill()
        }
        OneSignalLog.debug().__add(listener)
        defer { OneSignalLog.debug().__remove(listener) }

        controller.configure(remoteParams: Self.remoteParams(level: "ERROR"))

        wait(for: [reset], timeout: 2)
        XCTAssertEqual(telemetry.shutdownCount, 1)
    }

    private func makeController(
        notificationCenter: NotificationCenter = NotificationCenter(),
        usesScenes: @escaping () -> Bool = { false },
        beginBackgroundTask: @escaping (String) -> Void = { _ in },
        endBackgroundTask: @escaping (String) -> Void = { _ in },
        remoteLoggerFactory: @escaping OSRemoteLoggingController.RemoteLoggerFactory
    ) -> OSRemoteLoggingController {
        let controller = OSRemoteLoggingController(
            notificationCenter: notificationCenter,
            usesScenes: usesScenes,
            beginBackgroundTask: beginBackgroundTask,
            endBackgroundTask: endBackgroundTask,
            remoteLoggerFactory: remoteLoggerFactory
        )
        controllers.append(controller)
        return controller
    }

    private static func remoteParams(level: String) -> [String: Any] {
        [
            "sdk_remote_feature_flags": ["sdk_custom_logging"],
            "logging_config": ["log_level": level]
        ]
    }
}

private final class ReentrantLogListener: NSObject, OSLogListener {
    private let onLog: () -> Void

    init(onLog: @escaping () -> Void) {
        self.onLog = onLog
    }

    func onLogEvent(_ event: OneSignalLogEvent) {
        guard event.message.hasPrefix("OneSignal logging initialized:") else {
            return
        }
        onLog()
    }
}

private final class RemoteTelemetrySpy: OSRemoteLoggerProtocol {
    private let lock = NSLock()
    var emitExpectation: XCTestExpectation?
    var flushExpectation: XCTestExpectation?
    var shutdownExpectation: XCTestExpectation?
    let kmpVersion = "test"
    let crashStoragePath = "/test"
    private(set) var levels: [String] = []
    private(set) var messages: [String] = []
    private(set) var shutdownCount = 0

    func log(level: String, message: String) {
        lock.lock()
        levels.append(level)
        messages.append(message)
        lock.unlock()
        emitExpectation?.fulfill()
    }

    func forceFlush(completion: @escaping () -> Void) {
        flushExpectation?.fulfill()
        completion()
    }

    func shutdown() {
        lock.lock()
        shutdownCount += 1
        lock.unlock()
        shutdownExpectation?.fulfill()
    }
}
