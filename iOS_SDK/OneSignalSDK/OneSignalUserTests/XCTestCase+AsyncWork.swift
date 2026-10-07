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

extension XCTestCase {
    /**
     Gives queued async work a chance to run, for assertions that something did *not* happen.

     An absence has no condition to poll, so proving one needs either a fixed wait or a
     deterministic drain of whatever drives the work. Use `OneSignalCoreMocks.waitUntil`
     anywhere a condition does exist: it returns as soon as the condition holds and it fails
     the test with a message when it never does.

     Waits through `XCTWaiter` rather than sleeping, so the run loop keeps pumping and work
     dispatched to the main queue can actually run.
     */
    func allowAsyncWorkToRun(seconds: Double = 0.5) {
        let unfulfilled = XCTestExpectation(description: "Allow \(seconds)s for async work")
        _ = XCTWaiter.wait(for: [unfulfilled], timeout: seconds)
    }
}
