#import <objc/runtime.h>

#import <XCTest/XCTest.h>
// TODO: Commented out 🧪

// #import "UnitTestCommonMethods.h"
// #import "OneSignalExtensionBadgeHandler.h"
// #import "UNUserNotificationCenterOverrider.h"
// #import "UNUserNotificationCenter+OneSignal.h"
// #import "OneSignalHelperOverrider.h"
// #import "OneSignalHelper.h"
// #import "OneSignalUNUserNotificationCenterHelper.h"
// #import "TestHelperFunctions.h"
// #import "OneSignalUNUserNotificationCenterOverrider.h"

// @interface DummyNotificationCenterDelegateForDoesSwizzleTest : NSObject<UNUserNotificationCenterDelegate>
// @end
// @implementation DummyNotificationCenterDelegateForDoesSwizzleTest
// -(void)userNotificationCenter:(UNUserNotificationCenter *)center willPresentNotification:(UNNotification *)notification withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completionHandler {
// }

// -(void)userNotificationCenter:(UNUserNotificationCenter *)center didReceiveNotificationResponse:(UNNotificationResponse *)response withCompletionHandler:(void (^)(void))completionHandler {
// }
// @end

// @interface DummyNotificationCenterDelegateAssignedBeforeOneSignalTest : NSObject<UNUserNotificationCenterDelegate>
// @end
// @implementation DummyNotificationCenterDelegateAssignedBeforeOneSignalTest
// -(void)userNotificationCenter:(UNUserNotificationCenter *)center willPresentNotification:(UNNotification *)notification withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completionHandler {
// }

// -(void)userNotificationCenter:(UNUserNotificationCenter *)center didReceiveNotificationResponse:(UNNotificationResponse *)response withCompletionHandler:(void (^)(void))completionHandler {
// }
// @end

// @interface UNUserNotificationCenterDelegateForwardingTargetForSelectorTest : UIResponder<UNUserNotificationCenterDelegate>
// @end
// @implementation UNUserNotificationCenterDelegateForwardingTargetForSelectorTest {
//     id forwardingInstance;
// }
// - (instancetype)initForwardingTarget:(id)forwardingTarget {
//     self = [super init];
//     forwardingInstance = forwardingTarget;
//     return self;
// }

// - (id)forwardingTargetForSelector:(SEL)selector {
//     return forwardingInstance;
// }
// @end

// @interface UNUserNotificationCenterDelegateForwardReceiver : UIResponder<UNUserNotificationCenterDelegate> {
//     @public NSMutableDictionary *selectorCallsDict;
// }
// @end
// @implementation UNUserNotificationCenterDelegateForwardReceiver

// - (instancetype)init {
//     self = [super init];
//     selectorCallsDict = [NSMutableDictionary new];
//     return self;
// }
// - (void)userNotificationCenter:(UNUserNotificationCenter *)center willPresentNotification:(UNNotification *)notification withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completionHandler {
//     SEL thisSelector = @selector(userNotificationCenter:willPresentNotification:withCompletionHandler:);
//     [selectorCallsDict
//        setObject:@(true)
//        forKey:NSStringFromSelector(thisSelector)
//     ];
// }

// - (void)userNotificationCenter:(UNUserNotificationCenter *)center didReceiveNotificationResponse:(UNNotificationResponse *)response withCompletionHandler:(void (^)(void))completionHandler {
//     SEL thisSelector = @selector(userNotificationCenter:didReceiveNotificationResponse:withCompletionHandler:);
//     [selectorCallsDict
//        setObject:@(true)
//        forKey:NSStringFromSelector(thisSelector)
//     ];
// }

// - (void)userNotificationCenter:(UNUserNotificationCenter *)center openSettingsForNotification:(UNNotification *)notification {
//     SEL thisSelector = @selector(userNotificationCenter:openSettingsForNotification:);
//     [selectorCallsDict
//        setObject:@(true)
//        forKey:NSStringFromSelector(thisSelector)
//     ];
// }
// @end

// @interface UNUserNotificationCenterDelegateForExistingSelectorsTest : UIResponder<UNUserNotificationCenterDelegate> {
//     @public NSMutableDictionary *selectorCallsDict;
// }
// @end
// @implementation UNUserNotificationCenterDelegateForExistingSelectorsTest

// - (instancetype)init {
//     self = [super init];
//     selectorCallsDict = [NSMutableDictionary new];
//     return self;
// }
// - (void)userNotificationCenter:(UNUserNotificationCenter *)center willPresentNotification:(UNNotification *)notification withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completionHandler {
//     SEL thisSelector = @selector(userNotificationCenter:willPresentNotification:withCompletionHandler:);
//     [selectorCallsDict
//        setObject:@(true)
//        forKey:NSStringFromSelector(thisSelector)
//     ];
// }

