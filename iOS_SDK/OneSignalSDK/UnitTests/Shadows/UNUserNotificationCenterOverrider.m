/*
 Modified MIT License
 
 Copyright 2017 OneSignal
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 
 1. The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.
 
 2. All copies of substantial portions of the Software may only be used in connection
 with services provided by OneSignal.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
 */

#import "UNUserNotificationCenterOverrider.h"

#include <dispatch/dispatch.h>

#import "OneSignalSelectorHelpers.h"

@implementation UNUserNotificationCenterOverrider

static int notifTypesOverride = 7;

static NSNumber *authorizationStatus;
static NSSet<UNNotificationCategory *>* lastSetCategories;

// Serial queue that simulates how UNNotification center fires callbacks.
static dispatch_queue_t unNotifiserialQueue;

static int getNotificationSettingsWithCompletionHandlerStackCount;

static XCTestCase* currentTestInstance;

static BOOL shouldSetProvisionalAuthStatus = false;

static UNAuthorizationOptions previousRequestedAuthorizationOptions = UNAuthorizationOptionNone;

static void (^lastRequestAuthorizationWithOptionsBlock)(BOOL granted, NSError *error);
// TODO: Commented out 🧪
+ (void)load {
    getNotificationSettingsWithCompletionHandlerStackCount =  0;
    
    unNotifiserialQueue = dispatch_queue_create("com.UNNotificationCenter", DISPATCH_QUEUE_SERIAL);
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wundeclared-selector"
    injectSelector(
        [UNUserNotificationCenter class],
        @selector(initWithBundleProxy:),
        [UNUserNotificationCenterOverrider class],
        @selector(overrideInitWithBundleProxy:)
    );
    #pragma clang diagnostic pop
//    
//    injectSelector(
//        [UNUserNotificationCenter class],
//        @selector(initWithBundleIdentifier:),
//        [UNUserNotificationCenterOverrider class],
//        @selector(overrideInitWithBundleIdentifier:)
//    );
//    injectSelector(
//        [UNUserNotificationCenter class],
//        @selector(getNotificationSettingsWithCompletionHandler:),
//        [UNUserNotificationCenterOverrider class],
//        @selector(overrideGetNotificationSettingsWithCompletionHandler:)
//    );
//    injectSelector(
//        [UNUserNotificationCenter class],
//        @selector(setNotificationCategories:),
//        [UNUserNotificationCenterOverrider class],
//        @selector(overrideSetNotificationCategories:)
//    );
//    injectSelector(
//       [UNUserNotificationCenter class],
//       @selector(getNotificationCategoriesWithCompletionHandler:),
//       [UNUserNotificationCenterOverrider class],
//       @selector(overrideGetNotificationCategoriesWithCompletionHandler:)
//    );
//    injectSelector(
//       [UNUserNotificationCenter class],
//       @selector(requestAuthorizationWithOptions:completionHandler:),
//       [UNUserNotificationCenterOverrider class],
//       @selector(overrideRequestAuthorizationWithOptions:completionHandler:)
//   );
}

//+ (UNAuthorizationOptions)lastRequestedAuthorizationOptions {
//    return previousRequestedAuthorizationOptions;
//}
//
//+ (void)reset:(XCTestCase*)testInstance {
//    currentTestInstance = testInstance;
//    lastSetCategories = nil;
//    shouldSetProvisionalAuthStatus = false;
//    previousRequestedAuthorizationOptions = UNAuthorizationOptionNone;
//}
//
//+ (void)setNotifTypesOverride:(int)value {
//    notifTypesOverride = value;
//}
//
//+ (int)notifTypesOverride {
//    return notifTypesOverride;
//}
//
//+ (void)setAuthorizationStatus:(NSNumber*)value {
//    authorizationStatus = value;
//}
//+ (NSNumber*)authorizationStatus {
//    return authorizationStatus;
//}
//
//+ (int)lastSetCategoriesCount {
//    return (int)[lastSetCategories count];
//}
//
//+ (void)fireLastRequestAuthorizationWithGranted:(BOOL)granted {
//    if (lastRequestAuthorizationWithOptionsBlock)
//        lastRequestAuthorizationWithOptionsBlock(granted, nil);
//}

