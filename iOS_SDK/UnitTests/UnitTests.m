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


@interface NSObjectOverrider : NSObject
@end
@implementation NSObjectOverrider

static BOOL enabledPerformSelectorAfterDelay = true;

+ (void)load {
    injectToProperClass(@selector(overridePerformSelector:withObject:afterDelay:), @selector(performSelector:withObject:afterDelay:), @[], [NSObjectOverrider class], [NSObject class]);
}

- (void)overridePerformSelector:(SEL)aSelector withObject:(nullable id)anArgument afterDelay:(NSTimeInterval)delay {
    if (enabledPerformSelectorAfterDelay)
        [self overridePerformSelector:aSelector withObject:nil afterDelay:delay];
}

@end



@interface NSUserDefaultsOverrider : NSObject
@end

static NSMutableDictionary* defaultsDictionary;

@implementation NSUserDefaultsOverrider
+ (void)load {
    defaultsDictionary = [[NSMutableDictionary alloc] init];
    
    injectToProperClass(@selector(overrideSetObject:forKey:), @selector(setObject:forKey:), @[], [NSUserDefaultsOverrider class], [NSUserDefaults class]);
    injectToProperClass(@selector(overrideSetDouble:forKey:), @selector(setDouble:forKey:), @[], [NSUserDefaultsOverrider class], [NSUserDefaults class]);
    injectToProperClass(@selector(overrideSetBool:forKey:), @selector(setBool:forKey:), @[], [NSUserDefaultsOverrider class], [NSUserDefaults class]);
    
    injectToProperClass(@selector(overrideObjectForKey:), @selector(objectForKey:), @[], [NSUserDefaultsOverrider class], [NSUserDefaults class]);
    injectToProperClass(@selector(overrideDoubleForKey:), @selector(doubleForKey:), @[], [NSUserDefaultsOverrider class], [NSUserDefaults class]);
    injectToProperClass(@selector(overrideBoolForKey:), @selector(boolForKey:), @[], [NSUserDefaultsOverrider class], [NSUserDefaults class]);
}

+(void) clearInternalDictionary {
    defaultsDictionary = [[NSMutableDictionary alloc] init];
}

// Sets
-(void) overrideSetObject:(id)value forKey:(NSString*)key {
    defaultsDictionary[key] = value;
}

-(void) overrideSetDouble:(double)value forKey:(NSString*)key {
    defaultsDictionary[key] = [NSNumber numberWithDouble:value];
}

-(void) overrideSetBool:(BOOL)value forKey:(NSString*)key {
    defaultsDictionary[key] = [NSNumber numberWithBool:value];
}

// Gets
-(id) overrideObjectForKey:(NSString*)key {
    return defaultsDictionary[key];
}

-(double) overrideDoubleForKey:(NSString*)key {
    return [defaultsDictionary[key] doubleValue];
}

-(BOOL) overrideBoolForKey:(NSString*)key {
    return [defaultsDictionary[key] boolValue];
}

@end


@interface NSBundleOverrider : NSObject
@end
@implementation NSBundleOverrider

static NSDictionary* nsbundleDictionary;

+ (void)load {
    [NSBundleOverrider sizzleBundleIdentifier];
    injectToProperClass(@selector(overrideObjectForInfoDictionaryKey:), @selector(objectForInfoDictionaryKey:), @[], [NSBundleOverrider class], [NSBundle class]);
}


+ (void)sizzleBundleIdentifier {
    injectToProperClass(@selector(overrideBundleIdentifier), @selector(bundleIdentifier), @[], [NSBundleOverrider class], [NSBundle class]);
}

- (NSString*)overrideBundleIdentifier {
    return @"com.onesignal.unittest";
}

- (nullable id)overrideObjectForInfoDictionaryKey:(NSString*)key {
    return nsbundleDictionary[key];
}

@end


@interface UNUserNotificationCenterOverrider : NSObject
@end
@implementation UNUserNotificationCenterOverrider

static NSNumber *authorizationStatus;

+ (void)load {
    injectToProperClass(@selector(overrideInitWithBundleIdentifier:), @selector(initWithBundleIdentifier:), @[], [UNUserNotificationCenterOverrider class], [UNUserNotificationCenter class]);
    injectToProperClass(@selector(overrideGetNotificationSettingsWithCompletionHandler:), @selector(getNotificationSettingsWithCompletionHandler:), @[], [UNUserNotificationCenterOverrider class], [UNUserNotificationCenter class]);
}

- (id) overrideInitWithBundleIdentifier:(NSString*) bundle {
    return self;
}

- (void)overrideGetNotificationSettingsWithCompletionHandler:(void(^)(id settings))completionHandler {
    id retSettings = [UNNotificationSettings alloc];
    [retSettings setValue:authorizationStatus forKeyPath:@"authorizationStatus"];
    completionHandler(retSettings);
}

@end



static int notifTypesOverride = 7;

@interface UIApplicationOverrider : NSObject
@end
@implementation UIApplicationOverrider

static BOOL shouldFireDeviceToken = true;

