#import <objc/runtime.h>
#import <UIKit/UIApplication.h>

#import <XCTest/XCTest.h>

#import "UnitTestCommonMethods.h"
#import "TestHelperFunctions.h"
#import "OneSignalAppDelegateOverrider.h"

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

@interface AppDelegateForInfiniteLoopWithAnotherSwizzlerTest : UIResponder<UIApplicationDelegate>
@end
@implementation AppDelegateForInfiniteLoopWithAnotherSwizzlerTest
@end
@interface OtherLibraryASwizzler : NSObject
+(void)swizzleAppDelegate;
+(BOOL)selectorCalled;
@end
@implementation OtherLibraryASwizzler
static BOOL selectorCalled = false;
+(BOOL)selectorCalled {
    return selectorCalled;
}

+(void)swizzleAppDelegate
{
    swizzleExistingSelector(
        [UIApplication.sharedApplication.delegate class],
        @selector(applicationWillTerminate:),
        [self class],
        @selector(applicationWillTerminateLibraryA:)
    );
}
- (void)applicationWillTerminateLibraryA:(UIApplication *)application
{
    selectorCalled = true;
    // Standard basic swizzling forwarder another library may have.
    if ([self respondsToSelector:@selector(applicationWillTerminateLibraryA:)])
        [self applicationWillTerminateLibraryA:application];
}
@end

@interface AppDelegateForExistingSelectorsTest : UIResponder<UIApplicationDelegate> {
    @public NSMutableDictionary *selectorCallsDict;
}
@end
@implementation AppDelegateForExistingSelectorsTest
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

@interface AppDelegateForDepercatedDidReceiveRemoteNotificationTest : UIResponder<UIApplicationDelegate> {
    @public BOOL selectorCalled;
}
@end

@implementation AppDelegateForDepercatedDidReceiveRemoteNotificationTest
- (instancetype)init {
    self = [super init];
    selectorCalled = false;
    return self;
}
-(void)application:(UIApplication *)application
    didReceiveRemoteNotification:(NSDictionary *)userInfo
{
    selectorCalled = true;
}
@end


@interface AppDelegateBaseClassForMissingSelectorsTest : UIResponder<UIApplicationDelegate>
@end
@implementation AppDelegateBaseClassForMissingSelectorsTest
@end
@interface AppDelegateInheritsFromBaseMissingSelectorsTest : AppDelegateBaseClassForMissingSelectorsTest
@end
@implementation AppDelegateInheritsFromBaseMissingSelectorsTest
@end

@interface AppDelegateBaseClassForBaseHasSelectorTest : UIResponder<UIApplicationDelegate>
    @property (nonatomic, readwrite) BOOL selectorCalled;
@end
@implementation AppDelegateBaseClassForBaseHasSelectorTest
- (instancetype)init {
    self = [super init];
    _selectorCalled = false;
    return self;
}
- (void)application:(UIApplication *)application
        didReceiveRemoteNotification:(NSDictionary *)userInfo
        fetchCompletionHandler:(void (^)(UIBackgroundFetchResult result))completionHandler {
    _selectorCalled = true;
}
@end
@interface AppDelegateInhertisFromBaseClassForBaseHasSelectorTest : AppDelegateBaseClassForBaseHasSelectorTest
@end
@implementation AppDelegateInhertisFromBaseClassForBaseHasSelectorTest
@end

@interface AppDelegateBaseClassOnlyProtocol : UIResponder<UIApplicationDelegate>
@end
@implementation AppDelegateBaseClassOnlyProtocol
@end
@interface AppDelegateInhertisFromBaseButChildHasSelector : AppDelegateBaseClassOnlyProtocol
@property (nonatomic, readwrite) BOOL selectorCalled;
@end
@implementation AppDelegateInhertisFromBaseButChildHasSelector
- (instancetype)init {
    self = [super init];
    _selectorCalled = false;
    return self;
}
- (void)application:(UIApplication *)application
        didReceiveRemoteNotification:(NSDictionary *)userInfo
        fetchCompletionHandler:(void (^)(UIBackgroundFetchResult result))completionHandler {
    _selectorCalled = true;
}
@end

