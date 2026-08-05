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
    func testConfigurationRequiresFeatureFlagAndRemoteLevel() {
        let levelOnly = OSRemoteLoggingConfiguration(
            remoteParams: ["logging_config": ["log_level": "WARN"]]
        )
        XCTAssertFalse(levelOnly.isRemoteLoggingEnabled)

        let flagOnly = OSRemoteLoggingConfiguration(
            remoteParams: ["sdk_custom_logging": true]
        )
        XCTAssertFalse(flagOnly.isRemoteLoggingEnabled)

        let enabled = OSRemoteLoggingConfiguration(
            remoteParams: [
                "sdk_custom_logging": true,
                "logging_config": ["log_level": "warn"]
            ]
        )
        XCTAssertTrue(enabled.isRemoteLoggingEnabled)
        XCTAssertTrue(enabled.allows(.LL_ERROR))
        XCTAssertTrue(enabled.allows(.LL_WARN))
        XCTAssertFalse(enabled.allows(.LL_INFO))

        let enabledFromFlagList = OSRemoteLoggingConfiguration(
            remoteParams: [
                "sdk_remote_feature_flags": ["sdk_custom_logging"],
                "logging_config": ["log_level": "ERROR"]
            ]
        )
        XCTAssertTrue(enabledFromFlagList.isRemoteLoggingEnabled)
    }

    func testControllerRoutesLogsAndFlushesOnBackground() {
        let notificationCenter = NotificationCenter()
        let telemetry = RemoteTelemetrySpy()
        telemetry.emitExpectation = expectation(description: "routes matching log")
        telemetry.flushExpectation = expectation(description: "flushes on background")
        let controller = OSRemoteLoggingController(
            notificationCenter: notificationCenter,
            remoteLoggerFactory: { _ in telemetry }
        )

        controller.configure(
            remoteParams: [
                "sdk_custom_logging": true,
                "logging_config": ["log_level": "ERROR"]
            ]
        )
        OneSignalLog.onesignalLog(.LL_INFO, message: "not uploaded")
        OneSignalLog.onesignalLog(.LL_ERROR, message: "uploaded")
        notificationCenter.post(name: UIApplication.didEnterBackgroundNotification, object: nil)

        wait(for: [telemetry.emitExpectation!, telemetry.flushExpectation!], timeout: 2)
        controller.shutdown()

        XCTAssertEqual(telemetry.messages, ["uploaded"])
        XCTAssertEqual(telemetry.levels, ["ERROR"])
        XCTAssertEqual(telemetry.shutdownCount, 1)
    }
}

private final class RemoteTelemetrySpy: OSRemoteLoggerProtocol {
    private let lock = NSLock()
    var emitExpectation: XCTestExpectation?
    var flushExpectation: XCTestExpectation?
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

    func forceFlush() {
        flushExpectation?.fulfill()
    }

    func shutdown() {
        lock.lock()
        shutdownCount += 1
        lock.unlock()
    }
}
