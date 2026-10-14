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
import OneSignalCoreMocks
import OneSignalOSCoreMocks
import OneSignalUserMocks
@testable import OneSignalOSCore
@testable import OneSignalUser

/// Executors retry a retryable failure in the same run, after a backoff, instead of at the next launch.
final class ExecutorRetryBackoffTests: XCTestCase {
    private var client = MockOneSignalClient()
    private var newRecordsState = MockNewRecordsState()
    private var uptime: TimeInterval = 1_000
    private var backoff: OSRequestRetryBackoff!
    private var identityModel = OSIdentityModel(aliases: nil, changeNotifier: OSEventProducer())
    private var addAliasesDescription = ""

    override func setUpWithError() throws {
        OneSignalCoreMocks.clearUserDefaults()
        OneSignalUserMocks.reset()
        OneSignalIdentifiers.currentAppId = "test-app-id"

        client = MockOneSignalClient()
        client.executeInstantaneously = true
        OneSignalCoreImpl.setSharedClient(client)
        newRecordsState = MockNewRecordsState()
        uptime = 1_000
        backoff = OSRequestRetryBackoff(uptime: { self.uptime }, jitter: { 1 })

        OSCoreMocks.hydrateSharedJwtConfig(requiresUserAuth: false)
        identityModel = OneSignalUserMocks.setUserManagerInternalUser(externalId: userA_EUID, onesignalId: userA_OSID).identityModel
    }

    override func tearDownWithError() throws {
        OneSignalCoreMocks.clearUserDefaults()
    }

    private func error(_ code: Int, headers: [String: String]? = nil) -> OneSignalClientError {
        return OneSignalClientError(code: code, message: "not-important", responseHeaders: headers, response: nil, underlyingError: nil)
    }

