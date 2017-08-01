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


#import "UncaughtExceptionHandler.h"


#import "OneSignal.h"

#import "OneSignalHelper.h"
#import "OneSignalTracker.h"
#import "OneSignalSelectorHelpers.h"
#import "NSString+OneSignal.h"
#import "UIApplicationDelegate+OneSignal.h"
#import "UNUserNotificationCenter+OneSignal.h"

#import "OneSignalNotificationSettingsIOS10.h"

#import "OSPermission.h"

#include <pthread.h>
#include <mach/mach.h>

static XCTestCase* currentTestInstance;

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

static dispatch_queue_t serialMockMainLooper;


@interface OneSignal (UN_extra)
+ (dispatch_queue_t) getRegisterQueue;
@end

// START - Selector Shadowing


@interface SelectorToRun : NSObject
@property NSObject* runOn;
@property SEL selector;
@property NSObject* withObject;
@end


@implementation SelectorToRun
@end

@interface NSObjectOverrider : NSObject
@end

@implementation NSObjectOverrider

static NSMutableArray* selectorsToRun;
static BOOL instantRunPerformSelectorAfterDelay;
static NSMutableArray* selectorNamesForInstantOnlyForFirstRun;

+ (void)load {
    injectToProperClass(@selector(overridePerformSelector:withObject:afterDelay:), @selector(performSelector:withObject:afterDelay:), @[], [NSObjectOverrider class], [NSObject class]);
    injectToProperClass(@selector(overridePerformSelector:withObject:), @selector(performSelector:withObject:), @[], [NSObjectOverrider class], [NSObject class]);
}

- (void)overridePerformSelector:(SEL)aSelector withObject:(nullable id)anArgument afterDelay:(NSTimeInterval)delay {
    // TOOD: Add && for calling from our unit test queue looper.
    /*
    if (![[NSThread mainThread] isEqual:[NSThread currentThread]])
        _XCTPrimitiveFail(currentTestInstance);
     */
    
    if (instantRunPerformSelectorAfterDelay || [selectorNamesForInstantOnlyForFirstRun containsObject:NSStringFromSelector(aSelector)]) {
        [selectorNamesForInstantOnlyForFirstRun removeObject:NSStringFromSelector(aSelector)];
        [self performSelector:aSelector withObject:anArgument];
    }
    else {
        SelectorToRun* selectorToRun = [SelectorToRun alloc];
        selectorToRun.runOn = self;
        selectorToRun.selector = aSelector;
        selectorToRun.withObject = anArgument;
        @synchronized(selectorsToRun) {
            [selectorsToRun addObject:selectorToRun];
        }
    }
}

- (id)overridePerformSelector:(SEL)aSelector withObject:(id)anArgument {
    return [self overridePerformSelector:aSelector withObject:anArgument];
}

+ (void)runPendingSelectors {
    @synchronized(selectorsToRun) {
        for(SelectorToRun* selectorToRun in selectorsToRun)
            [selectorToRun.runOn performSelector:selectorToRun.selector withObject:selectorToRun.withObject];
        
        [selectorsToRun removeAllObjects];
    }
}

@end



@interface NSUserDefaultsOverrider : NSObject
@end

static NSMutableDictionary* defaultsDictionary;

@implementation NSUserDefaultsOverrider
+ (void)load {
    defaultsDictionary = [[NSMutableDictionary alloc] init];
    
    injectToProperClass(@selector(overrideSetObject:forKey:), @selector(setObject:forKey:), @[], [NSUserDefaultsOverrider class], [NSUserDefaults class]);
    injectToProperClass(@selector(overrideSetString:forKey:), @selector(setString:forKey:), @[], [NSUserDefaultsOverrider class], [NSUserDefaults class]);
    injectToProperClass(@selector(overrideSetDouble:forKey:), @selector(setDouble:forKey:), @[], [NSUserDefaultsOverrider class], [NSUserDefaults class]);
    injectToProperClass(@selector(overrideSetBool:forKey:), @selector(setBool:forKey:), @[], [NSUserDefaultsOverrider class], [NSUserDefaults class]);
    
    injectToProperClass(@selector(overrideObjectForKey:), @selector(objectForKey:), @[], [NSUserDefaultsOverrider class], [NSUserDefaults class]);
    injectToProperClass(@selector(overrideStringForKey:), @selector(stringForKey:), @[], [NSUserDefaultsOverrider class], [NSUserDefaults class]);
    injectToProperClass(@selector(overrideDoubleForKey:), @selector(doubleForKey:), @[], [NSUserDefaultsOverrider class], [NSUserDefaults class]);
    injectToProperClass(@selector(overrideBoolForKey:), @selector(boolForKey:), @[], [NSUserDefaultsOverrider class], [NSUserDefaults class]);
}

+ (void)clearInternalDictionary {
    defaultsDictionary = [[NSMutableDictionary alloc] init];
}

// Sets
-(void)overrideSetObject:(id)value forKey:(NSString*)key {
    defaultsDictionary[key] = value;
}

-(void)overrideSetString:(NSString*)value forKey:(NSString*)key {
    defaultsDictionary[key] = value;
}

- (void)overrideSetDouble:(double)value forKey:(NSString*)key {
    defaultsDictionary[key] = [NSNumber numberWithDouble:value];
}

- (void)overrideSetBool:(BOOL)value forKey:(NSString*)key {
    defaultsDictionary[key] = [NSNumber numberWithBool:value];
}

// Gets
- (id)overrideObjectForKey:(NSString*)key {
    return defaultsDictionary[key];
}

- (NSString*)overrideStringForKey:(NSString*)key {
    return defaultsDictionary[key];
}

-( double)overrideDoubleForKey:(NSString*)key {
    return [defaultsDictionary[key] doubleValue];
}

- (BOOL)overrideBoolForKey:(NSString*)key {
    return [defaultsDictionary[key] boolValue];
}

@end

@interface NSDataOverrider : NSObject
@end
@implementation NSDataOverrider
+ (void)load {
    injectStaticSelector([NSDataOverrider class], @selector(overrideDataWithContentsOfURL:), [NSData class], @selector(dataWithContentsOfURL:));
}

// Mock data being downloaded from a remote URL.
+ (NSData*) overrideDataWithContentsOfURL:(NSURL *)url {
    char bytes[32];
    memset(bytes, 1, 32);
    
    return [NSData dataWithBytes:bytes length:32];
}

@end


@interface NSDateOverrider : NSObject
@end
@implementation NSDateOverrider

static NSTimeInterval timeOffset;

+ (void)load {
    injectToProperClass(@selector(overrideTimeIntervalSince1970), @selector(timeIntervalSince1970), @[], [NSDateOverrider class], [NSDate class]);
}

- (NSTimeInterval) overrideTimeIntervalSince1970 {
    NSTimeInterval current = [self overrideTimeIntervalSince1970];
    return current + timeOffset;
}

@end


@interface NSBundleOverrider : NSObject
@end
@implementation NSBundleOverrider

static NSDictionary* nsbundleDictionary;

