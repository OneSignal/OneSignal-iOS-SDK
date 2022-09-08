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
import OneSignalOSCore
import OneSignalCore

class OSPropertyOperationExecutor: OSOperationExecutor {
    var supportedDeltas: [String] = ["OSUpdatePropertyOperation"] // TODO: Don't hardcode
    var deltaQueue: [OSDelta] = []
    var operationQueue: [OSOperation] = []

    func start() {
        // Read unfinished operations from cache, if any... TODO: Don't hardcode
        guard let operationQueue = OneSignalUserDefaults.initShared().getSavedCodeableData(forKey: "OS_PROPERTY_OPERATION_EXECUTOR_OPERATIONS", defaultValue: []) as? [OSOperation] else {
            return
        }
        self.operationQueue = operationQueue
    }

    func enqueueDelta(_ delta: OSDelta) {
        print("🔥 OSPropertyOperationExecutor enqueue delta\(delta)")
        deltaQueue.append(delta)
    }

    func processDeltaQueue() {
        if deltaQueue.isEmpty {
            return
        }
        // TODO: Implementation
        for delta in deltaQueue {
            // Remove the delta from the cache when it becomes an Operation
            OSOperationRepo.sharedInstance.removeDeltaFromCache(delta)
            // enqueueOperation(operation)
        }
        processOperationQueue()
    }

    func enqueueOperation(_ operation: OSOperation) {
        print("🔥 OSPropertyOperationExecutor enqueueOperation: \(operation)")
        operationQueue.append(operation)

        // persist executor's operations (including new operation) to storage
        OneSignalUserDefaults.initShared().saveCodeableData(forKey: "OS_PROPERTY_OPERATION_EXECUTOR_OPERATIONS", withValue: self.operationQueue)
    }

    func processOperationQueue() {
        if operationQueue.isEmpty {
            return
        }
        for operation in operationQueue {
            executeOperation(operation)
        }
    }

    func executeOperation(_ operation: OSOperation) {
        // Execute the operation
        // Mock a response

        let response = ["language": "en"]

        // On success, remove operation from cache, and hydrate model
        OneSignalUserDefaults.initShared().saveCodeableData(forKey: "OS_PROPERTY_OPERATION_EXECUTOR_OPERATIONS", withValue: self.operationQueue)

        operation.model.hydrate(response)

        // On failure, retry logic
    }
}
