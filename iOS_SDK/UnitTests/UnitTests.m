//
//  UnitTests.m
//  UnitTests
//
//  Created by Kasten on 1/25/17.
//  Copyright © 2017 Hiptic. All rights reserved.
//

#import <XCTest/XCTest.h>

#import <objc/runtime.h>

#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>
#import <UserNotifications/UserNotifications.h>

#import "OneSignal.h"

#import "OneSignalHelper.h"
#import "OneSignalSelectorHelpers.h"



// Just for debugging
void DumpObjcMethods(Class clz) {
    unsigned int methodCount = 0;
    Method *methods = class_copyMethodList(clz, &methodCount);
    
    
    NSLog(@"Found %d methods on '%s'\n", methodCount, class_getName(clz));
    
    
    for (unsigned int i = 0; i < methodCount; i++) {
        Method method = methods[i];
        
        
        NSLog(@"'%s' has method named '%s' of encoding '%s'\n",
              class_getName(clz),
              sel_getName(method_getName(method)),
              method_getTypeEncoding(method));
    }
    
    
    free(methods);
}




BOOL injectStaticSelector(Class newClass, SEL newSel, Class addToClass, SEL makeLikeSel) {
    Method newMeth = class_getClassMethod(newClass, newSel);
    IMP imp = method_getImplementation(newMeth);
    
    const char* methodTypeEncoding = method_getTypeEncoding(newMeth);
    // Keep - class_getInstanceMethod for existing detection.
    //    class_addMethod will successfuly add if the addToClass was loaded twice into the runtime.
    BOOL existing = class_getClassMethod(addToClass, makeLikeSel) != NULL;
    
    if (existing) {
        // class_addMethod doesn't have a instance vs class name. It must just use the signature of the method.
        class_addMethod(addToClass, newSel, imp, methodTypeEncoding);
        // Even though we just added a static method we need to use getInstance here....
        newMeth = class_getInstanceMethod(addToClass, newSel);
        
        Method orgMeth = class_getClassMethod(addToClass, makeLikeSel);
        method_exchangeImplementations(orgMeth, newMeth);
    }
    else
        class_addMethod(addToClass, makeLikeSel, imp, methodTypeEncoding);
    
    return existing;
}



@interface NSBundleOverrider : NSObject
@end
@implementation NSBundleOverrider

+ (void)load {
    injectToProperClass(@selector(overrideBundleIdentifier), @selector(bundleIdentifier), @[], [NSBundleOverrider class], [NSBundle class]);
}

- (NSString*)overrideBundleIdentifier {
    return @"com.onesignal.unittest";
}

@end


@interface UNUserNotificationCenterOverrider : NSObject
@end
@implementation UNUserNotificationCenterOverrider

+ (void)load {
    injectToProperClass(@selector(overrideInitWithBundleIdentifier:), @selector(initWithBundleIdentifier:), @[], [UNUserNotificationCenterOverrider class], [UNUserNotificationCenter class]);
}

- (id) overrideInitWithBundleIdentifier:(NSString*) bundle {
    return self;
}

@end



static int notifTypesOverride = 7;

@interface UIApplicationOverrider : NSObject
@end
@implementation UIApplicationOverrider



+ (void)load {
   injectToProperClass(@selector(overrideRegisterForRemoteNotifications), @selector(registerForRemoteNotifications), @[], [UIApplicationOverrider class], [UIApplication class]);
   injectToProperClass(@selector(override_run), @selector(_run), @[], [UIApplicationOverrider class], [UIApplication class]);
   injectToProperClass(@selector(overrideCurrentUserNotificationSettings), @selector(currentUserNotificationSettings), @[], [UIApplicationOverrider class], [UIApplication class]);
}

// Keeps UIApplicationMain(...) from looping to continue to the next line.
- (void) override_run {}

- (void) overrideRegisterForRemoteNotifications {
    id app = [UIApplication sharedApplication];
    id appDelegate = [[UIApplication sharedApplication] delegate];
    
    char bytes[32];
    memset(bytes, 0, 32);
    
    id deviceToken = [NSData dataWithBytes:bytes length:32];
    [appDelegate application:app didRegisterForRemoteNotificationsWithDeviceToken:deviceToken];
}


- (UIUserNotificationSettings*) overrideCurrentUserNotificationSettings {
    return [UIUserNotificationSettings settingsForTypes:notifTypesOverride categories:nil];
}

@end


static NSString* lastUrl;
static NSDictionary* lastHTTPRequset;

