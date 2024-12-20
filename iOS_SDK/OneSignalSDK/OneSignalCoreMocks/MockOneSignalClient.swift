/*
 Modified MIT License
 Copyright 2024 OneSignal
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

/**
 This mock client is still adapting, and some logic from the existing OneSignalClientOverrider have been brought to here.
 */
@objc
public class MockOneSignalClient: NSObject, IOneSignalClient {
    public let executionQueue: DispatchQueue = DispatchQueue(label: "com.onesignal.execution", attributes: .concurrent)
    let lock = NSLock()

    var mockResponses: [String: [String: Any]] = [:]
    var mockFailureResponses: [String: OneSignalClientError] = [:]
    public var lastHTTPRequest: OneSignalRequest?
    public var networkRequestCount = 0
    public var executedRequests: [OneSignalRequest] = []
    public var executeInstantaneously = false
    /// Set to true to make it unnecessary to setup mock responses for every request possible
    public var fireSuccessForAllRequests = false

    var remoteParamsResponse: [String: Any]?
    var shouldUseProvisionalAuthorization = false // new in iOS 12 (aka Direct to History)
    var remoteParamsOutcomes: [String: Any] = [:]

    public var allRequestsHandled = true

    /** May add to or change this default remote params response*/
    public func getRemoteParamsResponse() -> [String: Any] {
        return remoteParamsResponse ?? [
            IOS_FBA: true,
            IOS_USES_PROVISIONAL_AUTHORIZATION: shouldUseProvisionalAuthorization,
                    IOS_RECEIVE_RECEIPTS_ENABLE: true,
            "outcomes": remoteParamsOutcomes
        ]
    }

    public func enableOutcomes() {
        remoteParamsOutcomes = [
            "direct": [
                "enabled": true
            ],
            "indirect": [
                "notification_attribution": [
                    "minutes_since_displayed": 1440,
                    "limit": 10
                ],
                "enabled": true
            ],
            "unattributed": [
                "enabled": true
            ]
        ]
    }

    // Temp. method to log info while building unit tests
    @objc public func logSelfInfo() {
        print("🧪 MockOneSignalClient with executedRequests \(executedRequests)")
    }

    public func reset() {
        mockResponses = [:]
        lastHTTPRequest = nil
        networkRequestCount = 0
        executedRequests.removeAll()
        executeInstantaneously = true
        remoteParamsResponse = nil
        shouldUseProvisionalAuthorization = false
        remoteParamsOutcomes = [:]
    }

    public func execute(_ request: OneSignalRequest, onSuccess successBlock: @escaping OSResultSuccessBlock, onFailure failureBlock: @escaping OSClientFailureBlock) {
        print("🧪 MockOneSignalClient execute called")

        if executeInstantaneously {
            finishExecutingRequest(request, onSuccess: successBlock, onFailure: failureBlock)
        } else {
            executionQueue.asyncAfter(deadline: .now() + .milliseconds(50)) {
                self.finishExecutingRequest(request, onSuccess: successBlock, onFailure: failureBlock)
            }
        }
    }

    /// Helper method to stringify the name of a request for identification and comparison
    private func stringify(_ request: OneSignalRequest) -> String {
        var stringified = request.description

        switch request.description {
        case let str where str.contains("OSRequestUpdateProperties"):
            // Return an ordered representation of the request parameters
            stringified = "<OSRequestUpdateProperties with parameters: \(request.stringifyParams())>"
        default:
            break
        }

        return stringified
    }

    func finishExecutingRequest(_ request: OneSignalRequest, onSuccess successBlock: OSResultSuccessBlock, onFailure failureBlock: OSClientFailureBlock) {

        // TODO: This entire method needs to contained within the equivalent of @synchronized ❗️
        print("🧪 completing HTTP request: \(request)")

        // TODO: Check for existence of app_id in the request and fail if not.
        lock.withLock {
            executedRequests.append(request)
        }

        self.didCompleteRequest(request)

        let stringifiedRequest = stringify(request)
        // Switch between types of requests with mock responses
        if request.isKind(of: OSRequestGetIosParams.self) {
            // send a mock remote params response
            successBlock(["mockTodo": "responseTodo"])
        }
        if (mockResponses[stringifiedRequest]) != nil {
            successBlock(mockResponses[stringifiedRequest])
        } else if let response = mockFailureResponses[stringifiedRequest] {
            failureBlock(response)
        } else if fireSuccessForAllRequests {
            allRequestsHandled = false
            successBlock([:])
        } else {
            allRequestsHandled = false
            print("🧪 cannot find a mock response for request: \(stringifiedRequest)")
        }
    }

    func didCompleteRequest(_ request: OneSignalRequest) {
        networkRequestCount += 1

        print("🧪 didCompleteRequest url(\(networkRequestCount)): \(String(describing: request.urlRequest().url)) params: \(String(describing: request.parameters))")

        lastHTTPRequest = request
    }

    /** This is not currently hooked up to anything to run */
    @objc public func runBackgroundThreads() {
        // Obj-C implementation: dispatch_sync(executionQueue, ^{})
        executionQueue.sync {}
    }

    public func setMockResponseForRequest(request: String, response: [String: Any]) {
        mockResponses[request] = response
    }

    public func setMockFailureResponseForRequest(request: String, error: OneSignalClientError) {
        mockFailureResponses[request] = error
    }
}

// MARK: - Asserts

extension MockOneSignalClient {
    /**
     Checks if there is only one executed request that contains the payload provided, and the url matches the path provided.
     */
    @objc
    public func onlyOneRequest(contains path: String, contains payload: [String: Any]) -> Bool {
        var found = false

        for request in executedRequests {
            guard let params = request.parameters as? NSDictionary  else {
                continue
            }

            if params.contains(payload) {
                if request.path == path {
                    guard !found else {
                        // False if more than 1 request satisfies both requirements
                        return false
                    }
                    found = true
                } else {
                    return false
                }
            }
        }

        return found
    }

    public func hasExecutedRequestOfType(_ type: AnyClass) -> Bool {
        executedRequests.contains { request in
            request.isKind(of: type)
        }
    }
}
