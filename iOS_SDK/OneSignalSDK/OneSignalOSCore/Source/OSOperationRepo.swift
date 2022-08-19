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
 OSOperation are enqueued to their appropriate executors when model store observers observe changes to their models.
 */
public class OSOperationRepo: NSObject {
    static let sharedInstance = OSOperationRepo(executors: []) // TODO: Setup executors
    
    // Maps operation names to the interfaces for the operation executors
    let operationToExecutorMap: [String : OSOperationExecutor]
    let executors: [OSOperationExecutor]

    // TODO: This should come from a config
    var operationsProcessingInterval = 5000
    
    public init(executors: [OSOperationExecutor]) {
        self.executors = executors
        var executorsMap: [String : OSOperationExecutor] = [:]
        for executor in executors {
            for operation in executor.supportedOperations {
                executorsMap[operation] = executor
            }
        }
        self.operationToExecutorMap = executorsMap
    }
    
    /**
     An OSOperation will be enqueued to its executor who will save it to disk via UserDefaults.
     When app is relaunched, read from disk to see if any operations need to be sent still.
     */
    func enqueue(_ operation: OSOperation) {
        print("🔥 OSOperationRepo enqueue \(operation)")
        let executor = operationToExecutorMap[operation.name] // do some check for it not existing?
        executor?.enqueue(operation)
    }
    
    func flush() {
        for executor in executors {
            executor.execute()
        }
    }
}

// how to implement every 5 seconds flush, some background service callign every 5 seconds,
// blocking queue, sync queue - many threads are manipulating the same queue, think about lock it when flush
// can't use async keyword bc ios 13+
// https://developer.apple.com/documentation/dispatch/dispatchqueue
