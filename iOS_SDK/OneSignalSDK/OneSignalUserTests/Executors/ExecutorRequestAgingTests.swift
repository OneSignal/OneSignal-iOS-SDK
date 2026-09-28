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
 What each executor drops from its queues on age alone. See `OSRequestAging` for the limits.

 A Request is aged from the `timestamp` its cache entry keeps, so these tests write Requests with old
 timestamps straight into the cache and read back what the executor kept. User A is the current user and
 user B is not. Both hold a token, so nothing here is dropped for being unsendable.
 */
final class ExecutorRequestAgingTests: XCTestCase {
    private let day: TimeInterval = 86_400
    private let propertiesKey = OS_PROPERTIES_EXECUTOR_UPDATE_REQUEST_QUEUE_KEY
    private let addAliasesKey = OS_IDENTITY_EXECUTOR_ADD_REQUEST_QUEUE_KEY
    private let removeAliasKey = OS_IDENTITY_EXECUTOR_REMOVE_REQUEST_QUEUE_KEY
    private let customEventsKey = OS_CUSTOM_EVENTS_EXECUTOR_REQUEST_QUEUE_KEY

    private var client = MockOneSignalClient()
    private var newRecordsState = MockNewRecordsState()
    private var current = OSIdentityModel(aliases: nil, changeNotifier: OSEventProducer())
    private var other = OSIdentityModel(aliases: nil, changeNotifier: OSEventProducer())
    /// The clock the executors under test read.
    private var now = Date()

    override func setUpWithError() throws {
        OneSignalCoreMocks.clearUserDefaults()
        OneSignalUserMocks.reset()
        OneSignalIdentifiers.currentAppId = "test-app-id"

        client = MockOneSignalClient()
        client.fireSuccessForAllRequests = true
        OneSignalCoreImpl.setSharedClient(client)
        newRecordsState = MockNewRecordsState()
        newRecordsState.holdWhilePresent = true
        now = Date()

        OSCoreMocks.hydrateSharedJwtConfig(requiresUserAuth: true)
        current = OneSignalUserMocks.setUserManagerInternalUser(externalId: userA_EUID, onesignalId: userA_OSID).identityModel
        current.jwtBearerToken = "token-a"
        other = addUserToRepo(externalId: userB_EUID, onesignalId: userB_OSID, token: "token-b")
    }

    override func tearDownWithError() throws {
        OneSignalCoreMocks.clearUserDefaults()
    }

    // MARK: - Setup helpers

    private func addUserToRepo(externalId: String, onesignalId: String, token: String) -> OSIdentityModel {
        let model = OSIdentityModel(aliases: [OS_ONESIGNAL_ID: onesignalId, OS_EXTERNAL_ID: externalId], changeNotifier: OSEventProducer())
        model.jwtBearerToken = token
        OneSignalUserManagerImpl.sharedInstance.addIdentityModelToRepo(model)
        return model
    }

    private var auth: OSRequestAuthorizing {
        return OneSignalUserManagerImpl.sharedInstance.requestAuth
    }

    private func propertyExecutor() -> OSPropertyOperationExecutor {
        return OSPropertyOperationExecutor(newRecordsState: newRecordsState, auth: auth, nowProvider: { self.now })
    }

    private func identityExecutor() -> OSIdentityOperationExecutor {
        return OSIdentityOperationExecutor(newRecordsState: newRecordsState, auth: auth, nowProvider: { self.now })
    }

    private func customEventsExecutor() -> OSCustomEventsExecutor {
        return OSCustomEventsExecutor(newRecordsState: newRecordsState, auth: auth, nowProvider: { self.now })
    }

    /// A negative `daysOld` puts the timestamp ahead of the clock.
    private func aged<T: OneSignalRequest>(_ request: T, daysOld: Double) -> T {
        request.timestamp = now.addingTimeInterval(-daysOld * day)
        return request
    }

    private func propertyUpdate(for identityModel: OSIdentityModel, daysOld: Double) -> OSRequestUpdateProperties {
        let request = OSRequestUpdateProperties(params: ["properties": ["language": "en"]], identityModel: identityModel, ownerExternalId: identityModel.externalId)
        return aged(request, daysOld: daysOld)
    }

    private func addAliases(for identityModel: OSIdentityModel, daysOld: Double) -> OSRequestAddAliases {
        let request = OSRequestAddAliases(aliases: ["test_alias_label": "test-alias-id"], identityModel: identityModel, ownerExternalId: identityModel.externalId)
        return aged(request, daysOld: daysOld)
    }

