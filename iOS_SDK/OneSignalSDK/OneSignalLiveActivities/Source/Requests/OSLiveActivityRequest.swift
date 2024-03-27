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

import OneSignalCore

/**
 Represents any live activity request, expected to be extended by
 `OSLiveActivityUpdateTokenRequest` (update token requests) and
 `OSLiveActivityStartTokenRequest` (start token requests).
 */
protocol OSLiveActivityRequest: OneSignalRequest, NSCoding {
    /**
     The unique key for this request.
     */
    var key: String { get }

    /**
     Whether the request has been successfully executed.
     */
    var requestSuccessful: Bool { get set }

    /**
     Whether this request should be forgotten about when successful.
     */
    var shouldForgetWhenSuccessful: Bool { get }

    /**
     Call this prior to executing the request. In addition to preparing the request for execution, it also
     returns whether the request *can* be executed.
     */
    func prepareForExecution() -> Bool

    /**
     Only one request "per" (i.e. activityId or activityType) can exist. This method determines
     whether  this request supersedes the provided (existing) request.
     */
    func supersedes(_ existing: OSLiveActivityRequest) -> Bool
}

/**
 A live activity request that is related to the update token of a specific `activityId` key.
 */
protocol OSLiveActivityUpdateTokenRequest: OSLiveActivityRequest {
}

/**
 A live activity request that is related to the start token of a specific `activityType` key.
 */
protocol OSLiveActivityStartTokenRequest: OSLiveActivityRequest {
}