@interface OneSignalHelperOverrider : NSObject
@end
@implementation OneSignalHelperOverrider

+ (void)load {
    injectStaticSelector([OneSignalHelperOverrider class], @selector(overrideEnqueueRequest:onSuccess:onFailure:isSynchronous:), [OneSignalHelper class], @selector(enqueueRequest:onSuccess:onFailure:isSynchronous:));
}

+ (void)overrideEnqueueRequest:(NSURLRequest*)request onSuccess:(OSResultSuccessBlock)successBlock onFailure:(OSFailureBlock)failureBlock isSynchronous:(BOOL)isSynchronous {
    NSError *error = nil;
    id url = [request URL];
    NSDictionary *parameters = [NSJSONSerialization JSONObjectWithData:[request HTTPBody] options:0 error:&error];
    NSLog(@"url: %@", url);
    NSLog(@"parameters: %@", parameters);
    
    lastUrl = [url absoluteString];
    lastHTTPRequset = parameters;
    
    if (successBlock)
        successBlock(@{@"id": @"1234"});
}

@end



@interface AppDelegate : UIResponder <UIApplicationDelegate, UNUserNotificationCenterDelegate>
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication*)application didFinishLaunchingWithOptions:(NSDictionary*)launchOptions {
    
    return true;
}

@end

/*
@interface UIApplication (UN_extra)
- (void) setOneSignalDelegate:(id<UIApplicationDelegate>)delegate;
@end

*/




@interface UnitTests : XCTestCase
@end


static BOOL setupUIApplicationDelegate = false;

@implementation UnitTests

- (void) clearNSUserDefaults {
    /*
     id nsDefaults = [NSUserDefaults standardUserDefaults];
     
     // Remove all saved state stored on disk.
     [nsDefaults removePersistentDomainForName:[[NSBundle mainBundle] bundleIdentifier]];
     [NSUserDefaults resetStandardUserDefaults];
     [NSUserDefaults standardUserDefaults];
     [nsDefaults synchronize];
     
     
     // Manually list and remove all keys
     id allKeys = [[nsDefaults dictionaryRepresentation] allKeys];
     for (NSString *key in allKeys) {
     NSLog(@"Deleting key: %@", key);
     // This line seems to break future builds from running the simulator.
     // [nsDefaults setObject:@"" forKey:key];
     // Remove doesn't seem to have an effect.
     //   Might be due to a domain preceding it.
     //   https://developer.apple.com/reference/foundation/nsuserdefaults/1411182-removeobjectforkey?language=objc
     [nsDefaults removeObjectForKey:key];
     }
     [nsDefaults synchronize];
     */
    
    // Need to clear each key manally since the above doesn't work.
    [[NSUserDefaults standardUserDefaults] setObject:@"" forKey:@"GT_LAST_MESSAGE_OPENED_"];
    [[NSUserDefaults standardUserDefaults] setDouble:0 forKey:@"GT_LAST_CLOSED_TIME"];
}

// Called before each test.
- (void)setUp {
    [super setUp];
    
    notifTypesOverride = 7;
    
    [self clearNSUserDefaults];
    
    [OneSignal setLogLevel:ONE_S_LL_VERBOSE visualLevel:ONE_S_LL_NONE];
    
    if (!setupUIApplicationDelegate) {
        // Normally this just loops internally, overwrote _run to work around this.
        UIApplicationMain(0, nil, nil, NSStringFromClass([AppDelegate class]));
        setupUIApplicationDelegate = true;
    }
}

// Called after each test.
- (void)tearDown {
    [super tearDown];
 
    lastUrl = nil;
    lastHTTPRequset = nil;
}



