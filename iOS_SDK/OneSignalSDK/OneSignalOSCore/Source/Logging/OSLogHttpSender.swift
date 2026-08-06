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
@_implementationOnly import OneSignalKMP

/// Sends the KMP logger's encoded OTLP requests using the native URL loading system.
final class OSLogHttpSender: ILogHttpSender {
    private static let requestTimeout: TimeInterval = 10
    private static let transportFailureStatusCode: Int32 = -1
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

    init(session: URLSession = OSLogHttpSender.defaultSession) {
        self.requestSender = { request, completion in
            session.dataTask(with: request, completionHandler: completion).resume()
        }
    }

    init(requestSender: @escaping RequestSender) {
        self.requestSender = requestSender
    }

    private let requestSender: RequestSender

    func send(
        request: LogHttpRequest,
        completionHandler: @escaping (LogHttpResponse?, Error?) -> Void
    ) {
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
        request.headers.forEach { urlRequest.setValue($0.value, forHTTPHeaderField: $0.key) }
        urlRequest.setValue(request.contentType, forHTTPHeaderField: "Content-Type")

        requestSender(urlRequest) { _, response, error in
            if let error = error {
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

            completionHandler(
                LogHttpResponse(
                    success: (200...299).contains(response.statusCode),
                    statusCode: Int32(response.statusCode),
                    message: nil
                ),
                nil
            )
        }
    }
}
