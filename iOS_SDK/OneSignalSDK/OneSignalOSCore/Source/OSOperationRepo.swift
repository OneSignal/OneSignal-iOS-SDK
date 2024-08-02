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
 The OSOperationRepo is a static singleton.
 OSDeltas are enqueued when model store observers observe changes to their models, and sorted to their appropriate executors.
 */
public class OSOperationRepo: NSObject {
    @objc public static let sharedInstance = OSOperationRepo()
    private var hasCalledStart = false

    // The Operation Repo dispatch queue, serial. This synchronizes access to `deltaQueue` and flushing behavior.
    private let dispatchQueue = DispatchQueue(label: "OneSignal.OSOperationRepo", target: .global())

    // Maps delta names to the interfaces for the operation executors
    var deltasToExecutorMap: [String: OSOperationExecutor] = [:]
    var executors: [OSOperationExecutor] = []
    private var deltaQueue: [OSDelta] = []

    // TODO: This could come from a config, plist, method, remote params
    var pollIntervalMilliseconds = Int(POLL_INTERVAL_MS)
    public var paused = false

    var requiresAuth: Bool?
    
    /**
     Initilize this Operation Repo. Read from the cache. Executors may not be available by this time.
     If everything starts up on initialize(), order can matter, ideally not but it can.
     Likely call init on this from oneSignal but exeuctors can come from diff modules.
     */
    public func start(requiresAuth: Bool?) {
        print("❌ OSOperationRepo start(\(requiresAuth))")

        if self.requiresAuth == nil {
            self.requiresAuth = requiresAuth
        }
        // TODO: JWT OneSignalUserManagerImpl.sharedInstance.jwtConfig.changeNotifier.subscribe(self)

        guard !OneSignalConfigManager.shouldAwaitAppIdAndLogMissingPrivacyConsent(forMethod: nil) else {
            return
        }
        guard !hasCalledStart else {
            return
        }
        hasCalledStart = true

        OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OSOperationRepo calling start()")
        // register as user observer
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.addFlushDeltaQueueToDispatchQueue),
                                               name: Notification.Name(OS_ON_USER_WILL_CHANGE),
                                               object: nil)
        // Read the Deltas from cache, if any...
        if let deltaQueue = OneSignalUserDefaults.initShared().getSavedCodeableData(forKey: OS_OPERATION_REPO_DELTA_QUEUE_KEY, defaultValue: []) as? [OSDelta] {
            self.deltaQueue = deltaQueue
            OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OSOperationRepo.start() with deltaQueue: \(deltaQueue)")
        } else {
            OneSignalLog.onesignalLog(.LL_ERROR, message: "OSOperationRepo.start() is unable to uncache the OSDelta queue.")
        }

        pollFlushQueue()
    }

    private func pollFlushQueue() {
        self.dispatchQueue.asyncAfter(deadline: .now() + .milliseconds(pollIntervalMilliseconds)) { [weak self] in
            self?.flushDeltaQueue()
            self?.pollFlushQueue()
        }
    }

    /**
     Add and start an executor.
     */
    public func addExecutor(_ executor: OSOperationExecutor) {
        guard !OneSignalConfigManager.shouldAwaitAppIdAndLogMissingPrivacyConsent(forMethod: nil) else {
            return
        }

        // TODO: JWT 🔐
//        start()
        if !hasCalledStart {
            fatalError("❌❌❌❌ Operation Repo has not called start in addExecutor()")
        }
        
        executors.append(executor)
        for delta in executor.supportedDeltas {
            deltasToExecutorMap[delta] = executor
        }
    }

    /**
     Enqueueing is driven by model changes and called manually by the User Manager to
     add session time, session count and purchase data.
     
     // TODO: We can make this method internal once there is no manual adding of a Delta except through stores.
     This can happen when session data and purchase data use the model / store / listener infrastructure.
     */
    public func enqueueDelta(_ delta: OSDelta) {
        guard !OneSignalConfigManager.shouldAwaitAppIdAndLogMissingPrivacyConsent(forMethod: nil) else {
            return
        }
        // TODO: JWT 🔐
//        start()
        if !hasCalledStart {
            fatalError("❌❌❌❌ Operation Repo has not called start in enqueueDelta()")
        }
        self.dispatchQueue.async {
            OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OSOperationRepo enqueueDelta: \(delta)")
            self.deltaQueue.append(delta)
            // Persist the deltas (including new delta) to storage
            OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_OPERATION_REPO_DELTA_QUEUE_KEY, withValue: self.deltaQueue)
        }
    }

    @objc public func addFlushDeltaQueueToDispatchQueue(inBackground: Bool = false) {
        self.dispatchQueue.async {
            self.flushDeltaQueue(inBackground: inBackground)
        }
    }

    private func flushDeltaQueue(inBackground: Bool = false) {
        guard !paused else {
            OneSignalLog.onesignalLog(.LL_DEBUG, message: "OSOperationRepo not flushing queue due to being paused")
            return
        }

        guard !OneSignalConfigManager.shouldAwaitAppIdAndLogMissingPrivacyConsent(forMethod: nil) else {
            return
        }

        if inBackground {
            OSBackgroundTaskManager.beginBackgroundTask(OPERATION_REPO_BACKGROUND_TASK)
        }

        // TODO: JWT 🔐
//        self.start()
        if !hasCalledStart {
            fatalError("❌❌❌❌ Operation Repo has not called start in flushDeltaQueue()")
        }
        
        if !self.deltaQueue.isEmpty {
            OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OSOperationRepo flushDeltaQueue in background: \(inBackground) with queue: \(self.deltaQueue)")
        }

        var index = 0
        for delta in self.deltaQueue {
            if let executor = self.deltasToExecutorMap[delta.name] {
                executor.enqueueDelta(delta)
                self.deltaQueue.remove(at: index)
            } else {
                // keep in queue if no executor matches, we may not have the executor available yet
                index += 1
            }
        }

        // Persist the deltas (including removed deltas) to storage after they are divvy'd up to executors.
        OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_OPERATION_REPO_DELTA_QUEUE_KEY, withValue: self.deltaQueue)

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

extension OSOperationRepo: OSUserJwtConfigListener {
    func removeInvalidDeltas() {
        print("❌ OSOperationRepo removeInvalidDeltas")
    }
    public func onUserAuthChanged(from: Bool?, to: Bool?) {
        print("❌ OSOperationRepo onUserAuthChanged from \(from) to \(to)")

        // If auth changed from false or unknown to true, process requests
        if (to == true) {
            removeInvalidDeltas()
        }
        pollFlushQueue()
    }
    
    public func onJwtInvalidated(externalId: String, error: String?) {
        //
    }
    
    public func onJwtUpdated(externalId: String, jwtToken: String) {
        //
    }
    
    public func onJwtTokenChanged(externalId: String, from: String?, to: String?) {
        //
    }
    
    
}

extension OSOperationRepo: OSLoggable {
    @objc
    public func logSelf() {
        print("💛 Operation Repo: executors")
        for executor in self.executors {
            executor.logSelf()
        }

        print("💛 Operation Repo: deltaQueue: ")
        for delta in self.deltaQueue {
            print(delta)
        }
    }
}