    private func removeAlias(for identityModel: OSIdentityModel, daysOld: Double) -> OSRequestRemoveAlias {
        let request = OSRequestRemoveAlias(labelToRemove: "test_alias_label", identityModel: identityModel, ownerExternalId: identityModel.externalId)
        return aged(request, daysOld: daysOld)
    }

    private func customEvents(for identityModel: OSIdentityModel, daysOld: Double) -> OSRequestCustomEvents {
        let event: [String: Any] = [
            "name": "test_event",
            "onesignal_id": identityModel.onesignalId ?? "",
            "timestamp": "2026-01-01T00:00:00Z",
            "payload": ["test_property": "test-value"]
        ]
        let request = OSRequestCustomEvents(events: [event], identityModel: identityModel, ownerExternalId: identityModel.externalId)
        return aged(request, daysOld: daysOld)
    }

    private func cache<T: OSUserRequest>(_ requests: [T], under key: String) {
        OneSignalUserDefaults.initShared().saveCodeableData(forKey: key, withValue: requests)
    }

    // MARK: - Assertion helpers

    private func cachedOwners<T: OSUserRequest>(_ key: String, of type: T.Type) -> [String?] {
        let requests = OneSignalUserDefaults.initShared().getSavedCodeableData(forKey: key, defaultValue: []) as? [T] ?? []
        return requests.map { $0.ownerExternalId }
    }

    // MARK: - Property updates

    func testAPropertyUpdate91DaysOldIsDroppedAtUncache() {
        cache([propertyUpdate(for: current, daysOld: 91)], under: propertiesKey)

        _ = propertyExecutor()

        XCTAssertEqual(cachedOwners(propertiesKey, of: OSRequestUpdateProperties.self), [])
    }

    func testAPropertyUpdate89DaysOldIsKeptAtUncache() {
        cache([propertyUpdate(for: current, daysOld: 89)], under: propertiesKey)

        _ = propertyExecutor()

        XCTAssertEqual(cachedOwners(propertiesKey, of: OSRequestUpdateProperties.self), [userA_EUID])
    }

    /// The check runs before `prepareForExecution`, so the Request goes on the flush that finds it stale
    /// even though the hold that stopped the first flush has lifted by then.
    func testAPropertyUpdateThatCrosses90DaysBetweenFlushesIsDroppedAtTheSecondFlush() {
        newRecordsState.add(userA_OSID)
        cache([propertyUpdate(for: current, daysOld: 89)], under: propertiesKey)
        let executor = propertyExecutor()

        executor.processDeltaQueue(inBackground: false)
        allowAsyncWorkToRun()
        XCTAssertEqual(client.executedRequests.count, 0)
        XCTAssertEqual(cachedOwners(propertiesKey, of: OSRequestUpdateProperties.self), [userA_EUID])

        newRecordsState.holdWhilePresent = false
        now = now.addingTimeInterval(2 * day)
        executor.processDeltaQueue(inBackground: false)
        OneSignalCoreMocks.waitUntil("The stale Update Properties was not dropped from the cache") {
            self.cachedOwners(self.propertiesKey, of: OSRequestUpdateProperties.self).isEmpty
        }

        XCTAssertEqual(client.executedRequests.count, 0)
    }

    /// The premise of the test above: once the hold lifts, a Request still under its limit is sent.
    func testAPropertyUpdateStillUnderItsLimitIsSentOnceTheHoldLifts() {
        newRecordsState.add(userA_OSID)
        cache([propertyUpdate(for: current, daysOld: 89)], under: propertiesKey)
        let executor = propertyExecutor()

        executor.processDeltaQueue(inBackground: false)
        allowAsyncWorkToRun()
        XCTAssertEqual(client.executedRequests.count, 0)

        newRecordsState.holdWhilePresent = false
        executor.processDeltaQueue(inBackground: false)
        OneSignalCoreMocks.waitUntil("The Update Properties was not sent") {
            self.client.hasExecutedRequestOfType(OSRequestUpdateProperties.self, expectedCount: 1)
        }

        XCTAssertTrue(client.hasExecutedRequestOfType(OSRequestUpdateProperties.self, expectedCount: 1))
    }

    // MARK: - Non-current users

    func testRequestsOwnedByANonCurrentUserAreDroppedAt31Days() {
        cache([propertyUpdate(for: other, daysOld: 31)], under: propertiesKey)
        cache([addAliases(for: other, daysOld: 31)], under: addAliasesKey)
        cache([removeAlias(for: other, daysOld: 31)], under: removeAliasKey)
        cache([customEvents(for: other, daysOld: 31)], under: customEventsKey)

        _ = propertyExecutor()
        _ = identityExecutor()
        _ = customEventsExecutor()

        XCTAssertEqual(cachedOwners(propertiesKey, of: OSRequestUpdateProperties.self), [])
        XCTAssertEqual(cachedOwners(addAliasesKey, of: OSRequestAddAliases.self), [])
        XCTAssertEqual(cachedOwners(removeAliasKey, of: OSRequestRemoveAlias.self), [])
        XCTAssertEqual(cachedOwners(customEventsKey, of: OSRequestCustomEvents.self), [])
    }

