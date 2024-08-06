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

import XCTest
import OneSignalCore
import OneSignalCoreMocks
import OneSignalUserMocks
// Testable import OSCore to allow setting a different poll flush interval
@testable import OneSignalOSCore
@testable import OneSignalUser

final class UserConcurrencyTests: XCTestCase {

    override func setUpWithError() throws {
        // TODO: Something like the existing [UnitTestCommonMethods beforeEachTest:self];
        // TODO: Need to clear all data between tests for client, user manager, models, etc.
        OneSignalCoreMocks.clearUserDefaults()
        OneSignalUserMocks.reset()
        // App ID is set because User Manager has guards against nil App ID
        OneSignalConfigManager.setAppId("test-app-id")
        // Temp. logging to help debug during testing
        OneSignalLog.setLogLevel(.LL_VERBOSE)
    }

    override func tearDownWithError() throws { }

    /**
     This test reproduces a crash in the Operation Repo's flushing delta queue.
     It is possible for two threads to flush concurrently.
     However, this test does not crash 100% of the time.
     */
    func testOperationRepoFlushingConcurrency() throws {
        /* Setup */
        OneSignalCoreImpl.setSharedClient(MockOneSignalClient())

        /* When */

        // 1. Enqueue 10 Deltas to the Operation Repo
        for num in 0...9 {
            OneSignalUserManagerImpl.sharedInstance.addTag(key: "tag\(num)", value: "value")
        }

        // 2. Flush the delta queue from 4 multiple threads
        for _ in 1...4 {
            DispatchQueue.global().async {
                print("🧪 flushDeltaQueue on thread \(Thread.current)")
                OSOperationRepo.sharedInstance.addFlushDeltaQueueToDispatchQueue()
            }
        }

        /* Then */
        // There are two places that can crash, as multiple threads are manipulating arrays:
        // 1. OpRepo: `deltaQueue.remove(at: index)` index out of bounds
        // 2. OSPropertyOperationExecutor: `deltaQueue.append(delta)` EXC_BAD_ACCESS
    }

    /**
     This test reproduces a crash in the Subscription Executor.
     It is possible for two threads to modify and cache queues concurrently.
     */
    func testSubscriptionExecutorConcurrency() throws {
        /* Setup */

        let client = MockOneSignalClient()
        client.setMockResponseForRequest(
            request: "<OSRequestDeleteSubscription with subscriptionModel: nil>",
            response: [:]
        )
        OneSignalCoreImpl.setSharedClient(client)

        let executor = OSSubscriptionOperationExecutor()
        OSOperationRepo.sharedInstance.addExecutor(executor)

        /* When */

        DispatchQueue.concurrentPerform(iterations: 50) { _ in
            // 1. Enqueue Remove Subscription Deltas to the Operation Repo
            OSOperationRepo.sharedInstance.enqueueDelta(OSDelta(name: OS_REMOVE_SUBSCRIPTION_DELTA, identityModelId: UUID().uuidString, model: OSSubscriptionModel(type: .email, address: nil, subscriptionId: UUID().uuidString, reachable: true, isDisabled: false, changeNotifier: OSEventProducer()), property: "email", value: "email"))
            OSOperationRepo.sharedInstance.enqueueDelta(OSDelta(name: OS_REMOVE_SUBSCRIPTION_DELTA, identityModelId: UUID().uuidString, model: OSSubscriptionModel(type: .email, address: nil, subscriptionId: UUID().uuidString, reachable: true, isDisabled: false, changeNotifier: OSEventProducer()), property: "email", value: "email"))

            // 2. Flush Operation Repo
            OSOperationRepo.sharedInstance.addFlushDeltaQueueToDispatchQueue()

            // 3. Simulate updating the executor's request queue from a network response
            executor.executeDeleteSubscriptionRequest(OSRequestDeleteSubscription(subscriptionModel: OSSubscriptionModel(type: .email, address: nil, subscriptionId: UUID().uuidString, reachable: true, isDisabled: false, changeNotifier: OSEventProducer())), inBackground: false)
            executor.executeDeleteSubscriptionRequest(OSRequestDeleteSubscription(subscriptionModel: OSSubscriptionModel(type: .email, address: nil, subscriptionId: UUID().uuidString, reachable: true, isDisabled: false, changeNotifier: OSEventProducer())), inBackground: false)
        }

        // 4. Run background threads
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)

