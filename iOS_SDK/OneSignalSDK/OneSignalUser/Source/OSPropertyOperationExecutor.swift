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

import OneSignalOSCore
import OneSignalCore

class OSPropertyOperationExecutor: OSOperationExecutor {
    var supportedDeltas: [String] = [OS_UPDATE_PROPERTIES_DELTA]
    var deltaQueue: [OSDelta] = []
    var requestQueue: [OneSignalRequest] = []

    init() {
        // Read unfinished deltas and requests from cache, if any...

        if let deltaQueue = OneSignalUserDefaults.initShared().getSavedCodeableData(forKey: OS_PROPERTIES_EXECUTOR_DELTA_QUEUE_KEY, defaultValue: []) as? [OSDelta] {
            self.deltaQueue = deltaQueue
        } else {
            // log error
        }

        if let requestQueue = OneSignalUserDefaults.initShared().getSavedCodeableData(forKey: OS_PROPERTIES_EXECUTOR_REQUEST_QUEUE_KEY, defaultValue: []) as? [OneSignalRequest] {
            self.requestQueue = requestQueue
        } else {
            // log error
        }
    }

    func enqueueDelta(_ delta: OSDelta) {
        print("🔥 OSPropertyOperationExecutor enqueue delta\(delta)")
        deltaQueue.append(delta)
    }

    func cacheDeltaQueue() {
        OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_PROPERTIES_EXECUTOR_DELTA_QUEUE_KEY, withValue: self.deltaQueue)
    }

    func processDeltaQueue() {
        if deltaQueue.isEmpty {
            return
        }

        for delta in deltaQueue {
            guard let model = delta.model as? OSPropertiesModel else {
                // Log error
                continue
            }

            let request = OSRequestUpdateProperties(
                properties: [delta.property: delta.value],
                deltas: nil,
                refreshDeviceMetadata: false, // Sort this out.
                modelToUpdate: model,
                identityModel: OneSignalUserManagerImpl.user.identityModel // TODO: Make sure this is ok
            )
            enqueueRequest(request)
        }
        self.deltaQueue = [] // TODO: Check that we can simply clear all the deltas in the deltaQueue

        // persist executor's requests (including new request) to storage
        OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_PROPERTIES_EXECUTOR_REQUEST_QUEUE_KEY, withValue: self.requestQueue)

        OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_PROPERTIES_EXECUTOR_DELTA_QUEUE_KEY, withValue: self.deltaQueue) // This should be empty, can remove instead?
        processRequestQueue()
    }

    func enqueueRequest(_ request: OneSignalRequest) {
        print("🔥 OSPropertyOperationExecutor enqueueRequest: \(request)")
        requestQueue.append(request)
    }

    func processRequestQueue() {
        if requestQueue.isEmpty {
            return
        }

        for request in requestQueue {
            if let updatePropertiesRequest = request as? OSRequestUpdateProperties {
                executeUpdatePropertiesRequest(updatePropertiesRequest)
            }
        }
    }

    func executeUpdatePropertiesRequest(_ request: OSRequestUpdateProperties) {
        guard request.prepareForExecution() else {
            return
        }
        print("🔥 OSPropertyOperationExecutor: executeUpdatePropertiesRequest making request: \(request)")
        OneSignalClient.shared().execute(request) { result in
            print("🔥 OSPropertyOperationExecutor executed request SUCCESS block: \(result)")
            // Mock a response
            let response = ["language": "en"]

            // On success, remove request from cache, and hydrate model
            // For example, if app restarts and we read in operations between sending this off and getting the response
            self.requestQueue.removeAll(where: { $0 == request})
            OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_PROPERTIES_EXECUTOR_REQUEST_QUEUE_KEY, withValue: self.requestQueue)

            request.modelToUpdate.hydrate(response)

        } onFailure: { error in
            print("🔥 OSPropertyOperationExecutor executed request ERROR block: \(error)")
            // On failure, retry logic, but order of operations matters
        }
    }
}
