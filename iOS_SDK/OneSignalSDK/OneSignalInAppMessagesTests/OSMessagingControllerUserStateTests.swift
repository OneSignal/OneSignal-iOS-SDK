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
@testable import OneSignalInAppMessages
import OneSignalOSCore
import OneSignalCoreMocks
import OneSignalOSCoreMocks
import OneSignalUserMocks
@testable import OneSignalUser

/**
 Tests for OSMessagingController's user state observer functionality.

 These tests verify that IAM fetching is deferred when blockers (push subscription, alias, or
 OneSignal ID) are absent at fetch time, and retried when the user state observer fires with a
 valid OneSignal ID.

 Related to PR: https://github.com/OneSignal/OneSignal-iOS-SDK/pull/1626
 */
final class OSMessagingControllerUserStateTests: XCTestCase {

    private let testOneSignalId = "test-onesignal-id-12345"
    private let testExternalId = "test-external-id-12345"
    private let testAppId = "test-app-id"

    override func setUpWithError() throws {
        OneSignalCoreMocks.clearUserDefaults()
        OneSignalUserMocks.reset()
        OSConsistencyManager.shared.reset()
        OSMessagingController.removeInstance()

        OneSignalConfigManager.setAppId(testAppId)
        OneSignalLog.setLogLevel(.LL_VERBOSE)

        // Tell the User Manager JWT is not required so OSUserUtils.getAlias resolves
        // (otherwise the IAM fetch is blocked by null alias and no request fires).
        OneSignalUserManagerImpl.sharedInstance.setRequiresUserAuth(false)
    }

    override func tearDownWithError() throws {
        OSMessagingController.removeInstance()
    }

    /**
     Test that getInAppMessagesFromServer does not fire an IAM network request when the
     OneSignal ID is unavailable.

     Scenario:
     - User manager has not been started; no OneSignal ID is available
     - getInAppMessagesFromServer is called

     Expected:
     - No IAM request fires (the call returns early)
     */
    func testDoesNotFetchWhenOneSignalIDUnavailable() throws {
        /* Setup */
        let client = MockOneSignalClient()
        OneSignalCoreImpl.setSharedClient(client)
        OSMessagingController.start()

        /* Execute */
        OneSignalInAppMessages.getFromServer()
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)

        /* Verify */
        XCTAssertTrue(client.hasExecutedRequestOfType(OSRequestGetInAppMessages.self, expectedCount: 0))
    }

    /**
     Test that the IAM fetch is retried when the user state observer fires with a valid
     OneSignal ID after a previously-deferred attempt.

     Scenario:
     - Anonymous user is created (sets push subscription ID)
     - login() is called but the network response is delayed, so OneSignal ID is not yet hydrated
     - getInAppMessagesFromServer is called; the fetch is deferred because OneSignal ID is missing
     - The login response then arrives, OneSignal ID is hydrated, and the user state observer fires

     Expected:
     - No IAM request fires during the deferred call
     - Exactly one IAM request fires after the user state observer triggers the retry
     */
    func testRetriesFetchWhenUserStateChangesWithValidOneSignalID() throws {
        /* Setup */
        let client = MockOneSignalClient()
        OneSignalCoreImpl.setSharedClient(client)
        OSMessagingController.start()

        ConsistencyManagerTestHelpers.setDefaultRywToken(id: testOneSignalId)

        /* Execute */
        MockUserRequests.setDefaultCreateAnonUserResponses(with: client, onesignalId: testOneSignalId, subscriptionId: testPushSubId)
        OneSignalUserManagerImpl.sharedInstance.start()

        // Login to a new user, without setting the client response yet, so onesignal ID is not hydrated.
        OneSignalUserManagerImpl.sharedInstance.login(externalId: testExternalId, token: nil)

        // First attempt: fetch is deferred because OneSignal ID is missing on the new user.
        OneSignalInAppMessages.getFromServer()
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)

        XCTAssertTrue(client.hasExecutedRequestOfType(OSRequestGetInAppMessages.self, expectedCount: 0))

        // Now let the login succeed, receive onesignal ID which fires user state observer.
        MockUserRequests.setDefaultIdentifyUserResponses(with: client, externalId: testExternalId)
        OneSignalUserManagerImpl.sharedInstance.userExecutor?.userRequestQueue.first?.sentToClient = false
        OneSignalUserManagerImpl.sharedInstance.userExecutor?.executePendingRequests()
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)

        /* Verify */
        XCTAssertTrue(client.hasExecutedRequestOfType(OSRequestGetInAppMessages.self, expectedCount: 1))
    }

    /**
     Test that a user state change without a pending retry does not trigger an extra fetch.

     Scenario:
     - Anonymous user starts with a valid OneSignal ID, IAM fetch runs once during start
     - login() with an external ID fires a user state change

     Expected:
     - Exactly one IAM request total — the user state change does not produce an additional fetch
     */
    func testDoesNothingWhenNoRetryPending() throws {
        /* Setup */
        let client = MockOneSignalClient()
        OneSignalCoreImpl.setSharedClient(client)
        OneSignalInAppMessages.start()

        MockUserRequests.setDefaultCreateAnonUserResponses(
            with: client,
            onesignalId: testOneSignalId,
            subscriptionId: testPushSubId
        )
        ConsistencyManagerTestHelpers.setDefaultRywToken(id: testOneSignalId)
        OneSignalUserManagerImpl.sharedInstance.start()
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)

        XCTAssertTrue(client.hasExecutedRequestOfType(OSRequestGetInAppMessages.self, expectedCount: 1))

        /* Execute */
        MockUserRequests.setDefaultIdentifyUserResponses(with: client, externalId: testExternalId)
        OneSignalUserManagerImpl.sharedInstance.login(externalId: testExternalId, token: nil)
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)

        /* Verify */
        XCTAssertTrue(client.hasExecutedRequestOfType(OSRequestGetInAppMessages.self, expectedCount: 1))
    }
}