+ (void)load {
    [NSBundleOverrider sizzleBundleIdentifier];
    
    injectToProperClass(@selector(overrideObjectForInfoDictionaryKey:), @selector(objectForInfoDictionaryKey:), @[], [NSBundleOverrider class], [NSBundle class]);
    injectToProperClass(@selector(overrideURLForResource:withExtension:), @selector(URLForResource:withExtension:), @[], [NSBundleOverrider class], [NSBundle class]);
    
    // Doesn't work to swizzle for mocking. Both an NSDictionary and NSMutableDictionarys both throw odd selecotor not found errors.
    // injectToProperClass(@selector(overrideInfoDictionary), @selector(infoDictionary), @[], [NSBundleOverrider class], [NSBundle class]);
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

- (NSURL*)overrideURLForResource:(NSString*)name withExtension:(NSString*)ext {
    NSString *content = @"File Contents";
    NSData *fileContents = [content dataUsingEncoding:NSUTF8StringEncoding];
    
    NSArray* paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString* nameWithExt = [name stringByAppendingString:[@"." stringByAppendingString:ext]];
    NSString* fullpath = [paths[0] stringByAppendingPathComponent:nameWithExt];
    
    [[NSFileManager defaultManager] createFileAtPath:fullpath
                                            contents:fileContents
                                          attributes:nil];
    
    NSLog(@"fullpath: %@", fullpath);
    return [NSURL URLWithString:[@"file://" stringByAppendingString:fullpath]];
}

@end


@interface NSURLConnectionOverrider : NSObject
@end
@implementation NSURLConnectionOverrider

+ (void)load {
    // Swizzle an injected method defined in OneSignalHelper
    injectStaticSelector([NSURLConnectionOverrider class], @selector(overrideDownloadItemAtURL:toFile:error:), [NSURLConnection class], @selector(downloadItemAtURL:toFile:error:));
}

// Override downloading of media attachment
+ (BOOL)overrideDownloadItemAtURL:(NSURL*)url toFile:(NSString*)localPath error:(NSError*)error {
    NSString *content = @"File Contents";
    NSData *fileContents = [content dataUsingEncoding:NSUTF8StringEncoding];
    [[NSFileManager defaultManager] createFileAtPath:localPath
                                            contents:fileContents
                                          attributes:nil];
    
    return true;
}

@end


static int notifTypesOverride = 7;


@interface UNUserNotificationCenterOverrider : NSObject
@end
@implementation UNUserNotificationCenterOverrider

static NSNumber *authorizationStatus;
static NSSet<UNNotificationCategory *>* lastSetCategories;

// Serial queue that simulates how UNNotification center fires callbacks.
static dispatch_queue_t unNotifiserialQueue;

static int getNotificationSettingsWithCompletionHandlerStackCount;

static void (^lastRequestAuthorizationWithOptionsBlock)(BOOL granted, NSError *error);

+ (void)load {
    getNotificationSettingsWithCompletionHandlerStackCount =  0;
    
    unNotifiserialQueue = dispatch_queue_create("com.UNNotificationCenter", DISPATCH_QUEUE_SERIAL);
    
    injectToProperClass(@selector(overrideInitWithBundleIdentifier:),
                        @selector(initWithBundleIdentifier:), @[],
                        [UNUserNotificationCenterOverrider class], [UNUserNotificationCenter class]);
    injectToProperClass(@selector(overrideGetNotificationSettingsWithCompletionHandler:),
                        @selector(getNotificationSettingsWithCompletionHandler:), @[],
                        [UNUserNotificationCenterOverrider class], [UNUserNotificationCenter class]);
    injectToProperClass(@selector(overrideSetNotificationCategories:),
                        @selector(setNotificationCategories:), @[],
                        [UNUserNotificationCenterOverrider class], [UNUserNotificationCenter class]);
    injectToProperClass(@selector(overrideGetNotificationCategoriesWithCompletionHandler:),
                        @selector(getNotificationCategoriesWithCompletionHandler:), @[],
                        [UNUserNotificationCenterOverrider class], [UNUserNotificationCenter class]);
    injectToProperClass(@selector(overrideRequestAuthorizationWithOptions:completionHandler:),
                        @selector(requestAuthorizationWithOptions:completionHandler:), @[],
                        [UNUserNotificationCenterOverrider class], [UNUserNotificationCenter class]);
}

- (id) overrideInitWithBundleIdentifier:(NSString*) bundle {
    return self;
}

+ (void)mockInteralGetNotificationSettingsWithCompletionHandler:(void(^)(id settings))completionHandler {
    getNotificationSettingsWithCompletionHandlerStackCount++;
    
    // Simulates running on a sequential serial queue like iOS does.
    dispatch_async(unNotifiserialQueue, ^{
        
        id retSettings = [UNNotificationSettings alloc];
        [retSettings setValue:authorizationStatus forKeyPath:@"authorizationStatus"];
        
        if (notifTypesOverride >= 7) {
            [retSettings setValue:[NSNumber numberWithInt:UNNotificationSettingEnabled] forKeyPath:@"badgeSetting"];
            [retSettings setValue:[NSNumber numberWithInt:UNNotificationSettingEnabled] forKeyPath:@"soundSetting"];
            [retSettings setValue:[NSNumber numberWithInt:UNNotificationSettingEnabled] forKeyPath:@"alertSetting"];
            [retSettings setValue:[NSNumber numberWithInt:UNNotificationSettingEnabled] forKeyPath:@"lockScreenSetting"];
        }
        
        //if (getNotificationSettingsWithCompletionHandlerStackCount > 1)
        //    _XCTPrimitiveFail(currentTestInstance);
        //[NSThread sleepForTimeInterval:0.01];
        completionHandler(retSettings);
        getNotificationSettingsWithCompletionHandlerStackCount--;
    });
}

- (void)overrideGetNotificationSettingsWithCompletionHandler:(void(^)(id settings))completionHandler {
    [UNUserNotificationCenterOverrider mockInteralGetNotificationSettingsWithCompletionHandler:completionHandler];
}

- (void)overrideSetNotificationCategories:(NSSet<UNNotificationCategory *> *)categories {
    lastSetCategories = categories;
}

- (void)overrideGetNotificationCategoriesWithCompletionHandler:(void(^)(NSSet<id> *categories))completionHandler {
    completionHandler(lastSetCategories);
}

- (void)overrideRequestAuthorizationWithOptions:(UNAuthorizationOptions)options
                              completionHandler:(void (^)(BOOL granted, NSError *error))completionHandler {
    if (authorizationStatus != [NSNumber numberWithInteger:UNAuthorizationStatusNotDetermined])
        completionHandler([authorizationStatus isEqual:[NSNumber numberWithInteger:UNAuthorizationStatusAuthorized]], nil);
    else
        lastRequestAuthorizationWithOptionsBlock = completionHandler;
}

@end

@interface UIApplicationOverrider : NSObject
@end
@implementation UIApplicationOverrider

static BOOL calledRegisterForRemoteNotifications;
static BOOL calledCurrentUserNotificationSettings;

static NSInteger didFailRegistarationErrorCode;
static BOOL shouldFireDeviceToken;

static UIApplicationState currentUIApplicationState;

static UILocalNotification* lastUILocalNotification;

static BOOL pendingRegiseterBlock;

+ (void)load {
    injectToProperClass(@selector(overrideRegisterForRemoteNotifications), @selector(registerForRemoteNotifications), @[], [UIApplicationOverrider class], [UIApplication class]);
    injectToProperClass(@selector(override_run), @selector(_run), @[], [UIApplicationOverrider class], [UIApplication class]);
    injectToProperClass(@selector(overrideCurrentUserNotificationSettings), @selector(currentUserNotificationSettings), @[], [UIApplicationOverrider class], [UIApplication class]);
    injectToProperClass(@selector(overrideRegisterForRemoteNotificationTypes:), @selector(registerForRemoteNotificationTypes:), @[], [UIApplicationOverrider class], [UIApplication class]);
    injectToProperClass(@selector(overrideRegisterUserNotificationSettings:), @selector(registerUserNotificationSettings:), @[], [UIApplicationOverrider class], [UIApplication class]);
    injectToProperClass(@selector(overrideApplicationState), @selector(applicationState), @[], [UIApplicationOverrider class], [UIApplication class]);
    injectToProperClass(@selector(overrideScheduleLocalNotification:), @selector(scheduleLocalNotification:), @[], [UIApplicationOverrider class], [UIApplication class]);
}

// Keeps UIApplicationMain(...) from looping to continue to the next line.
- (void) override_run {
    NSLog(@"override_run!!!!!!");
}

+ (void)helperCallDidRegisterForRemoteNotificationsWithDeviceToken {
    id app = [UIApplication sharedApplication];
    id appDelegate = [[UIApplication sharedApplication] delegate];
    
    if (didFailRegistarationErrorCode) {
        id error = [NSError errorWithDomain:@"any" code:didFailRegistarationErrorCode userInfo:nil];
        [appDelegate application:app didFailToRegisterForRemoteNotificationsWithError:error];
        return;
    }
    
    if (!shouldFireDeviceToken)
        return;
    
    pendingRegiseterBlock = true;
}

+ (void)callPendingApplicationDidRegisterForRemoteNotificaitonsWithDeviceToken {
    if (!pendingRegiseterBlock || currentUIApplicationState != UIApplicationStateActive)
        return;
    pendingRegiseterBlock = false;
    
    id app = [UIApplication sharedApplication];
    id appDelegate = [[UIApplication sharedApplication] delegate];
    
    char bytes[32];
    memset(bytes, 0, 32);
    id deviceToken = [NSData dataWithBytes:bytes length:32];
    [appDelegate application:app didRegisterForRemoteNotificationsWithDeviceToken:deviceToken];
}

// Called on iOS 8+
- (void) overrideRegisterForRemoteNotifications {
    calledRegisterForRemoteNotifications = true;
    [UIApplicationOverrider helperCallDidRegisterForRemoteNotificationsWithDeviceToken];
}

// iOS 7
- (void)overrideRegisterForRemoteNotificationTypes:(UIRemoteNotificationType)types {
    // Just using this flag to mimic the non-prompted behavoir
    if (authorizationStatus != [NSNumber numberWithInteger:UNAuthorizationStatusNotDetermined])
          [UIApplicationOverrider helperCallDidRegisterForRemoteNotificationsWithDeviceToken];
}


// iOS 8 & 9 Only
- (UIUserNotificationSettings*) overrideCurrentUserNotificationSettings {
    calledCurrentUserNotificationSettings = true;
    
    // Check for this as it will create thread locks on a real device.
    if (getNotificationSettingsWithCompletionHandlerStackCount > 0)
        _XCTPrimitiveFail(currentTestInstance);
    
    return [UIUserNotificationSettings settingsForTypes:notifTypesOverride categories:nil];
}

// KEEP - Used to prevent xctest from fowarding to the iOS 10 equivalent.
- (void)overrideRegisterUserNotificationSettings:(UIUserNotificationSettings *)notificationSettings {
}

- (UIApplicationState) overrideApplicationState {
    return currentUIApplicationState;
}

- (void)overrideScheduleLocalNotification:(UILocalNotification*)notification {
    lastUILocalNotification = notification;
}

@end

@interface OneSignalHelperOverrider : NSObject
@end
@implementation OneSignalHelperOverrider

static NSString* lastUrl;
static NSDictionary* lastHTTPRequset;
static int networkRequestCount;

static float mockIOSVersion;

+ (void)load {
    serialMockMainLooper = dispatch_queue_create("com.onesignal.unittest", DISPATCH_QUEUE_SERIAL);
    
    injectStaticSelector([OneSignalHelperOverrider class], @selector(overrideEnqueueRequest:onSuccess:onFailure:isSynchronous:), [OneSignalHelper class], @selector(enqueueRequest:onSuccess:onFailure:isSynchronous:));
    injectStaticSelector([OneSignalHelperOverrider class], @selector(overrideGetAppName), [OneSignalHelper class], @selector(getAppName));
    injectStaticSelector([OneSignalHelperOverrider class], @selector(overrideIsIOSVersionGreaterOrEqual:), [OneSignalHelper class], @selector(isIOSVersionGreaterOrEqual:));
    injectStaticSelector([OneSignalHelperOverrider class], @selector(overrideDispatch_async_on_main_queue:), [OneSignalHelper class], @selector(dispatch_async_on_main_queue:));
}

+ (NSString*) overrideGetAppName {
    return @"App Name";
}

+ (void)overrideEnqueueRequest:(NSURLRequest*)request onSuccess:(OSResultSuccessBlock)successBlock onFailure:(OSFailureBlock)failureBlock isSynchronous:(BOOL)isSynchronous {
    NSError *error = nil;
    
    NSLog(@"request.URL: %@", request.URL);
    
    NSMutableDictionary *parameters;
    
    NSData* httpData = [request HTTPBody];
    if (httpData)
         parameters = [NSJSONSerialization JSONObjectWithData:[request HTTPBody] options:0 error:&error];
    else {
        NSURLComponents *components = [NSURLComponents componentsWithString:request.URL.absoluteString];
        parameters = [NSMutableDictionary new];
        for(NSURLQueryItem *item in components.queryItems) {
            parameters[item.name] = item.value;
        }
    }
    
    // We should always send an app_id with every request.
    if (!parameters[@"app_id"])
        _XCTPrimitiveFail(currentTestInstance);
    
    networkRequestCount++;
    

    
    id url = [request URL];
    NSLog(@"url: %@", url);
    NSLog(@"parameters: %@", parameters);
    
    lastUrl = [url absoluteString];
    lastHTTPRequset = parameters;
    
    if (successBlock)
        successBlock(@{@"id": @"1234"});
}

+ (BOOL)overrideIsIOSVersionGreaterOrEqual:(float)version {
   return mockIOSVersion >= version;
}

+ (void) overrideDispatch_async_on_main_queue:(void(^)())block {
    dispatch_async(serialMockMainLooper, block);
}

@end



@interface AppDelegate : UIResponder <UIApplicationDelegate, UNUserNotificationCenterDelegate>
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication*)application didFinishLaunchingWithOptions:(NSDictionary*)launchOptions {
    
    return true;
}

@end

@interface NSLocaleOverrider : NSObject
@end

@implementation NSLocaleOverrider

static NSArray* preferredLanguagesArray;

+ (void)load {
    injectStaticSelector([NSLocaleOverrider class], @selector(overriderPreferredLanguages), [NSLocale class], @selector(preferredLanguages));
}

+ (NSArray<NSString*> *) overriderPreferredLanguages {
    return preferredLanguagesArray;
}

@end


@interface UIAlertViewOverrider : NSObject
@end

@implementation UIAlertViewOverrider
static NSMutableArray* uiAlertButtonArray;
static NSObject<UIAlertViewDelegate>* lastUIAlertViewDelegate;

+ (void)load {
    injectToProperClass(@selector(overrideAddButtonWithTitle:), @selector(addButtonWithTitle:), @[], [UIAlertViewOverrider class], [UIAlertView class]);
    
    injectToProperClass(@selector(overrideInitWithTitle:message:delegate:cancelButtonTitle:otherButtonTitles:),
                        @selector(initWithTitle:message:delegate:cancelButtonTitle:otherButtonTitles:), @[],
                        [UIAlertViewOverrider class], [UIAlertView class]);
}

- (NSInteger)overrideAddButtonWithTitle:(nullable NSString*)title {
    [uiAlertButtonArray addObject:title];
    return 0;
}

- (instancetype)overrideInitWithTitle:(nullable NSString *)title message:(nullable NSString *)message delegate:(nullable id /*<UIAlertViewDelegate>*/)delegate cancelButtonTitle:(nullable NSString *)cancelButtonTitle otherButtonTitles:(nullable NSString *)otherButtonTitles, ... {
    lastUIAlertViewDelegate = delegate;
    return self;
}

@end


