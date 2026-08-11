/*
 Modified MIT License

 Copyright 2022 OneSignal

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
 Enqueues OSDeltas from model-store observers and routes them to executors.

 Also owns Identity Verification decisions for queued work: hold flushes until `requirement` is known,
 and drop anonymous Deltas while IV is active — except push subscription updates, which stay unsigned
 and have to keep flowing with or without an identified user.
 */
public class OSOperationRepo: NSObject {
    private let identityVerificationService: OSIdentityVerificationService

    /**
     Serial, and the only place `deltaQueue`, the executor registry, and the two start flags may be
     touched once this instance is handed out — `init` runs before anything else can reach it. Every
     private method here assumes it is already running on this queue.
     Non-private so test helpers can synchronize with it.
     */
    let dispatchQueue = DispatchQueue(label: "OneSignal.OSOperationRepo", target: .global())

    private var hasCalledStart = false
    private var hasBegunObserving = false

    var deltasToExecutorMap: [String: OSOperationExecutor] = [:]
    var executors: [OSOperationExecutor] = []
    var deltaQueue: [OSDelta] = [] // non-private for unit test access

    // TODO: This could come from a config, plist, method, remote params
    var pollIntervalMilliseconds = Int(POLL_INTERVAL_MS)
    public var paused = false

    // Uncache in init so an enqueue before start cannot persist over a previous session's queue.
    public init(identityVerificationService: OSIdentityVerificationService) {
        self.identityVerificationService = identityVerificationService
        super.init()
        uncacheDeltaQueue()
    }

    /**
     Re-reads the cache while the in-memory queue is still empty. `init` can run during prewarm before
     first unlock, when UserDefaults silently returns nothing — same gap as `OSModelStore.refresh`.
     */
    public func refreshIfEmpty() {
        dispatchQueue.async {
            guard self.deltaQueue.isEmpty else {
                return
            }
            self.uncacheDeltaQueue()
        }
    }

    private func uncacheDeltaQueue() {
        guard let cached = OneSignalUserDefaults.initShared().getSavedCodeableData(forKey: OS_OPERATION_REPO_DELTA_QUEUE_KEY, defaultValue: []) as? [OSDelta] else {
            OneSignalLog.onesignalLog(.LL_ERROR, message: "OSOperationRepo is unable to uncache the OSDelta queue.")
            return
        }
        deltaQueue = cached
        OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OSOperationRepo uncached deltaQueue: \(cached)")
    }

    public func start() {
        guard !OneSignalConfig.shouldAwaitAppIdAndLogMissingPrivacyConsent(forMethod: nil) else {
            return
        }
        dispatchQueue.async {
            self.startPolling()
        }
    }

    /**
     While `requirement` is unknown, returns without setting `hasCalledStart` so hydration can call
     `start()` again once remote params answer.
     */
    private func startPolling() {
        guard !hasCalledStart else {
            return
        }

        beginObserving()

        guard identityVerificationService.requirement != .unknown else {
            OneSignalLog.onesignalLog(.LL_DEBUG, message: "OSOperationRepo.start() deferred until the Identity Verification requirement is known")
            return
        }
        hasCalledStart = true

        OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OSOperationRepo calling start()")
        pollFlushQueue()
    }

