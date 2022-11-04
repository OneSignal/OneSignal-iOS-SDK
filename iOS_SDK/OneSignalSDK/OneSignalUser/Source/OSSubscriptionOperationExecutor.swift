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

class OSSubscriptionOperationExecutor: OSOperationExecutor {
    var supportedDeltas: [String] = [OS_ADD_SUBSCRIPTION_DELTA, OS_REMOVE_SUBSCRIPTION_DELTA, OS_UPDATE_SUBSCRIPTION_DELTA]
    var deltaQueue: [OSDelta] = []
    var requestQueue: [OneSignalRequest] = []

    init() {
        // Read unfinished deltas and requests from cache, if any...

        if let deltaQueue = OneSignalUserDefaults.initShared().getSavedCodeableData(forKey: OS_SUBSCRIPTION_EXECUTOR_DELTA_QUEUE_KEY, defaultValue: []) as? [OSDelta] {
            self.deltaQueue = deltaQueue
        } else {
            // log error
        }

        if let requestQueue = OneSignalUserDefaults.initShared().getSavedCodeableData(forKey: OS_SUBSCRIPTION_EXECUTOR_REQUEST_QUEUE_KEY, defaultValue: []) as? [OneSignalRequest] {
            self.requestQueue = requestQueue
        } else {
            // log error
        }
    }

    func enqueueDelta(_ delta: OSDelta) {
        print("🔥 OSSubscriptionOperationExecutor enqueueDelta: \(delta)")
        deltaQueue.append(delta)
    }

    func cacheDeltaQueue() {
        OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_SUBSCRIPTION_EXECUTOR_DELTA_QUEUE_KEY, withValue: self.deltaQueue)
    }

    func processDeltaQueue() {
        if deltaQueue.isEmpty {
            return
        }

        for delta in deltaQueue {
            guard let model = delta.model as? OSSubscriptionModel else {
                // Log error
                continue
            }

            switch delta.name {
            case OS_ADD_SUBSCRIPTION_DELTA:
                let request = OSRequestCreateSubscription(
                    subscriptionModel: model,
                    identityModel: OneSignalUserManagerImpl.user.identityModel // TODO: Make sure this is ok
                )
                enqueueRequest(request)

            case OS_REMOVE_SUBSCRIPTION_DELTA:
                let request = OSRequestDeleteSubscription(
                    subscriptionModel: model
                )
                enqueueRequest(request)

            case OS_UPDATE_SUBSCRIPTION_DELTA:
                let request = OSRequestUpdateSubscription(
                    subscriptionObject: [delta.property: delta.value],
                    subscriptionModel: model
                )
                enqueueRequest(request)

            default:
                // Log error
                print("🔥 OSSubscriptionOperationExecutor met incompatible OSDelta type.")
            }
        }

        self.deltaQueue = [] // TODO: Check that we can simply clear all the deltas in the deltaQueue

        // persist executor's requests (including new request) to storage
        OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_SUBSCRIPTION_EXECUTOR_REQUEST_QUEUE_KEY, withValue: self.requestQueue)

        OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_SUBSCRIPTION_EXECUTOR_DELTA_QUEUE_KEY, withValue: self.deltaQueue) // This should be empty, can remove instead?

        processRequestQueue()
    }

    func enqueueRequest(_ request: OneSignalRequest) {
        print("🔥 OSSubscriptionOperationExecutor enqueueRequest: \(request)")
        requestQueue.append(request)
    }

    func processRequestQueue() {
        if requestQueue.isEmpty {
            return
        }

        for request in requestQueue {
            if request.isKind(of: OSRequestCreateSubscription.self), let createSubscriptionRequest = request as? OSRequestCreateSubscription {
                executeCreateSubscriptionRequest(createSubscriptionRequest)
            } else if request.isKind(of: OSRequestDeleteSubscription.self), let deleteSubscriptionRequest = request as? OSRequestDeleteSubscription {
                executeDeleteSubscriptionRequest(deleteSubscriptionRequest)
            } else if request.isKind(of: OSRequestUpdateSubscription.self), let updateSubscriptionRequest = request as? OSRequestUpdateSubscription {
                executeUpdateSubscriptionRequest(updateSubscriptionRequest)
            } else {
                // Log Error
            }
        }
    }

    func executeCreateSubscriptionRequest(_ request: OSRequestCreateSubscription) {
        guard request.prepareForExecution() else {
            return
        }
        print("🔥 OSSubscriptionOperationExecutor: executeCreateSubscriptionRequest making request: \(request)")
        OneSignalClient.shared().execute(request) { result in
            print("🔥 OSSubscriptionOperationExecutor executed request SUCCESS block: \(result)")

            // Mock a response
            let response = ["id": UUID().uuidString, "type": "SMS", "enabled": "true"]

            // On success, remove request from cache, and hydrate model
            // For example, if app restarts and we read in operations between sending this off and getting the response
            self.requestQueue.removeAll(where: { $0 == request})
            OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_SUBSCRIPTION_EXECUTOR_REQUEST_QUEUE_KEY, withValue: self.requestQueue)
            request.subscriptionModel.hydrate(response)

        } onFailure: { error in
            print("🔥 OSSubscriptionOperationExecutor executed request ERROR block: \(error)")
            // On failure, retry logic, but order of operations matters
        }
    }

    func executeDeleteSubscriptionRequest(_ request: OSRequestDeleteSubscription) {
        guard request.prepareForExecution() else {
            return
        }

        // This request can be executed as-is.
        print("🔥 OSSubscriptionOperationExecutor: executeDeleteSubscriptionRequest making request: \(request)")
        OneSignalClient.shared().execute(request) { result in
            print("🔥 OSSubscriptionOperationExecutor executed request SUCCESS block: \(result)")

            // On success, remove request from cache. No model hydration occurs.
            // For example, if app restarts and we read in operations between sending this off and getting the response
            self.requestQueue.removeAll(where: { $0 == request})
            OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_SUBSCRIPTION_EXECUTOR_REQUEST_QUEUE_KEY, withValue: self.requestQueue)

        } onFailure: { error in
            print("🔥 OSSubscriptionOperationExecutor executed request ERROR block: \(error)")
            // On failure, retry logic, but order of operations matters
        }
    }

    func executeUpdateSubscriptionRequest(_ request: OSRequestUpdateSubscription) {
        print("🔥 OSSubscriptionOperationExecutor: executeUpdateSubscriptionRequest making request: \(request)")
        OneSignalClient.shared().execute(request) { result in
            print("🔥 OSSubscriptionOperationExecutor executed request SUCCESS block: \(result)")

            // On success, remove request from cache. No model hydration occurs.
            // For example, if app restarts and we read in operations between sending this off and getting the response
            self.requestQueue.removeAll(where: { $0 == request})
            OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_SUBSCRIPTION_EXECUTOR_REQUEST_QUEUE_KEY, withValue: self.requestQueue)

        } onFailure: { error in
            print("🔥 OSSubscriptionOperationExecutor executed request ERROR block: \(error)")
            // On failure, retry logic, but order of operations matters
        }
    }
}
