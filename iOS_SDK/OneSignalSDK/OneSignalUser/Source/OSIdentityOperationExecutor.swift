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

class OSIdentityOperationExecutor: OSOperationExecutor {
    var supportedDeltas: [String] = [OS_ADD_ALIAS_DELTA, OS_REMOVE_ALIAS_DELTA]
    var deltaQueue: [OSDelta] = []
    var requestQueue: [OneSignalRequest] = []

    init() {
        // Read unfinished deltas and requests from cache, if any...

        if let deltaQueue = OneSignalUserDefaults.initShared().getSavedCodeableData(forKey: OS_IDENTITY_EXECUTOR_DELTA_QUEUE_KEY, defaultValue: []) as? [OSDelta] {
            self.deltaQueue = deltaQueue
        } else {
            // log error
        }

        if let requestQueue = OneSignalUserDefaults.initShared().getSavedCodeableData(forKey: OS_IDENTITY_EXECUTOR_REQUEST_QUEUE_KEY, defaultValue: []) as? [OneSignalRequest] {
            self.requestQueue = requestQueue
        } else {
            // log error
        }
    }

    func enqueueDelta(_ delta: OSDelta) {
        print("🔥 OSIdentityOperationExecutor enqueueDelta: \(delta)")
        deltaQueue.append(delta)
    }

    func cacheDeltaQueue() {
        OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_IDENTITY_EXECUTOR_DELTA_QUEUE_KEY, withValue: self.deltaQueue)
    }

    func processDeltaQueue() {
        for delta in deltaQueue {
            guard let model = delta.model as? OSIdentityModel,
                  let aliases = delta.value as? [String: String]
            else {
                // Log error
                continue
            }

            switch delta.name {
            case OS_ADD_ALIAS_DELTA:
                let request = OSRequestAddAliases(aliases: aliases, identityModel: model)
                enqueueRequest(request)

            case OS_REMOVE_ALIAS_DELTA:
                if let label = aliases.first?.key {
                    let request = OSRequestRemoveAlias(labelToRemove: label, identityModel: model)
                    enqueueRequest(request)
                }
                // Log error

            default:
                // Log error
                print("🔥 OSIdentityOperationExecutor met incompatible OSDelta type.")
            }
        }

        self.deltaQueue = [] // TODO: Check that we can simply clear all the deltas in the deltaQueue

        // persist executor's requests (including new request) to storage
        OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_IDENTITY_EXECUTOR_REQUEST_QUEUE_KEY, withValue: self.requestQueue)

        OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_IDENTITY_EXECUTOR_DELTA_QUEUE_KEY, withValue: self.deltaQueue) // This should be empty, can remove instead?

        processRequestQueue()
    }

    func enqueueRequest(_ request: OneSignalRequest) {
        print("🔥 OSIdentityOperationExecutor enqueueRequest: \(request)")
        requestQueue.append(request)
    }

    func processRequestQueue() {
        if requestQueue.isEmpty {
            return
        }

        for request in requestQueue {
            if request.isKind(of: OSRequestAddAliases.self), let addAliasesRequest = request as? OSRequestAddAliases {
                executeAddAliasesRequest(addAliasesRequest)
            } else if request.isKind(of: OSRequestRemoveAlias.self), let removeAliasRequest = request as? OSRequestRemoveAlias {
                executeRemoveAliasRequest(removeAliasRequest)
            } else {
                // Log Error
            }
        }
    }

    func executeAddAliasesRequest(_ request: OSRequestAddAliases) {
        print("🔥 OSIdentityOperationExecutor: executeAddAliasesRequest making request: \(request)")
        OneSignalClient.shared().execute(request) { result in
            // Mock a response
            let response = ["onesignalId": UUID().uuidString, "label01": "id01"]

            // On success, remove request from cache, and hydrate model
            // For example, if app restarts and we read in operations between sending this off and getting the response
            self.requestQueue.removeAll(where: { $0 == request})
            OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_IDENTITY_EXECUTOR_REQUEST_QUEUE_KEY, withValue: self.requestQueue)

            // instead: modelstore.hydratewithresponse with modelid passed in.. request.modeltoupdate.modelId
                // store can determine if modelid is same, then hydrate or do nothign
            request.identityModel.hydrate(response)

        } onFailure: { error in
            self.requestQueue.removeAll(where: { $0 == request})
            OneSignalLog.onesignalLog(.LL_ERROR, message: error.debugDescription)
        }
    }

    func executeRemoveAliasRequest(_ request: OSRequestRemoveAlias) {
        print("🔥 OSIdentityOperationExecutor: executeRemoveAliasRequest making request: \(request)")
        OneSignalClient.shared().execute(request) { result in

            // Mock a response
            let response = ["onesignalId": UUID().uuidString, "label01": "id01"]

            // On success, remove request from cache, and hydrate model
            // For example, if app restarts and we read in operations between sending this off and getting the response
            self.requestQueue.removeAll(where: { $0 == request})
            OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_IDENTITY_EXECUTOR_REQUEST_QUEUE_KEY, withValue: self.requestQueue)

            request.identityModel.hydrate(response)

        } onFailure: { error in
            self.requestQueue.removeAll(where: { $0 == request})
            OneSignalLog.onesignalLog(.LL_ERROR, message: error.debugDescription)
        }
    }
}