- (void)testBasicInitTest {
    NSLog(@"iOS VERSION: %@", [[UIDevice currentDevice] systemVersion]);
    
    // This should fire the swizzled setDelegate in UIApplicationDelegate+OneSignal but it does not for some reason.
    // id appDelegate = [AppDelegate new];
    // [[UIApplication sharedApplication] setDelegate:appDelegate];
    
    // I really have no idea why this doesn't work.
    // id appDelegate = [AppDelegate new];
    // [[UIApplication sharedApplication] setOneSignalDelegate:appDelegate];
    
    [OneSignal initWithLaunchOptions:nil appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"];
    
    XCTAssertEqualObjects(lastHTTPRequset[@"app_id"], @"b2f7f966-d8cc-11e4-bed1-df8f05be55ba");
    XCTAssertEqualObjects(lastHTTPRequset[@"notification_types"], [NSNumber numberWithInt:7]);
    XCTAssertEqualObjects(lastHTTPRequset[@"device_model"], @"x86_64");
    XCTAssertEqualObjects(lastHTTPRequset[@"device_type"], [NSNumber numberWithInt:0]);
    XCTAssertEqualObjects(lastHTTPRequset[@"language"], @"en");
    
    // 2nd init call should not fire another on_session call.
    lastHTTPRequset = nil;
    [OneSignal initWithLaunchOptions:nil appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"];
    XCTAssertNil(lastHTTPRequset);
    
    // NSLog(@"Sleeping for debugging");
    // [NSThread sleepForTimeInterval:1000];
}

- (void)testBasicInitTestNotAcceptingNotifications {
    notifTypesOverride = 0;
    [OneSignal initWithLaunchOptions:nil appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"];
    
    XCTAssertEqualObjects(lastHTTPRequset[@"app_id"], @"b2f7f966-d8cc-11e4-bed1-df8f05be55ba");
    XCTAssertEqualObjects(lastHTTPRequset[@"notification_types"], [NSNumber numberWithInt:0]);
}

// Tests that a normal notification opened on iOS 10 triggers the handleNotificationAction.
- (void)testNotificationOpen {
    notifTypesOverride = 7;
    
    __block BOOL openedWasFire = false;
    
    [OneSignal initWithLaunchOptions:nil appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba" handleNotificationAction:^(OSNotificationOpenedResult *result) {
        XCTAssertNil(result.notification.payload.additionalData);
        XCTAssertEqual(result.action.type, OSNotificationActionTypeOpened);
        XCTAssertNil(result.action.actionID);
        openedWasFire = true;
    }];
    
    // Setting response.notification.request.content.userInfo
    UNNotificationResponse *notifResponse = [UNNotificationResponse alloc];
    // Normal tap on notification
    [notifResponse setValue:@"com.apple.UNNotificationDefaultActionIdentifier" forKeyPath:@"actionIdentifier"];
    
    id userInfo = @{@"custom": @{
                        @"i": @"b2f7f966-d8cc-11e4-bed1-df8f05be55bb"
                    }};
    
    UNNotificationContent *unNotifContent = [UNNotificationContent alloc];
    UNNotification *unNotif = [UNNotification alloc];
    UNNotificationRequest *unNotifRequqest = [UNNotificationRequest alloc];
    [unNotif setValue:unNotifRequqest forKeyPath:@"request"];
    [notifResponse setValue:unNotif forKeyPath:@"notification"];
    [unNotifRequqest setValue:unNotifContent forKeyPath:@"content"];
    [unNotifContent setValue:userInfo forKey:@"userInfo"];
    

    // Call iOS 10 selector entry point for a notification that was opened.
    UNUserNotificationCenter *notifCenter = [UNUserNotificationCenter currentNotificationCenter];
    id notifCenterDelegate = notifCenter.delegate;

    [notifCenterDelegate userNotificationCenter:notifCenter didReceiveNotificationResponse:notifResponse withCompletionHandler:^() {}];
    
    // Make sure open tracking network call was made.
    XCTAssertEqual(openedWasFire, true);
    XCTAssertEqualObjects(lastUrl, @"https://onesignal.com/api/v1/notifications/b2f7f966-d8cc-11e4-bed1-df8f05be55bb");
    XCTAssertEqualObjects(lastHTTPRequset[@"app_id"], @"b2f7f966-d8cc-11e4-bed1-df8f05be55ba");
    XCTAssertEqualObjects(lastHTTPRequset[@"opened"], @1);
    
    // Make sure if the device recieved a duplicate we don't fire the open network call again.
    lastUrl = nil;
    lastHTTPRequset = nil;
    [notifCenterDelegate userNotificationCenter:notifCenter didReceiveNotificationResponse:notifResponse withCompletionHandler:^() {}];
    
    XCTAssertNil(lastUrl);
    XCTAssertNil(lastHTTPRequset);
}

- (void)testSendTags {
    [OneSignal initWithLaunchOptions:nil appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"];
    
    [OneSignal sendTag:@"key" value:@"value"];
    XCTAssertEqualObjects(lastHTTPRequset[@"tags"][@"key"], @"value");
    
    [OneSignal sendTags:@{@"key1": @"value1", @"key2": @"value2"}];
    XCTAssertEqualObjects(lastHTTPRequset[@"tags"][@"key1"], @"value1");
    XCTAssertEqualObjects(lastHTTPRequset[@"tags"][@"key2"], @"value2");
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

@end