/*
@interface OneSignalAlertViewDelegateOverrider : NSObject
@end

@implementation OneSignalAlertViewDelegateOverrider

+ (void)load {
    injectToProperClass(@selector(overrideAlertView:clickedButtonAtIndex), @selector(alertView:clickedButtonAtIndex:), @[], [OneSignalAlertViewDelegateOverrider class], [OneSignalAlertViewDelegate class]);
}

- (void)overrideAlertView:(UIAlertView*)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    
}

@end
*/

// END - Selector Shadowing




// START - Test Classes
@interface OSPermissionStateTestObserver : NSObject<OSPermissionObserver>
@end

@implementation OSPermissionStateTestObserver {
    @package OSPermissionStateChanges* last;
    @package int fireCount;
}

- (void)onOSPermissionChanged:(OSPermissionStateChanges*)stateChanges {
    NSLog(@"UnitTest:onOSPermissionChanged :\n%@", stateChanges);
    last = stateChanges;
    fireCount++;
}

@end


@interface OSSubscriptionStateTestObserver : NSObject<OSSubscriptionObserver>
@end

@implementation OSSubscriptionStateTestObserver {
    @package OSSubscriptionStateChanges* last;
    @package int fireCount;
}
- (void)onOSSubscriptionChanged:(OSSubscriptionStateChanges*)stateChanges {
    NSLog(@"UnitTest:onOSSubscriptionChanged:\n%@", stateChanges);
    last = stateChanges;
    fireCount++;
}
@end


// END - Test Classes



@interface UnitTests : XCTestCase
@end


static BOOL setupUIApplicationDelegate = false;

@implementation UnitTests

- (void)beforeAllTest {
    if (setupUIApplicationDelegate)
        return;
    
    // Normally this just loops internally, overwrote _run to work around this.
    UIApplicationMain(0, nil, nil, NSStringFromClass([AppDelegate class]));
    setupUIApplicationDelegate = true;
    // InstallUncaughtExceptionHandler();
    
    
    // Force swizzle in all methods for tests.
    mockIOSVersion = 8;
    [OneSignalAppDelegate swizzleSelectors];
    mockIOSVersion = 10;
}

- (void)clearStateForAppRestart {
    NSLog(@"=======  APP RESTART ======\n\n");
    timeOffset = 0;
    networkRequestCount = 0;
    lastUrl = nil;
    lastHTTPRequset = nil;
    
    lastSetCategories = nil;
    
    lastUILocalNotification = nil;
    
    pendingRegiseterBlock = false;
    
    preferredLanguagesArray = @[@"en-US"];


    [OneSignalHelper performSelector:NSSelectorFromString(@"resetLocals")];
    
    
    [OneSignal setValue:nil forKeyPath:@"lastAppActiveMessageId"];
    [OneSignal setValue:nil forKeyPath:@"lastnonActiveMessageId"];
    [OneSignal setValue:@0 forKeyPath:@"mSubscriptionStatus"];
    
    [OneSignalTracker performSelector:NSSelectorFromString(@"resetLocals")];
    
    
    shouldFireDeviceToken = true;
    calledRegisterForRemoteNotifications = false;
    calledCurrentUserNotificationSettings = false;
    didFailRegistarationErrorCode = 0;
    
    
    instantRunPerformSelectorAfterDelay = false;
    selectorNamesForInstantOnlyForFirstRun = [@[] mutableCopy];
    selectorsToRun = [[NSMutableArray alloc] init];
    
    [OneSignal performSelector:NSSelectorFromString(@"clearStatics")];
    
    uiAlertButtonArray = [NSMutableArray new];
    
    currentUIApplicationState = UIApplicationStateActive;
    
    [OneSignal setLogLevel:ONE_S_LL_VERBOSE visualLevel:ONE_S_LL_NONE];
}

// Called before each test.
- (void)setUp {
    [super setUp];
    
    currentTestInstance = self;
    
    mockIOSVersion = 10;
    
    [OneSignalUNUserNotificationCenter setUseiOS10_2_workaround:true];
    
    notifTypesOverride = 7;
    authorizationStatus = [NSNumber numberWithInteger:UNAuthorizationStatusAuthorized];
    
    nsbundleDictionary = @{@"UIBackgroundModes": @[@"remote-notification"]};
    
    [NSUserDefaultsOverrider clearInternalDictionary];
    
    
    [self clearStateForAppRestart];

    
    [self beforeAllTest];
    
    // Uncomment to simulate slow travis-CI runs.
    /*float minRange = 0, maxRange = 15;
    float random = ((float)arc4random() / 0x100000000 * (maxRange - minRange)) + minRange;
    NSLog(@"Sleeping for debugging: %f", random);
    [NSThread sleepForTimeInterval:random];*/
}

// Called after each test.
- (void)tearDown {
    [super tearDown];
    [self runBackgroundThreads];
}

- (void)backgroundModesDisabledInXcode {
    nsbundleDictionary = @{};
}

- (void)setCurrentNotificationPermissionAsUnanswered {
    notifTypesOverride = 0;
    authorizationStatus = [NSNumber numberWithInteger:UNAuthorizationStatusNotDetermined];
}

- (void)setCurrentNotificationPermission:(BOOL)accepted {
    if (accepted) {
        notifTypesOverride = 7;
        authorizationStatus = [NSNumber numberWithInteger:UNAuthorizationStatusAuthorized];
    }
    else {
        notifTypesOverride = 0;
        authorizationStatus = [NSNumber numberWithInteger:UNAuthorizationStatusDenied];
    }
}

- (void)registerForPushNotifications {
    [OneSignal registerForPushNotifications];
    [self backgroundApp];
}

- (void)answerNotifiationPrompt:(BOOL)accept {
    // iOS 10.2.1 Real device obserserved sequence of events:
    //   1. Call requestAuthorizationWithOptions to prompt for notifications.
    ///  2. App goes out of focus when the prompt is shown.
    //   3. User press ACCPET! and focus event fires.
    //   4. *(iOS bug?)* We check permission with currentNotificationCenter.getNotificationSettingsWithCompletionHandler and it show up as UNAuthorizationStatusDenied!?!?!
    //   5. Callback passed to getNotificationSettingsWithCompletionHandler then fires with Accpeted as TRUE.
    //   6. Check getNotificationSettingsWithCompletionHandler and it is then correctly reporting UNAuthorizationStatusAuthorized
    //   7. Note: If remote notification background modes are on then application:didRegisterForRemoteNotificationsWithDeviceToken: will fire after #5 on it's own.
    BOOL triggerDidRegisterForRemoteNotfications = (authorizationStatus == [NSNumber numberWithInteger:UNAuthorizationStatusNotDetermined] && accept);
    if (triggerDidRegisterForRemoteNotfications)
        [self setCurrentNotificationPermission:false];
    
    [self resumeApp];
    [self setCurrentNotificationPermission:accept];
    
    if (triggerDidRegisterForRemoteNotfications && nsbundleDictionary[@"UIBackgroundModes"])
        [UIApplicationOverrider helperCallDidRegisterForRemoteNotificationsWithDeviceToken];
    
    if (mockIOSVersion > 9) {
        if (lastRequestAuthorizationWithOptionsBlock)
            lastRequestAuthorizationWithOptionsBlock(accept, nil);
    }
    else if (mockIOSVersion > 7) {
        UIApplication *sharedApp = [UIApplication sharedApplication];
        [sharedApp.delegate application:sharedApp didRegisterUserNotificationSettings:[UIUserNotificationSettings settingsForTypes:notifTypesOverride categories:nil]];
    }
    else // iOS 7 - Only support accepted for now.
        [UIApplicationOverrider helperCallDidRegisterForRemoteNotificationsWithDeviceToken];
}

- (void)backgroundApp {
    currentUIApplicationState = UIApplicationStateBackground;
    UIApplication *sharedApp = [UIApplication sharedApplication];
    [sharedApp.delegate applicationWillResignActive:sharedApp];
}

- (void)resumeApp {
    currentUIApplicationState = UIApplicationStateActive;
    UIApplication *sharedApp = [UIApplication sharedApplication];
    [sharedApp.delegate applicationDidBecomeActive:sharedApp];
}

// Runs any blocks passed to dispatch_async()
- (void)runBackgroundThreads {

    NSLog(@"START runBackgroundThreads");
    
    dispatch_queue_t registerUserQueue, notifSettingsQueue;
    for(int i = 0; i < 10; i++) {
        dispatch_sync(serialMockMainLooper, ^{});
        
        notifSettingsQueue = [OneSignalNotificationSettingsIOS10 getQueue];
        if (notifSettingsQueue)
            dispatch_sync(notifSettingsQueue, ^{});
        
        registerUserQueue = [OneSignal getRegisterQueue];
        if (registerUserQueue)
            dispatch_sync(registerUserQueue, ^{});
        
        dispatch_sync(unNotifiserialQueue, ^{});
        
        dispatch_barrier_sync(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{});
        
        [UIApplicationOverrider callPendingApplicationDidRegisterForRemoteNotificaitonsWithDeviceToken];
    }
    
    NSLog(@"END runBackgroundThreads");
}


- (UNNotificationResponse*)createBasiciOSNotificationResponseWithPayload:(NSDictionary*)userInfo {
    // Mocking an iOS 10 notification
    // Setting response.notification.request.content.userInfo
    UNNotificationResponse *notifResponse = [UNNotificationResponse alloc];
    
    // Normal tap on notification
    [notifResponse setValue:@"com.apple.UNNotificationDefaultActionIdentifier" forKeyPath:@"actionIdentifier"];
    
    UNNotificationContent *unNotifContent = [UNNotificationContent alloc];
    UNNotification *unNotif = [UNNotification alloc];
    UNNotificationRequest *unNotifRequqest = [UNNotificationRequest alloc];
    // Set as remote push type
    [unNotifRequqest setValue:[UNPushNotificationTrigger alloc] forKey:@"trigger"];
    
    [unNotif setValue:unNotifRequqest forKeyPath:@"request"];
    [notifResponse setValue:unNotif forKeyPath:@"notification"];
    [unNotifRequqest setValue:unNotifContent forKeyPath:@"content"];
    [unNotifContent setValue:userInfo forKey:@"userInfo"];
    
    return notifResponse;
}
                                                                          
- (UNNotificationResponse*)createBasiciOSNotificationResponse {
  id userInfo = @{@"custom":
                      @{@"i": @"b2f7f966-d8cc-11e4-bed1-df8f05be55bb"}
                  };
  
  return [self createBasiciOSNotificationResponseWithPayload:userInfo];
}