// - (void)userNotificationCenter:(UNUserNotificationCenter *)center didReceiveNotificationResponse:(UNNotificationResponse *)response withCompletionHandler:(void (^)(void))completionHandler {
//     SEL thisSelector = @selector(userNotificationCenter:didReceiveNotificationResponse:withCompletionHandler:);
//     [selectorCallsDict
//        setObject:@(true)
//        forKey:NSStringFromSelector(thisSelector)
//     ];
// }

// - (void)userNotificationCenter:(UNUserNotificationCenter *)center openSettingsForNotification:(UNNotification *)notification {
//     SEL thisSelector = @selector(userNotificationCenter:openSettingsForNotification:);
//     [selectorCallsDict
//        setObject:@(true)
//        forKey:NSStringFromSelector(thisSelector)
//     ];
// }
// @end

// @interface UNUserNotificationCenterDelegateForInfiniteLoopTest : UIResponder<UNUserNotificationCenterDelegate>
// @end
// @implementation UNUserNotificationCenterDelegateForInfiniteLoopTest
// @end


// @interface UNUserNotificationCenterDelegateForInfiniteLoopWithAnotherSwizzlerTest : UIResponder<UNUserNotificationCenterDelegate>
// @end
// @implementation UNUserNotificationCenterDelegateForInfiniteLoopWithAnotherSwizzlerTest
// @end
// @interface OtherUNNotificationLibraryASwizzler : UIResponder<UNUserNotificationCenterDelegate>
// +(void)swizzleUNUserNotificationCenterDelegate;
// +(BOOL)selectorCalled;
// @end
// @implementation OtherUNNotificationLibraryASwizzler
// static BOOL selectorCalled = false;
// +(BOOL)selectorCalled {
//     return selectorCalled;
// }

// +(void)swizzleUNUserNotificationCenterDelegate
// {
//     swizzleExistingSelector(
//         [UNUserNotificationCenter.currentNotificationCenter.delegate class],
//         @selector(userNotificationCenter:willPresentNotification:withCompletionHandler:),
//         [self class],
//         @selector(userNotificationCenterLibraryA:willPresentNotification:withCompletionHandler:)
//     );
// }
// -(void)userNotificationCenterLibraryA:(UNUserNotificationCenter *)center willPresentNotification:(UNNotification *)notification withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completionHandler
// {
//     selectorCalled = true;
//     // Standard basic swizzling forwarder another library may have.
//     if ([self respondsToSelector:@selector(userNotificationCenterLibraryA:willPresentNotification:withCompletionHandler:)])
//         [self userNotificationCenterLibraryA:center willPresentNotification:notification withCompletionHandler:completionHandler];
// }
// @end
// @interface OtherUNNotificationLibraryBSubClassSwizzler : OtherUNNotificationLibraryASwizzler
// +(void)swizzleUNUserNotificationCenterDelegate;
// +(BOOL)selectorCalled;
// @end
// @implementation OtherUNNotificationLibraryBSubClassSwizzler

// +(BOOL)selectorCalled {
//     return selectorCalled;
// }

// +(void)swizzleUNUserNotificationCenterDelegate
// {
//     swizzleExistingSelector(
//         [UNUserNotificationCenter.currentNotificationCenter.delegate class],
//         @selector(userNotificationCenter:willPresentNotification:withCompletionHandler:),
//         [self class],
//         @selector(userNotificationCenterLibraryB:willPresentNotification:withCompletionHandler:)
//     );
// }
// -(void)userNotificationCenterLibraryB:(UNUserNotificationCenter *)center willPresentNotification:(UNNotification *)notification withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completionHandler
// {
//     selectorCalled = true;
//     // Standard basic swizzling forwarder another library may have.
//     if ([self respondsToSelector:@selector(userNotificationCenterLibraryA:willPresentNotification:withCompletionHandler:)])
//         [self userNotificationCenterLibraryB:center willPresentNotification:notification withCompletionHandler:completionHandler];
// }
// @end


// @interface OneSignalUNUserNotificationCenterSwizzlingTest : XCTestCase
// @end

// @implementation OneSignalUNUserNotificationCenterSwizzlingTest

// // Called BEFORE each test method
// - (void)setUp {
//     [super setUp];
//     [UnitTestCommonMethods beforeEachTest:self];
    
//     [OneSignalUNUserNotificationCenter setUseiOS10_2_workaround:true];
// }