+ (void)load {
   injectToProperClass(@selector(overrideRegisterForRemoteNotifications), @selector(registerForRemoteNotifications), @[], [UIApplicationOverrider class], [UIApplication class]);
   injectToProperClass(@selector(override_run), @selector(_run), @[], [UIApplicationOverrider class], [UIApplication class]);
   injectToProperClass(@selector(overrideCurrentUserNotificationSettings), @selector(currentUserNotificationSettings), @[], [UIApplicationOverrider class], [UIApplication class]);
}

// Keeps UIApplicationMain(...) from looping to continue to the next line.
- (void) override_run {}

- (void) overrideRegisterForRemoteNotifications {
    if (!shouldFireDeviceToken)
        return;
    
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

// Called before each test.
- (void)setUp {
    [super setUp];
    
    lastUrl = nil;
    lastHTTPRequset = nil;
    
    notifTypesOverride = 7;
    authorizationStatus = [NSNumber numberWithInteger:UNAuthorizationStatusAuthorized];
    
    shouldFireDeviceToken = true;
    nsbundleDictionary = @{@"UIBackgroundModes": @[@"remote-notification"]};
    
    // TODO: Keep commented out for now, might need this later.
    // [OneSignal performSelector:NSSelectorFromString(@"clearStatics")];
    
    //[OneSignal setValue:@-1 forKey:@"_mSubscriptionStatus"];
    //[OneSignal setValue:-1 forKeyPath:@"mSubscriptionStatus"];
    
    [NSUserDefaultsOverrider clearInternalDictionary];
    
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
}


- (void)pressDontAllowOnNotifiationPrompt {
    UIApplication *sharedApp = [UIApplication sharedApplication];
    [sharedApp.delegate application:sharedApp didRegisterUserNotificationSettings:[UIUserNotificationSettings settingsForTypes:notifTypesOverride categories:nil]];
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
    XCTAssertEqualObjects(lastHTTPRequset[@"notification_types"], @7);
    XCTAssertEqualObjects(lastHTTPRequset[@"device_model"], @"x86_64");
    XCTAssertEqualObjects(lastHTTPRequset[@"device_type"], @0);
    XCTAssertEqualObjects(lastHTTPRequset[@"language"], @"en");
    
    // 2nd init call should not fire another on_session call.
    lastHTTPRequset = nil;
    [OneSignal initWithLaunchOptions:nil appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"];
    XCTAssertNil(lastHTTPRequset);
    
    // NSLog(@"Sleeping for debugging");
    // [NSThread sleepForTimeInterval:1000];
}

- (void)testPromptedButNeverAnwserNotificationPrompt {
    notifTypesOverride = 0;
    authorizationStatus = [NSNumber numberWithInteger:UNAuthorizationStatusNotDetermined];
    
    [OneSignal initWithLaunchOptions:nil appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"];
    
    // Don't make a network call right away.
    XCTAssertNil(lastHTTPRequset);
    
    // Triggers the 30 fallback to register device right away.
    [OneSignal performSelector:NSSelectorFromString(@"registerUser")];
    
    XCTAssertEqualObjects(lastHTTPRequset[@"app_id"], @"b2f7f966-d8cc-11e4-bed1-df8f05be55ba");
    XCTAssertEqualObjects(lastHTTPRequset[@"notification_types"], @0);
}

- (void)testNotAcceptingNotificationsWithoutBackgroundModes {
    notifTypesOverride = 0;
    nsbundleDictionary = @{};
    
    [OneSignal initWithLaunchOptions:nil appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"];
    
    // Don't make a network call right away.
    XCTAssertNil(lastHTTPRequset);
    
    [self pressDontAllowOnNotifiationPrompt];
    
    XCTAssertEqualObjects(lastUrl, @"https://onesignal.com/api/v1/players");
    XCTAssertEqualObjects(lastHTTPRequset[@"app_id"], @"b2f7f966-d8cc-11e4-bed1-df8f05be55ba");
    XCTAssertNil(lastHTTPRequset[@"identifier"]);
    XCTAssertEqualObjects(lastHTTPRequset[@"notification_types"], @0);
}

- (void)testgetIdsAvailableNotAcceptingNotifications {
    notifTypesOverride = 0;
    [OneSignal initWithLaunchOptions:nil appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"
            handleNotificationAction:nil
                            settings:@{kOSSettingsKeyAutoPrompt: @false}];
    
    __block BOOL idsAvailable1Called = false;
    [OneSignal IdsAvailable:^(NSString *userId, NSString *pushToken) {
        idsAvailable1Called = true;
    }];
    
    [OneSignal registerForPushNotifications];
    
    [self pressDontAllowOnNotifiationPrompt];
    
    XCTAssertTrue(idsAvailable1Called);
    
    
    [OneSignal initWithLaunchOptions:nil appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"
            handleNotificationAction:nil
                            settings:@{kOSSettingsKeyAutoPrompt: @false}];
    
    __block BOOL idsAvailable2Called = false;
    [OneSignal IdsAvailable:^(NSString *userId, NSString *pushToken) {
        idsAvailable2Called = true;
        NSLog(@"22222222HERE idsAvaialble!: %@, %@", userId, pushToken);
    }];
    
    XCTAssertTrue(idsAvailable2Called);
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
