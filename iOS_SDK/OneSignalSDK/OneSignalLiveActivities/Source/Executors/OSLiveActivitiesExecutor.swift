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
import OneSignalUser

private class TokenCache {
    var cache: [String : OSLiveActivityRequest]
    private var cacheKey: String

    func requests(_ block: (OSLiveActivityRequest) -> Void) {
        for (_, request) in self.cache {
            block(request)
        }
    }
    
    init(cacheKey: String) {
        self.cacheKey = cacheKey
        self.cache = OneSignalUserDefaults.initShared().getSavedCodeableData(forKey: cacheKey, defaultValue: nil) as? [String : OSLiveActivityRequest] ?? [String: OSLiveActivityRequest]()
        OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OneSignal.LiveActivities initialized token cache \(self): \(cache)")
    }
    
    func save() {
        OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OneSignal.LiveActivities saving token cache \(self): \(cache)")
        OneSignalUserDefaults.initShared().saveCodeableData(forKey:  self.cacheKey, withValue: self.cache)
    }
    
    func addAndSave(_ request: OSLiveActivityRequest) -> Bool {
        let existingRequest = self.cache[getRequestKey(request)]

        if (existingRequest == nil || request.supersedes(existingRequest!)) {
            self.cache.updateValue(request, forKey: getRequestKey(request))
            self.save()
            return true
        }
        
        return false
    }
    
    func removeAndSave(_ request: OSLiveActivityRequest) {
        self.cache.removeValue(forKey: getRequestKey(request))
        self.save()
    }
    
    func getRequestKey(_ request: OSLiveActivityRequest) -> String {
        fatalError("getRequestKey() has not been implemented")
    }
}

private class UpdateTokenCache : TokenCache {
    init() {
        super.init(cacheKey: OS_LIVE_ACTIVITIES_EXECUTOR_UPDATE_TOKENS_KEY)
    }
    
    override func getRequestKey(_ request: OSLiveActivityRequest) -> String {
        return (request as! OSLiveActivityUpdateTokenRequest).activityId
    }
}

private class StartTokenCache : TokenCache {
    init() {
        super.init(cacheKey: OS_LIVE_ACTIVITIES_EXECUTOR_START_TOKENS_KEY)
    }
    
    override func getRequestKey(_ request: OSLiveActivityRequest) -> String {
        return (request as! OSLiveActivityStartTokenRequest).activityType
    }
}

// TODO: Remove update tokens that are older than 24 hours old, they cannot be updated after 12 hours
// TODO: Remove start tokens that are older than ?? old (maybe?)
class OSLiveActivitiesExecutor : OSPushSubscriptionObserver {
    // The currently tracked update and start tokens (key) and their associated request (value). THESE ARE NOT THREAD SAFE
    private let updateTokens: UpdateTokenCache = UpdateTokenCache()
    private let startTokens: StartTokenCache = StartTokenCache()
    
    // The live activities request dispatch queue, serial.
    private var requestDispatch: DispatchQueue = DispatchQueue(label: "OneSignal LiveActivities DispatchQueue")
    private var pollIntervalSeconds = 30
    
    // Read in the currently tracked update and start tokens from the cache
    func start() {
        OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OneSignal.LiveActivities starting executor")
        OneSignalUserManagerImpl.sharedInstance.pushSubscriptionImpl.addObserver(self)
        
        // drive a poll if there are any outstanding requests in the cache.
        self.pollPendingRequests()
    }
    
    func onPushSubscriptionDidChange(state: OneSignalUser.OSPushSubscriptionChangedState) {
        // when a push subscription changes, we need to re-send up all update and start tokens with the new ID.
        // There are safeguards in `executeRequest` to not send the request when subscription ID is null, so
        // all we have to do here is flip the flag.
        self.requestDispatch.async {
            self.caches { cache in
                cache.requests { request in
                    request.requestSuccessful = false
                }
                cache.save()
            }
            
            self.pollPendingRequests()
        }
    }
    
    func append(_ request: OSLiveActivityRequest) {
        // first add/save the request to the appropriate cache
        self.requestDispatch.async {
            self.withCache(request) { cache in
                if(cache.addAndSave(request)) {
                    OSLiveActivitiesExecutor.executeRequest(cache, request: request) { isPollRequired in
                        if(isPollRequired) {
                            // drive a poll when the request fails
                            self.pollPendingRequests()
                        }
                    }
                } else {
                    OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OneSignal.LiveActivities request not saved because it's been superseded: \(request)")
                }
            }
        }
    }

    private func pollPendingRequests() {
        OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OneSignal.LiveActivities pollPendingRequests")
        
        self.requestDispatch.asyncAfter(deadline: .now() + .seconds(pollIntervalSeconds)) { [weak self] in
            OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OneSignal.LiveActivities executing outstanding requests")

            var hasOutstandingRequests = false
            self?.allRequests { (cache, request) in
                if request.requestSuccessful {
                    return
                }

                OSLiveActivitiesExecutor.executeRequest(cache, request: request) { isPollRequired in
                    hasOutstandingRequests = hasOutstandingRequests || isPollRequired
                }
            }
            
            // if there are outstanding requests, poll again
            if hasOutstandingRequests {
                self?.pollPendingRequests()
            }
        }
    }
    
    private func allRequests(_ block: (TokenCache, OSLiveActivityRequest) -> Void) {
        self.caches { cache in
            cache.requests { request in
                block(cache, request)
            }
        }
    }
    
    private func caches(_ block: (TokenCache) -> Void) {
        block(self.startTokens)
        block(self.updateTokens)
    }
    
    private func withCache(_ request: OSLiveActivityRequest, block: (TokenCache) -> Void) {
        if request is OSLiveActivityUpdateTokenRequest {
            block(self.updateTokens)
        }
        else {
            block(self.startTokens)
        }
    }
    
    /**
     block is called with `true` when a poll is required (i.e. the request failed **and** should be retried). Static to show it is thread safe.
     */
    private static func executeRequest(_ cache: TokenCache, request: OSLiveActivityRequest, block: @escaping (Bool) -> Void){
        if(OSPrivacyConsentController.requiresUserPrivacyConsent()) {
            OneSignalLog.onesignalLog(.LL_WARN, message: "Cannot send live activity request when the user has not granted privacy permission")
            block(true)
            return
        }
        
        if (!request.prepareForExecution()) {
            block(true)
            return
        }
        
        OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OneSignal.LiveActivities executing request: \(request)")
        OneSignalClient.shared().execute(request) { _ in
            OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OneSignal.LiveActivities request succeeded")
            // Save the appropriate cache with the updated request for this request key.
            if request.shouldForgetWhenSuccessful {
                cache.removeAndSave(request)
            }
            else {
                request.requestSuccessful = true
                cache.save()
            }
            block(false)
        } onFailure: { error in
            OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OneSignal.LiveActivities request failed with error \(error.debugDescription)")
            if let nsError = error as? NSError {
                let responseType = OSNetworkingUtils.getResponseStatusType(nsError.code)
                if responseType != .retryable {
                    // Failed, no retry. Remove the key from the cache entirely so we don't try again.
                    cache.removeAndSave(request)
                    block(false)
                    return
                }
            }
            block(true)
        }
    }
}