// Helper used to simpify tests below.
- (void)initOneSignal {
    [OneSignal initWithLaunchOptions:nil appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"];
    
    // iOS fires the resume event when app is cold started.
    [self resumeApp];
}

- (void)testBasicInitTest {
    NSLog(@"iOS VERSION: %@", [[UIDevice currentDevice] systemVersion]);
    
    [self initOneSignal];
    [self runBackgroundThreads];
    
    XCTAssertEqualObjects(lastHTTPRequset[@"app_id"], @"b2f7f966-d8cc-11e4-bed1-df8f05be55ba");
    XCTAssertEqualObjects(lastHTTPRequset[@"identifier"], @"0000000000000000000000000000000000000000000000000000000000000000");
    XCTAssertEqualObjects(lastHTTPRequset[@"notification_types"], @15);
    XCTAssertEqualObjects(lastHTTPRequset[@"device_model"], @"x86_64");
    XCTAssertEqualObjects(lastHTTPRequset[@"device_type"], @0);
    XCTAssertEqualObjects(lastHTTPRequset[@"language"], @"en-US");
    
    OSPermissionSubscriptionState* status = [OneSignal getPermissionSubscriptionState];
    XCTAssertTrue(status.permissionStatus.accepted);
    XCTAssertTrue(status.permissionStatus.hasPrompted);
    XCTAssertTrue(status.permissionStatus.answeredPrompt);
    
    XCTAssertEqual(status.subscriptionStatus.subscribed, true);
    XCTAssertEqual(status.subscriptionStatus.userSubscriptionSetting, true);
    XCTAssertEqual(status.subscriptionStatus.userId, @"1234");
    XCTAssertEqualObjects(status.subscriptionStatus.pushToken, @"0000000000000000000000000000000000000000000000000000000000000000");
    
    // 2nd init call should not fire another on_session call.
    lastHTTPRequset = nil;
    [OneSignal initWithLaunchOptions:nil appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"];
    XCTAssertNil(lastHTTPRequset);
    
    XCTAssertEqual(networkRequestCount, 1);
}

- (void)testVersionStringLength {
	XCTAssertEqual(ONESIGNAL_VERSION.length, 6, @"ONESIGNAL_VERSION length is not 6: length is %lu", (unsigned long)ONESIGNAL_VERSION.length);
	XCTAssertEqual([OneSignal sdk_version_raw].length, 6, @"OneSignal sdk_version_raw length is not 6: length is %lu", (unsigned long)[OneSignal sdk_version_raw].length);
}

- (void)testSymanticVersioning {
	NSDictionary *versions = @{@"011303" : @"1.13.3",
                               @"020000" : @"2.0.0",
                               @"020116" : @"2.1.16",
                               @"020400" : @"2.4.0",
                               @"000400" : @"0.4.0",
                               @"000000" : @"0.0.0"};

	[versions enumerateKeysAndObjectsUsingBlock:^(NSString* raw, NSString* semantic, BOOL* stop) {
		XCTAssertEqualObjects([raw one_getSemanticVersion], semantic, @"Strings are not equal %@ %@", semantic, [raw one_getSemanticVersion] );
	}];

	NSDictionary *versionsThatFail = @{ @"011001" : @"1.0.1",
                                        @"011086" : @"1.10.6",
                                        @"011140" : @"1.11.0",
                                        @"011106" : @"1.11.1",
                                        @"091103" : @"1.11.3"};

	[versionsThatFail enumerateKeysAndObjectsUsingBlock:^(NSString* raw, NSString* semantic, BOOL* stop) {
		XCTAssertNotEqualObjects([raw one_getSemanticVersion], semantic, @"Strings are equal %@ %@", semantic, [raw one_getSemanticVersion] );
	}];

}

- (void)testRegisterationOniOS7 {
    mockIOSVersion = 7;
    
    [self initOneSignal];
    [self runBackgroundThreads];
    
    XCTAssertEqualObjects(lastHTTPRequset[@"app_id"], @"b2f7f966-d8cc-11e4-bed1-df8f05be55ba");
    XCTAssertEqualObjects(lastHTTPRequset[@"identifier"], @"0000000000000000000000000000000000000000000000000000000000000000");
    XCTAssertEqualObjects(lastHTTPRequset[@"notification_types"], @7);
    XCTAssertEqualObjects(lastHTTPRequset[@"device_model"], @"x86_64");
    XCTAssertEqualObjects(lastHTTPRequset[@"device_type"], @0);
    XCTAssertEqualObjects(lastHTTPRequset[@"language"], @"en-US");
    
    // 2nd init call should not fire another on_session call.
    lastHTTPRequset = nil;
    [OneSignal initWithLaunchOptions:nil appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"];
    XCTAssertNil(lastHTTPRequset);
    
    XCTAssertEqual(networkRequestCount, 1);
    
    // Make the following methods were not called as they are not available on iOS 7
    XCTAssertFalse(calledRegisterForRemoteNotifications);
    XCTAssertFalse(calledCurrentUserNotificationSettings);
}

// Seen a few rare crash reports where [NSLocale preferredLanguages] resturns an empty array
- (void)testInitWithEmptyPreferredLanguages {
    preferredLanguagesArray = @[];
    [self initOneSignal];
    [self runBackgroundThreads];
}

- (void)testInitOnSimulator {
    [self setCurrentNotificationPermissionAsUnanswered];
    [self backgroundModesDisabledInXcode];
    didFailRegistarationErrorCode = 3010;
    
    [self initOneSignal];
    [self runBackgroundThreads];
    [self answerNotifiationPrompt:true];
    [self runBackgroundThreads];
    
    XCTAssertEqualObjects(lastHTTPRequset[@"app_id"], @"b2f7f966-d8cc-11e4-bed1-df8f05be55ba");
    XCTAssertNil(lastHTTPRequset[@"identifier"]);
    XCTAssertEqualObjects(lastHTTPRequset[@"notification_types"], @-15);
    XCTAssertEqualObjects(lastHTTPRequset[@"device_model"], @"x86_64");
    XCTAssertEqualObjects(lastHTTPRequset[@"device_type"], @0);
    XCTAssertEqualObjects(lastHTTPRequset[@"language"], @"en-US");
    
    // 2nd init call should not fire another on_session call.
    lastHTTPRequset = nil;
    [self initOneSignal];
    XCTAssertNil(lastHTTPRequset);
    
    XCTAssertEqual(networkRequestCount, 1);
}


- (void)testFocusSettingsOnInit {
    // Test old kOSSettingsKeyInFocusDisplayOption
    [OneSignal initWithLaunchOptions:nil appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"
            handleNotificationAction:nil
                            settings:@{kOSSettingsKeyInFocusDisplayOption: @(OSNotificationDisplayTypeNone)}];
    
    XCTAssertEqual(OneSignal.inFocusDisplayType, OSNotificationDisplayTypeNone);
    
    [self clearStateForAppRestart];

    // Test old very old kOSSettingsKeyInAppAlerts
    [OneSignal initWithLaunchOptions:nil appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"
            handleNotificationAction:nil
                            settings:@{kOSSettingsKeyInAppAlerts: @(false)}];
    XCTAssertEqual(OneSignal.inFocusDisplayType, OSNotificationDisplayTypeNone);
}

- (void)testCallingMethodsBeforeInit {
    [self setCurrentNotificationPermission:true];
    
    [OneSignal sendTag:@"key" value:@"value"];
    [OneSignal setSubscription:true];
    [OneSignal promptLocation];
    [OneSignal promptForPushNotificationsWithUserResponse:nil];
    [self runBackgroundThreads];
    
    [self initOneSignal];
    [self runBackgroundThreads];
    
    XCTAssertEqualObjects(lastHTTPRequset[@"app_id"], @"b2f7f966-d8cc-11e4-bed1-df8f05be55ba");
    XCTAssertEqualObjects(lastHTTPRequset[@"tags"][@"key"], @"value");
    XCTAssertEqual(networkRequestCount, 1);
    
    [self clearStateForAppRestart];
    
    [OneSignal sendTag:@"key" value:@"value"];
    [OneSignal setSubscription:true];
    [OneSignal promptLocation];
    [OneSignal promptForPushNotificationsWithUserResponse:nil];
    [self runBackgroundThreads];
    
    [self initOneSignal];
    [self runBackgroundThreads];
    XCTAssertEqual(networkRequestCount, 0);
    
}

- (void)testPermissionChangeObserverIOS10 {
    mockIOSVersion = 10;
    [self sharedTestPermissionChangeObserver];
}
- (void)testPermissionChangeObserverIOS8 {
    mockIOSVersion = 8;
    [self sharedTestPermissionChangeObserver];
}
- (void)testPermissionChangeObserverIOS7 {
    mockIOSVersion = 7;
    [self sharedTestPermissionChangeObserver];
}
- (void)sharedTestPermissionChangeObserver {
    
    [self setCurrentNotificationPermissionAsUnanswered];
    [OneSignal initWithLaunchOptions:nil appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"
            handleNotificationAction:nil
                            settings:@{kOSSettingsKeyAutoPrompt: @false}];
    
    OSPermissionStateTestObserver* observer = [OSPermissionStateTestObserver new];
    [OneSignal addPermissionObserver:observer];
    
    [self registerForPushNotifications];
    [self runBackgroundThreads];
    
    XCTAssertEqual(observer->last.from.hasPrompted, false);
    XCTAssertEqual(observer->last.from.answeredPrompt, false);
    XCTAssertEqual(observer->last.to.hasPrompted, true);
    XCTAssertEqual(observer->last.to.answeredPrompt, false);
    XCTAssertEqual(observer->fireCount, 1);
    
    [self answerNotifiationPrompt:true];
    [self runBackgroundThreads];
    
    XCTAssertEqual(observer->last.from.accepted, false);
    XCTAssertEqual(observer->last.to.answeredPrompt, true);
    XCTAssertEqual(observer->last.to.accepted, true);
    
    // Make sure it doesn't fire for answeredPrompt then again right away for accepted
    XCTAssertEqual(observer->fireCount, 2);
    
    XCTAssertEqualObjects([observer->last description], @"<OSSubscriptionStateChanges:\nfrom: <OSPermissionState: hasPrompted: 1, status: NotDetermined>,\nto:   <OSPermissionState: hasPrompted: 1, status: Authorized>\n>");
}


- (void)testPermissionChangeObserverWhenAlreadyAccepted {
    [self initOneSignal];
    [self runBackgroundThreads];
    
    OSPermissionStateTestObserver* observer = [OSPermissionStateTestObserver new];
    [OneSignal addPermissionObserver:observer];
    [self runBackgroundThreads];
    
    XCTAssertEqual(observer->last.from.hasPrompted, false);
    XCTAssertEqual(observer->last.from.answeredPrompt, false);
    XCTAssertEqual(observer->last.from.accepted, false);
    XCTAssertEqual(observer->last.to.accepted, true);
    XCTAssertEqual(observer->fireCount, 1);
}

- (void)testPermissionChangeObserverFireAfterAppRestart {
    // Setup app as accepted.
    [self initOneSignal];
    [self runBackgroundThreads];
    OSPermissionStateTestObserver* observer = [OSPermissionStateTestObserver new];
    [OneSignal addPermissionObserver:observer];
    
    
    // User kills app, turns off notifications, then opnes it agian.
    [self clearStateForAppRestart];
    [self setCurrentNotificationPermission:false];
    [self initOneSignal];
    [self runBackgroundThreads];
    
    // Added Observer should be notified of the change right away.
    observer = [OSPermissionStateTestObserver new];
    [OneSignal addPermissionObserver:observer];
    [self runBackgroundThreads];
    
    XCTAssertEqual(observer->last.from.accepted, true);
    XCTAssertEqual(observer->last.to.accepted, false);
}


- (void)testPermissionObserverDontFireIfNothingChangedAfterAppRestartiOS10 {
    mockIOSVersion = 10;
    [self sharedPermissionObserverDontFireIfNothingChangedAfterAppRestart];
}
- (void)testPermissionObserverDontFireIfNothingChangedAfterAppRestartiOS8 {
    mockIOSVersion = 8;
    [self sharedPermissionObserverDontFireIfNothingChangedAfterAppRestart];
}
- (void)testPermissionObserverDontFireIfNothingChangedAfterAppRestartiOS7 {
    mockIOSVersion = 7;
    [self sharedPermissionObserverDontFireIfNothingChangedAfterAppRestart];
}
- (void)sharedPermissionObserverDontFireIfNothingChangedAfterAppRestart {
    [self setCurrentNotificationPermissionAsUnanswered];
    
    OSPermissionStateTestObserver* observer = [OSPermissionStateTestObserver new];
    [OneSignal addPermissionObserver:observer];
    
    [OneSignal initWithLaunchOptions:nil appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"
            handleNotificationAction:nil
                            settings:@{kOSSettingsKeyAutoPrompt: @false}];
    [self runBackgroundThreads];
    
    
    [self answerNotifiationPrompt:true];
    [self runBackgroundThreads];
    
    // Restart App
    [self clearStateForAppRestart];
    
    [OneSignal initWithLaunchOptions:nil appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"
            handleNotificationAction:nil
                            settings:@{kOSSettingsKeyAutoPrompt: @false}];
    
    observer = [OSPermissionStateTestObserver new];
    [OneSignal addPermissionObserver:observer];
    
    [self runBackgroundThreads];
    
    XCTAssertNil(observer->last);
}




- (void)testPermissionChangeObserverDontLoseFromChanges {
    [self setCurrentNotificationPermissionAsUnanswered];
    [OneSignal initWithLaunchOptions:nil appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"
            handleNotificationAction:nil
                            settings:@{kOSSettingsKeyAutoPrompt: @false}];
    [self runBackgroundThreads];
    
    [self registerForPushNotifications];
    [self answerNotifiationPrompt:true];
    [self runBackgroundThreads];
    
    OSPermissionStateTestObserver* observer = [OSPermissionStateTestObserver new];
    [OneSignal addPermissionObserver:observer];
    [self runBackgroundThreads];

    XCTAssertEqual(observer->last.from.hasPrompted, false);
    XCTAssertEqual(observer->last.from.answeredPrompt, false);
    XCTAssertEqual(observer->last.from.accepted, false);
    XCTAssertEqual(observer->last.to.accepted, true);
}

- (void)testSubscriptionChangeObserverWhenAlreadyAccepted {
    [self initOneSignal];
    [self runBackgroundThreads];
    
    OSSubscriptionStateTestObserver* observer = [OSSubscriptionStateTestObserver new];
    [OneSignal addSubscriptionObserver:observer];
    [self runBackgroundThreads];
    
    XCTAssertEqual(observer->last.from.subscribed, false);
    XCTAssertEqual(observer->last.to.subscribed, true);
    XCTAssertEqual(observer->fireCount, 1);
}

- (void)testSubscriptionChangeObserverFireAfterAppRestart {
    // Setup app as accepted.
    [self initOneSignal];
    [self runBackgroundThreads];
    OSSubscriptionStateTestObserver* observer = [OSSubscriptionStateTestObserver new];
    [OneSignal addSubscriptionObserver:observer];
    
    
    // User kills app, turns off notifications, then opnes it agian.
    [self clearStateForAppRestart];
    [self setCurrentNotificationPermission:false];
    [self initOneSignal];
    [self runBackgroundThreads];
    
    // Added Observer should be notified of the change right away.
    observer = [OSSubscriptionStateTestObserver new];
    [OneSignal addSubscriptionObserver:observer];
    [self runBackgroundThreads];
    
    XCTAssertEqual(observer->last.from.subscribed, true);
    XCTAssertEqual(observer->last.to.subscribed, false);
}


- (void)testPermissionChangeObserverWithNativeiOS10PromptCall {
    [self setCurrentNotificationPermissionAsUnanswered];
    [OneSignal initWithLaunchOptions:nil appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"
            handleNotificationAction:nil
                            settings:@{kOSSettingsKeyAutoPrompt: @false}];
    
    OSPermissionStateTestObserver* observer = [OSPermissionStateTestObserver new];
    [OneSignal addPermissionObserver:observer];
    
    UNUserNotificationCenter* center = [UNUserNotificationCenter currentNotificationCenter];
    [center requestAuthorizationWithOptions:(UNAuthorizationOptionAlert + UNAuthorizationOptionSound + UNAuthorizationOptionBadge)
                          completionHandler:^(BOOL granted, NSError* error) {}];
    [self backgroundApp];
    [self runBackgroundThreads];
    
    XCTAssertEqual(observer->fireCount, 1);
    XCTAssertEqualObjects([observer->last description],
                          @"<OSSubscriptionStateChanges:\nfrom: <OSPermissionState: hasPrompted: 0, status: NotDetermined>,\nto:   <OSPermissionState: hasPrompted: 1, status: NotDetermined>\n>");
    
    [self answerNotifiationPrompt:true];
    [self runBackgroundThreads];
    
    // Make sure it doesn't fire for answeredPrompt then again right away for accepted
    XCTAssertEqual(observer->fireCount, 2);
    XCTAssertEqualObjects([observer->last description],
                          @"<OSSubscriptionStateChanges:\nfrom: <OSPermissionState: hasPrompted: 1, status: NotDetermined>,\nto:   <OSPermissionState: hasPrompted: 1, status: Authorized>\n>");
}

// Yes, this starts with testTest, we are testing our Unit Test behavior!
//  Making sure our simulated methods using swizzling can reproduce an iOS 10.2.1 bug.
- (void)testTestPermissionChangeObserverWithNativeiOS10PromptCall {
    [OneSignalUNUserNotificationCenter setUseiOS10_2_workaround:false];
    
    [self setCurrentNotificationPermissionAsUnanswered];
    [OneSignal initWithLaunchOptions:nil appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"
            handleNotificationAction:nil
                            settings:@{kOSSettingsKeyAutoPrompt: @false}];
    
    OSPermissionStateTestObserver* observer = [OSPermissionStateTestObserver new];
    [OneSignal addPermissionObserver:observer];
    
    UNUserNotificationCenter* center = [UNUserNotificationCenter currentNotificationCenter];
    [center requestAuthorizationWithOptions:(UNAuthorizationOptionAlert + UNAuthorizationOptionSound + UNAuthorizationOptionBadge)
                          completionHandler:^(BOOL granted, NSError* error) {}];
    [self backgroundApp];
    // Full bug details explained in answerNotifiationPrompt
    [self answerNotifiationPrompt:true];
    [self runBackgroundThreads];
    
    XCTAssertEqual(observer->fireCount, 3);
    
    XCTAssertEqualObjects([observer->last description],
                          @"<OSSubscriptionStateChanges:\nfrom: <OSPermissionState: hasPrompted: 1, status: Denied>,\nto:   <OSPermissionState: hasPrompted: 1, status: Authorized>\n>");
}

- (void)testPermissionChangeObserverWithDecline {
    [self setCurrentNotificationPermissionAsUnanswered];
    [OneSignal initWithLaunchOptions:nil appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"
            handleNotificationAction:nil
                            settings:@{kOSSettingsKeyAutoPrompt: @false}];
    
    OSPermissionStateTestObserver* observer = [OSPermissionStateTestObserver new];
    [OneSignal addPermissionObserver:observer];
    
    [self registerForPushNotifications];
    [self runBackgroundThreads];
    
    XCTAssertEqual(observer->last.from.hasPrompted, false);
    XCTAssertEqual(observer->last.from.answeredPrompt, false);
    XCTAssertEqual(observer->last.to.hasPrompted, true);
    XCTAssertEqual(observer->last.to.answeredPrompt, false);
    XCTAssertEqual(observer->fireCount, 1);
    
    [self answerNotifiationPrompt:false];
    [self runBackgroundThreads];
    
    XCTAssertEqual(observer->last.from.accepted, false);
    XCTAssertEqual(observer->last.to.answeredPrompt, true);
    XCTAssertEqual(observer->last.to.accepted, false);
    XCTAssertEqual(observer->fireCount, 2);
}


- (void)testPermissionAndSubscriptionChangeObserverRemove {
    [self setCurrentNotificationPermissionAsUnanswered];
    [self backgroundModesDisabledInXcode];
    [OneSignal initWithLaunchOptions:nil appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"
            handleNotificationAction:nil
                            settings:@{kOSSettingsKeyAutoPrompt: @false}];
    
    OSPermissionStateTestObserver* permissionObserver = [OSPermissionStateTestObserver new];
    [OneSignal addPermissionObserver:permissionObserver];
    [OneSignal removePermissionObserver:permissionObserver];
    
    OSSubscriptionStateTestObserver* subscriptionObserver = [OSSubscriptionStateTestObserver new];
    [OneSignal addSubscriptionObserver:subscriptionObserver];
    [OneSignal removeSubscriptionObserver:subscriptionObserver];
    
    [self registerForPushNotifications];
    [self answerNotifiationPrompt:true];
    [self runBackgroundThreads];
    
    XCTAssertNil(permissionObserver->last);
    XCTAssertNil(subscriptionObserver->last);
}


- (void)testSubscriptionChangeObserverBasic {
    [self setCurrentNotificationPermissionAsUnanswered];
    [OneSignal initWithLaunchOptions:nil appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"
            handleNotificationAction:nil
                            settings:@{kOSSettingsKeyAutoPrompt: @false}];
    
    OSSubscriptionStateTestObserver* observer = [OSSubscriptionStateTestObserver new];
    [OneSignal addSubscriptionObserver:observer];
    [self registerForPushNotifications];
    [self answerNotifiationPrompt:true];
    [self runBackgroundThreads];
    
    XCTAssertEqual(observer->last.from.subscribed, false);
    XCTAssertEqual(observer->last.to.subscribed, true);
    
    [OneSignal setSubscription:false];
    
    XCTAssertEqual(observer->last.from.subscribed, true);
    XCTAssertEqual(observer->last.to.subscribed, false);
    
    XCTAssertEqualObjects([observer->last description], @"<OSSubscriptionStateChanges:\nfrom: <OSSubscriptionState: userId: 1234, pushToken: 0000000000000000000000000000000000000000000000000000000000000000, userSubscriptionSetting: 1, subscribed: 1>,\nto:   <OSSubscriptionState: userId: 1234, pushToken: 0000000000000000000000000000000000000000000000000000000000000000, userSubscriptionSetting: 0, subscribed: 0>\n>");
    NSLog(@"Test description: %@", observer->last);
}

- (void)testSubscriptionChangeObserverWhenPromptNotShown {
    [self setCurrentNotificationPermissionAsUnanswered];
    [OneSignal initWithLaunchOptions:nil appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"
            handleNotificationAction:nil
                            settings:@{kOSSettingsKeyAutoPrompt: @false}];
    
    OSSubscriptionStateTestObserver* observer = [OSSubscriptionStateTestObserver new];
    [OneSignal addSubscriptionObserver:observer];
    
    // Triggers the 30 fallback to register device right away.
    [self runBackgroundThreads];
    [NSObjectOverrider runPendingSelectors];
    [self runBackgroundThreads];
    
    XCTAssertNil(observer->last.from.userId);
    XCTAssertEqualObjects(observer->last.to.userId, @"1234");
    XCTAssertFalse(observer->last.to.subscribed);
    
    [OneSignal setSubscription:false];
    [self runBackgroundThreads];
    
    XCTAssertTrue(observer->last.from.userSubscriptionSetting);
    XCTAssertFalse(observer->last.to.userSubscriptionSetting);
    // Device registered with OneSignal so now make pushToken available.
    XCTAssertEqualObjects(observer->last.to.pushToken, @"0000000000000000000000000000000000000000000000000000000000000000");
    
    XCTAssertFalse(observer->last.from.subscribed);
    XCTAssertFalse(observer->last.to.subscribed);
    
    // Prompt and accept notifications
    [self registerForPushNotifications];
    [self answerNotifiationPrompt:true];
    [self runBackgroundThreads];
    
    // Shouldn't be subscribed yet as we called setSubscription:false before
    XCTAssertFalse(observer->last.from.subscribed);
    XCTAssertFalse(observer->last.to.subscribed);
    
    // Device should be reported a subscribed now as all condiditions are true.
    [OneSignal setSubscription:true];
    XCTAssertFalse(observer->last.from.subscribed);
    XCTAssertTrue(observer->last.to.subscribed);
}

- (void)testInitAcceptingNotificationsWithoutCapabilitesSet {
    [self backgroundModesDisabledInXcode];
    didFailRegistarationErrorCode = 3000;
    [self setCurrentNotificationPermissionAsUnanswered];
    
    [self initOneSignal];
    XCTAssertNil(lastHTTPRequset);
    
    [self answerNotifiationPrompt:true];
    [self runBackgroundThreads];
    XCTAssertEqualObjects(lastHTTPRequset[@"app_id"], @"b2f7f966-d8cc-11e4-bed1-df8f05be55ba");
    XCTAssertEqualObjects(lastHTTPRequset[@"notification_types"], @-13);
    XCTAssertEqual(networkRequestCount, 1);
}


- (void)testPromptForPushNotificationsWithUserResponse {
    [self setCurrentNotificationPermissionAsUnanswered];
    
    [self initOneSignal];
    
    __block BOOL didAccept;
    [OneSignal promptForPushNotificationsWithUserResponse:^(BOOL accepted) {
        didAccept = accepted;
    }];
    [self backgroundApp];
    [self answerNotifiationPrompt:true];
    [self runBackgroundThreads];
    XCTAssertTrue(didAccept);
}

- (void)testPromptForPushNotificationsWithUserResponseOnIOS8 {
    [self setCurrentNotificationPermissionAsUnanswered];
    mockIOSVersion = 8;
    
    [self initOneSignal];
    
    __block BOOL didAccept;
    [OneSignal promptForPushNotificationsWithUserResponse:^(BOOL accepted) {
        didAccept = accepted;
    }];
    [self backgroundApp];
    [self answerNotifiationPrompt:true];
    [self runBackgroundThreads];
    XCTAssertTrue(didAccept);
}

- (void)testPromptForPushNotificationsWithUserResponseOnIOS7 {
    [self setCurrentNotificationPermissionAsUnanswered];
    mockIOSVersion = 7;
    
    [self initOneSignal];
    
    __block BOOL didAccept;
    [OneSignal promptForPushNotificationsWithUserResponse:^(BOOL accepted) {
        didAccept = accepted;
    }];
    [self backgroundApp];
    [self answerNotifiationPrompt:true];
    [self runBackgroundThreads];
    XCTAssertTrue(didAccept);
}


- (void)testPromptedButNeveranswerNotificationPrompt {
    [self setCurrentNotificationPermissionAsUnanswered];
    
    [self initOneSignal];
    [self runBackgroundThreads];
    
    // Don't make a network call right away.
    XCTAssertNil(lastHTTPRequset);
    
    // Triggers the 30 fallback to register device right away.
    [OneSignal performSelector:NSSelectorFromString(@"registerUser")];
    [self runBackgroundThreads];
    
    XCTAssertEqualObjects(lastHTTPRequset[@"app_id"], @"b2f7f966-d8cc-11e4-bed1-df8f05be55ba");
    XCTAssertEqualObjects(lastHTTPRequset[@"notification_types"], @-19);
}

- (void)testNotificationTypesWhenAlreadyAcceptedWithAutoPromptOffOnFristStartPreIos10 {
    mockIOSVersion = 8;
    
    [OneSignal initWithLaunchOptions:nil appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"
            handleNotificationAction:nil
                            settings:@{kOSSettingsKeyAutoPrompt: @false}];
    
    [self runBackgroundThreads];
    
    XCTAssertEqualObjects(lastHTTPRequset[@"notification_types"], @7);
}


- (void)testNeverPromptedStatus {
    [self setCurrentNotificationPermissionAsUnanswered];
    
    [OneSignal initWithLaunchOptions:nil appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"
            handleNotificationAction:nil
                            settings:@{kOSSettingsKeyAutoPrompt: @false}];
    
    [self runBackgroundThreads];
    // Triggers the 30 fallback to register device right away.
    [NSObjectOverrider runPendingSelectors];
    [self runBackgroundThreads];
    
    XCTAssertEqualObjects(lastHTTPRequset[@"app_id"], @"b2f7f966-d8cc-11e4-bed1-df8f05be55ba");
    XCTAssertEqualObjects(lastHTTPRequset[@"notification_types"], @-18);
}

- (void)testNotAcceptingNotificationsWithoutBackgroundModes {
    [self setCurrentNotificationPermissionAsUnanswered];
    [self backgroundModesDisabledInXcode];
    
    [self initOneSignal];
    
    // Don't make a network call right away.
    XCTAssertNil(lastHTTPRequset);
    
    [self answerNotifiationPrompt:false];
    [self runBackgroundThreads];
    
    XCTAssertEqualObjects(lastUrl, @"https://onesignal.com/api/v1/players");
    XCTAssertEqualObjects(lastHTTPRequset[@"app_id"], @"b2f7f966-d8cc-11e4-bed1-df8f05be55ba");
    XCTAssertNil(lastHTTPRequset[@"identifier"]);
    XCTAssertEqualObjects(lastHTTPRequset[@"notification_types"], @0);
}

- (void)testIdsAvailableNotAcceptingNotifications {
    [self setCurrentNotificationPermissionAsUnanswered];
    [OneSignal initWithLaunchOptions:nil appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"
            handleNotificationAction:nil
                            settings:@{kOSSettingsKeyAutoPrompt: @false}];
    
    __block BOOL idsAvailable1Called = false;
    [OneSignal IdsAvailable:^(NSString *userId, NSString *pushToken) {
        idsAvailable1Called = true;
    }];
    
    [self runBackgroundThreads];
    
    [self registerForPushNotifications];
    
    [self answerNotifiationPrompt:false];
    
    [self runBackgroundThreads];
    XCTAssertTrue(idsAvailable1Called);
    
    
    [OneSignal initWithLaunchOptions:nil appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"
            handleNotificationAction:nil
                            settings:@{kOSSettingsKeyAutoPrompt: @false}];
    
    __block BOOL idsAvailable2Called = false;
    [OneSignal IdsAvailable:^(NSString *userId, NSString *pushToken) {
        idsAvailable2Called = true;
    }];
    
    [self runBackgroundThreads];
    XCTAssertTrue(idsAvailable2Called);
}

// Tests that a normal notification opened on iOS 10 triggers the handleNotificationAction.
- (void)testNotificationOpen {
    __block BOOL openedWasFire = false;
    
    [OneSignal initWithLaunchOptions:nil appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba" handleNotificationAction:^(OSNotificationOpenedResult *result) {
        XCTAssertNil(result.notification.payload.additionalData);
        XCTAssertEqual(result.action.type, OSNotificationActionTypeOpened);
        XCTAssertNil(result.action.actionID);
        openedWasFire = true;
    }];
    [self runBackgroundThreads];
    
    id notifResponse = [self createBasiciOSNotificationResponse];
    UNUserNotificationCenter *notifCenter = [UNUserNotificationCenter currentNotificationCenter];
    id notifCenterDelegate = notifCenter.delegate;
    // UNUserNotificationCenterDelegate method iOS 10 calls directly when a notification is opened.
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
    XCTAssertEqual(networkRequestCount, 2);
}

// Testing iOS 10 - old pre-2.4.0 button fromat - with original aps payload format
- (void)testNotificationOpenFromButtonPress {
    __block BOOL openedWasFire = false;
    
    [OneSignal initWithLaunchOptions:nil appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba" handleNotificationAction:^(OSNotificationOpenedResult *result) {
        XCTAssertEqualObjects(result.notification.payload.additionalData[@"actionSelected"], @"id1");
        XCTAssertEqual(result.action.type, OSNotificationActionTypeActionTaken);
        XCTAssertEqualObjects(result.action.actionID, @"id1");
        openedWasFire = true;
    }];
    [self runBackgroundThreads];
    currentUIApplicationState = UIApplicationStateInactive;
    
    id userInfo = @{@"aps": @{@"content_available": @1},
                    @"m": @"alert body only",
                    @"o": @[@{@"i": @"id1", @"n": @"text1"}],
                    @"custom": @{
                                @"i": @"b2f7f966-d8cc-11e4-bed1-df8f05be55bb"
                            }
                    };
    
    id notifResponse = [self createBasiciOSNotificationResponseWithPayload:userInfo];
    [notifResponse setValue:@"id1" forKeyPath:@"actionIdentifier"];
    
    UNUserNotificationCenter *notifCenter = [UNUserNotificationCenter currentNotificationCenter];
    id notifCenterDelegate = notifCenter.delegate;
    
    // UNUserNotificationCenterDelegate method iOS 10 calls directly when a notification is opened.
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
    XCTAssertEqual(networkRequestCount, 2);
}


// Testing iOS 10 - 2.4.0+ button fromat - with os_data aps payload format
- (void)testNotificationOpenFromButtonPressWithNewformat {
    __block BOOL openedWasFire = false;
    
    [OneSignal initWithLaunchOptions:nil appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba" handleNotificationAction:^(OSNotificationOpenedResult *result) {
        XCTAssertEqualObjects(result.notification.payload.additionalData[@"actionSelected"], @"id1");
        XCTAssertEqual(result.action.type, OSNotificationActionTypeActionTaken);
        XCTAssertEqualObjects(result.action.actionID, @"id1");
        openedWasFire = true;
    }];
    [self runBackgroundThreads];
    currentUIApplicationState = UIApplicationStateInactive;
    
    id userInfo = @{@"aps": @{
                        @"mutable-content": @1,
                        @"alert": @"Message Body"
                    },
                    @"os_data": @{
                        @"i": @"b2f7f966-d8cc-11e4-bed1-df8f05be55bb",
                        @"buttons": @[@{@"i": @"id1", @"n": @"text1"}],
                    }};
    
    id notifResponse = [self createBasiciOSNotificationResponseWithPayload:userInfo];
    [notifResponse setValue:@"id1" forKeyPath:@"actionIdentifier"];
    
    UNUserNotificationCenter *notifCenter = [UNUserNotificationCenter currentNotificationCenter];
    id notifCenterDelegate = notifCenter.delegate;
    
    // UNUserNotificationCenterDelegate method iOS 10 calls directly when a notification is opened.
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
    XCTAssertEqual(networkRequestCount, 2);
}

