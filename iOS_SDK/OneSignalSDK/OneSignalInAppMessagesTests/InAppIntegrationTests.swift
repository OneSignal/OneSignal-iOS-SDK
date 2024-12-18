@testable import OneSignalInAppMessages
@_implementationOnly import OneSignalInAppMessagesMocks
import OneSignalCoreMocks
import XCTest

/**
 InAppMessagingIntegrationTests migrations
 */
final class IAMIntegrationTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testDisablingIAMs_stillCreatesMessageQueue_butPreventsMessageDisplay() throws {
        // Temp. logging to help debug during testing
        OneSignalLog.setLogLevel(.LL_VERBOSE)
        print("💛 hello world")
        let message = InAppTestHelpers.testMessageJsonWithTrigger(property: OS_DYNAMIC_TRIGGER_KIND_SESSION_TIME, triggerId: "test_id1", type: .lessThan, value: 10.0)
        // let registrationResponse = InAppMessagingHelpers.testRegistrationJson(withMessages: [message])

        let fetchIamResponse = InAppTestHelpers.testRegistrationJsonWithMessages([message])
        
        
        // this should prevent message from being shown
     OneSignalInAppMessages.isPaused = true
        
        // the trigger should immediately evaluate to true and should
        // be shown once the SDK is fully initialized.
        let client = MockOneSignalClient()
        client.setMockResponseForRequest(
            request: "<OSRequestGetInAppMessages>",
            response: [String: Any]()
        )
        
        
        
//    OSMessagingController.sharedInstance().getInAppMessages(fromServer: "subscription_id")
        
        // [UnitTestCommonMethods initOneSignal_andThreadWait];


    }

    /*
    - (void)testDisablingIAMs_stillCreatesMessageQueue_butPreventsMessageDisplay { // 💛
        let message = [OSInAppMessageTestHelper testMessageJsonWithTriggerPropertyName:OS_DYNAMIC_TRIGGER_KIND_SESSION_TIME withId:@"test_id1" withOperator:OSTriggerOperatorTypeLessThan withValue:@10.0];
        let registrationResponse = [OSInAppMessageTestHelper testRegistrationJsonWithMessages:@[message]];
       
        // this should prevent message from being shown
        [OneSignal pauseInAppMessages:true];
       
        // the trigger should immediately evaluate to true and should
        // be shown once the SDK is fully initialized.
        [OneSignalClientOverrider setMockResponseForRequest:NSStringFromClass([OSRequestRegisterUser class]) withResponse:registrationResponse];

        [UnitTestCommonMethods initOneSignal_andThreadWait];
       
        // Make sure no IAM is showing, but the queue has any IAMs
        XCTAssertFalse(OSMessagingControllerOverrider.isInAppMessageShowing);
        XCTAssertEqual(OSMessagingControllerOverrider.messageDisplayQueue.count, 1);
    }
     */

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
