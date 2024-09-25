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
import OneSignalOSCore
import OneSignalCoreMocks
import OneSignalOSCoreMocks
import OneSignalUserMocks
@testable import OneSignalUser

private class Mocks: OneSignalExecutorMocks {
    var subscriptionExecutor: OSSubscriptionOperationExecutor!

    override init() {
        super.init()
        subscriptionExecutor = OSSubscriptionOperationExecutor(newRecordsState: newRecordsState, jwtConfig: jwtConfig)
    }
}

final class SubscriptionExecutorTests: XCTestCase {

    override func setUpWithError() throws {
        OneSignalCoreMocks.clearUserDefaults()
        OneSignalUserMocks.reset()
        // App ID is set because requests have guards against null App ID
        OneSignalConfigManager.setAppId("test-app-id")
        // Temp. logging to help debug during testing
        OneSignalLog.setLogLevel(.LL_VERBOSE)
    }

    override func tearDownWithError() throws { }

    func testAddEmailSendsWhenProcessed() {
        /* Setup */
        let mocks = Mocks()
        mocks.setAuthRequired(false)
        OneSignalUserManagerImpl.sharedInstance.operationRepo.paused = true

        let user = mocks.setUserManagerInternalUser(externalId: userA_EUID, onesignalId: userA_OSID)
        let email = userA_email
        MockUserRequests.setAddEmailResponse(with: mocks.client, email: email)
        mocks.subscriptionExecutor.enqueueDelta(OSDelta(name: OS_ADD_SUBSCRIPTION_DELTA, identityModelId: user.identityModel.modelId, model: OSSubscriptionModel(type: .email, address: email, subscriptionId: nil, reachable: true, isDisabled: false, changeNotifier: OSEventProducer()), property: OSSubscriptionType.email.rawValue, value: email))

        /* When */
        mocks.subscriptionExecutor.processDeltaQueue(inBackground: false)
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)