@interface AppDelegateBaseClassBothHaveSelectors : UIResponder<UIApplicationDelegate>
@property (nonatomic, readwrite) BOOL selectorCalledOnParent;
@end
@implementation AppDelegateBaseClassBothHaveSelectors
- (instancetype)init {
    self = [super init];
    _selectorCalledOnParent = false;
    return self;
}
- (void)application:(UIApplication *)application
        didReceiveRemoteNotification:(NSDictionary *)userInfo
        fetchCompletionHandler:(void (^)(UIBackgroundFetchResult result))completionHandler {
    _selectorCalledOnParent = true;
}
@end
@interface AppDelegateInhertisFromBaseBothHaveSelectors : AppDelegateBaseClassBothHaveSelectors
@property (nonatomic, readwrite) BOOL selectorCalledOnChild;
@end
@implementation AppDelegateInhertisFromBaseBothHaveSelectors
- (instancetype)init {
    self = [super init];
    _selectorCalledOnChild = false;
    return self;
}
- (void)application:(UIApplication *)application
        didReceiveRemoteNotification:(NSDictionary *)userInfo
        fetchCompletionHandler:(void (^)(UIBackgroundFetchResult result))completionHandler {
    _selectorCalledOnChild = true;
    [super
        application:application
        didReceiveRemoteNotification:userInfo
        fetchCompletionHandler:completionHandler];
}
@end

@interface AppDelegateBaseClassBothHaveSelectorsButSuperIsNotCalled : UIResponder<UIApplicationDelegate>
@property (nonatomic, readwrite) BOOL selectorCalledOnParent;
@end
@implementation AppDelegateBaseClassBothHaveSelectorsButSuperIsNotCalled
- (instancetype)init {
    self = [super init];
    _selectorCalledOnParent = false;
    return self;
}
- (void)application:(UIApplication *)application
        didReceiveRemoteNotification:(NSDictionary *)userInfo
        fetchCompletionHandler:(void (^)(UIBackgroundFetchResult result))completionHandler {
    _selectorCalledOnParent = true;
}
@end
@interface AppDelegateInhertisFromBaseBothHaveSelectorsButSuperIsNotCalled
    : AppDelegateBaseClassBothHaveSelectorsButSuperIsNotCalled
@property (nonatomic, readwrite) BOOL selectorCalledOnChild;
@end
@implementation AppDelegateInhertisFromBaseBothHaveSelectorsButSuperIsNotCalled
- (instancetype)init {
    self = [super init];
    _selectorCalledOnChild = false;
    return self;
}
- (void)application:(UIApplication *)application
        didReceiveRemoteNotification:(NSDictionary *)userInfo
        fetchCompletionHandler:(void (^)(UIBackgroundFetchResult result))completionHandler {
    _selectorCalledOnChild = true;
}
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

- (void)testCompatibleWithOtherSwizzlerWhenSwapingBetweenNil {
    // 1. Create a new delegate and assign it
    id myAppDelegate = [AppDelegateForInfiniteLoopWithAnotherSwizzlerTest new];
    UIApplication.sharedApplication.delegate = myAppDelegate;
    
    // 2. Other library swizzles
    [OtherLibraryASwizzler swizzleAppDelegate];
    
    // 3. Nil and set it again to trigger OneSignal swizzling again.
    UIApplication.sharedApplication.delegate = nil;
    UIApplication.sharedApplication.delegate = myAppDelegate;

    // 4. Call something to confirm we don't get stuck in an infinite call loop
    id<UIApplicationDelegate> delegate = UIApplication.sharedApplication.delegate;
    [delegate applicationWillTerminate:UIApplication.sharedApplication];
    
    // 5. Ensure OneSignal's selector is called.
    XCTAssertEqual([OneSignalAppDelegateOverrider
        callCountForSelector:@"oneSignalApplicationWillTerminate:"], 1);
    
    // 6. Ensure other library selector is still called too.
    XCTAssertTrue([OtherLibraryASwizzler selectorCalled]);
}

- (void)testSwizzleExistingSelectors {
    AppDelegateForExistingSelectorsTest* myAppDelegate = [AppDelegateForExistingSelectorsTest new];
    UIApplication.sharedApplication.delegate = myAppDelegate;
    id<UIApplicationDelegate> appDelegate = UIApplication.sharedApplication.delegate;

    [appDelegate
        application:UIApplication.sharedApplication
        didReceiveRemoteNotification:@{}
        fetchCompletionHandler:^(UIBackgroundFetchResult result){}];
    XCTAssertTrue([myAppDelegate->selectorCallsDict
        objectForKey:NSStringFromSelector(
            @selector(application:didReceiveRemoteNotification:fetchCompletionHandler:)
        )
    ]);
    XCTAssertEqual([OneSignalAppDelegateOverrider callCountForSelector:@"oneSignalReceiveRemoteNotification:UserInfo:fetchCompletionHandler:"], 1);

    [appDelegate
        application:UIApplication.sharedApplication
        didFailToRegisterForRemoteNotificationsWithError:[NSError new]];
    XCTAssertTrue([myAppDelegate->selectorCallsDict
        objectForKey:NSStringFromSelector(
            @selector(application:didFailToRegisterForRemoteNotificationsWithError:)
        )
    ]);

    [appDelegate
        application:UIApplication.sharedApplication
        didRegisterForRemoteNotificationsWithDeviceToken:[NSData new]];
    XCTAssertTrue([myAppDelegate->selectorCallsDict
        objectForKey:NSStringFromSelector(
            @selector(application:didRegisterForRemoteNotificationsWithDeviceToken:)
        )
    ]);

    [appDelegate
        applicationWillTerminate:UIApplication.sharedApplication];
    XCTAssertTrue([myAppDelegate->selectorCallsDict
        objectForKey:NSStringFromSelector(
            @selector(applicationWillTerminate:)
        )
    ]);
}

