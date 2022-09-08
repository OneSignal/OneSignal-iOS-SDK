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
    public static let sharedInstance = OSOperationRepo().start()

    // Maps delta names to the interfaces for the operation executors
    var deltasToExecutorMap: [String: OSOperationExecutor] = [:]
    var executors: [OSOperationExecutor] = []
    var deltaQueue: [OSDelta] = []

    // TODO: This should come from a config, plist, method, remote params
    var operationsProcessingInterval = 5000

    /**
     Initilize this Operation Repo. Read from the cache. Executors may not be available by this time.
     If everything starts up on initialize(), order can matter, ideally not but it can.
     Likely call init on this from oneSignal but exeuctors can come from diff modules.
     */
    func start() -> OSOperationRepo {
        // Read the Deltas from cache, if any... TODO: Don't hardcode key value
        guard let deltaQueue = OneSignalUserDefaults.initShared().getSavedCodeableData(forKey: "OS_OPERATION_REPO_DELTA_QUEUE", defaultValue: []) as? [OSDelta] else {
            // log error
            return self
        }
        self.deltaQueue = deltaQueue
        return self
    }

    /**
     Add and start an executor.
     */
    public func addExecutor(_ executor: OSOperationExecutor) {
        executors.append(executor)
        for delta in executor.supportedDeltas {
            deltasToExecutorMap[delta] = executor
            executor.start()
        }
    }

    func enqueueDelta(_ delta: OSDelta) {
        print("🔥 OSOperationRepo enqueueDelta: \(delta)")
        deltaQueue.append(delta)

        // Persist the deltas (including new delta) to storage
        OneSignalUserDefaults.initShared().saveCodeableData(forKey: "OS_OPERATION_REPO_DELTA_QUEUE", withValue: self.deltaQueue)
    }

    public func removeDeltaFromCache(_ delta: OSDelta) {
        // Persist the deltas (including removed delta) to storage
        OneSignalUserDefaults.initShared().saveCodeableData(forKey: "OS_OPERATION_REPO_DELTA_QUEUE", withValue: self.deltaQueue)
    }

    func flushDeltaQueue() {
        if deltaQueue.isEmpty {
            return
        }
        for delta in deltaQueue {
            if let executor = deltasToExecutorMap[delta.name] {
                executor.enqueueDelta(delta)
            }
            // keep in queue if no executor matches, we may not have the executor available yet
        }

        for executor in executors {
            executor.processDeltaQueue()
        }
    }
}

// how to implement every 5 seconds flush, some background service callign every 5 seconds,
// blocking queue, sync queue - many threads are manipulating the same queue, think about lock it when flush
// can't use async keyword bc ios 13+
// https://developer.apple.com/documentation/dispatch/dispatchqueue