// Testing iOS 10 - 2.4.0+ button fromat - with os_data aps payload format
- (void)testNotificationAlertButtonsDisplayWithNewformat {
    __block BOOL openedWasFire = false;
    
    [OneSignal initWithLaunchOptions:nil appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba" handleNotificationAction:^(OSNotificationOpenedResult *result) {
        XCTAssertEqualObjects(result.notification.payload.additionalData[@"actionSelected"], @"id1");
        XCTAssertEqual(result.action.type, OSNotificationActionTypeActionTaken);
        XCTAssertEqualObjects(result.action.actionID, @"id1");
        openedWasFire = true;
    }];
    [self resumeApp];
    [self runBackgroundThreads];
    
    id userInfo = @{@"aps": @{
                            @"mutable-content": @1,
                            @"alert": @{@"body": @"Message Body", @"title": @"title"}
                            },
                    @"os_data": @{
                            @"i": @"b2f7f966-d8cc-11e4-bed1-df8f05be55bf",
                            @"buttons": @[@{@"i": @"id1", @"n": @"text1"}],
                            }};
    
    id notifResponse = [self createBasiciOSNotificationResponseWithPayload:userInfo];
    [notifResponse setValue:@"id1" forKeyPath:@"actionIdentifier"];
    
    UNUserNotificationCenter *notifCenter = [UNUserNotificationCenter currentNotificationCenter];
    id notifCenterDelegate = notifCenter.delegate;
    [notifCenterDelegate userNotificationCenter:notifCenter willPresentNotification:[notifResponse notification] withCompletionHandler:^(UNNotificationPresentationOptions options) {}];
    
    XCTAssertEqual(uiAlertButtonArray.count, 1);
    [lastUIAlertViewDelegate alertView:nil clickedButtonAtIndex:1];
    XCTAssertEqual(openedWasFire, true);
}