// OneSignal adds application:didReceiveRemoteNotification:fetchCompletionHandler: however
// this causes iOS to no longer call application:didReceiveRemoteNotification: since it sees
// the delegate is using the newer method. To prevent OneSignal from creating side effects we
// need to forward this event to the deprecated application:didReceiveRemoteNotification:.
/** From Apple's documenation:
 Implement the application:didReceiveRemoteNotification:fetchCompletionHandler:
 method instead of this one whenever possible. If your delegate implements both
 methods, the app object calls the
 application:didReceiveRemoteNotification:fetchCompletionHandler: method.
*/
- (void)testCallsDepercatedDidReceiveRemoteNotification {
    AppDelegateForDepercatedDidReceiveRemoteNotificationTest* myAppDelegate =
        [AppDelegateForDepercatedDidReceiveRemoteNotificationTest new];
    UIApplication.sharedApplication.delegate = myAppDelegate;
    id<UIApplicationDelegate> appDelegate = UIApplication.sharedApplication.delegate;
    
    // Apple will call this AppDelegate method
    [appDelegate
        application:UIApplication.sharedApplication
        didReceiveRemoteNotification:@{}
        fetchCompletionHandler:^(UIBackgroundFetchResult result){}];
    // Ensures the OneSignal swizzling code forwarded it to
    // application:didReceiveRemoteNotification:
    XCTAssertTrue(myAppDelegate->selectorCalled);
}

- (UNNotificationResponse*)createOneSignalNotificationResponse {
  id userInfo = @{@"custom":
                       @{ @"i": @"b2f7f966-d8cc-11e4-bed1-df8f05be55ba" }
                };
  
  return [UnitTestCommonMethods createBasiciOSNotificationResponseWithPayload:userInfo];
}

- (UNNotificationResponse*)createNonOneSignalNotificationResponse {
    return [UnitTestCommonMethods createBasiciOSNotificationResponseWithPayload:@{}];
}

- (void)testNotificationOpenForwardsToLegacySelector {
    
    AppDelegateForExistingSelectorsTest* myAppDelegate = [AppDelegateForExistingSelectorsTest new];
    UIApplication.sharedApplication.delegate = myAppDelegate;

    id notifResponse = [self createOneSignalNotificationResponse];
    UNUserNotificationCenter *notifCenter = [UNUserNotificationCenter currentNotificationCenter];
    id notifCenterDelegate = notifCenter.delegate;
    // UNUserNotificationCenterDelegate method iOS 10 calls directly when a notification is opened.
    [notifCenterDelegate userNotificationCenter:notifCenter didReceiveNotificationResponse:notifResponse withCompletionHandler:^() {}];
    XCTAssertTrue([myAppDelegate->selectorCallsDict
        objectForKey:NSStringFromSelector(
            @selector(application:didReceiveRemoteNotification:fetchCompletionHandler:)
        )
    ]);
    XCTAssertEqual([OneSignalAppDelegateOverrider callCountForSelector:@"oneSignalReceiveRemoteNotification:UserInfo:fetchCompletionHandler:"], 1);
    
    
    
    notifResponse = [self createNonOneSignalNotificationResponse];
    notifCenter = [UNUserNotificationCenter currentNotificationCenter];
    notifCenterDelegate = notifCenter.delegate;
    // UNUserNotificationCenterDelegate method iOS 10 calls directly when a notification is opened.
    [notifCenterDelegate userNotificationCenter:notifCenter didReceiveNotificationResponse:notifResponse withCompletionHandler:^() {}];
    XCTAssertTrue([myAppDelegate->selectorCallsDict
        objectForKey:NSStringFromSelector(
            @selector(application:didReceiveRemoteNotification:fetchCompletionHandler:)
        )
    ]);
    XCTAssertEqual([OneSignalAppDelegateOverrider callCountForSelector:@"oneSignalReceiveRemoteNotification:UserInfo:fetchCompletionHandler:"], 2);
    
}

