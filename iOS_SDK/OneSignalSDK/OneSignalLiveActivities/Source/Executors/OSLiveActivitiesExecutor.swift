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
    
    func load() {
        self.cache = OneSignalUserDefaults.initShared().getSavedCodeableData(forKey: getCacheStoreKey(), defaultValue: nil) as? [String : OSLiveActivityRequest] ?? [String: OSLiveActivityRequest]()
        OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OneSignal.LiveActivities loading token cache \(self): \(cache)")
    }
    
    func save() {
        OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OneSignal.LiveActivities saving token cache \(self): \(cache)")
        OneSignalUserDefaults.initShared().saveCodeableData(forKey:  getCacheStoreKey(), withValue: self.cache)
    }
    
    func addAndSave(_ request: OSLiveActivityRequest) -> Bool {
        let existingRequest = self.cache[getRequestKey(request)]
        
        // when is replaced?
        // * there isn't anything there
        // * there is something there, but the new thing is a delete
        // * there is something there, the new thing isn't a delete, but the new thing has a different token
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
    
    func getCacheStoreKey() -> String {
        fatalError("getCacheStoreKey() has not been implemented")
    }
}

private class UpdateTokenCache : TokenCache {
    override func getRequestKey(_ request: OSLiveActivityRequest) -> String {
        return (request as! OSLiveActivityUpdateTokenRequest).activityId
    }

    override func getCacheStoreKey() -> String {
        return OS_LIVE_ACTIVITIES_EXECUTOR_UPDATE_TOKENS_KEY
    }
}

private class StartTokenCache : TokenCache {
    override func getRequestKey(_ request: OSLiveActivityRequest) -> String {
        return (request as! OSLiveActivityStartTokenRequest).activityType
    }

    override func getCacheStoreKey() -> String { return OS_LIVE_ACTIVITIES_EXECUTOR_START_TOKENS_KEY }
}

// TODO: Remove update tokens that are older than 24 hours old, they cannot be updated after 12 hours
// TODO: Remove start tokens that are older than ?? old (maybe?)
class OSLiveActivitiesExecutor : OSPushSubscriptionObserver {
    // The currently tracked update and start tokens (key) and their associated request (value).
    fileprivate var updateTokens: UpdateTokenCache = UpdateTokenCache()
    fileprivate var startTokens: StartTokenCache = StartTokenCache()
    
    // The live activities request dispatch queue, serial.
    private var requestDispatch: DispatchQueue = DispatchQueue(label: "OneSignal LiveActivities DispatchQueue")
    private var pollIntervalSeconds = 30
    
    init() {
        OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OneSignal.LiveActivities starting activity executor")
        self.caches { cache in
            cache.load()
        }
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
        OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OneSignal.LiveActivities starting activity poll")

        // drive a poll in case there are any outstanding requests.
        pollPendingRequests()
    }
    
    func append(_ request: OSLiveActivityRequest) {
        self.requestDispatch.async {
            self.withCache(request) { cache in
                // first add/save the request to the appropriate cache
                if(cache.addAndSave(request)) {
                    // execute immediately
                    self.executeRequest(cache, request: request) { wasSuccessful in
                        if(!wasSuccessful) {
                            // drive a poll when the request fails
                            self.pollPendingRequests()
                        }
                    }
                }
            }
        }
    }

    private func pollPendingRequests() {
        self.requestDispatch.asyncAfter(deadline: .now() + .seconds(pollIntervalSeconds)) { [weak self] in
            OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OneSignal.LiveActivities pollPendingRequests")

            var hasOutstandingRequests = false
            self?.caches { cache in
                cache.requests { request in
                    if request.requestSuccessful {
                        return
                    }

                    self?.executeRequest(cache, request: request) { wasSuccessful in
                        hasOutstandingRequests = hasOutstandingRequests || !wasSuccessful
                    }
                }
            }
            
            // if there are outstanding requests, poll again
            if hasOutstandingRequests {
                self?.pollPendingRequests()
            }
        }
    }
    
    private func executeRequest(_ cache: TokenCache, request: OSLiveActivityRequest, block: @escaping (Bool) -> Void){
        if(OSPrivacyConsentController.requiresUserPrivacyConsent()) {
            OneSignalLog.onesignalLog(.LL_WARN, message: "Cannot send live activity request when the user has not granted privacy permission")
            block(false)
            return
        }
        
        if (!request.prepareForExecution()) {
            OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OneSignal.LiveActivities unable to execute activity request")
            block(false)
            return
        }
        
        OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OneSignal.LiveActivities executing request: \(request)")
        OneSignalClient.shared().execute(request) { _ in
            OneSignalLog.onesignalLog(.LL_VERBOSE, message: "Live activities request succeeded")
            // Save the appropriate cache with the updated request for this request key.
            if request.isRemoveRequest {
                cache.removeAndSave(request)
            }
            else {
                request.requestSuccessful = true
                cache.save()
            }
            block(true)
        } onFailure: { error in
            OneSignalLog.onesignalLog(.LL_VERBOSE, message: "Live activities request failed with error \(error.debugDescription)")
            if let nsError = error as? NSError {
                let responseType = OSNetworkingUtils.getResponseStatusType(nsError.code)
                if responseType != .retryable {
                    // Failed, no retry. Remove the key from the cache entirely so we don't try again.
                    cache.removeAndSave(request)
                    block(true)
                    return
                }
            }
            block(false)
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
}
