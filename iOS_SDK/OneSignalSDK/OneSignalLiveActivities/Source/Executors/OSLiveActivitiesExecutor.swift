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
import OneSignalOSCore
import OneSignalUser

/**
 A request cache keeps track of all the current update token or start token requests.  There can only be one request
 per OSLiveActivityRequest.key, and each request has either been successfully sent to OneSignal or hasn't.  Requests
 that have been sent to OneSignal remain in the cache to avoid sending redundant reequests, as the update/start
 token updates are called frequently with the same information.
 
 The cache is persisted to disk via the `cacheKey`, and items will remain in the cache until explicitely removed or
 it has existed past the `ttl` provided.
 
 WARNING: This cache is **not** thread safe, synchronization required!
 */
class RequestCache {
    var items: [String: OSLiveActivityRequest]
    private var cacheKey: String
    private var ttl: TimeInterval

    init(cacheKey: String, ttl: TimeInterval) {
        self.cacheKey = cacheKey
        self.ttl = ttl
        self.items = OneSignalUserDefaults.initShared()
            .getSavedCodeableData(forKey: cacheKey, defaultValue: nil) as? [String: OSLiveActivityRequest] ?? [String: OSLiveActivityRequest]()
        OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OneSignal.LiveActivities initialized token cache \(self): \(items)")
    }

    func add(_ request: OSLiveActivityRequest) {
        self.items.updateValue(request, forKey: request.key)
        self.save()
    }

    func remove(_ request: OSLiveActivityRequest) {
        if self.items.contains(where: { $0.1 == request}) {
            self.items.removeValue(forKey: request.key)
            self.save()
        }
    }

    func markAllUnsuccessful() {
        for (_, request) in self.items {
            request.requestSuccessful = false
        }
        self.save()
    }

    func markSuccessful(_ request: OSLiveActivityRequest) {
        if self.items.contains(where: { $0.1 == request}) {
            // Save the appropriate cache with the updated request for this request key.
            if request.shouldForgetWhenSuccessful {
                self.items.removeValue(forKey: request.key)
            } else {
                request.requestSuccessful = true
            }
            self.save()
        }
    }

    private func save() {
        // before saving, remove any stale requests from the cache.
        for (_, request) in self.items where -request.timestamp.timeIntervalSinceNow > ttl {
            OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OneSignal.LiveActivities remove stale request from token cache \(self): \(request)")
            self.items.removeValue(forKey: request.key)
        }
        OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OneSignal.LiveActivities saving token cache \(self): \(items)")
        OneSignalUserDefaults.initShared().saveCodeableData(forKey: self.cacheKey, withValue: self.items)
    }
}

class LiveActivityIdRequestCache: RequestCache {
    // An update token should not last longer than 8 hours, we keep for 24 hours to be safe.
    static let OneDayInSeconds = TimeInterval(60 * 60 * 24 * 365)

    init() {
        super.init(cacheKey: OS_LIVE_ACTIVITIES_EXECUTOR_UPDATE_TOKENS_KEY, ttl: LiveActivityIdRequestCache.OneDayInSeconds)
    }
}

class LiveActivityTypeRequestCache: RequestCache {
    // A start token will exist for a year in the cache.
    static let OneYearInSeconds = TimeInterval(60 * 60 * 24 * 365)

    init() {
        super.init(cacheKey: OS_LIVE_ACTIVITIES_EXECUTOR_START_TOKENS_KEY, ttl: LiveActivityTypeRequestCache.OneYearInSeconds)
    }
}

class OSLiveActivitiesExecutor: OSPushSubscriptionObserver {
    // The currently tracked update and start tokens (key) and their associated request (value). THESE ARE NOT THREAD SAFE
    let idRequestCache: LiveActivityIdRequestCache = LiveActivityIdRequestCache()
    let typeRequestCache: LiveActivityTypeRequestCache = LiveActivityTypeRequestCache()

    // The live activities request dispatch queue, serial.  This synchronizes access to `updateTokens` and `startTokens`.
    private var requestDispatch: OSDispatchQueue
    private var pollIntervalSeconds = 30

