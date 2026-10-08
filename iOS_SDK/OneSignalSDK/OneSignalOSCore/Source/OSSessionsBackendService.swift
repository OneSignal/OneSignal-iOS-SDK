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

struct OSCreateSessionRequestBody: Equatable {
    let onesignalId: String
    let subscriptionId: String
    let startTime: Date
    let idempotencyKey: String
    let directAttributionId: String?

    init(onesignalId: String, subscriptionId: String, startTime: Date, idempotencyKey: String, directAttributionId: String? = nil) {
        self.onesignalId = onesignalId
        self.subscriptionId = subscriptionId
        self.startTime = startTime
        self.idempotencyKey = idempotencyKey
        self.directAttributionId = directAttributionId
    }
}

struct OSUpdateSessionRequestBody: Equatable {
    let onesignalId: String
    let subscriptionId: String
    /// Cumulative for the whole session, so a retried or reordered update cannot double count.
    let durationSeconds: Int64
    let idempotencyKey: String
    /// Set only on the update that ends the session.
    let endTime: Date?

    init(onesignalId: String, subscriptionId: String, durationSeconds: Int64, idempotencyKey: String, endTime: Date? = nil) {
        self.onesignalId = onesignalId
        self.subscriptionId = subscriptionId
        self.durationSeconds = durationSeconds
        self.idempotencyKey = idempotencyKey
        self.endTime = endTime
    }
}

enum OSSessionsApiResult<Value> {
    case success(Value)
    /// No response, 5xx, 408, 429, or a create success without a session ID.
    /// Wait at least `retryAfterSeconds` when set.
    case retry(statusCode: Int, retryAfterSeconds: Int?)
    /// Any other 4xx, or a request the client rejected before sending. It will never succeed as sent.
    case drop(statusCode: Int)
}

extension OSSessionsApiResult: Equatable where Value: Equatable {}

protocol OSSessionsBackend {
    func createSession(appId: String, body: OSCreateSessionRequestBody, completion: @escaping (OSSessionsApiResult<String>) -> Void)
    func updateSession(appId: String, sessionId: String, body: OSUpdateSessionRequestBody, completion: @escaping (OSSessionsApiResult<Void>) -> Void)
}

/// Typed client for the sessions API.
final class OSSessionsBackendService: OSSessionsBackend {
    static let defaultRetryAfterSeconds = 60

    private let client: () -> IOneSignalClient

    convenience init() {
        self.init(client: { OneSignalCoreImpl.sharedClient() })
    }

    init(client: @escaping () -> IOneSignalClient) {
        self.client = client
    }

    /// On success the result holds the backend session ID.
    func createSession(
        appId: String,
        body: OSCreateSessionRequestBody,
        completion: @escaping (OSSessionsApiResult<String>) -> Void
    ) {
        let request = OSRequestCreateSession(appId: appId, body: body)
        client().execute(request) { response in
            guard let sessionId = Self.sessionId(from: response) else {
                // Retrying with the same idempotency key returns the session the backend already created.
                OneSignalLog.onesignalLog(.LL_WARN, message: "OSSessionsBackendService: create session response is missing data.session_id")
                completion(.retry(statusCode: Self.statusCode(of: response), retryAfterSeconds: nil))
                return
            }
            completion(.success(sessionId))
        } onFailure: { error in
            completion(Self.classifyFailure(error, emptySuccess: .retry(statusCode: error.code, retryAfterSeconds: nil)))
        }
    }

    /// Reports the session's cumulative duration, and ends it when `body.endTime` is set.
    func updateSession(
        appId: String,
        sessionId: String,
        body: OSUpdateSessionRequestBody,
        completion: @escaping (OSSessionsApiResult<Void>) -> Void
    ) {
        let request = OSRequestUpdateSession(appId: appId, sessionId: sessionId, body: body)
        client().execute(request) { _ in
            completion(.success(()))
        } onFailure: { error in
            completion(Self.classifyFailure(error, emptySuccess: .success(())))
        }
    }

    private static func sessionId(from response: [AnyHashable: Any]?) -> String? {
        guard let data = response?["data"] as? [String: Any],
              let sessionId = data["session_id"] as? String,
              !sessionId.isEmpty
        else {
            return nil
        }
        return sessionId
    }

    private static func statusCode(of response: [AnyHashable: Any]?) -> Int {
        (response?["httpStatusCode"] as? NSNumber)?.intValue ?? 202
    }

    /// `emptySuccess` covers a 2xx whose body failed to parse, which `OneSignalClient` reports as a failure.
    private static func classifyFailure<Value>(
        _ error: OneSignalClientError,
        emptySuccess: OSSessionsApiResult<Value>
    ) -> OSSessionsApiResult<Value> {
        let code = error.code
        if (200..<300).contains(code) {
            return emptySuccess
        }
        // 0 means no HTTP response: no network, timeout, or missing privacy consent. The client's
        // only negative code is a missing app ID, which a retry cannot fix.
        if code == 0 || code == 408 || code == 429 || code >= 500 {
            return .retry(statusCode: code, retryAfterSeconds: retryAfterSeconds(error))
        }
        return .drop(statusCode: code)
    }

    /// Only the delay-seconds form is supported, not the HTTP-date form.
    static func retryAfterSeconds(_ error: OneSignalClientError) -> Int? {
        let value = error.responseHeaders?.first { key, _ in
            (key as? String)?.caseInsensitiveCompare("Retry-After") == .orderedSame
        }?.value
        if let value {
            return Int("\(value)".trimmingCharacters(in: .whitespaces)) ?? defaultRetryAfterSeconds
        }
        return error.code == 429 ? defaultRetryAfterSeconds : nil
    }
}
