import XCTest
import OneSignalCoreMocks
import OneSignalUserMocks

final class NewUnitTests: XCTestCase {

    // TODO: These are copied over from existing UnitTests.m, decide what to keep...
    override func setUpWithError() throws {
        OneSignalCore.setSharedClient(MockOneSignalClient())
        UnitTestCommonMethods.beforeEachTest(self)
        OneSignalOverrider.shouldOverrideLaunchURL = false
        
        // Only enable remote-notifications in UIBackgroundModes
        NSBundleOverrider.setNsbundleDictionary(["UIBackgroundModes": ["remote-notification"]])
        
        // Clear last location stored
        OneSignalLocation.clearLast()
        
        OneSignalHelperOverrider.setMockIOSVersion(10)
        
        OneSignalHelperOverrider.reset()
        
        UIDeviceOverrider.reset()
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testBasicInit() throws {
        // Simulator iPhone
        print("iOS VERSION: \(UIDevice.current.systemVersion)")
        
        // 1. Set up mock responses
        OneSignalUserMocks.setMockCreateUserResponse()
        OneSignalUserMocks.setMockFetchUserResponse(externalId: "nil")
        
        // 2. Initialize OneSignal
        OneSignal.Debug.setLogLevel(.LL_VERBOSE)
        UnitTestCommonMethods.initOneSignal_andThreadWait()
        
        // 3. Check for values in request payload such as notification_types, app_id, token, etc.
        // Checks the HTTP request for app_id, language, etc.
        // This would be the CreateUser request
        let deviceModel = OSDeviceUtils.getDeviceVariant()
        
        XCTAssertTrue(OneSignal.Notifications.permission)
        
        print("🔥 executedRequests \(OneSignalCoreMocks.getClient().executedRequests)")
        
        // Expected requests made:
        // 1. OSRequestGetIosParams
        // 2. OSRequestCreateUser
        // 3. OSRequestGetInAppMessages
        // 4. OSRequestUpdateProperties
        // 5. OSRequestUpdateSubscription
        let requestCount = OneSignalCoreMocks.getClient().networkRequestCount
        XCTAssertGreaterThanOrEqual(requestCount, 5)
        
        // 2nd init call should not fire another additional requests
        UnitTestCommonMethods.initOneSignal_andThreadWait()
        XCTAssertEqual(OneSignalCoreMocks.getClient().networkRequestCount, requestCount);
        
        print("🔥 Test is technically done")
    }
      
    // Login to an external_id that does not exist
    func testLoginToNewExternalId() throws {
        // 1. Set up mock responses
        OneSignalUserMocks.setMockCreateUserResponse()
        OneSignalUserMocks.setMockFetchUserResponse(externalId: nil)

        // 2. Initialize OneSignal
        OneSignal.Debug.setLogLevel(.LL_VERBOSE)
        UnitTestCommonMethods.initOneSignal_andThreadWait()
        let requestCount = OneSignalCoreMocks.getClient().networkRequestCount
        
        // 3. Set up mock responses for the login
        OneSignalUserMocks.setMockIdentifyUserRequest(externalId: "my-external-id")
        OneSignalUserMocks.setMockFetchUserResponse(externalId: "my-external-id")

        // 4. Login with an external id
        OneSignal.login("my-external-id")
        UnitTestCommonMethods.runBackgroundThreads()

        // 5. Expect requests OSRequestIdentifyUser and OSRequestFetchUser
        print("🔥 executedRequests \(OneSignalCoreMocks.getClient().executedRequests)")
        XCTAssertEqual(OneSignalCoreMocks.getClient().networkRequestCount, requestCount + 2)
        let num = 15.4
        let other = 15.4
        XCTAssertTrue(num == other)
    }
}