// // Called AFTER each test method
// - (void)tearDown {
//     [super tearDown];
//     [OneSignalUNUserNotificationCenterHelper restoreDelegateAsOneSignal];
// }

// - (UNNotificationResponse *)createBasiciOSNotificationResponse {
//   id userInfo = @{@"custom":
//                        @{ @"i": @"b2f7f966-d8cc-11e4-bed1-df8f05be55ba" }
//                 };
  
//   return [UnitTestCommonMethods createBasiciOSNotificationResponseWithPayload:userInfo];
// }

// - (UNNotification *)createNonOneSignaliOSNotification {
//     id userInfo = @{@"aps": @{
//                             @"mutable-content": @1,
//                             @"alert": @"Message Body"
//                             }
//                     };

//     return [UnitTestCommonMethods createBasiciOSNotificationWithPayload:userInfo];
// }

// - (UNNotification *)createBasiciOSNotification {
//     id userInfo = @{@"aps": @{
//                             @"mutable-content": @1,
//                             @"alert": @"Message Body"
//                             },
//                     @"os_data": @{
//                             @"i": @"b2f7f966-d8cc-11e4-bed1-df8f05be55ba",
//                             @"buttons": @[@{@"i": @"id1", @"n": @"text1"}],
//                             }};

//     return [UnitTestCommonMethods createBasiciOSNotificationWithPayload:userInfo];
// }

// // Tests to make sure that UNNotificationCenter setDelegate: duplicate calls don't double-swizzle for the same object
// - (void)testAUNUserNotificationCenterDelegateAssigningDoesSwizzle {
//     UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];

//     let dummyDelegate = [DummyNotificationCenterDelegateForDoesSwizzleTest new];

//     IMP original = class_getMethodImplementation([dummyDelegate class], @selector(userNotificationCenter:didReceiveNotificationResponse:withCompletionHandler:));

//     // This triggers UNUserNotificationCenter+OneSignal.m setOneSignalUNDelegate which does the implemenation swizzling
//     center.delegate = dummyDelegate;

//     IMP swizzled = class_getMethodImplementation([dummyDelegate class], @selector(userNotificationCenter:didReceiveNotificationResponse:withCompletionHandler:));
//     // Since we swizzled the implemenations should be different.
//     XCTAssertNotEqual(original, swizzled);

//     // Calling setDelegate: a second time on the same object should not re-exchange method implementations
//     // thus the new method implementation should still be the same, swizzled == newSwizzled should be true
//     center.delegate = dummyDelegate;

//     IMP newSwizzled = class_getMethodImplementation([dummyDelegate class], @selector(userNotificationCenter:didReceiveNotificationResponse:withCompletionHandler:));

//     XCTAssertEqual(swizzled, newSwizzled);
// }

// - (void)testUNUserNotificationCenterDelegateAssignedBeforeOneSignal {
//     [OneSignalUNUserNotificationCenterHelper putIntoPreloadedState];

//     // Create and assign a delegate with iOS
//     let dummyDelegate = [DummyNotificationCenterDelegateAssignedBeforeOneSignalTest new];
//     UNUserNotificationCenter.currentNotificationCenter.delegate = dummyDelegate;
    
//     // Save original implemenation reference, before OneSignal is loaded.
//     IMP originalDummyImp = class_getMethodImplementation([dummyDelegate class], @selector(userNotificationCenter:didReceiveNotificationResponse:withCompletionHandler:));

//     // Setup the OneSignal delegate where it will be loaded into memeory
//     [OneSignalUNUserNotificationCenter setup];

//     IMP swizzledDummyImp = class_getMethodImplementation([dummyDelegate class], @selector(userNotificationCenter:didReceiveNotificationResponse:withCompletionHandler:));
    
//     // Since we swizzled the implemenations should be different.
//     XCTAssertNotEqual(originalDummyImp, swizzledDummyImp);
// }

// - (void)testForwardingTargetForSelector {
//     UNUserNotificationCenterDelegateForwardReceiver *receiver = [UNUserNotificationCenterDelegateForwardReceiver new];
//     id myNotifCenterDelegate = [[UNUserNotificationCenterDelegateForwardingTargetForSelectorTest alloc]
//                         initForwardingTarget:receiver];
//     UNUserNotificationCenter.currentNotificationCenter.delegate = myNotifCenterDelegate;
//     id<UNUserNotificationCenterDelegate> notifCenterDelegate = UNUserNotificationCenter.currentNotificationCenter.delegate;