        /* Then */
        // Previously caused crash: signal SIGABRT - malloc: double free for ptr
        // Assert that every request SDK makes has a response set, and is handled
        XCTAssertTrue(client.allRequestsHandled)
    }

    /**
     This test reproduces a crash in the Identity Executor.
     It is possible for two threads to modify and cache queues concurrently.
     */
    func testIdentityExecutorConcurrency() throws {
        /* Setup */
        let client = MockOneSignalClient()
        let aliases = [UUID().uuidString: "id"]

        OneSignalCoreImpl.setSharedClient(client)
        MockUserRequests.setAddAliasesResponse(with: client, aliases: aliases)

        let executor = OSIdentityOperationExecutor()
        OSOperationRepo.sharedInstance.addExecutor(executor)

        /* When */

        DispatchQueue.concurrentPerform(iterations: 50) { _ in
            // 1. Enqueue Add Alias Deltas to the Operation Repo
            OSOperationRepo.sharedInstance.enqueueDelta(OSDelta(name: OS_ADD_ALIAS_DELTA, identityModelId: UUID().uuidString, model: OSIdentityModel(aliases: [OS_ONESIGNAL_ID: UUID().uuidString], changeNotifier: OSEventProducer()), property: "aliases", value: aliases))
            OSOperationRepo.sharedInstance.enqueueDelta(OSDelta(name: OS_ADD_ALIAS_DELTA, identityModelId: UUID().uuidString, model: OSIdentityModel(aliases: [OS_ONESIGNAL_ID: UUID().uuidString], changeNotifier: OSEventProducer()), property: "aliases", value: aliases))

            // 2. Flush Operation Repo
            OSOperationRepo.sharedInstance.addFlushDeltaQueueToDispatchQueue()

            // 3. Simulate updating the executor's request queue from a network response
            executor.executeAddAliasesRequest(OSRequestAddAliases(aliases: aliases, identityModel: OSIdentityModel(aliases: [OS_ONESIGNAL_ID: UUID().uuidString], changeNotifier: OSEventProducer())), inBackground: false)
            executor.executeAddAliasesRequest(OSRequestAddAliases(aliases: aliases, identityModel: OSIdentityModel(aliases: [OS_ONESIGNAL_ID: UUID().uuidString], changeNotifier: OSEventProducer())), inBackground: false)
        }

        // 4. Run background threads
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)

        /* Then */
        // Previously caused crash: signal SIGABRT - malloc: double free for ptr
        // Assert that every request SDK makes has a response set, and is handled
        XCTAssertTrue(client.allRequestsHandled)
    }

    /**
     This test aims to ensure concurrency safety in the Property Executor.
     It is possible for two threads to modify and cache queues concurrently.
     */
    func testPropertyExecutorConcurrency() throws {
        /* Setup */
        let client = MockOneSignalClient()
        // Ensure all requests fire the executor's callback so it will modify queues and cache it
        client.fireSuccessForAllRequests = true
        OneSignalCoreImpl.setSharedClient(client)

        let identityModel = OSIdentityModel(aliases: [OS_ONESIGNAL_ID: UUID().uuidString], changeNotifier: OSEventProducer())
        OneSignalUserManagerImpl.sharedInstance.addIdentityModelToRepo(identityModel)

        let executor = OSPropertyOperationExecutor()
        OSOperationRepo.sharedInstance.addExecutor(executor)

        /* When */

        DispatchQueue.concurrentPerform(iterations: 50) { _ in
            // 1. Enqueue Deltas to the Operation Repo
            OSOperationRepo.sharedInstance.enqueueDelta(OSDelta(name: OS_UPDATE_PROPERTIES_DELTA, identityModelId: identityModel.modelId, model: OSPropertiesModel(changeNotifier: OSEventProducer()), property: "language", value: UUID().uuidString))
            OSOperationRepo.sharedInstance.enqueueDelta(OSDelta(name: OS_UPDATE_PROPERTIES_DELTA, identityModelId: identityModel.modelId, model: OSPropertiesModel(changeNotifier: OSEventProducer()), property: "language", value: UUID().uuidString))

            // 2. Flush Operation Repo
            OSOperationRepo.sharedInstance.addFlushDeltaQueueToDispatchQueue()

            // 3. Simulate updating the executor's request queue from a network response
            executor.executeUpdatePropertiesRequest(OSRequestUpdateProperties(params: ["properties": ["language": UUID().uuidString], "refresh_device_metadata": false], identityModel: identityModel), inBackground: false)
        }

        // 4. Run background threads
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)

        /* Then */
        // No crash
    }

    /**
     This test aims to ensure concurrency safety in the User Executor.
     It is possible for two threads to modify and cache queues concurrently.
     Currently, this executor only allows one request to send at a time, which should prevent concurrent access.
     But out of caution and future-proofing, this test is added.
     */
    func testUserExecutorConcurrency() throws {
        /* Setup */

        let client = MockOneSignalClient()
        // Ensure all requests fire the executor's callback so it will modify queues and cache it
        client.fireSuccessForAllRequests = true
        OneSignalCoreImpl.setSharedClient(client)

        let identityModel1 = OSIdentityModel(aliases: [OS_ONESIGNAL_ID: UUID().uuidString], changeNotifier: OSEventProducer())
        let identityModel2 = OSIdentityModel(aliases: [OS_ONESIGNAL_ID: UUID().uuidString], changeNotifier: OSEventProducer())

        let userExecutor = OSUserExecutor()

        /* When */

        DispatchQueue.concurrentPerform(iterations: 50) { _ in
            let identifyRequest = OSRequestIdentifyUser(aliasLabel: OS_EXTERNAL_ID, aliasId: UUID().uuidString, identityModelToIdentify: identityModel1, identityModelToUpdate: identityModel2)
            let fetchRequest = OSRequestFetchUser(identityModel: identityModel1, aliasLabel: OS_ONESIGNAL_ID, aliasId: UUID().uuidString, onNewSession: false)

            // Append and execute requests simultaneously
            userExecutor.appendToQueue(identifyRequest)
            userExecutor.appendToQueue(fetchRequest)
            userExecutor.executeIdentifyUserRequest(identifyRequest)
            userExecutor.executeFetchUserRequest(fetchRequest)
        }

        // Run background threads
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)

        /* Then */
        // No crash
    }

    /**
     This test reproduced a crash when the property model is being encoded.
     */
    func testEncodingPropertiesModel_withConcurrency_doesNotCrash() throws {
        /* Setup */
        let propertiesModel = OSPropertiesModel(changeNotifier: OSEventProducer())

        /* When */
        DispatchQueue.concurrentPerform(iterations: 5_000) { i in
            // 1. Add tags
            for num in 0...9 {
                propertiesModel.addTags(["\(i)tag\(num)": "value"])
            }

            // 2. Encode the model
            OneSignalUserDefaults.initShared().saveCodeableData(forKey: "PropertyModel", withValue: propertiesModel)

            // 3. Clear the tags
            propertiesModel.clearData()
        }
    }

    /**
     This test reproduced a crash when the identity model is being encoded.
     */
    func testEncodingIdentityModel_withConcurrency_doesNotCrash() throws {
        /* Setup */
        let identityModel = OSIdentityModel(aliases: nil, changeNotifier: OSEventProducer())

        /* When */
        DispatchQueue.concurrentPerform(iterations: 5_000) { i in
            // 1. Add aliases
            for num in 0...9 {
                identityModel.addAliases(["\(i)alias\(num)": "value"])
            }

            // 2. Encode the model
            OneSignalUserDefaults.initShared().saveCodeableData(forKey: "IdentityModel", withValue: identityModel)

            // 2. Clear the aliases
            identityModel.clearData()
        }
    }
}
