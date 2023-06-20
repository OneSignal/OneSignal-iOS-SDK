/*
 Modified MIT License

 Copyright 2023 OneSignal

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

@objc
public class MockOneSignalClient: NSObject, IOneSignalClient {
    public let executionQueue: DispatchQueue = DispatchQueue(label: "com.onesignal.execution")
    
    var mockResponses: [String: [String: Any]] = [:]
    public var lastHTTPRequest: OneSignalRequest?
    public var networkRequestCount = 0
    public var executedRequests: [OneSignalRequest] = []
    public var executeInstantaneously = true
    
    // Temp method to log info while building unit tests
    @objc public func logSelfInfo() {
        print("🔥 MockOneSignalClient with executionQueue \(executionQueue)")
    }
    
    public func reset() {
        mockResponses = [:]
        lastHTTPRequest = nil
        networkRequestCount = 0
        executedRequests.removeAll()
        executeInstantaneously = true
    }
    
    public func execute(_ request: OneSignalRequest, onSuccess successBlock: @escaping OSResultSuccessBlock, onFailure failureBlock: @escaping OSFailureBlock) {
        print("🔥 MockOneSignalClient execute called")

        executedRequests.append(request)
        
        if (executeInstantaneously) {
            finishExecutingRequest(request, onSuccess: successBlock, onFailure: failureBlock)
        } else {
            executionQueue.async {
                self.finishExecutingRequest(request, onSuccess: successBlock, onFailure: failureBlock)
            }
        }
    }
    
    func finishExecutingRequest(_ request: OneSignalRequest, onSuccess successBlock: OSResultSuccessBlock, onFailure failureBlock: OSFailureBlock) {
        
        // TODO: Needs to contained within the equivalent of @synchronized ❗️
        print("🔥 completing HTTP request: \(request)")
        
        
        // TODO: Check for existence of app_id in the request
        
        self.didCompleteRequest(request)
        // Switch between types of requests with mock responses
        if (request.isKind(of: OSRequestGetIosParams.self)) {
            // send a mock remote params response
            // successBlock(["mock": "response"])
        }
        if ((mockResponses[String(describing: request)]) != nil) {
            successBlock(mockResponses[String(describing: request)])
        }
        successBlock(["mock": "response"])
    }
    
    func didCompleteRequest(_ request: OneSignalRequest) {
        networkRequestCount += 1
        print("🔥 didCompleteRequest url(\(networkRequestCount)): \(String(describing: request.urlRequest().url)) params: \(String(describing: request.parameters))")
        lastHTTPRequest = request
    }
    
    
    @objc
    public func runBackgroundThreads() {
        // OLD: dispatch_sync(executionQueue, ^{})
        executionQueue.sync {}
    }
    
    
    public func setMockResponseForRequest(request: String, response: [String: Any]) {
        
    }
}