// Testing iOS 10 - with original aps payload format
- (void)testOpeningWithAdditionalData {
    __block BOOL openedWasFire = false;
    
    [OneSignal initWithLaunchOptions:nil appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba" handleNotificationAction:^(OSNotificationOpenedResult *result) {
        XCTAssertEqualObjects(result.notification.payload.additionalData[@"foo"], @"bar");
        XCTAssertEqual(result.action.type, OSNotificationActionTypeOpened);
        XCTAssertNil(result.action.actionID);
        openedWasFire = true;
    }];
    [self runBackgroundThreads];
    
    id userInfo = @{@"custom": @{
                      @"i": @"b2f7f966-d8cc-11e4-bed1-df8f05be55bb",
                      @"a": @{ @"foo": @"bar" }
                  }};
    
    id notifResponse = [self createBasiciOSNotificationResponseWithPayload:userInfo];
    UNUserNotificationCenter *notifCenter = [UNUserNotificationCenter currentNotificationCenter];
    id notifCenterDelegate = notifCenter.delegate;
    
    // UNUserNotificationCenterDelegate method iOS 10 calls directly when a notification is opend.
    [notifCenterDelegate userNotificationCenter:notifCenter didReceiveNotificationResponse:notifResponse withCompletionHandler:^() {}];
    XCTAssertEqual(openedWasFire, true);
    
    
    // Part 2 - New paylaod test
    // Current mocking isn't able to setup this test correctly.
    // In an app AppDelete selectors fire instead of UNUserNotificationCenter
    // SDK could also used some refactoring as this should't have an effect.
    /*
    openedWasFire = false;
    userInfo = @{@"alert": @"body",
                 @"os_data": @{
                         @"i": @"b2f7f966-d8cc-11e4-bed1-df8f05be55bc"
                         },
                 @"foo": @"bar"};
    notifResponse = [self createBasiciOSNotificationResponseWithPayload:userInfo];
    [notifCenterDelegate userNotificationCenter:notifCenter didReceiveNotificationResponse:notifResponse withCompletionHandler:^() {}];
    XCTAssertEqual(openedWasFire, true);
    */
}


