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
    var identityExecutor: OSIdentityOperationExecutor!

    override init() {
        super.init()
        identityExecutor = OSIdentityOperationExecutor(newRecordsState: newRecordsState, jwtConfig: jwtConfig)
    }
}

final class IdentityExecutorTests: XCTestCase {

    override func setUpWithError() throws {
        OneSignalCoreMocks.clearUserDefaults()
        OneSignalUserMocks.reset()
        // App ID is set because requests have guards against null App ID
        OneSignalConfigManager.setAppId("test-app-id")
        // Temp. logging to help debug during testing
        OneSignalLog.setLogLevel(.LL_VERBOSE)
    }

    override func tearDownWithError() throws { }
    
    func testAddAliasSendsWhenProcessed() {
        /* Setup */
        let mocks = Mocks()
        mocks.setAuthRequired(false)
        OneSignalUserManagerImpl.sharedInstance.operationRepo.paused = true
        
        let user = mocks.setUserManagerInternalUser(externalId: userA_EUID, onesignalId: userA_OSID)
        let aliases = userA_Aliases
        MockUserRequests.setAddAliasesResponse(with: mocks.client, aliases: aliases)
        mocks.identityExecutor.enqueueDelta(OSDelta(name: OS_ADD_ALIAS_DELTA, identityModelId: user.identityModel.modelId, model: user.identityModel, property: "aliases", value:aliases))

        /* When */
        mocks.identityExecutor.processDeltaQueue(inBackground: false)
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)
        
        /* Then */
        XCTAssertTrue(mocks.client.hasExecutedRequestOfType(OSRequestAddAliases.self))
    }
    
    func testAddAlias_IdentityVerificationRequired_butNoToken() {
        /* Setup */
        let mocks = Mocks()
        mocks.setAuthRequired(true)
        OneSignalUserManagerImpl.sharedInstance.operationRepo.paused = true
        
        let user = mocks.setUserManagerInternalUser(externalId: userA_EUID, onesignalId: userA_OSID)
        let aliases = userA_Aliases
        MockUserRequests.setAddAliasesResponse(with: mocks.client, aliases: aliases)
        mocks.identityExecutor.enqueueDelta(OSDelta(name: OS_ADD_ALIAS_DELTA, identityModelId: user.identityModel.modelId, model: user.identityModel, property: "aliases", value:aliases))

        /* When */
        mocks.identityExecutor.processDeltaQueue(inBackground: false)
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)
        
        /* Then */
        XCTAssertFalse(mocks.client.hasExecutedRequestOfType(OSRequestAddAliases.self))
    }
    
    func testAddAlias_IdentityVerificationRequired_withToken() {
        /* Setup */
        let mocks = Mocks()
        mocks.setAuthRequired(true)
        OneSignalUserManagerImpl.sharedInstance.operationRepo.paused = true
        
        let user = mocks.setUserManagerInternalUser(externalId: userA_EUID, onesignalId: userA_OSID)
        user.identityModel.jwtBearerToken = userA_JwtToken
        let aliases = userA_Aliases
        MockUserRequests.setAddAliasesResponse(with: mocks.client, aliases: aliases)
        mocks.identityExecutor.enqueueDelta(OSDelta(name: OS_ADD_ALIAS_DELTA, identityModelId: user.identityModel.modelId, model: user.identityModel, property: "aliases", value:aliases))

        /* When */
        mocks.identityExecutor.processDeltaQueue(inBackground: false)
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)
        
        /* Then */
        XCTAssertTrue(mocks.client.hasExecutedRequestOfType(OSRequestAddAliases.self))
    }
    
    func testAddAlias_IdentityVerificationRequired_withInvalidToken_firesCallback() {
        /* Setup */
        let mocks = Mocks()
        mocks.setAuthRequired(true)
        OneSignalUserManagerImpl.sharedInstance.operationRepo.paused = true
        
        let user = mocks.setUserManagerInternalUser(externalId: userA_EUID, onesignalId: userA_OSID)
        user.identityModel.jwtBearerToken = userA_JwtToken
        let aliases = userA_Aliases
        MockUserRequests.setUnauthorizedAddAliasFailureResponse(with: mocks.client, aliases: aliases)
        mocks.identityExecutor.enqueueDelta(OSDelta(name: OS_ADD_ALIAS_DELTA, identityModelId: user.identityModel.modelId, model: user.identityModel, property: "aliases", value:aliases))
        
        var invalidatedCallbackWasCalled = false
        OneSignalUserManagerImpl.sharedInstance.User.onJwtInvalidated { event in
            XCTAssertTrue(event.message == "token has invalid claims: token is expired")
            invalidatedCallbackWasCalled = true
        }

        /* When */
        mocks.identityExecutor.processDeltaQueue(inBackground: false)
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)
        
        /* Then */
        XCTAssertTrue(mocks.client.hasExecutedRequestOfType(OSRequestAddAliases.self))
        XCTAssertTrue(invalidatedCallbackWasCalled)
    }
    
    func testRemoveAlias_IdentityVerificationRequired_withInvalidToken_firesCallback() {
        /* Setup */
        let mocks = Mocks()
        mocks.setAuthRequired(true)
        OneSignalUserManagerImpl.sharedInstance.operationRepo.paused = true
        
        let user = mocks.setUserManagerInternalUser(externalId: userA_EUID, onesignalId: userA_OSID)
        user.identityModel.jwtBearerToken = userA_JwtToken
        let aliases = userA_Aliases
        MockUserRequests.setUnauthorizedRemoveAliasFailureResponse(with: mocks.client, aliasLabel: userA_AliasLabel)
        mocks.identityExecutor.enqueueDelta(OSDelta(name: OS_REMOVE_ALIAS_DELTA, identityModelId: user.identityModel.modelId, model: user.identityModel, property: "aliases", value:aliases))
        
        var invalidatedCallbackWasCalled = false
        OneSignalUserManagerImpl.sharedInstance.User.onJwtInvalidated { event in
            XCTAssertTrue(event.message == "token has invalid claims: token is expired")
            invalidatedCallbackWasCalled = true
        }

        /* When */
        mocks.identityExecutor.processDeltaQueue(inBackground: false)
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)
        
        /* Then */
        XCTAssertTrue(mocks.client.hasExecutedRequestOfType(OSRequestRemoveAlias.self))
        XCTAssertTrue(invalidatedCallbackWasCalled)
    }
    
    
}