        /* Then */
        XCTAssertTrue(mocks.client.hasExecutedRequestOfType(OSRequestCreateSubscription.self))
    }

    func testAddEmail_IdentityVerificationRequired_butNoToken() {
        /* Setup */
        let mocks = Mocks()
        mocks.setAuthRequired(true)
        OneSignalUserManagerImpl.sharedInstance.operationRepo.paused = true

        let user = mocks.setUserManagerInternalUser(externalId: userA_EUID, onesignalId: userA_OSID)
        let email = userA_email
        MockUserRequests.setAddEmailResponse(with: mocks.client, email: email)
        mocks.subscriptionExecutor.enqueueDelta(OSDelta(name: OS_ADD_SUBSCRIPTION_DELTA, identityModelId: user.identityModel.modelId, model: OSSubscriptionModel(type: .email, address: email, subscriptionId: nil, reachable: true, isDisabled: false, changeNotifier: OSEventProducer()), property: OSSubscriptionType.email.rawValue, value: email))

        /* When */
        mocks.subscriptionExecutor.processDeltaQueue(inBackground: false)
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)

        /* Then */
        XCTAssertFalse(mocks.client.hasExecutedRequestOfType(OSRequestCreateSubscription.self))
    }

    func testAddEmail_IdentityVerificationRequired_withToken() {
        /* Setup */
        let mocks = Mocks()
        mocks.setAuthRequired(true)
        OneSignalUserManagerImpl.sharedInstance.operationRepo.paused = true

        let user = mocks.setUserManagerInternalUser(externalId: userA_EUID, onesignalId: userA_OSID)
        user.identityModel.jwtBearerToken = userA_InvalidJwtToken
        let email = userA_email
        MockUserRequests.setAddEmailResponse(with: mocks.client, email: email)
        mocks.subscriptionExecutor.enqueueDelta(OSDelta(name: OS_ADD_SUBSCRIPTION_DELTA, identityModelId: user.identityModel.modelId, model: OSSubscriptionModel(type: .email, address: email, subscriptionId: nil, reachable: true, isDisabled: false, changeNotifier: OSEventProducer()), property: OSSubscriptionType.email.rawValue, value: email))

        /* When */
        mocks.subscriptionExecutor.processDeltaQueue(inBackground: false)
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)

        /* Then */
        XCTAssertTrue(mocks.client.hasExecutedRequestOfType(OSRequestCreateSubscription.self))
    }

    func testAddEmail_IdentityVerificationRequired_withInvalidToken() {
        /* Setup */
        let mocks = Mocks()
        mocks.setAuthRequired(true)
        OneSignalUserManagerImpl.sharedInstance.operationRepo.paused = true

        let user = mocks.setUserManagerInternalUser(externalId: userA_EUID, onesignalId: userA_OSID)
        user.identityModel.jwtBearerToken = userA_InvalidJwtToken
        let email = userA_email
        MockUserRequests.setUnauthorizedAddEmailFailureResponse(with: mocks.client, email: email)
        mocks.subscriptionExecutor.enqueueDelta(OSDelta(name: OS_ADD_SUBSCRIPTION_DELTA, identityModelId: user.identityModel.modelId, model: OSSubscriptionModel(type: .email, address: email, subscriptionId: nil, reachable: true, isDisabled: false, changeNotifier: OSEventProducer()), property: OSSubscriptionType.email.rawValue, value: email))

        var invalidatedCallbackWasCalled = false
        OneSignalUserManagerImpl.sharedInstance.User.onJwtInvalidated { _ in
            invalidatedCallbackWasCalled = true
        }

        /* When */
        mocks.subscriptionExecutor.processDeltaQueue(inBackground: false)
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)

        /* Then */
        XCTAssertTrue(mocks.client.hasExecutedRequestOfType(OSRequestCreateSubscription.self))
        XCTAssertTrue(invalidatedCallbackWasCalled)
    }

    func testDeleteEmail_IdentityVerificationRequired_withInvalidToken() {
        /* Setup */
        let mocks = Mocks()
        mocks.setAuthRequired(true)
        OneSignalUserManagerImpl.sharedInstance.operationRepo.paused = true

        let user = mocks.setUserManagerInternalUser(externalId: userA_EUID, onesignalId: userA_OSID)
        user.identityModel.jwtBearerToken = userA_InvalidJwtToken
        let email = userA_email
        MockUserRequests.setUnauthorizedRemoveEmailFailureResponse(with: mocks.client, email: email)
        mocks.subscriptionExecutor.enqueueDelta(OSDelta(name: OS_REMOVE_SUBSCRIPTION_DELTA, identityModelId: user.identityModel.modelId, model: OSSubscriptionModel(type: .email, address: email, subscriptionId: testEmailSubId, reachable: true, isDisabled: false, changeNotifier: OSEventProducer()), property: OSSubscriptionType.email.rawValue, value: email))

        var invalidatedCallbackWasCalled = false
        OneSignalUserManagerImpl.sharedInstance.User.onJwtInvalidated { _ in
            invalidatedCallbackWasCalled = true
        }

        /* When */
        mocks.subscriptionExecutor.processDeltaQueue(inBackground: false)
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)

        /* Then */
        XCTAssertTrue(mocks.client.hasExecutedRequestOfType(OSRequestDeleteSubscription.self))
        XCTAssertTrue(invalidatedCallbackWasCalled)
    }

    func testCreateSubscriptionRequests_Retry_OnTokenUpdate() {
        /* Setup */
        let mocks = Mocks()
        mocks.setAuthRequired(true)
        OneSignalUserManagerImpl.sharedInstance.operationRepo.paused = true

        let user = mocks.setUserManagerInternalUser(externalId: userA_EUID, onesignalId: userA_OSID)
        user.identityModel.jwtBearerToken = userA_InvalidJwtToken

        // We need to use the user manager's executor because the onJWTUpdated callback won't fire on the mock executor
        let executor = OneSignalUserManagerImpl.sharedInstance.subscriptionExecutor!

        let email = userA_email
        MockUserRequests.setUnauthorizedAddEmailFailureResponse(with: mocks.client, email: email)
        executor.enqueueDelta(OSDelta(name: OS_ADD_SUBSCRIPTION_DELTA, identityModelId: user.identityModel.modelId, model: OSSubscriptionModel(type: .email, address: email, subscriptionId: nil, reachable: true, isDisabled: false, changeNotifier: OSEventProducer()), property: OSSubscriptionType.email.rawValue, value: email))

        var invalidatedCallbackWasCalled = false
        OneSignalUserManagerImpl.sharedInstance.User.onJwtInvalidated { _ in
            invalidatedCallbackWasCalled = true
            MockUserRequests.setAddEmailResponse(with: mocks.client, email: email)
            OneSignalUserManagerImpl.sharedInstance.updateUserJwt(externalId: userA_EUID, token: userA_ValidJwtToken)
        }

        /* When */
        executor.processDeltaQueue(inBackground: false)
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)

        /* Then */
        XCTAssertTrue(mocks.client.hasExecutedRequestOfType(OSRequestCreateSubscription.self))
        XCTAssertTrue(invalidatedCallbackWasCalled)
        XCTAssertEqual(mocks.client.networkRequestCount, 2)
    }

    func testCreateSubscriptionRequests_RetryRequests_OnTokenUpdate_ForOnlyUpdatedUser() {
        /* Setup */
        let mocks = Mocks()
        mocks.setAuthRequired(true)

        let userA = mocks.setUserManagerInternalUser(externalId: userA_EUID, onesignalId: userA_OSID)
        userA.identityModel.jwtBearerToken = userA_InvalidJwtToken

        let userB = mocks.setUserManagerInternalUser(externalId: userB_EUID, onesignalId: userB_OSID)
        userB.identityModel.jwtBearerToken = userA_InvalidJwtToken

        // We need to use the user manager's executor because the onJWTUpdated callback won't fire on the mock executor
        let executor = OneSignalUserManagerImpl.sharedInstance.subscriptionExecutor!

        let email = userA_email
        MockUserRequests.setUnauthorizedAddEmailFailureResponse(with: mocks.client, email: email)

        executor.enqueueDelta(OSDelta(name: OS_ADD_SUBSCRIPTION_DELTA, identityModelId: userA.identityModel.modelId, model: OSSubscriptionModel(type: .email, address: email, subscriptionId: nil, reachable: true, isDisabled: false, changeNotifier: OSEventProducer()), property: OSSubscriptionType.email.rawValue, value: email))
        executor.enqueueDelta(OSDelta(name: OS_ADD_SUBSCRIPTION_DELTA, identityModelId: userB.identityModel.modelId, model: OSSubscriptionModel(type: .email, address: email, subscriptionId: nil, reachable: true, isDisabled: false, changeNotifier: OSEventProducer()), property: OSSubscriptionType.email.rawValue, value: email))

        var invalidatedCallbackWasCalled = false
        OneSignalUserManagerImpl.sharedInstance.User.onJwtInvalidated { _ in
            invalidatedCallbackWasCalled = true
        }

        /* When */
        executor.processDeltaQueue(inBackground: false)
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)

        OneSignalUserManagerImpl.sharedInstance.updateUserJwt(externalId: userB_EUID, token: userB_ValidJwtToken)

        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)

        /* Then */
        // The executor should execute this request since identity verification is required and the token was set
        XCTAssertTrue(mocks.client.hasExecutedRequestOfType(OSRequestCreateSubscription.self))
        XCTAssertTrue(invalidatedCallbackWasCalled)
        let addRequests = mocks.client.executedRequests.filter { request in
            request.isKind(of: OSRequestCreateSubscription.self)
        }

        XCTAssertEqual(addRequests.count, 3)
    }

    func testDeleteSubscriptionRequests_RetryRequests_OnTokenUpdate_ForOnlyUpdatedUser() {
        /* Setup */
        let mocks = Mocks()
        mocks.setAuthRequired(true)

        let userA = mocks.setUserManagerInternalUser(externalId: userA_EUID, onesignalId: userA_OSID)
        userA.identityModel.jwtBearerToken = userA_InvalidJwtToken

        let userB = mocks.setUserManagerInternalUser(externalId: userB_EUID, onesignalId: userB_OSID)
        userB.identityModel.jwtBearerToken = userA_InvalidJwtToken

        // We need to use the user manager's executor because the onJWTUpdated callback won't fire on the mock executor
        let executor = OneSignalUserManagerImpl.sharedInstance.subscriptionExecutor!

        let email = userA_email
        MockUserRequests.setUnauthorizedRemoveEmailFailureResponse(with: mocks.client, email: email)

        executor.enqueueDelta(OSDelta(name: OS_REMOVE_SUBSCRIPTION_DELTA, identityModelId: userA.identityModel.modelId, model: OSSubscriptionModel(type: .email, address: email, subscriptionId: UUID().uuidString, reachable: true, isDisabled: false, changeNotifier: OSEventProducer()), property: OSSubscriptionType.email.rawValue, value: email))
        executor.enqueueDelta(OSDelta(name: OS_REMOVE_SUBSCRIPTION_DELTA, identityModelId: userB.identityModel.modelId, model: OSSubscriptionModel(type: .email, address: email, subscriptionId: UUID().uuidString, reachable: true, isDisabled: false, changeNotifier: OSEventProducer()), property: OSSubscriptionType.email.rawValue, value: email))

        var invalidatedCallbackWasCalled = false
        OneSignalUserManagerImpl.sharedInstance.User.onJwtInvalidated { _ in
            invalidatedCallbackWasCalled = true
        }

        /* When */
        executor.processDeltaQueue(inBackground: false)
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)

        OneSignalUserManagerImpl.sharedInstance.updateUserJwt(externalId: userB_EUID, token: userB_ValidJwtToken)

        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)

        /* Then */
        // The executor should execute this request since identity verification is required and the token was set
        XCTAssertTrue(mocks.client.hasExecutedRequestOfType(OSRequestDeleteSubscription.self))
        XCTAssertTrue(invalidatedCallbackWasCalled)
        let deleteRequests = mocks.client.executedRequests.filter { request in
            request.isKind(of: OSRequestDeleteSubscription.self)
        }

        XCTAssertEqual(deleteRequests.count, 3)
    }
}
