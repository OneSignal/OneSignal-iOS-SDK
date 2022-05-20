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

- (void)application:(UIApplication *)application
    didFailToRegisterForRemoteNotificationsWithError:(NSError*)err
{
    SEL thisSelector = @selector(application:didFailToRegisterForRemoteNotificationsWithError:);
    [selectorCallsDict
       setObject:@(true)
       forKey:NSStringFromSelector(thisSelector)
    ];
}

- (void)application:(UIApplication *)application
    didRegisterForRemoteNotificationsWithDeviceToken:(NSData*)data
{
    SEL thisSelector = @selector(application:didRegisterForRemoteNotificationsWithDeviceToken:);
    [selectorCallsDict
       setObject:@(true)
       forKey:NSStringFromSelector(thisSelector)
    ];
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    SEL thisSelector = @selector(applicationWillTerminate:);
    [selectorCallsDict
       setObject:@(true)
       forKey:NSStringFromSelector(thisSelector)
    ];
}

@end

@interface AppDelegateForInfiniteLoopTest : UIResponder<UIApplicationDelegate>
@end
@implementation AppDelegateForInfiniteLoopTest
@end

static id<UIApplicationDelegate> orignalDelegate;

@interface UIApplicationDelegateSwizzlingTest : XCTestCase
@end

@implementation UIApplicationDelegateSwizzlingTest

// Called once BEFORE -setUp
+ (void)setUp {
    [super setUp];
    orignalDelegate = UIApplication.sharedApplication.delegate;
}

// Called BEFORE each test method
- (void)setUp {
    [super setUp];
    [UnitTestCommonMethods beforeEachTest:self];
}

// Called AFTER each test method
- (void)tearDown {
    [super tearDown];
    UIApplication.sharedApplication.delegate = orignalDelegate;
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

    [appDelegate
        application:UIApplication.sharedApplication
        didReceiveRemoteNotification:@{}
        fetchCompletionHandler:^(UIBackgroundFetchResult result){}];
    XCTAssertTrue([receiver->selectorCallsDict
        objectForKey:NSStringFromSelector(
            @selector(application:didReceiveRemoteNotification:fetchCompletionHandler:)
        )
    ]);

    [appDelegate
        application:UIApplication.sharedApplication
        didFailToRegisterForRemoteNotificationsWithError:[NSError new]];
    XCTAssertTrue([receiver->selectorCallsDict
        objectForKey:NSStringFromSelector(
            @selector(application:didFailToRegisterForRemoteNotificationsWithError:)
        )
    ]);

    [appDelegate
        application:UIApplication.sharedApplication
        didRegisterForRemoteNotificationsWithDeviceToken:[NSData new]];
    XCTAssertTrue([receiver->selectorCallsDict
        objectForKey:NSStringFromSelector(
            @selector(application:didRegisterForRemoteNotificationsWithDeviceToken:)
        )
    ]);

    [appDelegate
        applicationWillTerminate:UIApplication.sharedApplication];
    XCTAssertTrue([receiver->selectorCallsDict
        objectForKey:NSStringFromSelector(
            @selector(applicationWillTerminate:)
        )
    ]);
}

- (void)testDoubleSwizzleInfiniteLoop {
    // 1. Save original delegate
    id<UIApplicationDelegate> localOrignalDelegate = UIApplication.sharedApplication.delegate;
    
    // 2. Create a new delegate and assign it
    id myAppDelegate = [AppDelegateForInfiniteLoopTest new];
    UIApplication.sharedApplication.delegate = myAppDelegate;
    
    // 3. Put the original delegate back
    UIApplication.sharedApplication.delegate = localOrignalDelegate;
    
    // 4. Call something to confirm we don't get stuck in an infinite call loop
    [localOrignalDelegate applicationWillTerminate:UIApplication.sharedApplication];
}
@end