    func testRequestsOwnedByANonCurrentUserAreKeptAt29Days() {
        cache([propertyUpdate(for: other, daysOld: 29)], under: propertiesKey)
        cache([addAliases(for: other, daysOld: 29)], under: addAliasesKey)
        cache([removeAlias(for: other, daysOld: 29)], under: removeAliasKey)
        cache([customEvents(for: other, daysOld: 29)], under: customEventsKey)

        _ = propertyExecutor()
        _ = identityExecutor()
        _ = customEventsExecutor()

        XCTAssertEqual(cachedOwners(propertiesKey, of: OSRequestUpdateProperties.self), [userB_EUID])
        XCTAssertEqual(cachedOwners(addAliasesKey, of: OSRequestAddAliases.self), [userB_EUID])
        XCTAssertEqual(cachedOwners(removeAliasKey, of: OSRequestRemoveAlias.self), [userB_EUID])
        XCTAssertEqual(cachedOwners(customEventsKey, of: OSRequestCustomEvents.self), [userB_EUID])
    }

    func testAPropertyUpdateOwnedByTheCurrentUserIsKeptAt31Days() {
        cache([propertyUpdate(for: current, daysOld: 31)], under: propertiesKey)

        _ = propertyExecutor()

        XCTAssertEqual(cachedOwners(propertiesKey, of: OSRequestUpdateProperties.self), [userA_EUID])
    }

    // MARK: - Custom events

    func testCustomEventsOwnedByTheCurrentUserAreDroppedAt31Days() {
        cache([customEvents(for: current, daysOld: 31)], under: customEventsKey)

        _ = customEventsExecutor()

        XCTAssertEqual(cachedOwners(customEventsKey, of: OSRequestCustomEvents.self), [])
    }

    // MARK: - Requests with no age limit

    func testACreateUser91DaysOldIsKeptAtUncache() throws {
        let user = try XCTUnwrap(OneSignalUserManagerImpl.sharedInstance._user)
        // Held so the User executor cannot send it. The assertion is that uncache kept it.
        newRecordsState.add(testPushSubId)
        let request = OSRequestCreateUser(identityModel: current, propertiesModel: user.propertiesModel, pushSubscriptionModel: user.pushSubscriptionModel, originalPushToken: nil)
        cache([aged(request, daysOld: 91)], under: OS_USER_EXECUTOR_USER_REQUEST_QUEUE_KEY)

        _ = OSUserExecutor(newRecordsState: newRecordsState, identityVerificationService: OneSignalUserManagerImpl.sharedInstance.identityVerificationService, auth: auth)
        allowAsyncWorkToRun()

        XCTAssertEqual(cachedOwners(OS_USER_EXECUTOR_USER_REQUEST_QUEUE_KEY, of: OSRequestCreateUser.self), [userA_EUID])
        XCTAssertEqual(client.executedRequests.count, 0)
    }

    func testACreateSubscription91DaysOldIsKeptAtUncache() {
        let subscription = OSSubscriptionModel(type: .email, address: "a@example.com", subscriptionId: "test-email-subscription-id", reachable: true, isDisabled: false, changeNotifier: OSEventProducer())
        let request = OSRequestCreateSubscription(subscriptionModel: subscription, identityModel: current, ownerExternalId: userA_EUID)
        cache([aged(request, daysOld: 91)], under: OS_SUBSCRIPTION_EXECUTOR_ADD_REQUEST_QUEUE_KEY)

        _ = OSSubscriptionOperationExecutor(newRecordsState: newRecordsState, auth: auth)

        XCTAssertEqual(cachedOwners(OS_SUBSCRIPTION_EXECUTOR_ADD_REQUEST_QUEUE_KEY, of: OSRequestCreateSubscription.self), [userA_EUID])
    }

    // MARK: - Clock

    /// Owned by the other user, so both limits would apply if it had any age.
    func testARequestWithATimestampAheadOfTheClockIsKept() {
        cache([propertyUpdate(for: other, daysOld: -365)], under: propertiesKey)

        _ = propertyExecutor()

        XCTAssertEqual(cachedOwners(propertiesKey, of: OSRequestUpdateProperties.self), [userB_EUID])
    }
}
