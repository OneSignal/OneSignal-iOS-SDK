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

import Darwin
import Foundation
import OneSignalCore
import OneSignalKMP
@testable import OneSignalOSCore
import XCTest

final class OSLoggerAdaptersTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: temporaryDirectory)
    }

    func testFileStoreSynchronouslySavesAndListsPayload() throws {
        let store = FileLogStore(rootPath: temporaryDirectory.path)
        let payload = makeKotlinBytes([1, 2, 3, 255])

        XCTAssertTrue(store.save(bytes: payload))
        let files = try FileManager.default.contentsOfDirectory(atPath: temporaryDirectory.path)
        XCTAssertEqual(files.count, 1)
        XCTAssertTrue(files[0].hasSuffix(".otlp"))

        let listed = expectation(description: "lists saved payload")
        store.listReadable(minAgeMillis: 0) { records, error in
            XCTAssertNil(error)
            XCTAssertEqual(records?.count, 1)
            XCTAssertEqual(records?.first?.id, files[0])
            XCTAssertEqual(records?.first?.bytes.bytes, [1, 2, 3, 255])
            listed.fulfill()
        }
        wait(for: [listed], timeout: 2)
    }

    func testFileStoreDeletesOnlyInterruptedTemporaryWrites() throws {
        let store = FileLogStore(rootPath: temporaryDirectory.path)
        XCTAssertTrue(store.save(bytes: makeKotlinBytes([1])))

        let temporaryURL = temporaryDirectory.appendingPathComponent("interrupted.otlp.tmp")
        try Data([2]).write(to: temporaryURL)
        let foreignURL = temporaryDirectory.appendingPathComponent("unowned")
        try Data([2]).write(to: foreignURL)

        let cleaned = expectation(description: "cleans interrupted write")
        store.deleteUnrecognizedEntries(minAgeMillis: 0) { count, error in
            XCTAssertNil(error)
            XCTAssertEqual(count?.int32Value, 1)
            XCTAssertFalse(FileManager.default.fileExists(atPath: temporaryURL.path))
            XCTAssertTrue(FileManager.default.fileExists(atPath: foreignURL.path))
            cleaned.fulfill()
        }
        wait(for: [cleaned], timeout: 2)

        XCTAssertEqual(
            try FileManager.default.contentsOfDirectory(atPath: temporaryDirectory.path)
                .filter { $0.hasSuffix(".otlp") }
                .count,
            1
        )
    }

    func testFileStoreRejectsEmptyPayload() {
        let store = FileLogStore(rootPath: temporaryDirectory.path)

        XCTAssertFalse(store.save(bytes: makeKotlinBytes([])))
    }

    func testHttpSenderPostsEncodedBytesAndPassesHeaders() {
        let sent = expectation(description: "sends payload")
        let sender = OneSignalLogHttpSender { request, completion in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/custom")
            XCTAssertEqual(request.value(forHTTPHeaderField: "SDK-Version"), "onesignal/ios/test")
            XCTAssertEqual(request.httpBody, Data([4, 5, 6]))
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 202,
                httpVersion: nil,
                headerFields: nil
            )!
            completion(nil, response, nil)
        }

        let request = LogHttpRequest(
            url: "https://example.com/sdk/log",
            headers: [
                "Content-Type": "application/custom",
                "SDK-Version": "onesignal/ios/test"
            ],
            contentType: "application/x-protobuf",
            body: makeKotlinBytes([4, 5, 6])
        )
        sender.send(request: request) { response, error in
            XCTAssertNil(error)
            XCTAssertEqual(response?.statusCode, 202)
            XCTAssertTrue(response?.success == true)
            sent.fulfill()
        }

        wait(for: [sent], timeout: 2)
    }

    func testHttpSenderReturnsAndLogsFailureBodyWhenDiagnosticsEnabled() {
        let logger = TestLogger()
        let sender = OneSignalLogHttpSender(
            requestSender: { request, completion in
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 403,
                    httpVersion: nil,
                    headerFields: nil
                )!
                completion(Data("denied".utf8), response, nil)
            },
            logger: logger,
            isDiagnosticsEnabled: { true }
        )
        let request = LogHttpRequest(
            url: "https://example.com/sdk/log",
            headers: [:],
            contentType: "application/x-protobuf",
            body: makeKotlinBytes([1])
        )
        let sent = expectation(description: "returns failed response")

        sender.send(request: request) { response, error in
            XCTAssertNil(error)
            XCTAssertEqual(response?.statusCode, 403)
            XCTAssertEqual(response?.message, "denied")
            XCTAssertEqual(logger.warnings.count, 1)
            sent.fulfill()
        }

        wait(for: [sent], timeout: 2)
    }

    func testHttpSenderDoesNotStartRequestWhenDisabled() {
        var requestStarted = false
        let sender = OneSignalLogHttpSender(
            requestSender: { _, _ in requestStarted = true },
            isEnabled: { false }
        )
        let request = LogHttpRequest(
            url: "https://example.com/sdk/log",
            headers: [:],
            contentType: "application/x-protobuf",
            body: makeKotlinBytes([1])
        )
        let sent = expectation(description: "returns disabled response")

        sender.send(request: request) { response, error in
            XCTAssertNil(error)
            XCTAssertFalse(response?.success == true)
            XCTAssertEqual(response?.message, "Remote logging is disabled")
            sent.fulfill()
        }

        wait(for: [sent], timeout: 2)
        XCTAssertFalse(requestStarted)
    }

    func testLoggerDelegatesToOneSignalLog() {
        let listener = LoggerAdapterListener()
        OneSignalLog.debug().__add(listener)
        defer { OneSignalLog.debug().__remove(listener) }

        let logger = IOSLogger()
        logger.error(message: "error")
        logger.warn(message: "warn")
        logger.info(message: "info")
        logger.debug(message: "debug")

        XCTAssertEqual(listener.levels, [.LL_ERROR, .LL_WARN, .LL_INFO, .LL_DEBUG])
    }

    func testKmpPipelineInvokesSwiftAdapters() throws {
        let listener = LoggerAdapterListener()
        OneSignalLog.debug().__add(listener)
        defer { OneSignalLog.debug().__remove(listener) }
        let store = FileLogStore(rootPath: temporaryDirectory.path)
        let logger = IOSLogger()
        let telemetry = LoggerFactory.shared.createCrashLocalTelemetry(
            platformProvider: makePlatformProvider(),
            fileStore: store
        )
        let reporter = LoggerFactory.shared.createCrashReporter(
            crashTelemetry: telemetry,
            logger: logger
        )
        let crash = CrashData(
            threadName: "test",
            exceptionType: "TestError",
            exceptionMessage: "test message",
            stacktrace: "test stack"
        )

        _ = try reporter.saveNonFatal(crash: crash)

        XCTAssertEqual(listener.levels, [.LL_INFO, .LL_INFO])
        XCTAssertEqual(
            try FileManager.default.contentsOfDirectory(atPath: temporaryDirectory.path)
                .filter { $0.hasSuffix(".otlp") }
                .count,
            1
        )
    }

    func testCrashHandlerSynchronouslyPersistsUncaughtException() throws {
        let store = FileLogStore(rootPath: temporaryDirectory.path)
        let logger = IOSLogger()
        let telemetry = LoggerFactory.shared.createCrashLocalTelemetry(
            platformProvider: makePlatformProvider(),
            fileStore: store
        )
        let reporter = LoggerFactory.shared.createCrashReporter(
            crashTelemetry: telemetry,
            logger: logger
        )
        let handler = OSLogCrashHandler(reporter: reporter)
        let exception = NSException(
            name: NSExceptionName("TestException"),
            reason: "test crash",
            userInfo: nil
        )

        handler.handle(
            exception: exception,
            stackSymbols: ["0 OneSignalCore 0x000000 OneSignalExample + 1"]
        )

        XCTAssertEqual(
            try FileManager.default.contentsOfDirectory(atPath: temporaryDirectory.path)
                .filter { $0.hasSuffix(".otlp") }
                .count,
            1
        )
    }

    func testCrashHandlerIgnoresCrashWithoutOneSignalFrames() throws {
        let store = FileLogStore(rootPath: temporaryDirectory.path)
        let telemetry = LoggerFactory.shared.createCrashLocalTelemetry(
            platformProvider: makePlatformProvider(),
            fileStore: store
        )
        let reporter = LoggerFactory.shared.createCrashReporter(
            crashTelemetry: telemetry,
            logger: IOSLogger()
        )
        let handler = OSLogCrashHandler(reporter: reporter)

        handler.handle(
            exception: NSException(name: NSExceptionName("HostException"), reason: nil),
            stackSymbols: ["0 ExampleApp 0x000000 AppDelegate + 1"]
        )

        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: temporaryDirectory.path).isEmpty)
    }

    func testCrashHandlerDoesNotReplaceHostSignalHandler() {
        let store = FileLogStore(rootPath: temporaryDirectory.path)
        let telemetry = LoggerFactory.shared.createCrashLocalTelemetry(
            platformProvider: makePlatformProvider(),
            fileStore: store
        )
        let reporter = LoggerFactory.shared.createCrashReporter(
            crashTelemetry: telemetry,
            logger: IOSLogger()
        )
        let handler = OSLogCrashHandler(reporter: reporter)
        let originalHandler = Darwin.signal(SIGABRT, osLoggerAdaptersTestSignalHandler)
        defer { Darwin.signal(SIGABRT, originalHandler) }

        handler.initialize()
        defer { handler.unregister() }
        let installedHandler = Darwin.signal(SIGABRT, osLoggerAdaptersTestSignalHandler)
        Darwin.signal(SIGABRT, installedHandler)

        XCTAssertEqual(
            signalHandlerAddress(installedHandler),
            signalHandlerAddress(osLoggerAdaptersTestSignalHandler)
        )
    }

    func testCrashHandlerRestoresPreviousExceptionHandler() {
        let handler = makeCrashHandler()
        let originalHandler = NSGetUncaughtExceptionHandler()
        NSSetUncaughtExceptionHandler(osLoggerAdaptersTestExceptionHandler)
        defer { NSSetUncaughtExceptionHandler(originalHandler) }

        handler.initialize()
        handler.unregister()

        XCTAssertEqual(
            exceptionHandlerAddress(NSGetUncaughtExceptionHandler()),
            exceptionHandlerAddress(osLoggerAdaptersTestExceptionHandler)
        )
    }

    func testCrashHandlerPreservesHandlerInstalledAfterIt() {
        let handler = makeCrashHandler()
        let originalHandler = NSGetUncaughtExceptionHandler()
        defer { NSSetUncaughtExceptionHandler(originalHandler) }
        handler.initialize()

        NSSetUncaughtExceptionHandler(osLoggerAdaptersReplacementExceptionHandler)
        handler.unregister()

        XCTAssertEqual(
            exceptionHandlerAddress(NSGetUncaughtExceptionHandler()),
            exceptionHandlerAddress(osLoggerAdaptersReplacementExceptionHandler)
        )
    }

    func testCrashHandlerForwardsInFlightCallbackAfterUnregister() {
        resetExceptionHandlerCallCount()
        let handler = makeCrashHandler()
        let originalHandler = NSGetUncaughtExceptionHandler()
        NSSetUncaughtExceptionHandler(osLoggerAdaptersCountingExceptionHandler)
        defer { NSSetUncaughtExceptionHandler(originalHandler) }
        handler.initialize()
        handler.unregister()

        OSLogCrashHandler.handleActive(
            NSException(name: NSExceptionName("InFlightException"), reason: nil)
        )

        XCTAssertEqual(exceptionHandlerCallCount(), 1)
    }

    func testCrashHandlerStopsReentrantPreviousHandler() {
        resetExceptionHandlerCallCount()
        let handler = makeCrashHandler()
        let originalHandler = NSGetUncaughtExceptionHandler()
        NSSetUncaughtExceptionHandler(osLoggerAdaptersReentrantExceptionHandler)
        defer { NSSetUncaughtExceptionHandler(originalHandler) }
        handler.initialize()
        defer { handler.unregister() }

        OSLogCrashHandler.handleActive(
            NSException(name: NSExceptionName("ReentrantException"), reason: nil)
        )

        XCTAssertEqual(exceptionHandlerCallCount(), 1)
    }

    func testCrashUploaderCoordinatorSerializesUploaders() {
        let coordinator = OSCrashUploaderCoordinator()
        let firstOwner = UUID()
        let secondOwner = UUID()
        var started: [String] = []

        coordinator.enqueue(owner: firstOwner) {
            started.append("first")
        }
        coordinator.enqueue(owner: secondOwner) {
            started.append("second")
        }

        XCTAssertEqual(started, ["first"])
        coordinator.finish(owner: firstOwner)
        XCTAssertEqual(started, ["first", "second"])
    }

    func testCrashUploaderCoordinatorCancelsPendingUploader() {
        let coordinator = OSCrashUploaderCoordinator()
        let firstOwner = UUID()
        let secondOwner = UUID()
        var started: [String] = []

        coordinator.enqueue(owner: firstOwner) {
            started.append("first")
        }
        coordinator.enqueue(owner: secondOwner) {
            started.append("second")
        }
        coordinator.cancel(owner: secondOwner)
        coordinator.finish(owner: firstOwner)

        XCTAssertEqual(started, ["first"])
    }

    func testPlatformProviderReturnsInjectedIdentifiersAndPlatformMetadata() {
        let provider = makePlatformProvider()
        var firstInstallId: String?
        var secondInstallId: String?

        provider.getInstallId { value, _ in firstInstallId = value }
        provider.getInstallId { value, _ in secondInstallId = value }

        XCTAssertEqual(firstInstallId, "install-id")
        XCTAssertEqual(firstInstallId, secondInstallId)
        XCTAssertEqual(provider.onesignalId, "onesignal-id")
        XCTAssertEqual(provider.pushSubscriptionId, "subscription-id")
        XCTAssertEqual(provider.appState, "foreground")
        XCTAssertEqual(provider.enabledFeatureFlags, ["feature"])
        XCTAssertEqual(provider.remoteLogLevel, "WARN")
        XCTAssertTrue(provider.isExporterLoggingEnabled)
        XCTAssertEqual(provider.sdkBase, "ios")
        XCTAssertFalse(provider.appPackageId.isEmpty)
        XCTAssertFalse(provider.osVersion.isEmpty)
        XCTAssertGreaterThanOrEqual(provider.processUptime, 0)
    }

    func testProcessUptimeUsesProcessStartAndClampsClockMismatch() {
        XCTAssertEqual(
            OSLoggerPlatformProvider.processUptimeMillis(
                systemUptime: 100,
                processStartUptime: 95
            ),
            5_000
        )
        XCTAssertEqual(
            OSLoggerPlatformProvider.processUptimeMillis(
                systemUptime: 95,
                processStartUptime: 100
            ),
            0
        )
    }

    private func makePlatformProvider() -> OSLoggerPlatformProvider {
        OSLoggerPlatformProvider(
            installIdProvider: { "install-id" },
            onesignalIdProvider: { "onesignal-id" },
            pushSubscriptionIdProvider: { "subscription-id" },
            appStateProvider: { "foreground" },
            featureFlagsProvider: { ["feature"] },
            remoteLogLevelProvider: { "warn" },
            exporterLoggingEnabledProvider: { true }
        )
    }

    private func makeCrashHandler() -> OSLogCrashHandler {
        let store = FileLogStore(rootPath: temporaryDirectory.path)
        let telemetry = LoggerFactory.shared.createCrashLocalTelemetry(
            platformProvider: makePlatformProvider(),
            fileStore: store
        )
        let reporter = LoggerFactory.shared.createCrashReporter(
            crashTelemetry: telemetry,
            logger: IOSLogger()
        )
        return OSLogCrashHandler(reporter: reporter)
    }

    private func makeKotlinBytes(_ bytes: [UInt8]) -> KotlinByteArray {
        AppleByteArrayInterop.shared.toByteArray(data: Data(bytes))
    }
}

