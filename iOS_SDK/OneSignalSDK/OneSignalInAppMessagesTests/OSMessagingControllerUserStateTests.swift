/*
 Modified MIT License
 
 Copyright 2025 OneSignal
 
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
import OneSignalOSCore
import OneSignalCoreMocks
import OneSignalOSCoreMocks
import OneSignalUserMocks
@testable import OneSignalUser

/**
 Tests for OSMessagingController's user state observer functionality.
 
 These tests verify that IAM fetching is retried when the OneSignal ID becomes available
 after an initial fetch attempt fails due to missing OneSignal ID during early app startup.
 
 Related to PR: https://github.com/OneSignal/OneSignal-iOS-SDK/pull/1626
 */
final class OSMessagingControllerUserStateTests: XCTestCase {

    private let testSubscriptionId = "test-subscription-id-12345"
    private let testOneSignalId = "test-onesignal-id-12345"
    private let testExternalId = "test-external-id-12345"
    private let testAppId = "test-app-id"

    override func setUpWithError() throws {
        OneSignalCoreMocks.clearUserDefaults()
        OneSignalUserMocks.reset()
        ConsistencyManagerTestHelpers.reset()
        OSMessagingController.removeInstance()

        // Set up basic configuration
        OneSignalIdentifiers.currentAppId = testAppId
        OneSignalLog.setLogLevel(.LL_VERBOSE)
    }

    override func tearDownWithError() throws {
        OSFeatureManager.shared.setEnabledFeatureKeys([])
        OSMessagingController.removeInstance()
    }

    /**
     Test that when getInAppMessagesFromServer is called without a OneSignal ID, it stores the subscription ID for later retry.
     
     Scenario:
     - User calls initialize() and login() early in app startup
     - Push subscription ID is available but OneSignal ID is not yet set
     - IAM fetch should be deferred
     
     Expected:
     - deferredFetchSubscriptionId property is set with the subscription ID
     - No IAM fetch actually occurs
     */
    func testStoresSubscriptionIDWhenOneSignalIDUnavailable() throws {
        /* Setup */
        let client = MockOneSignalClient()
        OneSignalCoreImpl.setSharedClient(client)

        // Note: nothing has set OneSignal ID

        /* Execute */
        OneSignalInAppMessages.getFromServer(testSubscriptionId)
        OneSignalCoreMocks.waitUntil("Deferred IAM subscription ID was not stored") {
            OSMessagingController.sharedInstance().deferredFetchSubscriptionId == self.testSubscriptionId
        }

        /* Verify */
        // The controller should have stored the subscription ID for retry
        XCTAssertEqual(OSMessagingController.sharedInstance().deferredFetchSubscriptionId, testSubscriptionId)

        // Verify no IAM request was actually made (since we don't have OneSignal ID)
        XCTAssertTrue(client.hasExecutedRequestOfType(OSRequestGetInAppMessages.self, expectedCount: 0))
    }

    /**
     Test that when user state changes with a valid OneSignal ID and deferredFetchSubscriptionId is set, it retries the fetch.
     
     Scenario:
     - IAM fetch was previously deferred due to missing OneSignal ID
     - User response is returned and OneSignal ID becomes available
     - User state change observer is triggered
     
     Expected:
     - IAM fetch is retried with the stored subscription ID
     - deferredFetchSubscriptionId is cleared
     */
    func testRetriesFetchWhenUserStateChangesWithValidOneSignalID() throws {
        /* Setup */
        let client = MockOneSignalClient()
        OneSignalCoreImpl.setSharedClient(client)
        OSMessagingController.start()
        let controller = OSMessagingController.sharedInstance()

        // Unblock consistency manager
        ConsistencyManagerTestHelpers.setDefaultRywToken(id: testOneSignalId)

        /* Execute */
        // Setup the anonymous user
        MockUserRequests.setDefaultCreateAnonUserResponses(with: client, onesignalId: testOneSignalId, subscriptionId: testSubscriptionId)
        OneSignalUserManagerImpl.sharedInstance.start()

        // Login to a new user, without setting the client response, so onesignal ID is not hydrated
        OneSignalUserManagerImpl.sharedInstance.login(externalId: testExternalId, token: nil)

        // First attempt: Try to fetch IAMs without OneSignal ID (should be deferred)
        OneSignalInAppMessages.getFromServer(testSubscriptionId)
        OneSignalCoreMocks.waitUntil("Deferred IAM subscription ID was not stored") {
            controller.deferredFetchSubscriptionId == self.testSubscriptionId
        }

        // Verify the subscription ID was stored and no IAM fetch occurred
        XCTAssertEqual(controller.deferredFetchSubscriptionId, testSubscriptionId)
        XCTAssertTrue(client.hasExecutedRequestOfType(OSRequestGetInAppMessages.self, expectedCount: 0))

        // Now let the login succeed, receive onesignal ID which fires user state observer
        MockUserRequests.setDefaultIdentifyUserResponses(with: client, externalId: testExternalId)
        OneSignalUserManagerImpl.sharedInstance.userExecutor?.userRequestQueue.first?.sentToClient = false
        OneSignalUserManagerImpl.sharedInstance.userExecutor?.executePendingRequests()
        OneSignalCoreMocks.waitUntil("Deferred IAM fetch was not retried") {
            client.hasCompletedRequestOfType(OSRequestGetInAppMessages.self)
                && controller.deferredFetchSubscriptionId == nil
        }

        /* Verify */
        // The fetch should have been retried now that OneSignal ID is available
        XCTAssertTrue(client.hasExecutedRequestOfType(OSRequestGetInAppMessages.self, expectedCount: 1))

        // The stored subscription ID should be cleared after successful retry
        XCTAssertNil(controller.deferredFetchSubscriptionId)
    }

