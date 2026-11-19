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

    // Tests read and configure these from the test thread while requests complete on `executionQueue`,
    // so every access goes through `lock`.
    private var mockResponses: [String: [String: Any]] = [:]
    private var mockFailureResponses: [String: OneSignalClientError] = [:]
    private var _lastHTTPRequest: OneSignalRequest?
    private var _networkRequestCount = 0
    private var _executedRequests: [OneSignalRequest] = []
    private var _startedRequests: [OneSignalRequest] = []
    private var _completedRequests: [OneSignalRequest] = []
    private var _allRequestsHandled = true

    public var lastHTTPRequest: OneSignalRequest? { lock.withLock { _lastHTTPRequest } }
    public var networkRequestCount: Int { lock.withLock { _networkRequestCount } }
    public var executedRequests: [OneSignalRequest] { lock.withLock { _executedRequests } }
    /// Requests that have entered `execute` (including those still held / delayed).
    public var startedRequests: [OneSignalRequest] { lock.withLock { _startedRequests } }
    public var completedRequests: [OneSignalRequest] { lock.withLock { _completedRequests } }
    public var allRequestsHandled: Bool { lock.withLock { _allRequestsHandled } }
    public var executeInstantaneously = false
    /// Set to true to make it unnecessary to setup mock responses for every request possible
    public var fireSuccessForAllRequests = false
    /// When true, `execute` records the request but does not complete until `releaseHeldResponses()`.
    public var holdResponses = false

    private var heldExecutions: [(request: OneSignalRequest, onSuccess: OSResultSuccessBlock, onFailure: OSClientFailureBlock)] = []

    var remoteParamsResponse: [String: Any]?
    var shouldUseProvisionalAuthorization = false // new in iOS 12 (aka Direct to History)
    var remoteParamsOutcomes: [String: Any] = [:]

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
        lock.withLock {
            mockResponses = [:]
            _lastHTTPRequest = nil
            _networkRequestCount = 0
            _executedRequests.removeAll()
            _startedRequests.removeAll()
            _completedRequests.removeAll()
            heldExecutions.removeAll()
            holdResponses = false
        }
        executeInstantaneously = true
        remoteParamsResponse = nil
        shouldUseProvisionalAuthorization = false
        remoteParamsOutcomes = [:]
    }

    public func execute(_ request: OneSignalRequest, onSuccess successBlock: @escaping OSResultSuccessBlock, onFailure failureBlock: @escaping OSClientFailureBlock) {
        print("🧪 MockOneSignalClient execute called")

        // Check hold + enqueue under one lock so releaseHeldResponses can't miss a callback mid-hold.
        let shouldHold = lock.withLock { () -> Bool in
            _startedRequests.append(request)
            guard holdResponses else {
                return false
            }
            heldExecutions.append((request, successBlock, failureBlock))
            return true
        }
        if shouldHold {
            return
        }

        if executeInstantaneously {
            finishExecutingRequest(request, onSuccess: successBlock, onFailure: failureBlock)
        } else {
            executionQueue.asyncAfter(deadline: .now() + .milliseconds(50)) {
                self.finishExecutingRequest(request, onSuccess: successBlock, onFailure: failureBlock)
            }
        }
    }

    /// Completes every request currently held by `holdResponses`, and stops holding further executes.
    public func releaseHeldResponses() {
        let held: [(request: OneSignalRequest, onSuccess: OSResultSuccessBlock, onFailure: OSClientFailureBlock)] = lock.withLock {
            holdResponses = false
            let copy = heldExecutions
            heldExecutions.removeAll()
            return copy
        }
        for item in held {
            finishExecutingRequest(item.request, onSuccess: item.onSuccess, onFailure: item.onFailure)
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

    private enum MockOutcome {
        case success([String: Any]?)
        case failure(OneSignalClientError)
        case unhandled
    }

    func finishExecutingRequest(_ request: OneSignalRequest, onSuccess successBlock: OSResultSuccessBlock, onFailure failureBlock: OSClientFailureBlock) {
        print("🧪 completing HTTP request: \(request)")

        let stringifiedRequest = stringify(request)
        // Recording the request and choosing its response must be one step. Tests wait for a request to
        // be executed and then register the response for its retry; if that landed in between, this
        // attempt would be answered with the retry's response.
        let outcome: MockOutcome = lock.withLock {
            _executedRequests.append(request)
            _networkRequestCount += 1
            _lastHTTPRequest = request
            if let response = mockResponses[stringifiedRequest] {
                return .success(response)
            } else if let error = mockFailureResponses[stringifiedRequest] {
                return .failure(error)
            } else if fireSuccessForAllRequests {
                _allRequestsHandled = false
                return .success([:])
            } else {
                _allRequestsHandled = false
                return .unhandled
            }
        }

        print("🧪 didCompleteRequest url: \(String(describing: request.urlRequest().url)) params: \(String(describing: request.parameters))")

        if request.isKind(of: OSRequestGetIosParams.self) {
            successBlock(["mockTodo": "responseTodo"])
        }
        switch outcome {
        case .success(let response):
            successBlock(response)
        case .failure(let error):
            failureBlock(error)
        case .unhandled:
            print("🧪 cannot find a mock response for request: \(stringifiedRequest)")
        }

        lock.withLock {
            _completedRequests.append(request)
        }
    }

    /** This is not currently hooked up to anything to run */
    @objc public func runBackgroundThreads() {
        // Obj-C implementation: dispatch_sync(executionQueue, ^{})
        executionQueue.sync {}
    }

    // A request has one outcome: whichever of these was called for it last. Otherwise a test could not
    // override a default its setUp registered, nor let a retry succeed after the first attempt failed.
    public func setMockResponseForRequest(request: String, response: [String: Any]) {
        lock.withLock {
            mockResponses[request] = response
            mockFailureResponses.removeValue(forKey: request)
        }
    }

    public func setMockFailureResponseForRequest(request: String, error: OneSignalClientError) {
        lock.withLock {
            mockFailureResponses[request] = error
            mockResponses.removeValue(forKey: request)
        }
    }
}

// MARK: - Asserts

extension MockOneSignalClient {
    /**
     Checks if there is only one executed request that contains the payload provided, and the url matches the path provided.
     */
    @objc
    public func onlyOneRequest(contains path: String, contains payload: [String: Any]) -> Bool {
        let requests = executedRequests
        var found = false

        for request in requests {
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

    public func hasExecutedRequestOfType(_ type: AnyClass, expectedCount: Int? = nil) -> Bool {
        let requests = executedRequests
        let matchingCount = requests.filter { request in
            request.isKind(of: type)
        }.count

        if let expectedCount = expectedCount {
            return matchingCount == expectedCount
        } else {
            return matchingCount > 0
        }
    }

    /// Selected by type because a late request from an earlier test can reach the shared client first.
    public func firstExecutedRequest<T: OneSignalRequest>(ofType type: T.Type) -> T? {
        return executedRequests.lazy.compactMap { $0 as? T }.first
    }

    public func hasCompletedRequestOfType(_ type: AnyClass, expectedCount: Int? = nil) -> Bool {
        let matchingCount = completedRequestCount(ofType: type)

        if let expectedCount {
            return matchingCount == expectedCount
        }
        return matchingCount > 0
    }

    public func completedRequestCount(ofType type: AnyClass) -> Int {
        let requests = completedRequests
        return requests.filter { request in
            request.isKind(of: type)
        }.count
    }

    public func startedRequestCount(ofType type: AnyClass) -> Int {
        let requests = startedRequests
        return requests.filter { request in
            request.isKind(of: type)
        }.count
    }

    /// Held requests count as in flight. Read under the lock, so safe from the test thread.
    public var isIdle: Bool {
        return lock.withLock { _startedRequests.count == _completedRequests.count }
    }
}