// Testing iOS 10 - pre-2.4.0 button fromat - with os_data aps payload format
- (void)testRecievedCallbackWithButtons {
    __block BOOL recievedWasFire = false;
    
    [OneSignal initWithLaunchOptions:nil appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba" handleNotificationReceived:^(OSNotification *notification) {
        recievedWasFire = true;
        id actionButons = @[ @{@"id": @"id1", @"text": @"text1"} ];
        // TODO: Fix code so it don't use the shortened format.
        // XCTAssertEqualObjects(notification.payload.actionButtons, actionButons);
    } handleNotificationAction:nil settings:nil];
    [self runBackgroundThreads];
    
    id userInfo = @{@"aps": @{@"content_available": @1},
                    @"os_data": @{
                        @"i": @"b2f7f966-d8cc-11e4-bed1-df8f05be55bb",
                        @"buttons": @{
                            @"m": @"alert body only",
                            @"o": @[@{@"i": @"id1", @"n": @"text1"}]
                        }
                    }
                };
    
    id notifResponse = [self createBasiciOSNotificationResponseWithPayload:userInfo];
    UNUserNotificationCenter *notifCenter = [UNUserNotificationCenter currentNotificationCenter];
    id notifCenterDelegate = notifCenter.delegate;
    
    //iOS 10 calls  UNUserNotificationCenterDelegate method directly when a notification is received while the app is in focus.
    [notifCenterDelegate userNotificationCenter:notifCenter willPresentNotification:[notifResponse notification] withCompletionHandler:^(UNNotificationPresentationOptions options) {}];
    
    XCTAssertEqual(recievedWasFire, true);
}


// Testing iOS 8 - with os_data aps payload format
- (void)testGeneratingLocalNotificationWithButtonsiOS8OS_data {
    mockIOSVersion = 8;
    [self initOneSignal];
    [self runBackgroundThreads];
    [self backgroundApp];
    
    id userInfo = @{@"aps": @{@"content_available": @1},
                    @"os_data": @{
                            @"i": @"b2f7f966-d8cc-11e4-bed1-df8f05be55bb",
                            @"buttons": @{
                                    @"m": @"alert body only",
                                    @"o": @[@{@"i": @"id1", @"n": @"text1"}]
                                    }
                            }
                    };
    
    
    id appDelegate = [UIApplication sharedApplication].delegate;
                      
    [appDelegate application:[UIApplication sharedApplication]
didReceiveRemoteNotification:userInfo
      fetchCompletionHandler:^(UIBackgroundFetchResult result) { }];
    
    XCTAssertEqualObjects(lastUILocalNotification.alertBody, @"alert body only");
}


- (void)testGeneratingLocalNotificationWithButtonsiOS8 {
    mockIOSVersion = 8;
    [self initOneSignal];
    [self runBackgroundThreads];
    [self backgroundApp];
    
    id userInfo = @{@"aps": @{@"content_available": @1},
                    @"m": @"alert body only",
                    @"o": @[@{@"i": @"id1", @"n": @"text1"}],
                    @"custom": @{
                            @"i": @"b2f7f966-d8cc-11e4-bed1-df8f05be55bb"
                            }
                    };
    
    
    id appDelegate = [UIApplication sharedApplication].delegate;
    
    [appDelegate application:[UIApplication sharedApplication]
didReceiveRemoteNotification:userInfo
      fetchCompletionHandler:^(UIBackgroundFetchResult result) { }];
    
    XCTAssertEqualObjects(lastUILocalNotification.alertBody, @"alert body only");
}




- (void)testSendTags {
    [self initOneSignal];
    [self runBackgroundThreads];
    XCTAssertEqual(networkRequestCount, 1);
    
    // Simple test with a sendTag and sendTags call.
    [OneSignal sendTag:@"key" value:@"value"];
    [OneSignal sendTags:@{@"key1": @"value1", @"key2": @"value2"}];
    
    // Make sure all 3 sets of tags where send in 1 network call.
    [NSObjectOverrider runPendingSelectors];
    [self runBackgroundThreads];
    [NSObjectOverrider runPendingSelectors];
    
    XCTAssertEqualObjects(lastHTTPRequset[@"tags"][@"key"], @"value");
    XCTAssertEqualObjects(lastHTTPRequset[@"tags"][@"key1"], @"value1");
    XCTAssertEqualObjects(lastHTTPRequset[@"tags"][@"key2"], @"value2");
    XCTAssertEqual(networkRequestCount, 2);
    
    
    // More advanced test with callbacks.
    __block BOOL didRunSuccess1, didRunSuccess2, didRunSuccess3;
    [OneSignal sendTag:@"key10" value:@"value10" onSuccess:^(NSDictionary *result) {
        didRunSuccess1 = true;
    } onFailure:^(NSError *error) {}];
    [OneSignal sendTags:@{@"key11": @"value11", @"key12": @"value12"} onSuccess:^(NSDictionary *result) {
        didRunSuccess2 = true;
    } onFailure:^(NSError *error) {}];
    
    instantRunPerformSelectorAfterDelay = true;
    [OneSignal sendTag:@"key13" value:@"value13" onSuccess:^(NSDictionary *result) {
        didRunSuccess3 = true;
    } onFailure:^(NSError *error) {}];
    
    [self runBackgroundThreads];
    [NSObjectOverrider runPendingSelectors];
    [self runBackgroundThreads];
    
    XCTAssertEqualObjects(lastHTTPRequset[@"tags"][@"key10"], @"value10");
    XCTAssertEqualObjects(lastHTTPRequset[@"tags"][@"key11"], @"value11");
    XCTAssertEqualObjects(lastHTTPRequset[@"tags"][@"key12"], @"value12");
    XCTAssertEqualObjects(lastHTTPRequset[@"tags"][@"key13"], @"value13");
    XCTAssertEqual(networkRequestCount, 3);
    
    XCTAssertEqual(didRunSuccess1, true);
    XCTAssertEqual(didRunSuccess2, true);
    XCTAssertEqual(didRunSuccess3, true);
}

- (void)testDeleteTags {
    [self initOneSignal];
    [self runBackgroundThreads];
    XCTAssertEqual(networkRequestCount, 1);
    
    NSLog(@"Calling sendTag and deleteTag");
    // send 2 tags and delete 1 before they get sent off.
    [OneSignal sendTag:@"key" value:@"value"];
    [OneSignal sendTag:@"key2" value:@"value2"];
    [OneSignal deleteTag:@"key"];
    NSLog(@"Finished calling sendTag and deleteTag");
    
    // Make sure only 1 network call is made and only key2 gets sent.
    [NSObjectOverrider runPendingSelectors];
    [self runBackgroundThreads];
    
    XCTAssertNil(lastHTTPRequset[@"tags"][@"key"]);
    XCTAssertEqualObjects(lastHTTPRequset[@"tags"][@"key2"], @"value2");
    XCTAssertEqual(networkRequestCount, 2);
    
    
    [OneSignal sendTags:@{@"someKey": @NO}];
    [OneSignal deleteTag:@"someKey"];
}

- (void)testGetTags {
    [self initOneSignal];
    [self runBackgroundThreads];
    XCTAssertEqual(networkRequestCount, 1);
    
    __block BOOL fireGetTags = false;
    
    [OneSignal getTags:^(NSDictionary *result) {
        NSLog(@"getTags success HERE");
        fireGetTags = true;
    } onFailure:^(NSError *error) {
        NSLog(@"getTags onFailure HERE");
    }];
    
    [self runBackgroundThreads];
    
    XCTAssertTrue(fireGetTags);
}

- (void)testGetTagsBeforePlayerId {
    [self initOneSignal];
    [self runBackgroundThreads];
    XCTAssertEqual(networkRequestCount, 1);
    
    __block BOOL fireGetTags = false;
    
    [OneSignal getTags:^(NSDictionary *result) {
        NSLog(@"getTags success HERE");
        fireGetTags = true;
    } onFailure:^(NSError *error) {
        NSLog(@"getTags onFailure HERE");
    }];
    
    [self runBackgroundThreads];
    
    XCTAssertTrue(fireGetTags);

}

- (void)testGetTagsWithNestedDelete {
    [self initOneSignal];
    
    __block BOOL fireDeleteTags = false;
    
    [OneSignal getTags:^(NSDictionary *result) {
        NSLog(@"getTags success HERE");
        [OneSignal deleteTag:@"tag" onSuccess:^(NSDictionary *result) {
            fireDeleteTags = true;
            NSLog(@"deleteTag onSuccess HERE");
        } onFailure:^(NSError *error) {
            NSLog(@"deleteTag onFailure HERE");
        }];
    } onFailure:^(NSError *error) {
        NSLog(@"getTags onFailure HERE");
    }];
    
    
    [self runBackgroundThreads];
    
    [self runBackgroundThreads];
    [NSObjectOverrider runPendingSelectors];
    
    // create, ge tags, then sendTags call.
    XCTAssertEqual(networkRequestCount, 3);
    XCTAssertTrue(fireDeleteTags);
}

