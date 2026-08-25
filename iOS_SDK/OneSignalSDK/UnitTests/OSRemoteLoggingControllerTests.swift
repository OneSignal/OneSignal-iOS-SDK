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
@_spi(OneSignalInternal) import OneSignalOSCore
import UIKit
import XCTest

final class OSRemoteLoggingControllerTests: XCTestCase {
    private var controllers: [OSRemoteLoggingController] = []

    override func tearDown() {
        controllers.forEach { $0.shutdown() }
        controllers.removeAll()
        super.tearDown()
    }

    func testIosParamsPayloadRoutesEverySeverityThroughController() {
        let telemetry = RemoteTelemetrySpy()
        telemetry.emitExpectation = expectation(description: "routes verbose from ios_params payload")
        telemetry.emitExpectation?.expectedFulfillmentCount = 2
        let controller = makeController(remoteLoggerFactory: { _ in telemetry })

        controller.configure(remoteParams: Fixtures.iosParamsPayload)
        OneSignalLog.onesignalLog(.LL_VERBOSE, message: "verbose is exported")
        OneSignalLog.onesignalLog(.LL_ERROR, message: "error is exported")

        wait(for: [telemetry.emitExpectation!], timeout: 2)
        XCTAssertEqual(telemetry.messages, ["verbose is exported", "error is exported"])
        XCTAssertEqual(telemetry.levels, ["VERBOSE", "ERROR"])
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
            remoteParams: ["logging_config": ["log_level": "ERROR"]]
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
        controller.configure(remoteParams: Fixtures.remoteParams(level: "WARN"))

        OneSignalLog.onesignalLog(.LL_WARN, message: "warning body")

        wait(for: [telemetry.emitExpectation!], timeout: 2)
        XCTAssertEqual(telemetry.messages, ["warning body"])
        XCTAssertEqual(telemetry.levels, ["WARN"])
    }

    func testInternalSinkForwardsStructuredExceptionFields() {
        let telemetry = RemoteTelemetrySpy()
        telemetry.emitExpectation = expectation(description: "routes structured exception")
        let controller = makeController(remoteLoggerFactory: { _ in telemetry })
        controller.configure(remoteParams: Fixtures.remoteParams(level: "ERROR"))

        controller.captureLog(
            with: .LL_ERROR,
            message: "failed",
            exceptionType: "ExampleError",
            exceptionMessage: "details",
            exceptionStacktrace: "frame"
        )

        wait(for: [telemetry.emitExpectation!], timeout: 2)
        XCTAssertEqual(telemetry.exceptionTypes, ["ExampleError"])
        XCTAssertEqual(telemetry.exceptionMessages, ["details"])
        XCTAssertEqual(telemetry.exceptionStacktraces, ["frame"])
    }

    func testDisablingConfigurationStopsRemoteLogging() {
        let telemetry = RemoteTelemetrySpy()
        let controller = makeController(remoteLoggerFactory: { _ in telemetry })
        controller.configure(remoteParams: Fixtures.remoteParams(level: "ERROR"))
        controller.configure(remoteParams: [:])
        telemetry.emitExpectation = expectation(description: "does not route after disable")
        telemetry.emitExpectation?.isInverted = true

        OneSignalLog.onesignalLog(.LL_ERROR, message: "not uploaded")

        wait(for: [telemetry.emitExpectation!], timeout: 0.2)
        XCTAssertEqual(telemetry.shutdownCount, 1)
        XCTAssertTrue(telemetry.messages.isEmpty)
    }

    func testNoneLogLevelStartsLoggerButDoesNotSend() {
        let telemetry = RemoteTelemetrySpy()
        telemetry.emitExpectation = expectation(description: "does not route at NONE")
        telemetry.emitExpectation?.isInverted = true
        let controller = makeController(remoteLoggerFactory: { _ in telemetry })
        controller.configure(remoteParams: Fixtures.remoteParams(level: "NONE"))

        OneSignalLog.onesignalLog(.LL_ERROR, message: "not uploaded")

        wait(for: [telemetry.emitExpectation!], timeout: 0.2)
        XCTAssertEqual(telemetry.startCount, 1)
        XCTAssertEqual(telemetry.shutdownCount, 0)
        XCTAssertTrue(telemetry.messages.isEmpty)
    }