    /**
     Test that logging in refetches in-app messages for the user signing in.

     Scenario:
     - Identity Verification code paths are on
     - A user's in-app messages have already been fetched
     - The app logs in as someone else

     Expected:
     - A second fetch goes out once the new user has a OneSignal ID, so the previous user's messages are
       not what gets evaluated
     */
    func testLoginRefetchesInAppMessagesForTheIncomingUser() throws {
        /* Setup */
        OSFeatureManager.shared.setEnabledFeatureKeys([OSFeatureFlag.identityVerification.rawValue])
        let client = MockOneSignalClient()
        OneSignalCoreImpl.setSharedClient(client)
        OneSignalInAppMessages.start()
        let controller = OSMessagingController.sharedInstance()

        // Set up user with valid OneSignal ID from the start
        MockUserRequests.setDefaultCreateAnonUserResponses(
            with: client,
            onesignalId: testOneSignalId,
            subscriptionId: testSubscriptionId
        )
        ConsistencyManagerTestHelpers.setDefaultRywToken(id: testOneSignalId)
        OneSignalUserManagerImpl.sharedInstance.start()
        OneSignalCoreMocks.waitUntil("Initial IAM fetch did not complete") {
            client.hasCompletedRequestOfType(OSRequestGetInAppMessages.self)
        }

        /* Verify */
        // IAM is fetched and no retry is pending
        XCTAssertTrue(client.hasExecutedRequestOfType(OSRequestGetInAppMessages.self, expectedCount: 1))
        XCTAssertNil(controller.deferredFetchSubscriptionId)

        /* Execute */
        MockUserRequests.setDefaultIdentifyUserResponses(with: client, externalId: testExternalId)
        OneSignalUserManagerImpl.sharedInstance.login(externalId: testExternalId, token: nil)
        OneSignalCoreMocks.waitUntil("IAM fetch for the incoming user did not complete") {
            client.hasCompletedRequestOfType(OSRequestGetInAppMessages.self, expectedCount: 2)
        }

        /* Verify */
        XCTAssertTrue(client.hasExecutedRequestOfType(OSRequestGetInAppMessages.self, expectedCount: 2))
        XCTAssertNil(controller.deferredFetchSubscriptionId)
    }

    /// Without the rollout flag or `jwt_required`, a login leaves the current user's messages as they were.
    func testLoginDoesNotRefetchInAppMessagesWhenIdentityVerificationCodePathsAreOff() throws {
        let client = MockOneSignalClient()
        OneSignalCoreImpl.setSharedClient(client)
        OneSignalInAppMessages.start()
        let controller = OSMessagingController.sharedInstance()

        MockUserRequests.setDefaultCreateAnonUserResponses(
            with: client,
            onesignalId: testOneSignalId,
            subscriptionId: testSubscriptionId
        )
        ConsistencyManagerTestHelpers.setDefaultRywToken(id: testOneSignalId)
        OneSignalUserManagerImpl.sharedInstance.start()
        OneSignalCoreMocks.waitUntil("Initial IAM fetch did not complete") {
            client.hasCompletedRequestOfType(OSRequestGetInAppMessages.self, expectedCount: 1)
        }

        XCTAssertTrue(client.hasExecutedRequestOfType(OSRequestGetInAppMessages.self, expectedCount: 1))

        MockUserRequests.setDefaultIdentifyUserResponses(with: client, externalId: testExternalId)
        OneSignalUserManagerImpl.sharedInstance.login(externalId: testExternalId, token: nil)
        // The claim is that no second fetch follows, so wait for the login to run out of work rather
        // than for a fetch that should never arrive.
        OneSignalCoreMocks.waitUntil("The login left a Request in flight") {
            client.hasCompletedRequestOfType(OSRequestIdentifyUser.self)
                && client.completedRequests.count == client.startedRequests.count
        }

        XCTAssertTrue(client.hasExecutedRequestOfType(OSRequestGetInAppMessages.self, expectedCount: 1))
        XCTAssertNil(controller.deferredFetchSubscriptionId)
    }
}