- (void)testSendTagsBeforeRegisterComplete {
    [self setCurrentNotificationPermissionAsUnanswered];
    
    [self initOneSignal];
    [self runBackgroundThreads];
    
    selectorNamesForInstantOnlyForFirstRun = [@[@"sendTagsToServer"] mutableCopy];
    
    [OneSignal sendTag:@"key" value:@"value"];
    [self runBackgroundThreads];
    
    // Do not try to send tag update yet as there isn't a player_id yet.
    XCTAssertEqual(networkRequestCount, 0);
    
    [self answerNotifiationPrompt:false];
    [self runBackgroundThreads];
    
    // A single POST player create call should be made with tags included.
    XCTAssertEqual(networkRequestCount, 1);
    XCTAssertEqualObjects(lastHTTPRequset[@"tags"][@"key"], @"value");
    XCTAssertEqualObjects(lastHTTPRequset[@"notification_types"], @0);
    XCTAssertEqualObjects(lastHTTPRequset[@"identifier"], @"0000000000000000000000000000000000000000000000000000000000000000");
}


- (void)testPostNotification {
    [self initOneSignal];
    [self runBackgroundThreads];
    XCTAssertEqual(networkRequestCount, 1);
    
    
    // Normal post should auto add add_id.
    [OneSignal postNotification:@{@"contents": @{@"en": @"message body"}}];
    XCTAssertEqual(networkRequestCount, 2);
    XCTAssertEqualObjects(lastHTTPRequset[@"contents"][@"en"], @"message body");
    XCTAssertEqualObjects(lastHTTPRequset[@"app_id"], @"b2f7f966-d8cc-11e4-bed1-df8f05be55ba");
    
    // Should allow overriding the app_id
    [OneSignal postNotification:@{@"contents": @{@"en": @"message body"}, @"app_id": @"override_app_UUID"}];
    XCTAssertEqual(networkRequestCount, 3);
    XCTAssertEqualObjects(lastHTTPRequset[@"contents"][@"en"], @"message body");
    XCTAssertEqualObjects(lastHTTPRequset[@"app_id"], @"override_app_UUID");
}


- (void)testFirstInitWithNotificationsAlreadyDeclined {
    [self backgroundModesDisabledInXcode];
    notifTypesOverride = 0;
    authorizationStatus = [NSNumber numberWithInteger:UNAuthorizationStatusDenied];
    
    [self initOneSignal];
    [self runBackgroundThreads];
    
    XCTAssertEqualObjects(lastHTTPRequset[@"notification_types"], @0);
    XCTAssertEqual(networkRequestCount, 1);
}

- (void)testPermissionChangedInSettingsOutsideOfApp {
    [self backgroundModesDisabledInXcode];
    notifTypesOverride = 0;
    authorizationStatus = [NSNumber numberWithInteger:UNAuthorizationStatusDenied];
    
    [self initOneSignal];
    [self runBackgroundThreads];
    
    OSPermissionStateTestObserver* observer = [OSPermissionStateTestObserver new];
    
    [OneSignal addPermissionObserver:observer];
    
    XCTAssertEqualObjects(lastHTTPRequset[@"notification_types"], @0);
    XCTAssertNil(lastHTTPRequset[@"identifier"]);
    
    [self backgroundApp];
    [self setCurrentNotificationPermission:true];
    [self resumeApp];
    [self runBackgroundThreads];
    
    XCTAssertEqualObjects(lastHTTPRequset[@"notification_types"], @15);
    XCTAssertEqualObjects(lastHTTPRequset[@"identifier"], @"0000000000000000000000000000000000000000000000000000000000000000");
    XCTAssertEqual(networkRequestCount, 2);
    
    XCTAssertEqual(observer->last.from.accepted, false);
    XCTAssertEqual(observer->last.to.accepted, true);
}

- (void) testOnSessionWhenResuming {
    [self initOneSignal];
    [self runBackgroundThreads];
    
    // Don't make an on_session call if only out of the app for 20 secounds
    [self backgroundApp];
    timeOffset = 10;
    [self resumeApp];
    [self runBackgroundThreads];
    XCTAssertEqual(networkRequestCount, 1);
    
    // Anything over 30 secounds should count as a session.
    [self backgroundApp];
    timeOffset += 31;
    [self resumeApp];
    [self runBackgroundThreads];
    
    XCTAssertEqualObjects(lastUrl, @"https://onesignal.com/api/v1/players/1234/on_session");
    XCTAssertEqual(networkRequestCount, 2);
}



// Tests that a slient content-available 1 notification doesn't trigger an on_session or count it has opened.
- (void)testContentAvailableDoesNotTriggerOpen  {
    currentUIApplicationState = UIApplicationStateBackground;
    __block BOOL receivedWasFire = false;
    [OneSignal initWithLaunchOptions:nil appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"
          handleNotificationReceived:^(OSNotification *result) {
            receivedWasFire = true;
          }
                 handleNotificationAction:nil
                            settings:nil];
    [self runBackgroundThreads];
    
    id userInfo = @{@"aps": @{@"content_available": @1},
                    @"custom": @{
                            @"i": @"b2f7f966-d8cc-11e4-1111-df8f05be55bb"
                            }
                    };
    
    
    id appDelegate = [UIApplication sharedApplication].delegate;
    [appDelegate application:[UIApplication sharedApplication]
didReceiveRemoteNotification:userInfo
      fetchCompletionHandler:^(UIBackgroundFetchResult result) { }];
    
    [self runBackgroundThreads];
    
    XCTAssertEqual(receivedWasFire, true);
    XCTAssertEqual(networkRequestCount, 0);
}



// iOS 10 - Notification Service Extension test
- (void) testDidReceiveNotificatioExtensionRequest {
    // Example of a pre-existing category a developer setup. + possibly an existing "__dynamic__" category of ours.
    id category = [NSClassFromString(@"UNNotificationCategory") categoryWithIdentifier:@"some_category" actions:@[] intentIdentifiers:@[] options:UNNotificationCategoryOptionCustomDismissAction];
    id category2 = [NSClassFromString(@"UNNotificationCategory") categoryWithIdentifier:@"__dynamic__" actions:@[] intentIdentifiers:@[] options:UNNotificationCategoryOptionCustomDismissAction];
    id category3 = [NSClassFromString(@"UNNotificationCategory") categoryWithIdentifier:@"some_category2" actions:@[] intentIdentifiers:@[] options:UNNotificationCategoryOptionCustomDismissAction];
    
    [[NSClassFromString(@"UNUserNotificationCenter") currentNotificationCenter] setNotificationCategories:[[NSMutableSet alloc] initWithArray:@[category, category2, category3]]];
    
    id userInfo = @{@"aps": @{
                        @"mutable-content": @1,
                        @"alert": @"Message Body"
                    },
                    @"os_data": @{
                        @"i": @"b2f7f966-d8cc-11e4-bed1-df8f05be55bb",
                        @"buttons": @[@{@"i": @"id1", @"n": @"text1"}],
                        @"att": @{ @"id": @"http://domain.com/file.jpg" }
                    }};
    
    id notifResponse = [self createBasiciOSNotificationResponseWithPayload:userInfo];
    
    UNMutableNotificationContent* content = [OneSignal didReceiveNotificationExtensionRequest:[notifResponse notification].request withMutableNotificationContent:nil];
    
    // Make sure butons were added.
    XCTAssertEqualObjects(content.categoryIdentifier, @"__dynamic__");
    // Make sure attachments were added.
    XCTAssertEqualObjects(content.attachments[0].identifier, @"id");
    XCTAssertEqualObjects(content.attachments[0].URL.scheme, @"file");
    
    
    // Run again with different buttons.
    userInfo = @{@"aps": @{
                         @"mutable-content": @1,
                         @"alert": @"Message Body"
                         },
                 @"os_data": @{
                         @"i": @"b2f7f966-d8cc-11e4-bed1-df8f05be55bb",
                         @"buttons": @[@{@"i": @"id2", @"n": @"text2"}],
                         @"att": @{ @"id": @"http://domain.com/file.jpg" }
                         }};
    
    notifResponse = [self createBasiciOSNotificationResponseWithPayload:userInfo];
    [OneSignal didReceiveNotificationExtensionRequest:[notifResponse notification].request withMutableNotificationContent:nil];
    
    XCTAssertEqual([lastSetCategories count], 3);
}

// iOS 10 - Notification Service Extension test
- (void) testDidReceiveNotificationExtensionRequestDontOverrideCateogory {    
    id userInfo = @{@"aps": @{
                            @"mutable-content": @1,
                            @"alert": @"Message Body"
                            },
                    @"os_data": @{
                            @"i": @"b2f7f966-d8cc-11e4-bed1-df8f05be55bb",
                            @"buttons": @[@{@"i": @"id1", @"n": @"text1"}],
                            @"att": @{ @"id": @"http://domain.com/file.jpg" }
                            }};
    
    id notifResponse = [self createBasiciOSNotificationResponseWithPayload:userInfo];
    
    [[notifResponse notification].request.content setValue:@"some_category" forKey:@"categoryIdentifier"];
    
    UNMutableNotificationContent* content = [OneSignal didReceiveNotificationExtensionRequest:[notifResponse notification].request withMutableNotificationContent:nil];
    
    // Make sure we didn't override an existing category
    XCTAssertEqualObjects(content.categoryIdentifier, @"some_category");
    // Make sure attachments were added.
    XCTAssertEqualObjects(content.attachments[0].identifier, @"id");
    XCTAssertEqualObjects(content.attachments[0].URL.scheme, @"file");
}


// iOS 10 - Notification Service Extension test - local file
- (void) testDidReceiveNotificationExtensionRequestLocalFile {
    id userInfo = @{@"aps": @{
                            @"mutable-content": @1,
                            @"alert": @"Message Body"
                            },
                    @"os_data": @{
                            @"i": @"b2f7f966-d8cc-11e4-bed1-df8f05be55bb",
                            @"att": @{ @"id": @"file.jpg" }
                            }};
    
    id notifResponse = [self createBasiciOSNotificationResponseWithPayload:userInfo];
    
    UNMutableNotificationContent* content = [OneSignal didReceiveNotificationExtensionRequest:[notifResponse notification].request withMutableNotificationContent:nil];

    // Make sure attachments were added.
    XCTAssertEqualObjects(content.attachments[0].identifier, @"id");
    XCTAssertEqualObjects(content.attachments[0].URL.scheme, @"file");
}

// iOS 10 - Notification Service Extension test
- (void) testServiceExtensionTimeWillExpireRequest {
    id userInfo = @{@"aps": @{
                        @"mutable-content": @1,
                        @"alert": @"Message Body"
                        },
                    @"os_data": @{
                        @"i": @"b2f7f966-d8cc-11e4-bed1-df8f05be55bb",
                        @"buttons": @[@{@"i": @"id1", @"n": @"text1"}],
                        @"att": @{ @"id": @"http://domain.com/file.jpg" }
                    }};
    
    id notifResponse = [self createBasiciOSNotificationResponseWithPayload:userInfo];
    
    UNMutableNotificationContent* content = [OneSignal serviceExtensionTimeWillExpireRequest:[notifResponse notification].request withMutableNotificationContent:nil];
    
    // Make sure butons were added.
    XCTAssertEqualObjects(content.categoryIdentifier, @"__dynamic__");
    // Make sure attachments were NOT added.
    //   We should not try to download attachemts as iOS is about to kill the extension and this will take to much time.
    XCTAssertNil(content.attachments);

}

@end