    func testLogLevelUpdateRebuildsLoggerWithTheNewLevel() {
        var loggers: [RemoteTelemetrySpy] = []
        var levelsReportedToKmp: [String?] = []
        let controller = makeController { providers in
            levelsReportedToKmp.append(providers.remoteLogLevel())
            let logger = RemoteTelemetrySpy()
            loggers.append(logger)
            return logger
        }

        controller.configure(remoteParams: Fixtures.remoteParams(level: "ERROR"))
        controller.configure(remoteParams: Fixtures.remoteParams(level: "WARN"))

        // Android's updateLogLevel shuts the previous telemetry down and builds a new
        // one. Rebuilding is what keeps the level reported into KMP in step with the
        // configured level, which a live-instance filter swap would leave stale.
        XCTAssertEqual(loggers.count, 2)
        XCTAssertEqual(levelsReportedToKmp, ["ERROR", "WARN"])
        XCTAssertEqual(loggers[0].shutdownCount, 1)
        XCTAssertEqual(loggers[1].startCount, 1)

        let current = loggers[1]
        current.emitExpectation = expectation(description: "routes warn after level update")
        OneSignalLog.onesignalLog(.LL_WARN, message: "uploaded")
        OneSignalLog.onesignalLog(.LL_INFO, message: "not uploaded")

        wait(for: [current.emitExpectation!], timeout: 2)
        XCTAssertEqual(current.messages, ["uploaded"])
        XCTAssertEqual(current.levels, ["WARN"])
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
        controller.configure(remoteParams: Fixtures.remoteParams(level: "ERROR"))

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
        controller.configure(remoteParams: Fixtures.remoteParams(level: "ERROR"))
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
            controller.configure(remoteParams: Fixtures.remoteParams(level: "ERROR"))
            configured.fulfill()
        }

        wait(for: [constructed, configured], timeout: 2)
    }

    func testStartsOnlyLoggerThatWinsReentrantConfiguration() {
        var controller: OSRemoteLoggingController!
        var loggers: [RemoteTelemetrySpy] = []
        var didReenter = false
        controller = makeController { _ in
            let logger = RemoteTelemetrySpy()
            loggers.append(logger)
            if !didReenter {
                didReenter = true
                controller.configure(remoteParams: Fixtures.remoteParams(level: "ERROR"))
            }
            return logger
        }

        controller.configure(remoteParams: Fixtures.remoteParams(level: "ERROR"))

        XCTAssertEqual(loggers.count, 2)
        XCTAssertEqual(loggers.map(\.startCount).reduce(0, +), 1)
        XCTAssertEqual(loggers.map(\.shutdownCount).reduce(0, +), 1)
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

        controller.configure(remoteParams: Fixtures.remoteParams(level: "ERROR"))

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

}

/// Shared by the configuration and controller suites.
private enum Fixtures {
    static func remoteParams(level: String) -> [String: Any] {
        ["logging_config": ["log_level": level]]
    }

    /// Verbatim ios_params response, so parsing stays honest about the real shape
    /// rather than only the trimmed dictionaries the other tests use.
    static let iosParamsPayload: [String: Any] = [
        "fba": true,
        "uses_provisional_auth": true,
        "outcomes": [
            "direct": ["enabled": true],
            "indirect": [
                "notification_attribution": ["minutes_since_displayed": 1440, "limit": 10],
                "enabled": true
            ],
            "unattributed": ["enabled": true]
        ],
        "receive_receipts_enable": true,
        "logging_config": ["log_level": "VERBOSE"]
    ]
}

final class OSRemoteLoggingConfigurationTests: XCTestCase {
    func testConfigurationUsesRemoteLogLevel() {
        let enabled = OSRemoteLoggingConfiguration(
            remoteParams: ["logging_config": ["log_level": "warn"]]
        )
        XCTAssertTrue(enabled.isEnabled)
        XCTAssertEqual(enabled.logLevel, .LL_WARN)
        XCTAssertTrue(enabled.allows(.LL_ERROR))
        XCTAssertTrue(enabled.allows(.LL_WARN))
        XCTAssertFalse(enabled.allows(.LL_INFO))

        let invalidLevel = OSRemoteLoggingConfiguration(
            remoteParams: ["logging_config": ["log_level": "OFF"]]
        )
        XCTAssertFalse(invalidLevel.isEnabled)
        XCTAssertNil(invalidLevel.logLevel)
    }

