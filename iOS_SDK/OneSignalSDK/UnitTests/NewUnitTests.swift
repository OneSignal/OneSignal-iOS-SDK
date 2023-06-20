import XCTest
import OneSignalCoreMocks

final class NewUnitTests: XCTestCase {

    override func setUpWithError() throws {
        OneSignalCore.setSharedClient(MockOneSignalClient())
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    // Existing unit test
    func testBasicInitTest() throws {
        // Simulator iPhone
        print("iOS VERSION: \(UIDevice.current.systemVersion)")
        OneSignal.Debug.setLogLevel(.LL_VERBOSE)
        UnitTestCommonMethods.initOneSignal_andThreadWait()
        print("CHECKING LAST HTTP REQUEST")
        // TODO: unit-test-todo stil
        
        let deviceModel = OSDeviceUtils.getDeviceVariant()
        // Checks the HTTP request for app_id, language, etc.
        // This would be the CreateUser request
        // MockOneSignalClient.lastHTTPRequest = nil
        
        // 2nd init call should not fire another request.
        // UnitTestCommonMethods.initOneSignal()
        
        
        OneSignal.login("test-id")
        UnitTestCommonMethods.runBackgroundThreads()
        print("🔥 executedRequests \(OneSignalCoreMocks.getClient().executedRequests)")
        XCTAssertEqual(OneSignalCoreMocks.getClient().networkRequestCount, 2) // or 2 or whatever number other than 2
    }



}