    private func cachedAddAliases(failingWith failure: OneSignalClientError) -> OSIdentityOperationExecutor {
        let request = OSRequestAddAliases(aliases: ["test_alias_label": "test-alias-id"], identityModel: identityModel, ownerExternalId: userA_EUID)
        OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_IDENTITY_EXECUTOR_ADD_REQUEST_QUEUE_KEY, withValue: [request])
        addAliasesDescription = request.description
        client.setMockFailureResponseForRequest(request: addAliasesDescription, error: failure)
        return OSIdentityOperationExecutor(newRecordsState: newRecordsState, auth: OneSignalUserManagerImpl.sharedInstance.requestAuth, retryBackoff: backoff)
    }

    private func addAliasesCount() -> Int {
        return client.executedRequests.filter { $0 is OSRequestAddAliases }.count
    }

    private func cachedAddAliases() -> [OSRequestAddAliases] {
        let cached = OneSignalUserDefaults.initShared().getSavedCodeableData(forKey: OS_IDENTITY_EXECUTOR_ADD_REQUEST_QUEUE_KEY, defaultValue: []) as? [OSRequestAddAliases]
        return cached ?? []
    }

    /// Flushes, then waits until the attempt has been sent and its response handled.
    private func flushAndWaitForAttempt(_ executor: OSIdentityOperationExecutor, number: Int) {
        executor.processDeltaQueue(inBackground: false)
        OneSignalCoreMocks.waitUntil("Attempt \(number) was not handled") {
            self.addAliasesCount() == number && self.backoff.isWaitingOnAny()
        }
    }

    /// Flushes and gives the executor time to send, for asserting that nothing was sent.
    private func flushExpectingNoAttempt(_ executor: OSIdentityOperationExecutor) {
        let before = addAliasesCount()
        executor.processDeltaQueue(inBackground: false)
        allowAsyncWorkToRun(seconds: 0.3)
        XCTAssertEqual(addAliasesCount(), before, "still backing off")
    }

    func testARetryableFailureIsResentOnceTheBackoffPasses() {
        let executor = cachedAddAliases(failingWith: error(500))

        flushAndWaitForAttempt(executor, number: 1)
        flushExpectingNoAttempt(executor)

        uptime += OSRequestRetryBackoff.baseDelaySeconds
        flushAndWaitForAttempt(executor, number: 2)
        XCTAssertEqual(cachedAddAliases().count, 1, "kept until it succeeds")
    }

    func testASuccessfulRetryRemovesTheRequest() {
        let executor = cachedAddAliases(failingWith: error(0))
        flushAndWaitForAttempt(executor, number: 1)

        client.setMockResponseForRequest(request: addAliasesDescription, response: [:])
        uptime += OSRequestRetryBackoff.baseDelaySeconds
        executor.processDeltaQueue(inBackground: false)

        OneSignalCoreMocks.waitUntil("The retried Add Aliases was not removed") {
            self.addAliasesCount() == 2 && self.cachedAddAliases().isEmpty
        }
    }

    func testANonRetryableFailureIsNotRetried() {
        let executor = cachedAddAliases(failingWith: error(400))

        executor.processDeltaQueue(inBackground: false)
        OneSignalCoreMocks.waitUntil("The rejected Add Aliases was not removed") {
            self.addAliasesCount() == 1 && self.cachedAddAliases().isEmpty
        }
        uptime += OSRequestRetryBackoff.maxDelaySeconds
        flushExpectingNoAttempt(executor)
    }

    func testRetryNowEndsTheBackoff() {
        let executor = cachedAddAliases(failingWith: error(500))
        flushAndWaitForAttempt(executor, number: 1)

        backoff.retryNow()
        flushAndWaitForAttempt(executor, number: 2)
    }

    func testRetryNowStillWaitsOutRetryAfter() {
        let executor = cachedAddAliases(failingWith: error(429, headers: ["Retry-After": "120"]))
        flushAndWaitForAttempt(executor, number: 1)

        backoff.retryNow()
        uptime += 119
        flushExpectingNoAttempt(executor)

        uptime += 1
        flushAndWaitForAttempt(executor, number: 2)
    }

    private func userExecutor() -> OSUserExecutor {
        return OSUserExecutor(
            newRecordsState: newRecordsState,
            identityVerificationService: OneSignalUserManagerImpl.sharedInstance.identityVerificationService,
            auth: OneSignalUserManagerImpl.sharedInstance.requestAuth,
            retryBackoff: backoff
        )
    }

    private func count(_ type: AnyClass) -> Int {
        return client.executedRequests.filter { $0.isKind(of: type) }.count
    }

    /// The User executor re-sends from the Operation Repo's poll, and holds the Requests behind it.
    func testTheUserExecutorRetriesAFailedFetchUserOnThePollOnceTheBackoffPasses() {
        let fetch = "<OSRequestFetchUser with onesignal_id: \(userA_OSID)>"
        let executor = userExecutor()
        client.setMockFailureResponseForRequest(request: fetch, error: error(500))

        executor.fetchUser(aliasLabel: OS_ONESIGNAL_ID, aliasId: userA_OSID, identityModel: identityModel, onNewSession: true)
        OneSignalCoreMocks.waitUntil("The Fetch User was not attempted") {
            self.count(OSRequestFetchUser.self) == 1 && self.backoff.isWaitingOnAny()
        }

        // Includes this device's subscription, so the on-new-session check does not go on to create one.
        let response: [String: Any] = [
            "identity": [OS_ONESIGNAL_ID: userA_OSID, OS_EXTERNAL_ID: userA_EUID],
            "subscriptions": [["id": testPushSubId, "type": "iOSPush"]]
        ]
        client.setMockResponseForRequest(request: fetch, response: response)
        executor.retryIfDue()
        allowAsyncWorkToRun(seconds: 0.3)
        XCTAssertEqual(count(OSRequestFetchUser.self), 1, "still backing off")

        uptime += OSRequestRetryBackoff.baseDelaySeconds
        OneSignalCoreMocks.waitUntil("The Fetch User was not retried until it succeeded") {
            executor.retryIfDue()
            return self.count(OSRequestFetchUser.self) == 2 && executor.userRequestQueue.isEmpty
        }
        allowAsyncWorkToRun()
    }

    /// Holds the Create User's response, then rejects it with a 400 once `whileInFlight` has run.
    private func createUserRejected(
        _ executor: OSUserExecutor,
        for model: OSIdentityModel,
        externalId: String,
        whileInFlight: () -> Void = {}
    ) {
        client.holdResponses = true
        executor.createUser(aliasLabel: OS_EXTERNAL_ID, aliasId: externalId, identityModel: model)
        OneSignalCoreMocks.waitUntil("The Create User was not attempted") {
            self.client.startedRequests.contains { $0 is OSRequestCreateUser }
        }
        let createUser = client.startedRequests.first { $0 is OSRequestCreateUser }!
        client.setMockFailureResponseForRequest(request: createUser.description, error: error(400))
        whileInFlight()
        client.releaseHeldResponses()
    }

    func testARejectedCreateUserIsOnlyResentOnANewSession() {
        let executor = userExecutor()
        createUserRejected(executor, for: identityModel, externalId: userA_EUID)

        // A foreground that ends some other backoff flushes the executor.
        executor.executePendingRequests()
        executor.retryIfDue()
        allowAsyncWorkToRun(seconds: 0.3)
        XCTAssertEqual(count(OSRequestCreateUser.self), 1, "held until a new session")

        executor.executePendingRequestsOnNewSession()
        OneSignalCoreMocks.waitUntil("The Create User was not resent on the new session") {
            self.count(OSRequestCreateUser.self) == 2
        }
        OneSignalUserManagerImpl.sharedInstance.operationRepo.paused = false
    }

    func testARejectedCreateUserOfALoggedOutUserDoesNotHoldTheNextUser() {
        let executor = userExecutor()
        let loggedOut = OSIdentityModel(aliases: nil, changeNotifier: OSEventProducer())
        createUserRejected(executor, for: loggedOut, externalId: userB_EUID)
        OneSignalCoreMocks.waitUntil("The repo was not paused") {
            OneSignalUserManagerImpl.sharedInstance.operationRepo.paused
        }

        client.setMockResponseForRequest(request: "<OSRequestCreateUser with external_id: \(userA_EUID)>", response: [:])
        executor.createUser(aliasLabel: OS_EXTERNAL_ID, aliasId: userA_EUID, identityModel: identityModel)
        OneSignalCoreMocks.waitUntil("The current user's Create User was held behind the logged out one") {
            self.count(OSRequestCreateUser.self) == 2
        }
        XCTAssertFalse(executor.userRequestQueue.contains { ($0 as? OSRequestCreateUser)?.identityModel === loggedOut })
        XCTAssertFalse(OneSignalUserManagerImpl.sharedInstance.operationRepo.paused)
    }

    func testACreateUserRejectedAfterANewSessionStartedIsResentRightAway() {
        let executor = userExecutor()
        createUserRejected(executor, for: identityModel, externalId: userA_EUID) {
            executor.executePendingRequestsOnNewSession()
            allowAsyncWorkToRun(seconds: 0.3)
        }

        OneSignalCoreMocks.waitUntil("The Create User was not resent for the session that started while it was in flight") {
            self.count(OSRequestCreateUser.self) == 2
        }
        OneSignalUserManagerImpl.sharedInstance.operationRepo.paused = false
    }
}