+ (void)runBackgroundThreads {
   dispatch_sync(unNotifiserialQueue, ^{});
}

// Called internally by currentNotificationCenter
- (id)overrideInitWithBundleProxy:(id)arg1 {
    return self;
}

- (id)overrideInitWithBundleIdentifier:(NSString*) bundle {
    return self;
}

+ (void)mockInteralGetNotificationSettingsWithCompletionHandler:(void(^)(id settings))completionHandler {
    getNotificationSettingsWithCompletionHandlerStackCount++;
    
    // Simulates running on a sequential serial queue like iOS does.
    dispatch_async(unNotifiserialQueue, ^{
        
        id retSettings = [UNNotificationSettings alloc];
        [retSettings setValue:authorizationStatus forKeyPath:@"authorizationStatus"];
        
        if (notifTypesOverride >= 7 && notifTypesOverride != 16) {
            [retSettings setValue:[NSNumber numberWithInt:UNNotificationSettingEnabled] forKeyPath:@"badgeSetting"];
            [retSettings setValue:[NSNumber numberWithInt:UNNotificationSettingEnabled] forKeyPath:@"soundSetting"];
            [retSettings setValue:[NSNumber numberWithInt:UNNotificationSettingEnabled] forKeyPath:@"alertSetting"];
            [retSettings setValue:[NSNumber numberWithInt:UNNotificationSettingEnabled] forKeyPath:@"lockScreenSetting"];
        } else if (notifTypesOverride == 16) {
            [retSettings setValue:[NSNumber numberWithInt:UNNotificationSettingEnabled] forKey:@"notificationCenterSetting"];
        }
        
        //if (getNotificationSettingsWithCompletionHandlerStackCount > 1)
        //    _XCTPrimitiveFail(currentTestInstance);
        //[NSThread sleepForTimeInterval:0.01];
        completionHandler(retSettings);
        getNotificationSettingsWithCompletionHandlerStackCount--;
    });
}

//- (void)overrideGetNotificationSettingsWithCompletionHandler:(void(^)(id settings))completionHandler {
//    [UNUserNotificationCenterOverrider mockInteralGetNotificationSettingsWithCompletionHandler:completionHandler];
//}
//
//- (void)overrideSetNotificationCategories:(NSSet<UNNotificationCategory *> *)categories {
//    lastSetCategories = categories;
//}
//
//- (void)overrideGetNotificationCategoriesWithCompletionHandler:(void(^)(NSSet<id> *categories))completionHandler {
//    completionHandler(lastSetCategories);
//}
//
//- (void)overrideRequestAuthorizationWithOptions:(UNAuthorizationOptions)options
//                              completionHandler:(void (^)(BOOL granted, NSError *error))completionHandler {
//    previousRequestedAuthorizationOptions = options;
//    
//    if (shouldSetProvisionalAuthStatus)
//        authorizationStatus = @3;
//    
//    if (![authorizationStatus isEqualToNumber:[NSNumber numberWithInteger:UNAuthorizationStatusNotDetermined]] && ![authorizationStatus isEqualToNumber:@3])
//        completionHandler([authorizationStatus isEqual:[NSNumber numberWithInteger:UNAuthorizationStatusAuthorized]] || shouldSetProvisionalAuthStatus, nil);
//    else
//        lastRequestAuthorizationWithOptionsBlock = completionHandler;
//}
//
//+ (void)failIfInNotificationSettingsWithCompletionHandler {
//    if (getNotificationSettingsWithCompletionHandlerStackCount > 0)
//        _XCTPrimitiveFail(currentTestInstance);
//}
//
//+ (void)setShouldSetProvisionalAuthorizationStatus:(BOOL)provisional {
//    shouldSetProvisionalAuthStatus = provisional;
//}
@end
