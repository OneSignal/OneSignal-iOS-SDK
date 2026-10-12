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
import OneSignalCore
@testable import OneSignalOSCore

final class OSRequestRetryBackoffTests: XCTestCase {
    private var uptime: TimeInterval = 1_000
    private var backoff: OSRequestRetryBackoff!

    override func setUp() {
        super.setUp()
        uptime = 1_000
        backoff = OSRequestRetryBackoff(uptime: { self.uptime }, jitter: { 1 })
    }

    private func error(_ code: Int, headers: [String: String]? = nil) -> OneSignalClientError {
        return OneSignalClientError(code: code, message: "not-important", responseHeaders: headers, response: nil, underlyingError: nil)
    }

    func testDelaysDoubleUpToTheCap() {
        let request = NSObject()

        let delays = (0..<8).map { _ in backoff.recordFailure(request, error: error(500)) }

        XCTAssertEqual(delays, [5, 10, 20, 40, 80, 160, 300, 300])
    }

    func testJitterShortensTheDelay() {
        backoff = OSRequestRetryBackoff(uptime: { self.uptime }, jitter: { 0.5 })

        XCTAssertEqual(backoff.recordFailure(NSObject(), error: error(500)), 2.5)
    }

    func testWaitsUntilTheDelayPasses() {
        let request = NSObject()
        XCTAssertFalse(backoff.isWaiting(request))

        backoff.recordFailure(request, error: error(0))
        XCTAssertTrue(backoff.isWaiting(request))

        uptime += 5
        XCTAssertFalse(backoff.isWaiting(request))
    }

    func testRequestsBackOffIndependently() {
        let failed = NSObject()
        backoff.recordFailure(failed, error: error(500))

        XCTAssertFalse(backoff.isWaiting(NSObject()))
    }

    func testRetryAfterIsTheMinimumWait() {
        XCTAssertEqual(backoff.recordFailure(NSObject(), error: error(503, headers: ["retry-after": "120"])), 120)
    }

    func testA429WithoutRetryAfterWaitsTheDefault() {
        XCTAssertEqual(backoff.recordFailure(NSObject(), error: error(429)), OSRequestRetryBackoff.defaultRetryAfterSeconds)
    }

    func testRetryAfterThatIsNotAFiniteDelayWaitsTheDefault() {
        for value in ["inf", "nan", "-5", "Wed, 21 Oct 2026 07:28:00 GMT"] {
            let delay = backoff.recordFailure(NSObject(), error: error(503, headers: ["Retry-After": value]))
            XCTAssertEqual(delay, OSRequestRetryBackoff.defaultRetryAfterSeconds, value)
        }
    }

    func testRetryAfterIsCapped() {
        let delay = backoff.recordFailure(NSObject(), error: error(503, headers: ["Retry-After": "1e400"]))
        XCTAssertEqual(delay, OSRequestRetryBackoff.defaultRetryAfterSeconds, "1e400 overflows to inf")

        let capped = backoff.recordFailure(NSObject(), error: error(503, headers: ["Retry-After": "86400"]))
        XCTAssertEqual(capped, OSRequestRetryBackoff.maxRetryAfterSeconds)
    }

    func testRetryNowReportsWhetherItEndedAWait() {
        XCTAssertFalse(backoff.retryNow(), "nothing is waiting")

        let request = NSObject()
        backoff.recordFailure(request, error: error(500))
        XCTAssertTrue(backoff.retryNow())
        XCTAssertFalse(backoff.retryNow(), "already ended")

        backoff.recordFailure(request, error: error(500))
        uptime += 60
        XCTAssertFalse(backoff.retryNow(), "the wait had already passed")
    }

    func testRetryNowEndsTheBackoffButNotRetryAfter() {
        let backingOff = NSObject()
        let rateLimited = NSObject()
        backoff.recordFailure(backingOff, error: error(500))
        backoff.recordFailure(rateLimited, error: error(429, headers: ["Retry-After": "30"]))

        backoff.retryNow()

        XCTAssertFalse(backoff.isWaiting(backingOff))
        XCTAssertTrue(backoff.isWaiting(rateLimited))
        uptime += 30
        XCTAssertFalse(backoff.isWaiting(rateLimited))
    }
}
