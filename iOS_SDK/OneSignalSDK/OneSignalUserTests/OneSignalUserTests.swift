/*
 Modified MIT License

 Copyright 2023 OneSignal

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
import OneSignalCoreMocks
import OneSignalCore // TODO: Can we omit this import and rely only on OneSignalCoreMocks?
import OneSignalOSCore
@testable import OneSignalUser

final class OneSignalUserTests: XCTestCase {

    override func setUpWithError() throws {
        // [UnitTestCommonMethods beforeEachTest:self];
        OneSignalCore.setSharedClient(MockOneSignalClient())
        OneSignalConfigManager.setAppId("test-app-id")
        OneSignalCoreMocks.clearUserDefaults()
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    // Comparable to Android test: externalId is backed by the identity model
    func testLoginSetsExternalId() throws {
        /* When */
        OneSignalUserManagerImpl.sharedInstance.login(externalId: "my-external-id", token: nil)
        
        /* Then */
        let identityModelStoreExternalId = OneSignalUserManagerImpl.sharedInstance.identityModelStore.getModel(key: OS_IDENTITY_MODEL_KEY)?.externalId
        let userInstanceExternalId = OneSignalUserManagerImpl.sharedInstance.user.identityModel.externalId
        
        XCTAssertEqual(identityModelStoreExternalId, "my-external-id")
        XCTAssertEqual(userInstanceExternalId, "my-external-id")
    }

    func testAddAlias_setsCorrectly_andEnqueuesDelta() throws {
        OneSignalLog.setLogLevel(.LL_VERBOSE)
        
        OneSignalUserManagerImpl.sharedInstance.addAlias(label: "my_alias_label", id: "my_alias_id")
        let aliases = OneSignalUserManagerImpl.sharedInstance.user.identityModel.aliases
        
        XCTAssertEqual(aliases["my_alias_label"], "my_alias_id")
        print("🔥 \(aliases)")
    
        // on the identity model
        // in the request payload to be sent
        // OSOperationRepo.sharedInstance.deltaQueue.count
    }

    func testAddAlias_usingLabelOneSignalId_isNotAllowed() throws {
        OneSignalUserManagerImpl.sharedInstance.addAlias(label: "onesignal_id", id: "my_onesignal_id")
        let aliases = OneSignalUserManagerImpl.sharedInstance.user.identityModel.aliases
        print("🔥 \(aliases)")
    }
    
    func testAddAlias_usingLabelExternalId_isNotAllowed() throws {
        OneSignalUserManagerImpl.sharedInstance.addAlias(label: "external_id", id: "my_external_id")
        let aliases = OneSignalUserManagerImpl.sharedInstance.user.identityModel.aliases
        print(aliases)

    }
    
    
    
    
    func testSomething() throws {
        OneSignalUserManagerImpl.sharedInstance.setLanguage("new-language")
        print("🔥 propertiesModel \(OneSignalUserManagerImpl.sharedInstance.user.propertiesModel.language)")
    }


}
