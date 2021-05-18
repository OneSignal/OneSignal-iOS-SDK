#import <objc/runtime.h>

#import <XCTest/XCTest.h>

#import "UnitTestCommonMethods.h"
#import "OneSignalExtensionBadgeHandler.h"
#import "UNUserNotificationCenterOverrider.h"
#import "UNUserNotificationCenter+OneSignal.h"
#import "OneSignalHelperOverrider.h"
#import "OneSignalHelper.h"
#import "DummyNotificationCenterDelegate.h"
#import "OneSignalUNUserNotificationCenterHelper.h"

@interface OneSignalUNUserNotificationCenterSwizzingTest : XCTestCase
@end

@implementation OneSignalUNUserNotificationCenterSwizzingTest

// Called BEFORE each test method
- (void)setUp {
    [super setUp];
    [UnitTestCommonMethods beforeEachTest:self];
    
    [OneSignalUNUserNotificationCenter setUseiOS10_2_workaround:true];
}

// Called AFTER each test method
- (void)tearDown {
    [super tearDown];
}

// Tests to make sure that UNNotificationCenter setDelegate: duplicate calls don't double-swizzle for the same object
- (void)testAUNUserNotificationCenterDelegateAssigningDoesSwizzle {
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];

    let dummyDelegate = [[DummyNotificationCenterDelegate alloc] init];

    IMP original = class_getMethodImplementation([dummyDelegate class], @selector(userNotificationCenter:didReceiveNotificationResponse:withCompletionHandler:));

    // This triggers UNUserNotificationCenter+OneSignal.m setOneSignalUNDelegate which does the implemenation swizzling
    center.delegate = dummyDelegate;

    IMP swizzled = class_getMethodImplementation([dummyDelegate class], @selector(userNotificationCenter:didReceiveNotificationResponse:withCompletionHandler:));
    // Since we swizzled the implemenations should be different.
    XCTAssertNotEqual(original, swizzled);

    // Calling setDelegate: a second time on the same object should not re-exchange method implementations
    // thus the new method implementation should still be the same, swizzled == newSwizzled should be true
    center.delegate = dummyDelegate;

    IMP newSwizzled = class_getMethodImplementation([dummyDelegate class], @selector(userNotificationCenter:didReceiveNotificationResponse:withCompletionHandler:));

    XCTAssertEqual(swizzled, newSwizzled);

    [OneSignalUNUserNotificationCenterHelper restoreDelegateAsOneSignal];
}

- (void)testUNUserNotificationCenterDelegateAssignedBeforeOneSignal {
    [OneSignalUNUserNotificationCenterHelper putIntoPreloadedState];

    // Create and assign a delegate with iOS
    let dummyDelegate = [DummyNotificationCenterDelegate new];
    UNUserNotificationCenter.currentNotificationCenter.delegate = dummyDelegate;
    
    // Save original implemenation reference, before OneSignal is loaded.
    IMP originalDummyImp = class_getMethodImplementation([dummyDelegate class], @selector(userNotificationCenter:didReceiveNotificationResponse:withCompletionHandler:));

    // Setup the OneSignal delegate where it will be loaded into memeory
    [OneSignalUNUserNotificationCenter setup];

    IMP swizzledDummyImp = class_getMethodImplementation([dummyDelegate class], @selector(userNotificationCenter:didReceiveNotificationResponse:withCompletionHandler:));
    
    // Since we swizzled the implemenations should be different.
    XCTAssertNotEqual(originalDummyImp, swizzledDummyImp);
    
    [OneSignalUNUserNotificationCenterHelper restoreDelegateAsOneSignal];
}

@end
