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
import OneSignalKMP
@testable import OneSignalOSCore
import XCTest

final class OSLogCrashHandlerTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: temporaryDirectory)
    }

    func testSynchronouslyPersistsUncaughtException() throws {
        let handler = makeCrashHandler()
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

    func testIgnoresCrashWithoutOneSignalModule() throws {
        let handler = makeCrashHandler()

        handler.handle(
            exception: NSException(name: NSExceptionName("HostException"), reason: nil),
            stackSymbols: ["0 ExampleApp 0x000000 AppDelegate + 1"]
        )

        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: temporaryDirectory.path).isEmpty)
    }

    func testIgnoresOneSignalSubstringOutsideModuleField() {
        XCTAssertFalse(
            OSLogCrashHandler.isOneSignalAtFault(
                ["0 ExampleApp 0x000000 OneSignalNotificationCallback + 1"]
            )
        )
    }

    func testRecognizesKnownOneSignalModule() {
        XCTAssertTrue(
            OSLogCrashHandler.isOneSignalAtFault(
                ["0 OneSignalNotifications 0x000000 NotificationHandler + 1"]
            )
        )
    }

    func testDoesNotReplaceHostSignalHandler() {
        let handler = makeCrashHandler()
        let originalHandler = Darwin.signal(SIGABRT, osLogCrashTestSignalHandler)
        defer { Darwin.signal(SIGABRT, originalHandler) }

        handler.initialize()
        defer { handler.unregister() }
        let installedHandler = Darwin.signal(SIGABRT, osLogCrashTestSignalHandler)
        Darwin.signal(SIGABRT, installedHandler)

        XCTAssertEqual(
            signalHandlerAddress(installedHandler),
            signalHandlerAddress(osLogCrashTestSignalHandler)
        )
    }

    func testRestoresPreviousExceptionHandler() {
        let handler = makeCrashHandler()
        let originalHandler = NSGetUncaughtExceptionHandler()
        NSSetUncaughtExceptionHandler(osLogCrashTestExceptionHandler)
        defer { NSSetUncaughtExceptionHandler(originalHandler) }

        handler.initialize()
        handler.unregister()

        XCTAssertEqual(
            exceptionHandlerAddress(NSGetUncaughtExceptionHandler()),
            exceptionHandlerAddress(osLogCrashTestExceptionHandler)
        )
    }

    func testPreservesHandlerInstalledAfterIt() {
        let handler = makeCrashHandler()
        let originalHandler = NSGetUncaughtExceptionHandler()
        defer { NSSetUncaughtExceptionHandler(originalHandler) }
        handler.initialize()

        NSSetUncaughtExceptionHandler(osLogCrashReplacementExceptionHandler)
        handler.unregister()

        XCTAssertEqual(
            exceptionHandlerAddress(NSGetUncaughtExceptionHandler()),
            exceptionHandlerAddress(osLogCrashReplacementExceptionHandler)
        )
    }

    func testForwardsInFlightCallbackAfterUnregister() {
        resetExceptionHandlerCallCount()
        let handler = makeCrashHandler()
        let originalHandler = NSGetUncaughtExceptionHandler()
        NSSetUncaughtExceptionHandler(osLogCrashCountingExceptionHandler)
        defer { NSSetUncaughtExceptionHandler(originalHandler) }
        handler.initialize()
        handler.unregister()

        OSLogCrashHandler.handleActive(
            NSException(name: NSExceptionName("InFlightException"), reason: nil)
        )

        XCTAssertEqual(exceptionHandlerCallCount(), 1)
    }

    func testStopsReentrantPreviousHandler() {
        resetExceptionHandlerCallCount()
        let handler = makeCrashHandler()
        let originalHandler = NSGetUncaughtExceptionHandler()
        NSSetUncaughtExceptionHandler(osLogCrashReentrantExceptionHandler)
        defer { NSSetUncaughtExceptionHandler(originalHandler) }
        handler.initialize()
        defer { handler.unregister() }

        OSLogCrashHandler.handleActive(
            NSException(name: NSExceptionName("ReentrantException"), reason: nil)
        )

        XCTAssertEqual(exceptionHandlerCallCount(), 1)
    }

    func testUploaderCoordinatorSerializesUploaders() {
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

    func testUploaderCoordinatorCancelsPendingUploader() {
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

    func testUploaderCoordinatorCancelActiveStartsNext() {
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
        coordinator.cancel(owner: firstOwner)
        coordinator.finish(owner: firstOwner)

        XCTAssertEqual(started, ["first", "second"])
    }

    private func makeCrashHandler() -> OSLogCrashHandler {
        let store = FileLogStore(rootPath: temporaryDirectory.path)
        let telemetry = LoggerFactory.shared.createCrashLocalTelemetry(
            platformProvider: makePlatformProvider(),
            fileStore: store
        )
        let reporter = LoggerFactory.shared.createCrashReporter(
            crashTelemetry: telemetry,
            logger: OSCrashLogger()
        )
        return OSLogCrashHandler(reporter: reporter)
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
}

private typealias TestSignalHandler = @convention(c) (Int32) -> Void
private typealias TestExceptionHandler = @convention(c) (NSException) -> Void
private let exceptionHandlerCallLock = NSLock()
private var exceptionHandlerCalls = 0

private func osLogCrashTestSignalHandler(_: Int32) {}
private func osLogCrashTestExceptionHandler(_: NSException) {}
private func osLogCrashReplacementExceptionHandler(_: NSException) {}
private func osLogCrashCountingExceptionHandler(_: NSException) {
    exceptionHandlerCallLock.lock()
    exceptionHandlerCalls += 1
    exceptionHandlerCallLock.unlock()
}

private func osLogCrashReentrantExceptionHandler(_ exception: NSException) {
    osLogCrashCountingExceptionHandler(exception)
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
