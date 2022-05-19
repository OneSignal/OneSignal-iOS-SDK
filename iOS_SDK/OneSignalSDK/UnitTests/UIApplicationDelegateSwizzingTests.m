#import <objc/runtime.h>
#import <UIKit/UIApplication.h>

#import <XCTest/XCTest.h>

#import "UnitTestCommonMethods.h"
#import "TestHelperFunctions.h"

@interface AppDelegateForAddsMissingSelectorsTest : UIResponder<UIApplicationDelegate>
@end
@implementation AppDelegateForAddsMissingSelectorsTest
@end

@interface AppDelegateForwardingTargetForSelectorTest : UIResponder<UIApplicationDelegate>
@end
@implementation AppDelegateForwardingTargetForSelectorTest {
    id forwardingInstance;
}
- (instancetype)initForwardingTarget:(id)forwardingTarget {
    self = [super init];
    forwardingInstance = forwardingTarget;
    return self;
}

- (id)forwardingTargetForSelector:(SEL)selector {
    return forwardingInstance;
}
@end

@interface AppDelegateForwardReceiver : UIResponder<UIApplicationDelegate> {
    @public NSMutableDictionary *selectorCallsDict;
}
@end
@implementation AppDelegateForwardReceiver

- (instancetype)init {
    self = [super init];
    selectorCallsDict = [NSMutableDictionary new];
    return self;
}

- (void)application:(UIApplication *)application
        didReceiveRemoteNotification:(NSDictionary *)userInfo
        fetchCompletionHandler:(void (^)(UIBackgroundFetchResult result))completionHandler {
    SEL thisSelector = @selector(application:didReceiveRemoteNotification:fetchCompletionHandler:);
    [selectorCallsDict
       setObject:@(true)
       forKey:NSStringFromSelector(thisSelector)
    ];
}
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

- (void)testForwardingTargetForSelector {
    AppDelegateForwardReceiver *receiver = [AppDelegateForwardReceiver new];
    id myAppDelegate = [[AppDelegateForwardingTargetForSelectorTest alloc]
                        initForwardingTarget:receiver];
    UIApplication.sharedApplication.delegate = myAppDelegate;
    id<UIApplicationDelegate> appDelegate = UIApplication.sharedApplication.delegate;
    
    // Test application:didReceiveRemoteNotification:fetchCompletionHandler:
    [appDelegate
        application:UIApplication.sharedApplication
        didReceiveRemoteNotification:@{}
        fetchCompletionHandler:^(UIBackgroundFetchResult result){}];
    XCTAssertTrue([receiver->selectorCallsDict
        objectForKey:NSStringFromSelector(
            @selector(application:didReceiveRemoteNotification:fetchCompletionHandler:)
        )
    ]);
    
    // TODO: Will add the rest of the methods in a follow up commit.
}

@end
