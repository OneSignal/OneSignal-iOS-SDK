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
import OneSignalOSCore
@testable import OneSignalUser

final class OneSignalUserTests: XCTestCase {

    override func setUpWithError() throws {
        // TODO: Something like the existing [UnitTestCommonMethods beforeEachTest:self];
        // App ID is set because User Manager has guards against nil App ID
        OneSignalConfigManager.setAppId("test-app-id")
        // Temp. logging to help debug during testing
        OneSignalLog.setLogLevel(.LL_VERBOSE)
    }

    override func tearDownWithError() throws {
        // TODO: Need to clear all data between tests for client, user manager, models, etc.
        OneSignalCoreMocks.clearUserDefaults()
        OneSignalUserMocks.reset()
    }

    // Comparable to Android test: "externalId is backed by the identity model"
    func testLoginSetsExternalId() throws {
        /* Setup */
        OneSignalCoreImpl.setSharedClient(MockOneSignalClient())

        /* When */
        OneSignalUserManagerImpl.sharedInstance.login(externalId: "my-external-id", token: nil)

        /* Then */
        let identityModelStoreExternalId = OneSignalUserManagerImpl.sharedInstance.identityModelStore.getModel(key: OS_IDENTITY_MODEL_KEY)?.externalId
        let userInstanceExternalId = OneSignalUserManagerImpl.sharedInstance.user.identityModel.externalId

        XCTAssertEqual(identityModelStoreExternalId, "my-external-id")
        XCTAssertEqual(userInstanceExternalId, "my-external-id")
    }

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

    func testSwitchUser_sendsCorrectTags() throws {
        /* Setup */

        let client = MockOneSignalClient()

        // 1. Set up mock responses for the anonymous user
        let anonCreateResponse = MockUserRequests.testIdentityPayload(onesignalId: anonUserOSID, externalId: nil)

        client.setMockResponseForRequest(
            request: "<OSRequestCreateUser with externalId: nil>",
            response: anonCreateResponse)

        // 2. Set up mock responses for User A
        let tagsUserA = ["tag_a": "value_a"]
        let createUserA = MockUserRequests.testIdentityPayload(onesignalId: userA_OSID, externalId: userA_EUID)
        let tagsResponseUserA = MockUserRequests.testPropertiesPayload(properties: ["tags": tagsUserA])

        client.setMockResponseForRequest(
            request: "<OSRequestIdentifyUser with aliasLabel: external_id aliasId: \(userA_EUID)>",
            response: createUserA
        )
        client.setMockResponseForRequest(
            request: "<OSRequestFetchUser with aliasLabel: external_id aliasId: \(userA_EUID)>",
            response: createUserA
        )
        client.setMockResponseForRequest(
            request: "<OSRequestUpdateProperties with properties: [\"tags\": \(tagsUserA)] deltas: nil refreshDeviceMetadata: false>",
            response: tagsResponseUserA
        )

        // 3. Set up mock responses for User B
        let tagsUserB = ["tag_b": "value_b"]
        let createUserB = MockUserRequests.testIdentityPayload(onesignalId: userB_OSID, externalId: userB_EUID)
        let tagsResponseUserB = MockUserRequests.testPropertiesPayload(properties: ["tags": tagsUserB])

        client.setMockResponseForRequest(
            request: "<OSRequestCreateUser with externalId: \(userB_EUID)>",
            response: createUserB
        )
        client.setMockResponseForRequest(
            request: "<OSRequestFetchUser with aliasLabel: external_id aliasId: \(userB_EUID)>",
            response: createUserB
        )
        client.setMockResponseForRequest(
            request: "<OSRequestUpdateProperties with properties: [\"tags\": \(tagsUserB)] deltas: nil refreshDeviceMetadata: false>",
            response: tagsResponseUserB)

        OneSignalCoreImpl.setSharedClient(client)

        /* When */

        // 1. Login to user A and add tag
        OneSignalUserManagerImpl.sharedInstance.login(externalId: userA_EUID, token: nil)
        OneSignalUserManagerImpl.sharedInstance.addTag(key: "tag_a", value: "value_a")

        // 2. Login to user B and add tag
        OneSignalUserManagerImpl.sharedInstance.login(externalId: userB_EUID, token: nil)
        OneSignalUserManagerImpl.sharedInstance.addTag(key: "tag_b", value: "value_b")

        // 3. Run background threads
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)

        /* Then */

        // Assert that every request SDK makes has a response set, and is handled
        XCTAssertTrue(client.allRequestsHandled)

        // Assert there is only one request containing these tags and they are sent to userA
        XCTAssertTrue(client.onlyOneRequest(
            contains: "apps/test-app-id/users/by/onesignal_id/\(userA_OSID)",
            contains: ["properties": ["tags": tagsUserA]])
        )
        // Assert there is only one request containing these tags and they are sent to userB
        XCTAssertTrue(client.onlyOneRequest(
            contains: "apps/test-app-id/users/by/onesignal_id/\(userB_OSID)",
            contains: ["properties": ["tags": tagsUserB]])
        )
    }
}
