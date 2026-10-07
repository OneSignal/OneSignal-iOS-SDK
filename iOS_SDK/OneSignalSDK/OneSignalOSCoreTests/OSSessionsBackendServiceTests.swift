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
@testable import OneSignalOSCore
import XCTest

private final class FakeClient: NSObject, IOneSignalClient {
    enum Outcome {
        case success([AnyHashable: Any]?)
        case failure(code: Int, headers: [String: String]?)
    }

    var outcome: Outcome = .success(nil)
    private(set) var requests: [OneSignalRequest] = []

    func execute(
        _ request: OneSignalRequest,
        onSuccess successBlock: @escaping OSResultSuccessBlock,
        onFailure failureBlock: @escaping OSClientFailureBlock
    ) {
        requests.append(request)
        switch outcome {
        case .success(let response):
            successBlock(response)
        case .failure(let code, let headers):
            failureBlock(OneSignalClientError(code: code, message: "failure", responseHeaders: headers, response: nil, underlyingError: nil))
        }
    }
}

final class OSSessionsBackendServiceTests: XCTestCase {
    private let createBody = OSCreateSessionRequestBody(
        onesignalId: "onesignal-id",
        subscriptionId: "subscription-id",
        startTime: 1_700_000_000,
        idempotencyKey: "create-key"
    )
    private let updateBody = OSUpdateSessionRequestBody(
        onesignalId: "onesignal-id",
        subscriptionId: "subscription-id",
        durationSeconds: 42,
        idempotencyKey: "update-key"
    )
    private var client: FakeClient!
    private var service: OSSessionsBackendService!

    override func setUp() {
        super.setUp()
        client = FakeClient()
        service = OSSessionsBackendService(client: { [unowned self] in self.client })
    }

    private func create(_ body: OSCreateSessionRequestBody? = nil) -> OSSessionsApiResult<String>? {
        var result: OSSessionsApiResult<String>?
        service.createSession(appId: "app-id", body: body ?? createBody) { result = $0 }
        return result
    }

    private func update(_ body: OSUpdateSessionRequestBody? = nil) -> OSSessionsApiResult<Void>? {
        var result: OSSessionsApiResult<Void>?
        service.updateSession(appId: "app-id", sessionId: "server-id", body: body ?? updateBody) { result = $0 }
        return result
    }

    /// `Void` is not `Equatable`, so compare update results through their failure fields.
    private func assertUpdate(
        _ result: OSSessionsApiResult<Void>?,
        matches expected: OSSessionsApiResult<String>,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let mapped: OSSessionsApiResult<String>? = result.map {
            switch $0 {
            case .success: return .success("")
            case .retry(let statusCode, let retryAfterSeconds): return .retry(statusCode: statusCode, retryAfterSeconds: retryAfterSeconds)
            case .drop(let statusCode): return .drop(statusCode: statusCode)
            }
        }
        XCTAssertEqual(mapped, expected, file: file, line: line)
    }

    func testCreateSessionPostsRequestBody() {
        client.outcome = .success(["data": ["session_id": "server-id"]])

        _ = create()

        let request = client.requests.first
        XCTAssertTrue(request is OSRequestCreateSession)
        XCTAssertEqual(request?.method, POST)
        XCTAssertEqual(request?.path, "apps/app-id/sessions")
        XCTAssertEqual(request?.parameters as NSDictionary?, [
            "onesignal_id": "onesignal-id",
            "subscription_id": "subscription-id",
            "device_type": 0,
            "start_time": 1_700_000_000,
            "idempotency_key": "create-key"
        ])
    }

    func testCreateSessionIncludesDirectAttributionWhenSet() {
        client.outcome = .success(["data": ["session_id": "server-id"]])

        _ = create(OSCreateSessionRequestBody(
            onesignalId: "onesignal-id",
            subscriptionId: "subscription-id",
            startTime: 1_700_000_000,
            idempotencyKey: "create-key",
            directAttributionId: "notification-id"
        ))

        XCTAssertEqual(client.requests.first?.parameters?["direct_attribution_id"] as? String, "notification-id")
    }

