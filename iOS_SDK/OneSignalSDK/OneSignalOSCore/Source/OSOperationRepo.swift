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
    public static let sharedInstance = OSOperationRepo()
    private var hasCalledStart = false

    // Maps delta names to the interfaces for the operation executors
    var deltasToExecutorMap: [String: OSOperationExecutor] = [:]
    var executors: [OSOperationExecutor] = []
    var deltaQueue: [OSDelta] = []

    // TODO: This should come from a config, plist, method, remote params
    var pollIntervalSeconds = Int(POLL_INTERVAL_MS)

    /**
     Initilize this Operation Repo. Read from the cache. Executors may not be available by this time.
     If everything starts up on initialize(), order can matter, ideally not but it can.
     Likely call init on this from oneSignal but exeuctors can come from diff modules.
     */
    public func start() {
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
                                               selector: #selector(self.flushDeltaQueue),
                                               name: Notification.Name(OS_ON_USER_WILL_CHANGE),
                                               object: nil)
        // Read the Deltas from cache, if any...
        if let deltaQueue = OneSignalUserDefaults.initShared().getSavedCodeableData(forKey: OS_OPERATION_REPO_DELTA_QUEUE_KEY, defaultValue: []) as? [OSDelta] {
            self.deltaQueue = deltaQueue
        } else {
            // log error
        }

        pollFlushQueue()
    }

    private func pollFlushQueue() {
        OneSignalLog.onesignalLog(.LL_VERBOSE, message: "🔥 OSOperationRepo pollFlushQueue")

        DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(pollIntervalSeconds)) { [weak self] in
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
        start()
        executors.append(executor)
        for delta in executor.supportedDeltas {
            deltasToExecutorMap[delta] = executor
        }
    }

    func enqueueDelta(_ delta: OSDelta) {
        guard !OneSignalConfigManager.shouldAwaitAppIdAndLogMissingPrivacyConsent(forMethod: nil) else {
            return
        }
        start()
        OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OSOperationRepo enqueueDelta: \(delta)")
        deltaQueue.append(delta)

        // Persist the deltas (including new delta) to storage
        OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_OPERATION_REPO_DELTA_QUEUE_KEY, withValue: self.deltaQueue)
    }

    @objc public func flushDeltaQueue() {
        OneSignalLog.onesignalLog(.LL_VERBOSE, message: "🔥 OSOperationRepo flushDeltaQueue with queue: \(deltaQueue)")

        guard !OneSignalConfigManager.shouldAwaitAppIdAndLogMissingPrivacyConsent(forMethod: nil) else {
            OneSignalLog.onesignalLog(.LL_VERBOSE, message: "🔥 OSOperationRepo flushDeltaQueue RETURNS")

            return
        }
        start()
        if !deltaQueue.isEmpty {
            OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OSOperationRepo flushDeltaQueue with queue: \(deltaQueue)")
        }

        var index = 0
        for delta in deltaQueue {
            if let executor = deltasToExecutorMap[delta.name] {
                executor.enqueueDelta(delta)
                deltaQueue.remove(at: index)
            } else {
                // keep in queue if no executor matches, we may not have the executor available yet
                index += 1
            }
        }

        // Persist the deltas (including removed deltas) to storage after they are divvy'd up to executors.
        OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_OPERATION_REPO_DELTA_QUEUE_KEY, withValue: self.deltaQueue)

        for executor in executors {
            executor.cacheDeltaQueue()
        }

        for executor in executors {
            executor.processDeltaQueue()
        }
    }
}
