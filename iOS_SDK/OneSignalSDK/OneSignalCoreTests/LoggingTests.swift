/*
 Modified MIT License
 
 Copyright 2025 OneSignal
 
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

class TestLogListener: NSObject, OSLogListener {
    var calls: [String] = []
    let callback: ((OneSignalLogEvent) -> Void)?

    init(_ callback: ((OneSignalLogEvent) -> Void)? = nil) {
        self.callback = callback
    }

    func onLogEvent(_ event: OneSignalLogEvent) {
        calls.append(event.entry)
        guard let callback = callback else { return }
        callback(event)
    }
}

private final class TestInternalLogSink: NSObject, OSInternalLogSink {
    var levels: [ONE_S_LOG_LEVEL] = []
    var messages: [String] = []

    func captureLog(
        with level: ONE_S_LOG_LEVEL,
        message: String,
        exceptionType: String?,
        exceptionMessage: String?,
        exceptionStacktrace: String?
    ) {
        levels.append(level)
        messages.append(message)
    }
}

final class LoggingTests: XCTestCase {
    override func setUpWithError() throws {
        OneSignalLog.setLogLevel(.LL_NONE)
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testAddListener() throws {
        // Given
        let listener = TestLogListener()
        OneSignalLog.debug().__add(listener)

        // When
        OneSignalLog.onesignalLog(.LL_DEBUG, message: "test")

        // Then
        XCTAssertEqual(listener.calls, ["DEBUG: test"])
    }

    func testAddListenerTwice() throws {
        // Given
        let listener = TestLogListener()
        OneSignalLog.debug().__add(listener)
        OneSignalLog.debug().__add(listener)

        // When
        OneSignalLog.onesignalLog(.LL_DEBUG, message: "test")

        // Then
        XCTAssertEqual(listener.calls, ["DEBUG: test"])
    }

    func testRemoveListener() throws {
        // Given
        let listener = TestLogListener()
        OneSignalLog.debug().__add(listener)
        OneSignalLog.debug().__remove(listener)

        // When
        OneSignalLog.onesignalLog(.LL_DEBUG, message: "test")

        // Then
        XCTAssertEqual(listener.calls, [])
    }

    func testRemoveListenerTwice() throws {
        // Given
        let listener = TestLogListener()
        OneSignalLog.debug().__add(listener)
        OneSignalLog.debug().__remove(listener)
        OneSignalLog.debug().__remove(listener)

        // When
        OneSignalLog.onesignalLog(.LL_DEBUG, message: "test")

        // Then
        XCTAssertEqual(listener.calls, [])
    }

    func testAddListenerNested() throws {
        // Given
        let nestedListener = TestLogListener()
        let firstListener = TestLogListener({ _ in
            OneSignalLog.debug().__add(nestedListener)
        })

        OneSignalLog.debug().__add(firstListener)

        // When
        OneSignalLog.onesignalLog(.LL_DEBUG, message: "test")
        OneSignalLog.onesignalLog(.LL_DEBUG, message: "test2")
        OneSignalLog.onesignalLog(.LL_DEBUG, message: "test3")

        // Then
        XCTAssertEqual(nestedListener.calls, ["DEBUG: test2", "DEBUG: test3"])
    }

    func testRemoveListenerNested() throws {
        // Given
        var calls: [String] = []
        var listener: OSLogListener?

        listener = TestLogListener({ event in
            calls.append(event.entry)
            OneSignalLog.debug().__remove(listener!)
        })

        OneSignalLog.debug().__add(listener!)

        // When
        OneSignalLog.onesignalLog(.LL_DEBUG, message: "test")
        OneSignalLog.onesignalLog(.LL_DEBUG, message: "test2")

        // Then
        XCTAssertEqual(calls, ["DEBUG: test"])
    }

    func testInternalSinkReceivesRawLogAndCanBeRemoved() {
        let sink = TestInternalLogSink()
        OneSignalLog.__setInternalLogSink(sink)

        OneSignalLog.onesignalLog(.LL_WARN, message: "raw message")
        OneSignalLog.__removeInternalLogSink(sink)
        OneSignalLog.onesignalLog(.LL_ERROR, message: "not captured")

        XCTAssertEqual(sink.levels, [.LL_WARN])
        XCTAssertEqual(sink.messages, ["raw message"])
    }

    // MARK: - Credential redaction

    private let bearer = "jwt-a1b2c3"

    /// Headers as `OSRequestAuth` and the User module set them on a signed request.
    private func signedRequest() -> OneSignalRequest {
        let request = OneSignalRequest()
        request.method = GET
        request.path = "apps/test-app-id/users/by/external_id/user-a"
        request.parameters = ["app_id": "test-app-id"]
        request.additionalHeaders = ["Authorization": "Bearer \(bearer)", "OneSignal-Subscription-Id": "sub-a"]
        return request
    }

    /// The send log masks the bearer and nothing else.
    func testSendingASignedRequestLogsTheHeadersWithTheBearerMasked() throws {
        let listener = TestLogListener()
        OneSignalLog.debug().__add(listener)
        defer { OneSignalLog.debug().__remove(listener) }
        let request = signedRequest()

        XCTAssertTrue(OneSignalClient.shared().validRequest(request))

        let entry = try XCTUnwrap(listener.calls.first { $0.contains("HTTP Request") })
        XCTAssertFalse(entry.contains(bearer), entry)
        XCTAssertTrue(entry.contains("Authorization = \"<redacted>\""), entry)
        XCTAssertTrue(entry.contains("sub-a"), entry)
        XCTAssertFalse(listener.calls.contains { $0.contains(bearer) }, "\(listener.calls)")
        XCTAssertEqual(request.urlRequest().value(forHTTPHeaderField: "Authorization"), "Bearer \(bearer)")
    }

    /// The response log masks the bearer too.
    func testHandlingAResponseLogsTheHeadersWithTheBearerMasked() throws {
        let listener = TestLogListener()
        OneSignalLog.debug().__add(listener)
        defer { OneSignalLog.debug().__remove(listener) }
        let request = signedRequest()
        let url = try XCTUnwrap(request.urlRequest().url)
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
        let body = try JSONSerialization.data(withJSONObject: ["onesignal_id": "osid-a"])
        var result: [AnyHashable: Any]?

        OneSignalClient.shared().handleJSONNSURLResponse(
            response, data: body, error: nil, isAsync: false, with: request,
            onSuccess: { result = $0 },
            onFailure: { XCTFail("\($0)") }
        )

        XCTAssertEqual(result?["onesignal_id"] as? String, "osid-a")
        let entry = try XCTUnwrap(listener.calls.first { $0.contains("network request") })
        XCTAssertFalse(entry.contains(bearer), entry)
        XCTAssertTrue(entry.contains("Authorization = \"<redacted>\""), entry)
        XCTAssertFalse(listener.calls.contains { $0.contains(bearer) }, "\(listener.calls)")
        XCTAssertEqual(request.urlRequest().value(forHTTPHeaderField: "Authorization"), "Bearer \(bearer)")
    }
}