    func testCreateSessionReturnsSessionIdFrom202() {
        client.outcome = .success(["data": ["session_id": "server-id"], "httpStatusCode": 202])

        XCTAssertEqual(create(), .success("server-id"))
    }

    func testCreateSessionRetriesSuccessWithoutSessionId() {
        let responses: [[AnyHashable: Any]?] = [
            nil,
            ["httpStatusCode": 202],
            ["data": [String: Any](), "httpStatusCode": 202],
            ["data": ["session_id": ""], "httpStatusCode": 202],
            ["data": ["session_id": NSNull()], "httpStatusCode": 202],
            ["data": ["session_id": 123], "httpStatusCode": 202],
            ["data": "server-id", "httpStatusCode": 202]
        ]
        for response in responses {
            client.outcome = .success(response)

            XCTAssertEqual(create(), .retry(statusCode: 202, retryAfterSeconds: nil), "\(String(describing: response))")
        }
    }

    func testCreateSessionRetriesUnparsableSuccessBody() {
        client.outcome = .failure(code: 202, headers: nil)

        XCTAssertEqual(create(), .retry(statusCode: 202, retryAfterSeconds: nil))
    }

    func testUpdateSessionPatchesRequestBody() {
        client.outcome = .success(nil)

        assertUpdate(update(), matches: .success(""))

        let request = client.requests.first
        XCTAssertTrue(request is OSRequestUpdateSession)
        XCTAssertEqual(request?.method, PATCH)
        XCTAssertEqual(request?.path, "apps/app-id/sessions/server-id")
        XCTAssertEqual(request?.parameters as NSDictionary?, [
            "onesignal_id": "onesignal-id",
            "subscription_id": "subscription-id",
            "duration_seconds": 42,
            "idempotency_key": "update-key"
        ])
    }

    func testUpdateSessionIncludesEndTimeWhenSet() {
        _ = update(OSUpdateSessionRequestBody(
            onesignalId: "onesignal-id",
            subscriptionId: "subscription-id",
            durationSeconds: 42,
            idempotencyKey: "update-key",
            endTime: 1_700_000_042
        ))

        XCTAssertEqual(client.requests.first?.parameters?["end_time"] as? Int64, 1_700_000_042)
    }

    func testUpdateSessionSucceedsWithUnparsableSuccessBody() {
        client.outcome = .failure(code: 202, headers: nil)

        assertUpdate(update(), matches: .success(""))
    }

    func testFailuresAreRetriedOnNetworkError5xx408And429() {
        for code in [-1, 0, 408, 500, 502, 503] {
            client.outcome = .failure(code: code, headers: nil)

            XCTAssertEqual(create(), .retry(statusCode: code, retryAfterSeconds: nil), "\(code)")
            assertUpdate(update(), matches: .retry(statusCode: code, retryAfterSeconds: nil))
        }
        client.outcome = .failure(code: 429, headers: nil)
        XCTAssertEqual(create(), .retry(statusCode: 429, retryAfterSeconds: OSSessionsBackendService.defaultRetryAfterSeconds))
    }

    func testOther4xxFailuresAreDropped() {
        for code in [400, 401, 403, 404, 409, 410, 422] {
            client.outcome = .failure(code: code, headers: ["Retry-After": "10"])

            XCTAssertEqual(create(), .drop(statusCode: code), "\(code)")
            assertUpdate(update(), matches: .drop(statusCode: code))
        }
    }

    func testRetryExposesRetryAfterFromResponse() {
        client.outcome = .failure(code: 429, headers: ["Retry-After": "30"])
        XCTAssertEqual(create(), .retry(statusCode: 429, retryAfterSeconds: 30))

        client.outcome = .failure(code: 503, headers: ["retry-after": "15"])
        assertUpdate(update(), matches: .retry(statusCode: 503, retryAfterSeconds: 15))
    }

    func testUnparsableRetryAfterFallsBackToDefault() {
        client.outcome = .failure(code: 503, headers: ["Retry-After": "Wed, 21 Oct 2026 07:28:00 GMT"])

        XCTAssertEqual(create(), .retry(statusCode: 503, retryAfterSeconds: OSSessionsBackendService.defaultRetryAfterSeconds))
    }
}
