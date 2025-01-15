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
@testable import OneSignalInAppMessages
import OneSignalOSCore
import OneSignalUser
import OneSignalUserMocks
import OneSignalCoreMocks
import OneSignalInAppMessagesMocks

/**
 These tests include InAppMessagingIntegrationTests migrations.
 */
final class IAMIntegrationTests: XCTestCase {

    override func setUpWithError() throws {
        OneSignalCoreMocks.clearUserDefaults()
        OneSignalUserMocks.reset()
        OSConsistencyManager.shared.reset()

    }

    override func tearDownWithError() throws { }

    func testExample() throws {
        // Temp. logging to help debug during testing
        OneSignalLog.setLogLevel(.LL_VERBOSE)
        
        // App ID is set because there are guards against nil App ID
        OneSignalConfigManager.setAppId("test-app-id")

        
        /* Setup */
        let client = MockOneSignalClient()
        
        // 1. Set up mock responses for the anonymous user, as the user needs an OSID
        MockUserRequests.setDefaultCreateAnonUserResponses(with: client)
        
        // 2. Set up mock responses for fetch IAMs
        let message = IAMTestHelpers.testMessageJsonWithTrigger(property: OS_DYNAMIC_TRIGGER_KIND_SESSION_TIME, triggerId: "test_id1", type: 1, value: 10.0)
        let response = IAMTestHelpers.testRegistrationJsonWithMessages([message])
        
        client.setMockResponseForRequest(
            request: "<OSRequestGetInAppMessages from apps/test-app-id/subscriptions/foobar/iams>",
            response: response)
       
        OneSignalCoreImpl.setSharedClient(client)
        
        OneSignalUserManagerImpl.sharedInstance.start()
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 2.0)

//        OSMessagingController.sharedInstance().setInAppMessagingPaused(false)
//
        
        // Unblock the Consistency Manager to allow fetching of IAMs
        let id = "test_anon_user_onesignal_id"
        let key = OSIamFetchOffsetKey.userUpdate
        let rywToken = "123"
        let rywDelay: NSNumber = 0
        let rywData = OSReadYourWriteData(rywToken: rywToken, rywDelay: rywDelay)
        OSConsistencyManager.shared.setRywTokenAndDelay(id: id, key: key, value: rywData)
        
        
        print("🥑 calling get")
        OSMessagingController.sharedInstance().getInAppMessages(fromServer: "foobar")
        
        
        
        
        
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 2)

    }
    
    /*
    
    func testDisablingIAMs_stillCreatesMessageQueue_butPreventsMessageDisplay() throws {
        // 1. Make a test message with OS_DYNAMIC_TRIGGER_KIND_SESSION_TIME, id of "test_id1", and OSTriggerOperatorTypeLessThan 10.0
        
        // 2. Make a get IAM response
        
        // OSTriggerOperatorTypeLessThan
        let message = InAppTestHelpers.testMessageJsonWithTrigger(property: OS_DYNAMIC_TRIGGER_KIND_SESSION_TIME, triggerId: "test_id1", type: .lessThan, value: 10.0)
        // let registrationResponse = InAppMessagingHelpers.testRegistrationJson(withMessages: [message])

        // x. this should prevent message from being shown
        OSMessagingController.sharedInstance().setInAppMessagingPaused(true)
        
        // the trigger should immediately evaluate to true and should
        // be shown once the SDK is fully initialized.
        [OneSignalClientOverrider setMockResponseForRequest:NSStringFromClass([OSRequestRegisterUser class]) withResponse:registrationResponse];
    }
     */
    
    func testDisablingIAMs_doesNotCreateMessageQueue() throws {
        // Temp. logging to help debug during testing
        OneSignalLog.setLogLevel(.LL_VERBOSE)
        
        // App ID is set because there are guards against nil App ID
        OneSignalConfigManager.setAppId("test-app-id")
        let client = MockOneSignalClient()

        // 1. Set up mock responses for the anonymous user, as the user needs an OSID
        MockUserRequests.setDefaultCreateAnonUserResponses(with: client)
        
        let message = IAMTestHelpers.testMessageJsonWithTrigger(property: OS_DYNAMIC_TRIGGER_KIND_SESSION_TIME, triggerId: "test_id1", type: 1, value: 10.0)
        let response = IAMTestHelpers.testRegistrationJsonWithMessages([message])
        // this should prevent message from being shown
        OSMessagingController.sharedInstance().setInAppMessagingPaused(true)
        

        // the trigger should immediately evaluate to true and should
        // be shown once the SDK is fully initialized.
        client.setMockResponseForRequest(
            request: "<OSRequestGetInAppMessages from apps/test-app-id/subscriptions/foobar/iams>",
            response: response)
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 2)

        
        // Unblock the Consistency Manager to allow fetching of IAMs
        let id = "test_anon_user_onesignal_id"
        let key = OSIamFetchOffsetKey.userUpdate
        let rywToken = "123"
        let rywDelay: NSNumber = 0
        let rywData = OSReadYourWriteData(rywToken: rywToken, rywDelay: rywDelay)
        OSConsistencyManager.shared.setRywTokenAndDelay(id: id, key: key, value: rywData)
        
        OneSignalCoreImpl.setSharedClient(client)
        
        OneSignalUserManagerImpl.sharedInstance.start()
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 2)
        print("🥑 calling get")

        OSMessagingController.sharedInstance().getInAppMessages(fromServer: "foobar")
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 2)


        print("💛 message queue is \(IAMObjcTestHelpers.messageDisplayQueue())")
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 2)

        // Make sure no IAM is showing, but the queue has any IAMs
        XCTAssertFalse(OSMessagingController.sharedInstance().isInAppMessageShowing)
        //XCTAssertEqual(OSMessagingController.sharedInstance().messageDisplayQueue.count, 1)
        XCTAssertEqual(IAMObjcTestHelpers.messageDisplayQueue().count, 0);

    }
}