    func testIosParamsPayloadEnablesVerboseLevelLogging() {
        let configuration = OSRemoteLoggingConfiguration(remoteParams: Fixtures.iosParamsPayload)

        XCTAssertTrue(configuration.isEnabled)
        XCTAssertEqual(configuration.logLevel, .LL_VERBOSE)
        XCTAssertEqual(configuration.logLevelName, "VERBOSE")

        // VERBOSE is the most permissive level, so every severity is exported.
        for level in [ONE_S_LOG_LEVEL.LL_FATAL, .LL_ERROR, .LL_WARN, .LL_INFO, .LL_DEBUG, .LL_VERBOSE] {
            XCTAssertTrue(configuration.allows(level))
        }
        XCTAssertFalse(configuration.allows(.LL_NONE))

        XCTAssertEqual(
            OSRemoteLoggingConfigEvaluator.evaluate(
                old: OSRemoteLoggingConfiguration.disabled,
                new: configuration
            ),
            .enable(.LL_VERBOSE)
        )

        let restored = OSRemoteLoggingConfiguration(
            cached: configuration.cachePayload(appId: "app-id")
        )
        XCTAssertEqual(restored.logLevel, .LL_VERBOSE)
        XCTAssertTrue(restored.isEnabled)
    }

    func testNoneLogLevelEnablesRemoteLoggingButDoesNotSend() {
        let none = OSRemoteLoggingConfiguration(
            remoteParams: ["logging_config": ["log_level": "NONE"]]
        )
        XCTAssertTrue(none.isEnabled)
        XCTAssertEqual(none.logLevel, .LL_NONE)
        XCTAssertFalse(none.allows(.LL_FATAL))
        XCTAssertFalse(none.allows(.LL_ERROR))
    }

    func testCachePersistsLogLevelAndEnabledFlag() {
        let enabled = OSRemoteLoggingConfiguration(
            remoteParams: ["logging_config": ["log_level": "ERROR"]]
        )
        let payload = enabled.cachePayload(appId: "app-id")
        XCTAssertEqual(payload["app_id"] as? String, "app-id")
        XCTAssertEqual(payload["log_level"] as? String, "ERROR")
        XCTAssertEqual(payload["is_enabled"] as? Bool, true)

        let restored = OSRemoteLoggingConfiguration(cached: payload)
        XCTAssertTrue(restored.isEnabled)
        XCTAssertEqual(restored.logLevel, .LL_ERROR)
    }

    func testLegacyCacheWithoutIsEnabledUsesLogLevelPresence() {
        let legacyEnabled = OSRemoteLoggingConfiguration(cached: ["log_level": "WARN"])
        XCTAssertTrue(legacyEnabled.isEnabled)
        XCTAssertEqual(legacyEnabled.logLevel, .LL_WARN)

        let legacyDisabled = OSRemoteLoggingConfiguration(cached: ["app_id": "app-id"])
        XCTAssertFalse(legacyDisabled.isEnabled)
        XCTAssertNil(legacyDisabled.logLevel)
    }

    /// A cache written by a newer SDK can name a level this one cannot parse. Without
    /// normalizing, the config would be enabled with a nil level, which starts a
    /// logger that can never export and reports no level into KMP.
    func testCachedEnabledWithUnparseableLevelFallsBackToError() {
        let configuration = OSRemoteLoggingConfiguration(
            cached: ["app_id": "app-id", "log_level": "TRACE_ALL_THE_THINGS", "is_enabled": true]
        )

        XCTAssertTrue(configuration.isEnabled)
        XCTAssertEqual(configuration.logLevel, .LL_ERROR)
        XCTAssertTrue(configuration.allows(.LL_ERROR))
        XCTAssertFalse(configuration.allows(.LL_WARN))

        // Absent entirely, rather than unparseable, behaves the same way.
        let missingLevel = OSRemoteLoggingConfiguration(
            cached: ["app_id": "app-id", "is_enabled": true]
        )
        XCTAssertEqual(missingLevel.logLevel, .LL_ERROR)

        // But an enabled flag of false must not manufacture a level.
        let disabled = OSRemoteLoggingConfiguration(
            cached: ["app_id": "app-id", "is_enabled": false]
        )
        XCTAssertFalse(disabled.isEnabled)
        XCTAssertNil(disabled.logLevel)
    }

