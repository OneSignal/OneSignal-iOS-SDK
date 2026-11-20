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

/// Listeners hear every line logged in the process, so a test reads back only the lines it is about.
private final class LogCapture: NSObject, OSLogListener {
    private let lock = NSLock()
    private var entries: [(level: ONE_S_LOG_LEVEL, entry: String)] = []

    func onLogEvent(_ event: OneSignalLogEvent) {
        lock.withLock { entries.append((event.level, event.entry)) }
    }

    func levels(mentioning text: String) -> [ONE_S_LOG_LEVEL] {
        return lock.withLock { entries.filter { $0.entry.contains(text) }.map { $0.level } }
    }
}

/// A failed Request logs at the level of what the executor does with it: INFO when it is held or
/// retried, WARN when it is dropped, ERROR when it stops the queue.
final class RequestFailureLogLevelTests: XCTestCase {
    private let addAliasesFailure = "add aliases request failed"
    private let fetchUserFailure = "executeFetchUserRequest failed"
    private let createUserFailure = "create user request failed"

    private var client = MockOneSignalClient()
    private var log = LogCapture()

    override func setUpWithError() throws {
        OneSignalCoreMocks.clearUserDefaults()
        OneSignalUserMocks.reset()
        OneSignalIdentifiers.currentAppId = "test-app-id"

        client = MockOneSignalClient()
        OneSignalCoreImpl.setSharedClient(client)

        log = LogCapture()
        OneSignalLog.debug().__add(log)
    }

    override func tearDownWithError() throws {
        OneSignalCoreMocks.waitUntil("A Request was still in flight at teardown") {
            self.client.completedRequests.count == self.client.startedRequests.count
        }
        OneSignalLog.debug().__remove(log)
        OneSignalUserManagerImpl.sharedInstance.operationRepo.paused = false
        OneSignalCoreMocks.clearUserDefaults()
    }

    private func error(_ code: Int) -> OneSignalClientError {
        return OneSignalClientError(code: code, message: "not-important", responseHeaders: nil, response: nil, underlyingError: nil)
    }

    /// Sends one cached Add Aliases for user A that the server answers with `code`, signed with `token` if given.
    private func sendAddAliases(failingWith code: Int, signedWith token: String? = nil) {
        let identityModel = OneSignalUserMocks.setUserManagerInternalUser(externalId: userA_EUID, onesignalId: userA_OSID).identityModel
        if let token {
            XCTAssertTrue(OneSignalUserManagerImpl.sharedInstance.userJwtRepo.updateJwt(externalId: userA_EUID, token: token))
        }
        let request = OSRequestAddAliases(aliases: ["test_alias_label": "test-alias-id"], identityModel: identityModel, ownerExternalId: userA_EUID)
        OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_IDENTITY_EXECUTOR_ADD_REQUEST_QUEUE_KEY, withValue: [request])
        client.setMockFailureResponseForRequest(request: request.description, error: error(code))

        let executor = OSIdentityOperationExecutor(newRecordsState: MockNewRecordsState(), auth: OneSignalUserManagerImpl.sharedInstance.requestAuth)
        executor.processDeltaQueue(inBackground: false)
    }

    private func loggedLevels(mentioning text: String) -> [ONE_S_LOG_LEVEL] {
        OneSignalCoreMocks.waitUntil("Nothing was logged about: \(text)") {
            !self.log.levels(mentioning: text).isEmpty
        }
        return log.levels(mentioning: text)
    }

    func testARequestHeldForANewTokenLogsInfo() {
        OSCoreMocks.hydrateSharedJwtConfig(requiresUserAuth: true)

        sendAddAliases(failingWith: 401, signedWith: "token-a")

        XCTAssertEqual(loggedLevels(mentioning: addAliasesFailure), [.LL_INFO])
        XCTAssertNil(OneSignalUserManagerImpl.sharedInstance.userJwtRepo.validJwt(externalId: userA_EUID), "the 401 was handled as a rejected token")
    }

    func testARetryableFailureLogsInfo() {
        sendAddAliases(failingWith: 500)

        XCTAssertEqual(loggedLevels(mentioning: addAliasesFailure), [.LL_INFO])
    }

    func testADroppedRequestLogsWarn() {
        sendAddAliases(failingWith: 400)

        XCTAssertEqual(loggedLevels(mentioning: addAliasesFailure), [.LL_WARN])
    }

    func testAFetchForAUserTheServerNoLongerHasLogsInfo() {
        _ = OneSignalUserMocks.setUserManagerInternalUser(externalId: userB_EUID, onesignalId: userB_OSID)
        let staleIdentityModel = OSIdentityModel(aliases: [OS_ONESIGNAL_ID: userA_OSID], changeNotifier: OSEventProducer())
        client.setMockFailureResponseForRequest(request: "<OSRequestFetchUser with onesignal_id: \(userA_OSID)>", error: error(404))
        let executor = OSUserExecutor(
            newRecordsState: MockNewRecordsState(),
            identityVerificationService: OneSignalUserManagerImpl.sharedInstance.identityVerificationService,
            auth: OneSignalUserManagerImpl.sharedInstance.requestAuth
        )

        executor.fetchUser(aliasLabel: OS_ONESIGNAL_ID, aliasId: userA_OSID, identityModel: staleIdentityModel, onNewSession: false)

        XCTAssertEqual(loggedLevels(mentioning: fetchUserFailure), [.LL_INFO])
    }

    func testAFetchThatLogsOutTheCurrentUserLogsWarn() {
        let identityModel = OneSignalUserMocks.setUserManagerInternalUser(externalId: userA_EUID, onesignalId: userA_OSID).identityModel
        client.setMockFailureResponseForRequest(request: "<OSRequestFetchUser with onesignal_id: \(userA_OSID)>", error: error(404))
        let executor = OSUserExecutor(
            newRecordsState: MockNewRecordsState(),
            identityVerificationService: OneSignalUserManagerImpl.sharedInstance.identityVerificationService,
            auth: OneSignalUserManagerImpl.sharedInstance.requestAuth
        )

        executor.fetchUser(aliasLabel: OS_ONESIGNAL_ID, aliasId: userA_OSID, identityModel: identityModel, onNewSession: false)

        XCTAssertEqual(loggedLevels(mentioning: fetchUserFailure), [.LL_WARN])
    }

    func testACreateUserFailureThatPausesTheRepoLogsError() {
        OSCoreMocks.hydrateSharedJwtConfig(requiresUserAuth: true)
        client.setMockFailureResponseForRequest(request: "<OSRequestCreateUser with external_id: \(userA_EUID)>", error: error(400))

        OneSignalUserManagerImpl.sharedInstance.login(externalId: userA_EUID, token: "token-a")

        XCTAssertEqual(loggedLevels(mentioning: createUserFailure), [.LL_ERROR])
        OneSignalCoreMocks.waitUntil("The failure did not pause the Repo") {
            OneSignalUserManagerImpl.sharedInstance.operationRepo.paused
        }
    }
}
