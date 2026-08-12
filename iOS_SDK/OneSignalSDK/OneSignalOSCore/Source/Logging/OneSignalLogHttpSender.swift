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

// Kotlin/Native does not produce a Mac Catalyst framework slice.
#if !targetEnvironment(macCatalyst)

import Foundation
@_implementationOnly import OneSignalKMP

/// Sends the KMP logger's encoded OTLP requests using the native URL loading system.
final class OneSignalLogHttpSender: ILogHttpSender {
    private static let requestTimeout: TimeInterval = 10
    private static let transportFailureStatusCode: Int32 = -1
    private static let maximumDiagnosticBodyLength = 500
    private static let defaultSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = requestTimeout
        configuration.timeoutIntervalForResource = requestTimeout
        return URLSession(configuration: configuration)
    }()

    typealias RequestSender = (
        URLRequest,
        @escaping (Data?, URLResponse?, Error?) -> Void
    ) -> Void

    init(
        session: URLSession = OneSignalLogHttpSender.defaultSession,
        logger: ILogger = IOSLogger(),
        isDiagnosticsEnabled: @escaping () -> Bool = { false },
        isEnabled: @escaping () -> Bool = { true }
    ) {
        self.requestSender = { request, completion in
            session.dataTask(with: request, completionHandler: completion).resume()
        }
        self.logger = logger
        self.isDiagnosticsEnabled = isDiagnosticsEnabled
        self.isEnabled = isEnabled
    }

    init(
        requestSender: @escaping RequestSender,
        logger: ILogger = IOSLogger(),
        isDiagnosticsEnabled: @escaping () -> Bool = { false },
        isEnabled: @escaping () -> Bool = { true }
    ) {
        self.requestSender = requestSender
        self.logger = logger
        self.isDiagnosticsEnabled = isDiagnosticsEnabled
        self.isEnabled = isEnabled
    }

    private let requestSender: RequestSender
    private let logger: ILogger
    private let isDiagnosticsEnabled: () -> Bool
    private let isEnabled: () -> Bool

    func send(
        request: LogHttpRequest,
        completionHandler: @escaping (LogHttpResponse?, Error?) -> Void
    ) {
        guard isEnabled() else {
            completionHandler(
                LogHttpResponse(
                    success: false,
                    statusCode: Self.transportFailureStatusCode,
                    message: "Remote logging is disabled"
                ),
                nil
            )
            return
        }
        guard let url = URL(string: request.url) else {
            completionHandler(
                LogHttpResponse(
                    success: false,
                    statusCode: Self.transportFailureStatusCode,
                    message: "Invalid log request URL"
                ),
                nil
            )
            return
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.httpBody = request.body.data
        urlRequest.setValue(request.contentType, forHTTPHeaderField: "Content-Type")
        request.headers.forEach { urlRequest.setValue($0.value, forHTTPHeaderField: $0.key) }

        requestSender(urlRequest) { data, response, error in
            if let error = error {
                if self.isDiagnosticsEnabled() {
                    self.logger.warn(
                        message: "OneSignalLogHttpSender: POST \(request.url) failed: \(error.localizedDescription)"
                    )
                }
                completionHandler(
                    LogHttpResponse(
                        success: false,
                        statusCode: Self.transportFailureStatusCode,
                        message: error.localizedDescription
                    ),
                    nil
                )
                return
            }

            guard let response = response as? HTTPURLResponse else {
                completionHandler(
                    LogHttpResponse(
                        success: false,
                        statusCode: Self.transportFailureStatusCode,
                        message: "Missing HTTP response"
                    ),
                    nil
                )
                return
            }

            let success = (200...299).contains(response.statusCode)
            let responseBody = data.flatMap { String(data: $0, encoding: .utf8) }
            if self.isDiagnosticsEnabled() {
                if success {
                    self.logger.debug(
                        message: "OneSignalLogHttpSender: POST \(request.url) -> \(response.statusCode) OK "
                            + "(\(request.body.size)B)"
                    )
                } else {
                    self.logger.warn(
                        message: "OneSignalLogHttpSender: POST \(request.url) -> \(response.statusCode) "
                            + "(ct=\(request.contentType), \(request.body.size)B) "
                            + "body=\(responseBody.map(Self.truncatedDiagnosticBody) ?? "nil")"
                    )
                }
            }

            completionHandler(
                LogHttpResponse(
                    success: success,
                    statusCode: Int32(response.statusCode),
                    message: success ? nil : responseBody
                ),
                nil
            )
        }
    }

    private static func truncatedDiagnosticBody(_ body: String) -> String {
        String(body.prefix(maximumDiagnosticBodyLength))
    }
}

#endif