//     [notifCenterDelegate userNotificationCenter:UNUserNotificationCenter.currentNotificationCenter
//                         willPresentNotification:[self createBasiciOSNotification]
//                           withCompletionHandler:^(UNNotificationPresentationOptions options) {}];
//     XCTAssertTrue([receiver->selectorCallsDict
//         objectForKey:NSStringFromSelector(
//                                           @selector(userNotificationCenter:willPresentNotification:withCompletionHandler:)
//         )
//     ]);
//     [notifCenterDelegate userNotificationCenter:UNUserNotificationCenter.currentNotificationCenter
//                  didReceiveNotificationResponse:[self createBasiciOSNotificationResponse]
//                           withCompletionHandler:^{}];
//     XCTAssertTrue([receiver->selectorCallsDict
//         objectForKey:NSStringFromSelector(
//                                           @selector(userNotificationCenter:didReceiveNotificationResponse:withCompletionHandler:)
//         )
//     ]);
//     if (@available(iOS 12.0, *)) {
//         [notifCenterDelegate userNotificationCenter:UNUserNotificationCenter.currentNotificationCenter
//                         openSettingsForNotification:[self createBasiciOSNotification]];
//     }
//     XCTAssertTrue([receiver->selectorCallsDict
//         objectForKey:NSStringFromSelector(
//                                           @selector(userNotificationCenter:openSettingsForNotification:)
//         )
//     ]);
// }

// - (void)testForwardingTargetForNonOneSignalNotification {
//     UNUserNotificationCenterDelegateForwardReceiver *receiver = [UNUserNotificationCenterDelegateForwardReceiver new];
//     id myNotifCenterDelegate = [[UNUserNotificationCenterDelegateForwardingTargetForSelectorTest alloc]
//                         initForwardingTarget:receiver];
//     UNUserNotificationCenter.currentNotificationCenter.delegate = myNotifCenterDelegate;
//     id<UNUserNotificationCenterDelegate> notifCenterDelegate = UNUserNotificationCenter.currentNotificationCenter.delegate;

//     [notifCenterDelegate userNotificationCenter:UNUserNotificationCenter.currentNotificationCenter
//                         willPresentNotification:[self createNonOneSignaliOSNotification]
//                           withCompletionHandler:^(UNNotificationPresentationOptions options) {}];
//     XCTAssertTrue([receiver->selectorCallsDict
//         objectForKey:NSStringFromSelector(
//                                           @selector(userNotificationCenter:willPresentNotification:withCompletionHandler:)
//         )
//     ]);
// }

// - (void)testDoubleSwizzleInfiniteLoop {
//     // 1. Save original delegate
//     id<UNUserNotificationCenterDelegate> localOrignalDelegate = UNUserNotificationCenter.currentNotificationCenter.delegate;

//     // 2. Create a new delegate and assign it
//     id myDelegate = [UNUserNotificationCenterDelegateForInfiniteLoopTest new];
//     UNUserNotificationCenter.currentNotificationCenter.delegate = myDelegate;

//     // 3. Put the original delegate back
//     UNUserNotificationCenter.currentNotificationCenter.delegate = localOrignalDelegate;

//     // 4. Call something to confirm we don't get stuck in an infinite call loop
//     [localOrignalDelegate userNotificationCenter:UNUserNotificationCenter.currentNotificationCenter willPresentNotification:[self createBasiciOSNotification] withCompletionHandler:^(UNNotificationPresentationOptions options) {}];
// }

// - (void)testNotificationCenterSubClassIsNotSwizzledTwice {
//     // 1. Create a new delegate and assign it
//     id myDelegate = [UNUserNotificationCenterDelegateForInfiniteLoopTest new];
//     UNUserNotificationCenter.currentNotificationCenter.delegate = myDelegate;
    
//     // 2. Create another Library's app delegate and assign it then swizzle
//     id thierDelegate = [OtherUNNotificationLibraryASwizzler new];
//     UNUserNotificationCenter.currentNotificationCenter.delegate = thierDelegate;
//     [OtherUNNotificationLibraryASwizzler swizzleUNUserNotificationCenterDelegate];
    
//     // 3. Create another Library's app delegate subclass and assign it then swizzle
//     id thierDelegateSubClass = [OtherUNNotificationLibraryBSubClassSwizzler new];
//     UNUserNotificationCenter.currentNotificationCenter.delegate = thierDelegateSubClass;
//     [OtherUNNotificationLibraryBSubClassSwizzler swizzleUNUserNotificationCenterDelegate];
    