private typealias TestSignalHandler = @convention(c) (Int32) -> Void
private typealias TestExceptionHandler = @convention(c) (NSException) -> Void
private let exceptionHandlerCallLock = NSLock()
private var exceptionHandlerCalls = 0

private func osLoggerAdaptersTestSignalHandler(_: Int32) {}
private func osLoggerAdaptersTestExceptionHandler(_: NSException) {}
private func osLoggerAdaptersReplacementExceptionHandler(_: NSException) {}
private func osLoggerAdaptersCountingExceptionHandler(_: NSException) {
    exceptionHandlerCallLock.lock()
    exceptionHandlerCalls += 1
    exceptionHandlerCallLock.unlock()
}

private func osLoggerAdaptersReentrantExceptionHandler(_ exception: NSException) {
    osLoggerAdaptersCountingExceptionHandler(exception)
    OSLogCrashHandler.handleActive(exception)
}

private func resetExceptionHandlerCallCount() {
    exceptionHandlerCallLock.lock()
    exceptionHandlerCalls = 0
    exceptionHandlerCallLock.unlock()
}

private func exceptionHandlerCallCount() -> Int {
    exceptionHandlerCallLock.lock()
    defer { exceptionHandlerCallLock.unlock() }
    return exceptionHandlerCalls
}

private func signalHandlerAddress(_ handler: TestSignalHandler?) -> UInt {
    handler.map { unsafeBitCast($0, to: UInt.self) } ?? 0
}

private func exceptionHandlerAddress(_ handler: TestExceptionHandler?) -> UInt {
    handler.map { unsafeBitCast($0, to: UInt.self) } ?? 0
}

private final class LoggerAdapterListener: NSObject, OSLogListener {
    var levels: [ONE_S_LOG_LEVEL] = []

    func onLogEvent(_ event: OneSignalLogEvent) {
        levels.append(event.level)
    }
}

private final class TestLogger: NSObject, ILogger {
    var warnings: [String] = []

    func error(message: String) {}

    func warn(message: String) {
        warnings.append(message)
    }

    func info(message: String) {}

    func debug(message: String) {}
}

private extension KotlinByteArray {
    var bytes: [UInt8] {
        Array(AppleByteArrayInterop.shared.toNSData(bytes: self))
    }
}
