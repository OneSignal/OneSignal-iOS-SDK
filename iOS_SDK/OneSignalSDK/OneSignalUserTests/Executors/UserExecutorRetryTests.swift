/*
 Modified MIT License

 Copyright 2026 OneSignal

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
import OneSignalOSCore
import OneSignalCoreMocks
import OneSignalOSCoreMocks
import OneSignalUserMocks
@testable import OneSignalUser

/**
 What the User executor retries on its own, and what it waits on the app for. A parked Request waits
 for a token that only `updateUserJwt` can supply; anything else that stops a prepare resolves on its
 own and has to be retried, or a login sits in the queue until the next launch.
 */
final class UserExecutorRetryTests: XCTestCase {
    private var client = MockOneSignalClient()
    private var newRecordsState = MockNewRecordsState()

    override func setUpWithError() throws {
        OneSignalCoreMocks.clearUserDefaults()
        OneSignalUserMocks.reset()
        OneSignalIdentifiers.currentAppId = "test-app-id"

        client = MockOneSignalClient()
        OneSignalCoreImpl.setSharedClient(client)
        newRecordsState = MockNewRecordsState()
        // Presence is the hold: the production timer is a no-op under TEST.
        newRecordsState.holdWhilePresent = true
    }

    override func tearDownWithError() throws {
        OneSignalCoreMocks.clearUserDefaults()
    }

    private func makeExecutor() -> OSUserExecutor {
        return OSUserExecutor(
            newRecordsState: newRecordsState,
            identityVerificationService: OneSignalUserManagerImpl.sharedInstance.identityVerificationService,
            auth: OneSignalUserManagerImpl.sharedInstance.requestAuth
        )
    }

    /**
     A Create User held by the new-records cool-down on its push subscription fails to prepare before
     the auth layer can park it, so nobody is asked for a token. It has to be retried once the cool-down
     passes, at which point it parks and asks, rather than be stepped over as if it were already parked.
     */
    func testACreateUserHeldByTheCoolDownIsRetriedUntilItCanParkAndAsk() {
        OSCoreMocks.hydrateSharedJwtConfig(requiresUserAuth: true)
        let jwtRepo = OneSignalUserManagerImpl.sharedInstance.userJwtRepo
        let user = OneSignalUserMocks.setUserManagerInternalUser(externalId: userA_EUID, onesignalId: nil)
        newRecordsState.add(testPushSubId)
        let executor = makeExecutor()

        executor.createUser(user)
        allowAsyncWorkToRun()
        XCTAssertFalse(jwtRepo.pendingTokenAsks().contains(userA_EUID), "held by the cool-down, so nobody may be asked yet")

        newRecordsState.holdWhilePresent = false
        OneSignalCoreMocks.waitUntil("The app was not asked for a token once the cool-down passed") {
            jwtRepo.pendingTokenAsks().contains(userA_EUID)
        }
        XCTAssertFalse(client.hasExecutedRequestOfType(OSRequestCreateUser.self), "nothing signs a Create User whose owner has no token")
    }
}