//     // 4. Call something to confirm we don't get stuck in an infinite call loop
//     id<UNUserNotificationCenterDelegate> delegate =
//         UNUserNotificationCenter.currentNotificationCenter.delegate;
//     [delegate
//         userNotificationCenter:UNUserNotificationCenter.currentNotificationCenter
//         willPresentNotification:[self createBasiciOSNotification]
//         withCompletionHandler:^(UNNotificationPresentationOptions options) {}
//     ];
    
//     // 5. Ensure OneSignal's selector is called.
//     XCTAssertEqual([OneSignalUNUserNotificationCenterOverrider
//         callCountForSelector:@"onesignalUserNotificationCenter:willPresentNotification:withCompletionHandler:"], 1);
    
//     // 6. Ensure other library selector is still called too.
//     XCTAssertTrue([OtherUNNotificationLibraryASwizzler selectorCalled]);
    
//     // 7. Ensure other library subclass selector is still called too.
//     XCTAssertTrue([OtherUNNotificationLibraryBSubClassSwizzler selectorCalled]);
// }

// - (void)testCompatibleWithOtherSwizzlerWhenSwapingBetweenNil {
//     // 1. Create a new delegate and assign it
//     id myAppDelegate = [UNUserNotificationCenterDelegateForInfiniteLoopWithAnotherSwizzlerTest new];
//     UNUserNotificationCenter.currentNotificationCenter.delegate = myAppDelegate;
    
//     // 2. Other library swizzles
//     [OtherUNNotificationLibraryASwizzler swizzleUNUserNotificationCenterDelegate];
    
//     // 3. Nil and set it again to trigger OneSignal swizzling again.
//     UNUserNotificationCenter.currentNotificationCenter.delegate = nil;
//     UNUserNotificationCenter.currentNotificationCenter.delegate = myAppDelegate;

//     // 4. Call something to confirm we don't get stuck in an infinite call loop
//     id<UNUserNotificationCenterDelegate> delegate =
//         UNUserNotificationCenter.currentNotificationCenter.delegate;
//     [delegate
//         userNotificationCenter:UNUserNotificationCenter.currentNotificationCenter
//         willPresentNotification:[self createBasiciOSNotification]
//         withCompletionHandler:^(UNNotificationPresentationOptions options) {}
//     ];
    
//     // 5. Ensure OneSignal's selector is called.
//     XCTAssertEqual([OneSignalUNUserNotificationCenterOverrider
//         callCountForSelector:@"onesignalUserNotificationCenter:willPresentNotification:withCompletionHandler:"], 1);
    
//     // 6. Ensure other library selector is still called too.
//     XCTAssertTrue([OtherUNNotificationLibraryASwizzler selectorCalled]);
// }

// - (void)testSwizzleExistingSelectors {
//     UNUserNotificationCenterDelegateForExistingSelectorsTest* myNotifCenterDelegate = [UNUserNotificationCenterDelegateForExistingSelectorsTest new];
//     UNUserNotificationCenter.currentNotificationCenter.delegate = myNotifCenterDelegate;
//     id<UNUserNotificationCenterDelegate> notifCenterDelegate = UNUserNotificationCenter.currentNotificationCenter.delegate;

//     [notifCenterDelegate userNotificationCenter:UNUserNotificationCenter.currentNotificationCenter
//                         willPresentNotification:[self createBasiciOSNotification]
//                           withCompletionHandler:^(UNNotificationPresentationOptions options) {}];
//     XCTAssertTrue([myNotifCenterDelegate->selectorCallsDict
//         objectForKey:NSStringFromSelector(
//                                           @selector(userNotificationCenter:willPresentNotification:withCompletionHandler:)
//         )
//     ]);
//     [notifCenterDelegate userNotificationCenter:UNUserNotificationCenter.currentNotificationCenter
//                  didReceiveNotificationResponse:[self createBasiciOSNotificationResponse]
//                           withCompletionHandler:^{}];
//     XCTAssertTrue([myNotifCenterDelegate->selectorCallsDict
//         objectForKey:NSStringFromSelector(
//                                           @selector(userNotificationCenter:didReceiveNotificationResponse:withCompletionHandler:)
//         )
//     ]);
//     if (@available(iOS 12.0, *)) {
//         [notifCenterDelegate userNotificationCenter:UNUserNotificationCenter.currentNotificationCenter
//                         openSettingsForNotification:[self createBasiciOSNotification]];
//     }
//     XCTAssertTrue([myNotifCenterDelegate->selectorCallsDict
//         objectForKey:NSStringFromSelector(
//                                           @selector(userNotificationCenter:openSettingsForNotification:)
//         )
//     ]);
// }

// @end
