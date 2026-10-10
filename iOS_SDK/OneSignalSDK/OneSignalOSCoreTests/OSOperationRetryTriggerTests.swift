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
@testable import OneSignalOSCore

private final class FakePathMonitor: OSNetworkPathMonitoring {
    private(set) var startCount = 0
    private var onAvailable: (() -> Void)?

    func start(onAvailable: @escaping () -> Void) {
        startCount += 1
        self.onAvailable = onAvailable
    }

    func networkBecomesAvailable() {
        onAvailable?()
    }
}

final class OSOperationRetryTriggerTests: XCTestCase {
    private var monitor: FakePathMonitor!
    private var trigger: OSOperationRetryTrigger!
    private var retryCount = 0

    override func setUp() {
        super.setUp()
        monitor = FakePathMonitor()
        trigger = OSOperationRetryTrigger(pathMonitor: monitor)
        retryCount = 0
        trigger.onRetry = { [unowned self] in self.retryCount += 1 }
    }

    func testRetriesOnFocus() {
        trigger.onFocus()

        XCTAssertEqual(retryCount, 1)
    }

    func testRetriesWhenTheNetworkReturnsWhileFocused() {
        trigger.onFocus()

        monitor.networkBecomesAvailable()

        XCTAssertEqual(retryCount, 2)
    }

    func testIgnoresTheNetworkReturningInTheBackground() {
        trigger.onFocus()
        trigger.onUnfocus()

        monitor.networkBecomesAvailable()

        XCTAssertEqual(retryCount, 1)
    }

    func testStartsMonitoringOnceOnTheFirstFocus() {
        XCTAssertEqual(monitor.startCount, 0)

        trigger.onFocus()
        trigger.onUnfocus()
        trigger.onFocus()

        XCTAssertEqual(monitor.startCount, 1)
    }
}
