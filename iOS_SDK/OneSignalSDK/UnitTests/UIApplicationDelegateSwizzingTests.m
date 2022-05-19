#import <objc/runtime.h>
#import <UIKit/UIApplication.h>

#import <XCTest/XCTest.h>

#import "UnitTestCommonMethods.h"
#import "TestHelperFunctions.h"

@interface AppDelegateForAddsMissingSelectorsTest : UIResponder<UIApplicationDelegate>
@end
@implementation AppDelegateForAddsMissingSelectorsTest
@end

@interface UIApplicationDelegateSwizzingTest : XCTestCase
@end

@implementation UIApplicationDelegateSwizzingTest

// Called BEFORE each test method
- (void)setUp {
    [super setUp];
    [UnitTestCommonMethods beforeEachTest:self];
}

// Called AFTER each test method
- (void)tearDown {
    [super tearDown];
}

- (void)testAddsMissingSelectors {
    id myAppDelegate = [AppDelegateForAddsMissingSelectorsTest new];
    UIApplication.sharedApplication.delegate = myAppDelegate;
    
    XCTAssertTrue([myAppDelegate respondsToSelector:
       @selector(application:didReceiveRemoteNotification:fetchCompletionHandler:)]);
    XCTAssertTrue([myAppDelegate respondsToSelector:
       @selector(application:didFailToRegisterForRemoteNotificationsWithError:)]);
    XCTAssertTrue([myAppDelegate respondsToSelector:
       @selector(application:didRegisterForRemoteNotificationsWithDeviceToken:)]);
    XCTAssertTrue([myAppDelegate respondsToSelector:
       @selector(applicationWillTerminate:)]);
    
    // Ensure we fail this test if we swizzle a new selector and we forget to update this test.
    unsigned int methodCount = 0;
    class_copyMethodList(AppDelegateForAddsMissingSelectorsTest.class, &methodCount);
    XCTAssertEqual(methodCount, 4);
}