    // Subscribe ahead of the requirement gate so a never-hydrated session still hears late hydration.
    private func beginObserving() {
        guard !hasBegunObserving else {
            return
        }
        hasBegunObserving = true

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.addFlushDeltaQueueToDispatchQueue),
                                               name: Notification.Name(OS_ON_USER_WILL_CHANGE),
                                               object: nil)

        // Callback rather than a repo dependency, which would cycle.
        identityVerificationService.addOnJwtConfigHydratedHandler(for: .operationRepo) { [weak self] _ in
            self?.onJwtConfigHydrated()
        }
    }

    /**
     Runs on every hydration, including an unchanged value — deferred work is waiting on it.

     Hop onto `dispatchQueue`: `hydrate` calls this from whichever thread received remote params, and a
     handler registered when the requirement is already cached fires synchronously from inside
     `startPolling()`, where the hop defers this until that call finishes.
     */
    private func onJwtConfigHydrated() {
        dispatchQueue.async {
            // Flush now rather than wait out a poll interval for work held since launch.
            self.startPolling()
            self.flushDeltaQueue()
        }
    }

    private func pollFlushQueue() {
        self.dispatchQueue.asyncAfter(deadline: .now() + .milliseconds(pollIntervalMilliseconds)) { [weak self] in
            self?.flushDeltaQueue()
            self?.pollFlushQueue()
        }
    }

    /**
     Registers before starting rather than after: once remote params are cached, `startPolling()` fires
     the hydration handler synchronously and that flush reads the registry being written here.
     */
    public func addExecutor(_ executor: OSOperationExecutor) {
        guard !OneSignalConfig.shouldAwaitAppIdAndLogMissingPrivacyConsent(forMethod: nil) else {
            return
        }
        dispatchQueue.async {
            self.executors.append(executor)
            for delta in executor.supportedDeltas {
                self.deltasToExecutorMap[delta] = executor
            }
            self.startPolling()
        }
    }

    /**
     Enqueueing is driven by model changes and called manually by the User Manager to
     add session time, session count and purchase data.

     // TODO: We can make this method internal once there is no manual adding of a Delta except through stores.
     This can happen when session data and purchase data use the model / store / listener infrastructure.
     */
    public func enqueueDelta(_ delta: OSDelta, flush: Bool = false) {
        guard !OneSignalConfig.shouldAwaitAppIdAndLogMissingPrivacyConsent(forMethod: nil) else {
            return
        }

        self.dispatchQueue.async {
            self.startPolling()

            // Drop here too so it is never persisted; flush still covers deltas restored from cache.
            guard !self.shouldDropAnonymousDelta(delta, ivActive: self.shouldDropAnonymousDeltas) else {
                OneSignalLog.onesignalLog(.LL_DEBUG, message: "OSOperationRepo dropping anonymous Delta, Identity Verification is required: \(delta)")
                return
            }

            OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OSOperationRepo enqueueDelta: \(delta)")
            self.deltaQueue.append(delta)

            OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_OPERATION_REPO_DELTA_QUEUE_KEY, withValue: self.deltaQueue)

            if flush {
                self.flushDeltaQueue()
            }
        }
    }

    @objc public func addFlushDeltaQueueToDispatchQueue(inBackground: Bool = false) {
        self.dispatchQueue.async {
            self.flushDeltaQueue(inBackground: inBackground)
        }
    }

    func flushAndWait() {
        dispatchQueue.sync {
            flushDeltaQueue()
        }
    }

    /// An anonymous Delta can never be signed, so drop it while Identity Verification is active.
    private var shouldDropAnonymousDeltas: Bool {
        return identityVerificationService.ivBehaviorActive
    }

    /**
     `OS_UPDATE_SUBSCRIPTION_DELTA` is exempt. In practice it is only ever the device's own push
     subscription — nothing updates an email or SMS subscription model — and that channel exists before
     any login and outlives every logout, so its token and device state have to keep flowing whether or
     not a user is identified. Its endpoint is addressed by subscription ID and takes no user JWT.

     That leaves the exemption resting on the invariant that email and SMS subscriptions are only ever
     added and removed, never updated. Should an update path for them appear, this has to narrow to the
     push type, which the repo cannot see from here: `OSSubscriptionModel` lives in OneSignalUser, so
     the Delta would have to carry the distinction the way it carries `externalId`.
     */
    private func shouldDropAnonymousDelta(_ delta: OSDelta, ivActive: Bool) -> Bool {
        return ivActive && delta.externalId == nil && delta.name != OS_UPDATE_SUBSCRIPTION_DELTA
    }

    private func flushDeltaQueue(inBackground: Bool = false) {
        guard !paused else {
            OneSignalLog.onesignalLog(.LL_DEBUG, message: "OSOperationRepo not flushing queue due to being paused")
            return
        }

        guard !OneSignalConfig.shouldAwaitAppIdAndLogMissingPrivacyConsent(forMethod: nil) else {
            return
        }

        // Before the requirement gate so a first flush still registers the hydration handler.
        self.startPolling()

        /*
         Hold until `requirement` is known. `newCodePathsRun` / `ivBehaviorActive` both read false while
         it is unknown.
         */
        guard identityVerificationService.requirement != .unknown else {
            let heldCount = self.deltaQueue.count
            if heldCount > 0 {
                OneSignalLog.onesignalLog(.LL_DEBUG, message: "OSOperationRepo holding \(heldCount) Deltas until the requirement is known")
            }
            return
        }

        if inBackground {
            OSBackgroundTaskManager.beginBackgroundTask(OPERATION_REPO_BACKGROUND_TASK)
        }

        if !self.deltaQueue.isEmpty {
            OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OSOperationRepo flushDeltaQueue in background: \(inBackground) with queue: \(self.deltaQueue)")
        }

        // Snapshot once so every Delta in this pass sees the same gate values.
        let dropAnonymous = shouldDropAnonymousDeltas

        var unmatched: [OSDelta] = []
        for delta in self.deltaQueue {
            if shouldDropAnonymousDelta(delta, ivActive: dropAnonymous) {
                OneSignalLog.onesignalLog(.LL_DEBUG, message: "OSOperationRepo dropping anonymous Delta, Identity Verification is required: \(delta)")
            } else if let executor = self.deltasToExecutorMap[delta.name] {
                executor.enqueueDelta(delta)
            } else {
                // Keep if no executor matches yet (module may not have started).
                unmatched.append(delta)
            }
        }
        // Persist only when the queue changed: a no-op write before `refreshIfEmpty` can clobber a
        // cache that prewarm failed to read.
        if unmatched.count != self.deltaQueue.count {
            self.deltaQueue = unmatched
            OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_OPERATION_REPO_DELTA_QUEUE_KEY, withValue: self.deltaQueue)
        }

        if dropAnonymous {
            for executor in self.executors {
                executor.removeOperationsWithoutExternalId()
            }
        }

        for executor in self.executors {
            executor.cacheDeltaQueue()
        }

        for executor in self.executors {
            executor.processDeltaQueue(inBackground: inBackground)
        }

        if inBackground {
            OSBackgroundTaskManager.endBackgroundTask(OPERATION_REPO_BACKGROUND_TASK)
        }
    }
}
