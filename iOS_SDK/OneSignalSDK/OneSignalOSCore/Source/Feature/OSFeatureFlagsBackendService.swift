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
@_implementationOnly import OneSignalKMP

/// iOS host for the shared Turbine feature-flags client.
///
/// This class is the platform adapter matching Android `FeatureFlagsBackendService`:
/// wrap native HTTP as `IFeatureFlagsHttp`, construct `FeatureFlagsClient`, log
/// unavailable outcomes at the right severity, and leave path/parse/orchestration in KMP.
final class OSFeatureFlagsBackendService {
    static let turbineFeaturesPlatformIOS = "ios"

    typealias FetchCompletion = (RemoteFeatureFlagsFetchOutcome) -> Void

    private let client: FeatureFlagsClient
    private let sdkVersionProvider: () -> String

    init(
        http: IFeatureFlagsHttp,
        sdkVersionProvider: @escaping () -> String = { ONESIGNAL_VERSION }
    ) {
        self.client = FeatureFlagsClient(http: http)
        self.sdkVersionProvider = sdkVersionProvider
    }

    convenience init(
        requestSender: @escaping OSFeatureFlagsHttpAdapter.RequestSender = OSFeatureFlagsHttpAdapter.defaultSender
    ) {
        self.init(http: OSFeatureFlagsHttpAdapter(requestSender: requestSender))
    }

    func fetchRemoteFeatureFlags(appId: String, completion: @escaping FetchCompletion) {
        OneSignalLog.onesignalLog(
            .LL_DEBUG,
            message: "FeatureFlagsBackendService.fetchRemoteFeatureFlags(appId=\(appId))"
        )
        let sdkVersion = sdkVersionProvider()
        client.fetchRemoteFeatureFlags(appId: appId, platform: Self.turbineFeaturesPlatformIOS, sdkVersion: sdkVersion) {
            outcome,
            error in
            let resolved: RemoteFeatureFlagsFetchOutcome
            if let outcome {
                resolved = outcome
            } else {
                resolved = RemoteFeatureFlagsFetchOutcome.companion.unavailable(
                    reason: .nonSuccessHttp,
                    statusCode: KotlinInt(int: 0),
                    bodySnippet: error?.localizedDescription ?? "<empty>"
                )
            }
            if resolved.isUnavailable {
                Self.logUnavailable(resolved, appId: appId, sdkVersion: sdkVersion)
            }
            completion(resolved)
        }
    }

    private static func logUnavailable(
        _ outcome: RemoteFeatureFlagsFetchOutcome,
        appId: String,
        sdkVersion: String
    ) {
        let reason = outcome.reason
        if reason == RemoteFeatureFlagsUnavailableReason.invalidAppId {
            OneSignalLog.onesignalLog(
                .LL_WARN,
                message: "FeatureFlagsBackendService: app id not usable for Turbine path: '\(appId)'"
            )
        } else if reason == RemoteFeatureFlagsUnavailableReason.invalidSdkVersion {
            OneSignalLog.onesignalLog(
                .LL_WARN,
                message: "FeatureFlagsBackendService: sdk version not usable for Turbine path (expected "
                    + "6-digit label optional -suffix, e.g. 050801 or 050801-beta): '\(sdkVersion)'"
            )
        } else if reason == RemoteFeatureFlagsUnavailableReason.nonSuccessHttp {
            let message =
                "FeatureFlagsBackendService: non-success status=\(statusDescription(outcome.statusCode)) "
                + "body=\(outcome.bodySnippet ?? "<empty>")"
            if outcome.isClientError {
                OneSignalLog.onesignalLog(.LL_WARN, message: message)
            } else {
                OneSignalLog.onesignalLog(.LL_DEBUG, message: message)
            }
        } else if reason == RemoteFeatureFlagsUnavailableReason.emptyBody {
            OneSignalLog.onesignalLog(
                .LL_WARN,
                message: "FeatureFlagsBackendService: empty body for success status=\(statusDescription(outcome.statusCode))"
            )
        } else if reason == RemoteFeatureFlagsUnavailableReason.invalidJson {
            OneSignalLog.onesignalLog(
                .LL_WARN,
                message: "FeatureFlagsBackendService: response body is not valid Turbine feature-flags JSON: "
                    + (outcome.bodySnippet ?? "<empty>")
            )
        } else {
            OneSignalLog.onesignalLog(
                .LL_WARN,
                message: "FeatureFlagsBackendService: unavailable without reason"
            )
        }
    }

    private static func statusDescription(_ statusCode: KotlinInt?) -> String {
        statusCode.map { "\($0.intValue)" } ?? "nil"
    }
}

/// URLSession (or injected sender) as `IFeatureFlagsHttp`. Resolves KMP's relative path
/// against `OS_API_SERVER_URL` and attaches the same SDK-Version / Accept headers as
/// `OneSignalRequest`.
final class OSFeatureFlagsHttpAdapter: IFeatureFlagsHttp {
    typealias RequestSender = (
        URLRequest,
        @escaping (Data?, URLResponse?, Error?) -> Void
    ) -> Void

    private static let requestTimeout: TimeInterval = 10

    static let defaultSender: RequestSender = { request, completion in
        defaultSession.dataTask(with: request, completionHandler: completion).resume()
    }

    private static let defaultSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = requestTimeout
        configuration.timeoutIntervalForResource = requestTimeout
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: configuration)
    }()

    private let requestSender: RequestSender

    init(requestSender: @escaping RequestSender = OSFeatureFlagsHttpAdapter.defaultSender) {
        self.requestSender = requestSender
    }

    func get(relativePath: String, completionHandler: @escaping (FeatureFlagsHttpResponse?, Error?) -> Void) {
        // `OneSignalRequest` is used for the base URL and the standard SDK headers only.
        // Its `disableLocalCaching` flag is read by `OneSignalClient`, which this path
        // deliberately bypasses, so cache policy is set on the session instead.
        let request = OneSignalRequest()
        request.method = GET
        request.path = relativePath
        requestSender(request.urlRequest() as URLRequest) { data, response, error in
            let statusCode: Int32
            if error != nil {
                statusCode = 0
            } else if let http = response as? HTTPURLResponse {
                statusCode = Int32(http.statusCode)
            } else {
                statusCode = 0
            }
            // A transport failure carries no HTTP status, so forward the error text as the
            // body. Without it every such failure logs as `status=0 body=<empty>` and
            // offline, DNS, TLS, and timeout are indistinguishable in the field.
            let body: String?
            if let error {
                body = error.localizedDescription
            } else {
                body = data.flatMap { String(data: $0, encoding: .utf8) }
            }
            completionHandler(FeatureFlagsHttpResponse(statusCode: statusCode, body: body), nil)
        }
    }
}
