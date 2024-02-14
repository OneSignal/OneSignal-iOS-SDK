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
    var cache: [String : OSLiveActivityRequest] = [String: OSLiveActivityRequest]()
    
    func requests(_ block: (OSLiveActivityRequest) -> Void) {
        for (_, request) in self.cache {
            block(request)
        }
    }
    
    func hasOutstandingRequest() -> Bool {
        self.cache.contains(where: {$0.value.requestSuccessful == false})
    }
    
    func load() {
        self.cache = OneSignalUserDefaults.initShared().getSavedCodeableData(forKey: getCacheStoreKey(), defaultValue: nil) as? [String : OSLiveActivityRequest] ?? [String: OSLiveActivityRequest]()
    }
    
    func save() {
        OneSignalUserDefaults.initShared().saveCodeableData(forKey:  getCacheStoreKey(), withValue: self.cache)
    }
    
    // These methods must be override
    func add(_ request: OSLiveActivityRequest) {
        self.cache.updateValue(request, forKey: getRequestKey(request))
    }
    
    func remove(_ request: OSLiveActivityRequest) {
        self.cache.removeValue(forKey: getRequestKey(request))
    }
    
    func getRequestKey(_ request: OSLiveActivityRequest) -> String {
        fatalError("getCacheStoreKey() has not been implemented")
    }
    
    func getCacheStoreKey() -> String {
        fatalError("getCacheStoreKey() has not been implemented")
    }
}

private class UpdateTokenCache : TokenCache {
    override func getRequestKey(_ request: OSLiveActivityRequest) -> String {
        return (request as? OSLiveActivityUpdateTokenRequest)?.activityId ?? ""
    }

    override func getCacheStoreKey() -> String {
        return OS_LIVE_ACTIVITIES_EXECUTOR_UPDATE_TOKENS_KEY
    }
}

private class StartTokenCache : TokenCache {
    override func getRequestKey(_ request: OSLiveActivityRequest) -> String {
        return (request as? OSLiveActivityStartTokenRequest)?.activityType ?? ""
    }

    override func getCacheStoreKey() -> String { return OS_LIVE_ACTIVITIES_EXECUTOR_START_TOKENS_KEY }
}

class OSLiveActivitiesExecutor : OSPushSubscriptionObserver {
    // The currently tracked update and start tokens (key) and their associated request (value).
    fileprivate var updateTokens: UpdateTokenCache = UpdateTokenCache()
    fileprivate var startTokens: StartTokenCache = StartTokenCache()
    
    // The live activities request dispatch queue, serial.
    private var requestDispatch: DispatchQueue = DispatchQueue(label: "OneSignal LiveActivities DispatchQueue")
    private var pollIntervalSeconds = 30
    
    init() {
        OneSignalUserManagerImpl.sharedInstance.pushSubscriptionImpl.addObserver(self)
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
    
    // Read in the currently tracked update and start tokens from the cache
    func start() {
        self.caches { cache in
            cache.load()
        }
        
        // drive a poll in case there are any outstanding requests.
        pollPendingRequests()
    }
    
    func append(_ request: OSLiveActivityRequest) {
        withCache(request) { cache in
            // first add/save the request to the appropriate cache
            cache.add(request)
            cache.save()
            
            // then execute immediately inline
            executeRequest(cache, request: request)
        }
        
        // drive a poll in case the above request failed, or a previously failed request is outstanding.
        pollPendingRequests()
    }

    private func pollPendingRequests() {
        self.requestDispatch.asyncAfter(deadline: .now() + .seconds(pollIntervalSeconds)) { [weak self] in
            var hasOutstandingRequests = false
            self?.caches { cache in
                cache.requests { request in
                    if request.requestSuccessful {
                        return
                    }

                    self?.executeRequest(cache, request: request)
                }
                
                hasOutstandingRequests = hasOutstandingRequests || cache.hasOutstandingRequest()
            }
            
            // if there are outstanding requests, poll again
            if hasOutstandingRequests {
                self?.pollPendingRequests()
            }
        }
    }
    
    private func executeRequest(_ cache: TokenCache, request: OSLiveActivityRequest) {
        if(OSPrivacyConsentController.requiresUserPrivacyConsent()) {
            OneSignalLog.onesignalLog(.LL_WARN, message: "Cannot send live activity request when the user has not granted privacy permission")
            return
        }
        
        if (!request.prepareForExecution()) {
            return
        }
        
        OneSignalClient.shared().execute(request) { _ in
            // Save the appropriate cache with the updated request for this request key.
            if request.removeOnSuccess {
                cache.remove(request)
            }
            else {
                request.requestSuccessful = true
            }

            cache.save()
        } onFailure: { error in
            OneSignalLog.onesignalLog(.LL_VERBOSE, message: "Live activities request failed with error \(error.debugDescription)")
            if let nsError = error as? NSError {
                let responseType = OSNetworkingUtils.getResponseStatusType(nsError.code)
                if responseType != .retryable {
                    // Failed, no retry. Remove the key from the cache entirely so we don't try again.
                    cache.remove(request)
                    cache.save()
                }
            }
        }
    }

    private func caches(_ block: (TokenCache) -> Void) {
        block(self.startTokens)
        block(self.updateTokens)
    }
    
    private func withCache(_ request: OSLiveActivityRequest, block: (TokenCache) -> Void) {
        if let req = request as? OSLiveActivityUpdateTokenRequest {
            block(self.updateTokens)
        }
        else {
            block(self.startTokens)
        }
    }
}
