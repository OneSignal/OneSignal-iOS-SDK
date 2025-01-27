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
import OneSignalCoreMocks
import OneSignalOSCoreMocks
import OneSignalUserMocks
import OneSignalInAppMessagesMocks

/**
 These tests can include some Obj-C InAppMessagingIntegrationTests migrations.
 */
final class IAMIntegrationTests: XCTestCase {
    override func setUpWithError() throws {
        OneSignalCoreMocks.clearUserDefaults()
        OneSignalUserMocks.reset()
        OSConsistencyManager.shared.reset()
        // Temp. logging to help debug during testing
        OneSignalLog.setLogLevel(.LL_VERBOSE)
    }

    override func tearDownWithError() throws { }
    
    /**
     Pausing IAMs will not evaluate messages.
     */
    func testPausingIAMs_doesNotCreateMessageQueue() throws {
        /* Setup */
        
        let client = MockOneSignalClient()
        OneSignalCoreImpl.setSharedClient(client)
        
        // 1. App ID is set because there are guards against nil App ID
        OneSignalConfigManager.setAppId("test-app-id")

        // 2. Set up mock responses for the anonymous user, as the user needs an OSID
        MockUserRequests.setDefaultCreateAnonUserResponses(with: client)
        
        // 3. Set up mock responses for fetching IAMs
        let message = IAMTestHelpers.testMessageJsonWithTrigger(property: "session_time", triggerId: "test_id1", type: 1, value: 10.0)
        let response = IAMTestHelpers.testFetchMessagesResponse(messages: [message])
        client.setMockResponseForRequest(
            request: "<OSRequestGetInAppMessages from apps/test-app-id/subscriptions/\(testPushSubId)/iams>",
            response: response)

        // 4. Unblock the Consistency Manager to allow fetching of IAMs
        ConsistencyManagerHelpers.setDefaultRywToken(id: anonUserOSID)
        
        // 5. Pausing should prevent messages from being evaluated and shown
        OneSignalInAppMessages.__paused(true)
        
        // 6. Start the user manager to generate a user instance
        OneSignalUserManagerImpl.sharedInstance.start()
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)
        
        // 7. Fetch IAMs
        OneSignalInAppMessages.getFromServer(testPushSubId)
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)

        // Make sure no IAM is showing, and the queue has no IAMs
        XCTAssertFalse(MockMessagingController.isInAppMessageShowing())
        XCTAssertEqual(MockMessagingController.messageDisplayQueue().count, 0);
    }
}