- (void)testAppDelegateInheritsFromBaseMissingSelectors {
    id myAppDelegate = [AppDelegateInheritsFromBaseMissingSelectorsTest new];
    UIApplication.sharedApplication.delegate = myAppDelegate;
    id<UIApplicationDelegate> appDelegate = UIApplication.sharedApplication.delegate;
    
    [appDelegate
        application:UIApplication.sharedApplication
        didReceiveRemoteNotification:@{}
        fetchCompletionHandler:^(UIBackgroundFetchResult result){}];
    XCTAssertEqual([OneSignalAppDelegateOverrider callCountForSelector:@"oneSignalReceiveRemoteNotification:UserInfo:fetchCompletionHandler:"], 1);
}

- (void)testAppDelegateInheritsFromBaseWhereBaseHasSelector {
    AppDelegateInhertisFromBaseClassForBaseHasSelectorTest *myAppDelegate =
        [AppDelegateInhertisFromBaseClassForBaseHasSelectorTest new];
    UIApplication.sharedApplication.delegate = myAppDelegate;
    id<UIApplicationDelegate> appDelegate = UIApplication.sharedApplication.delegate;
    
    // Apple will call this AppDelegate method
    [appDelegate
        application:UIApplication.sharedApplication
        didReceiveRemoteNotification:@{}
        fetchCompletionHandler:^(UIBackgroundFetchResult result){}];
    // Ensures the OneSignal swizzling code forwards to original
    XCTAssertTrue(myAppDelegate.selectorCalled);
    XCTAssertEqual([OneSignalAppDelegateOverrider callCountForSelector:@"oneSignalReceiveRemoteNotification:UserInfo:fetchCompletionHandler:"], 1);
}

- (void)testAppDelegateInheritsFromBaseWhereChildHasSelector {
    AppDelegateInhertisFromBaseButChildHasSelector *myAppDelegate =
        [AppDelegateInhertisFromBaseButChildHasSelector new];
    UIApplication.sharedApplication.delegate = myAppDelegate;
    id<UIApplicationDelegate> appDelegate = UIApplication.sharedApplication.delegate;
    
    // Apple will call this AppDelegate method
    [appDelegate
        application:UIApplication.sharedApplication
        didReceiveRemoteNotification:@{}
        fetchCompletionHandler:^(UIBackgroundFetchResult result){}];
    // Ensures the OneSignal swizzling code forwards to original
    XCTAssertTrue(myAppDelegate.selectorCalled);
    XCTAssertEqual([OneSignalAppDelegateOverrider callCountForSelector:@"oneSignalReceiveRemoteNotification:UserInfo:fetchCompletionHandler:"], 1);
}

- (void)testAppDelegateInheritsFromBaseWhereBothHaveSelectors {
    AppDelegateInhertisFromBaseBothHaveSelectors *myAppDelegate =
        [AppDelegateInhertisFromBaseBothHaveSelectors new];
    UIApplication.sharedApplication.delegate = myAppDelegate;
    id<UIApplicationDelegate> appDelegate = UIApplication.sharedApplication.delegate;
    
    // Apple will call this AppDelegate method
    [appDelegate
        application:UIApplication.sharedApplication
        didReceiveRemoteNotification:@{}
        fetchCompletionHandler:^(UIBackgroundFetchResult result){}];
    // Ensures the OneSignal swizzling code forwards to original
    XCTAssertTrue(myAppDelegate.selectorCalledOnChild);
    XCTAssertTrue(myAppDelegate.selectorCalledOnParent);
    XCTAssertEqual([OneSignalAppDelegateOverrider callCountForSelector:@"oneSignalReceiveRemoteNotification:UserInfo:fetchCompletionHandler:"], 1);
}

- (void)testAppDelegateInheritsFromBaseWhereBothHaveSelectorsButSuperIsNotCalled {
    AppDelegateInhertisFromBaseBothHaveSelectorsButSuperIsNotCalled *myAppDelegate =
        [AppDelegateInhertisFromBaseBothHaveSelectorsButSuperIsNotCalled new];
    UIApplication.sharedApplication.delegate = myAppDelegate;
    id<UIApplicationDelegate> appDelegate = UIApplication.sharedApplication.delegate;
    
    // Apple will call this AppDelegate method
    [appDelegate
        application:UIApplication.sharedApplication
        didReceiveRemoteNotification:@{}
        fetchCompletionHandler:^(UIBackgroundFetchResult result){}];
    // Ensures the OneSignal swizzling code forwards to original
    XCTAssertTrue(myAppDelegate.selectorCalledOnChild);
    // In this test, child overrides the parent and intently doesn't call super
    XCTAssertFalse(myAppDelegate.selectorCalledOnParent);
    XCTAssertEqual([OneSignalAppDelegateOverrider callCountForSelector:@"oneSignalReceiveRemoteNotification:UserInfo:fetchCompletionHandler:"], 1);
}
@end