    func testEvaluatorMirrorsAndroidOtelConfigEvaluator() {
        XCTAssertEqual(
            OSRemoteLoggingConfigEvaluator.evaluate(
                old: nil,
                new: OSRemoteLoggingConfiguration(logLevel: .LL_WARN, isEnabled: true)
            ),
            .enable(.LL_WARN)
        )
        XCTAssertEqual(
            OSRemoteLoggingConfigEvaluator.evaluate(
                old: nil,
                new: OSRemoteLoggingConfiguration(logLevel: nil, isEnabled: true)
            ),
            .enable(.LL_ERROR)
        )
        XCTAssertEqual(
            OSRemoteLoggingConfigEvaluator.evaluate(
                old: nil,
                new: OSRemoteLoggingConfiguration.disabled
            ),
            .noChange
        )
        XCTAssertEqual(
            OSRemoteLoggingConfigEvaluator.evaluate(
                old: OSRemoteLoggingConfiguration.disabled,
                new: OSRemoteLoggingConfiguration(logLevel: .LL_INFO, isEnabled: true)
            ),
            .enable(.LL_INFO)
        )
        XCTAssertEqual(
            OSRemoteLoggingConfigEvaluator.evaluate(
                old: OSRemoteLoggingConfiguration(logLevel: .LL_ERROR, isEnabled: true),
                new: OSRemoteLoggingConfiguration.disabled
            ),
            .disable
        )
        XCTAssertEqual(
            OSRemoteLoggingConfigEvaluator.evaluate(
                old: OSRemoteLoggingConfiguration(logLevel: .LL_ERROR, isEnabled: true),
                new: OSRemoteLoggingConfiguration(logLevel: .LL_WARN, isEnabled: true)
            ),
            .updateLogLevel(old: .LL_ERROR, new: .LL_WARN)
        )
        XCTAssertEqual(
            OSRemoteLoggingConfigEvaluator.evaluate(
                old: OSRemoteLoggingConfiguration(logLevel: .LL_ERROR, isEnabled: true),
                new: OSRemoteLoggingConfiguration(logLevel: .LL_ERROR, isEnabled: true)
            ),
            .noChange
        )
    }
}

private final class ReentrantLogListener: NSObject, OSLogListener {
    private let onLog: () -> Void

    init(onLog: @escaping () -> Void) {
        self.onLog = onLog
    }

    func onLogEvent(_ event: OneSignalLogEvent) {
        guard event.entry.contains("OneSignal logging initialized:") else {
            return
        }
        onLog()
    }
}

private final class RemoteTelemetrySpy: OSStructuredRemoteLoggerProtocol {
    private let lock = NSLock()
    var emitExpectation: XCTestExpectation?
    var flushExpectation: XCTestExpectation?
    var shutdownExpectation: XCTestExpectation?
    let kmpVersion = "test"
    let crashStoragePath = "/test"
    private(set) var levels: [String] = []
    private(set) var messages: [String] = []
    private(set) var exceptionTypes: [String?] = []
    private(set) var exceptionMessages: [String?] = []
    private(set) var exceptionStacktraces: [String?] = []
    private(set) var startCount = 0
    private(set) var shutdownCount = 0

    func start() {
        lock.lock()
        startCount += 1
        lock.unlock()
    }

    func log(level: String, message: String) {
        log(
            level: level,
            message: message,
            exceptionType: nil,
            exceptionMessage: nil,
            exceptionStacktrace: nil
        )
    }

    func log(
        level: String,
        message: String,
        exceptionType: String?,
        exceptionMessage: String?,
        exceptionStacktrace: String?
    ) {
        lock.lock()
        levels.append(level)
        messages.append(message)
        exceptionTypes.append(exceptionType)
        exceptionMessages.append(exceptionMessage)
        exceptionStacktraces.append(exceptionStacktrace)
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