    init(requestDispatch: OSDispatchQueue) {
        self.requestDispatch = requestDispatch
    }

    func start() {
        OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OneSignal.LiveActivities starting executor")
        OneSignalUserManagerImpl.sharedInstance.pushSubscriptionImpl.addObserver(self)

        // drive a poll in case there are any outstanding requests in the cache.
        self.pollPendingRequests()
    }

    func onPushSubscriptionDidChange(state: OneSignalUser.OSPushSubscriptionChangedState) {
        if state.previous.id == state.current.id {
            return
        }

        // when a push subscription id changes, we need to re-send up all update and start tokens with the new ID.
        self.requestDispatch.async {
            self.caches { _ in
                self.typeRequestCache.markAllUnsuccessful()
            }

            self.pollPendingRequests()
        }
    }

    // TODO: For OSRequestTrackReciept we **must** build in a concept of waiting before sending up the request. The waiting would
    //       have a randomness factor so we don't get a thundering herd problem.  We **should** consider waiting at least a few
    //       minutes + some randomness. Normal push confirmed deliveries waits between 0 and 25 seconds, but the frequency of a
    //       normal push notification is significanly less than LA push notifications. Some apps might send multiple LA updates per
    //       minute.  By waiting minutes we can batch confirm multiple LA push notification deliveries.  Alternatively we might
    //       consider not sending up confirmations until the user dismisses the LA?  How long we wait to send up confirmation will
    //       have product consequences.
    func append(_ request: OSLiveActivityRequest) {
        self.requestDispatch.async {
            let cache = self.getCache(request)
            let existingRequest = cache.items[request.key]

            if existingRequest == nil || request.supersedes(existingRequest!) {
                cache.add(request)
                self.executeRequest(cache, request: request)
            } else {
                OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OneSignal.LiveActivities superseded request not saved/executed: \(request)")
            }
        }
    }

    private func pollPendingRequests() {
        OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OneSignal.LiveActivities pollPendingRequests")

        self.requestDispatch.asyncAfterTime(deadline: .now() + .seconds(pollIntervalSeconds)) { [weak self] in
            OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OneSignal.LiveActivities executing outstanding requests")

            // execute any request that hasn't been successfully executed.
            self?.caches { cache in
                for request in cache.items.values.filter({ !$0.requestSuccessful }) {
                    self?.executeRequest(cache, request: request)
                }
            }
        }
    }

    private func caches(_ block: (RequestCache) -> Void) {
        block(self.typeRequestCache)
        block(self.idRequestCache)
    }

    private func getCache(_ request: OSLiveActivityRequest) -> RequestCache {
        if request is OSLiveActivityIdRequest {
            return self.idRequestCache
        }

        return self.typeRequestCache
    }

    private func executeRequest(_ cache: RequestCache, request: OSLiveActivityRequest) {
        if OSPrivacyConsentController.requiresUserPrivacyConsent() {
            OneSignalLog.onesignalLog(.LL_WARN, message: "Cannot send live activity request when the user has not granted privacy permission")
            self.pollPendingRequests()
            return
        }

        if !request.prepareForExecution() {
            return
        }

        OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OneSignal.LiveActivities executing request: \(request)")
        OneSignalCoreImpl.sharedClient().execute(request) { _ in
            // NOTE: No longer running under `requestDispatch` DispatchQueue!
            OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OneSignal.LiveActivities request succeeded: \(request)")
            self.requestDispatch.async {
                cache.markSuccessful(request)
            }
        } onFailure: { error in
            // NOTE: No longer running under `requestDispatch` DispatchQueue!
            OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OneSignal.LiveActivities request failed with error \(error.debugDescription)")
            if let nsError = error as? NSError {
                let responseType = OSNetworkingUtils.getResponseStatusType(nsError.code)
                if responseType != .retryable {
                    self.requestDispatch.async {
                        // Failed, no retry. Remove the key from the cache entirely so we don't try again.
                        cache.remove(request)
                    }
                    return
                }
            }
            // retryable failures will stay in the cache, and will retry the next time the app starts
        }
    }
}
