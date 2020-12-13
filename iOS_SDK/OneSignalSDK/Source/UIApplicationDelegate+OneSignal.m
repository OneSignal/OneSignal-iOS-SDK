/**
 * Modified MIT License
 *
 * Copyright 2016 OneSignal
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * 1. The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * 2. All copies of substantial portions of the Software may only be used in connection
 * with services provided by OneSignal.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "UIApplicationDelegate+OneSignal.h"
#import "OSNotification+Internal.h"
#import "OneSignal.h"
#import "OneSignalCommonDefines.h"
#import "OneSignalTracker.h"
#import "OneSignalLocation.h"
#import "OneSignalSelectorHelpers.h"
#import "OneSignalHelper.h"
#import "OSMessagingController.h"

@interface OneSignal (UN_extra)
+ (void) didRegisterForRemoteNotifications:(UIApplication*)app deviceToken:(NSData*)inDeviceToken;
+ (void) handleDidFailRegisterForRemoteNotification:(NSError*)error;
+ (void) updateNotificationTypes:(int)notificationTypes;
+ (NSString*) appId;
+ (void)notificationReceived:(NSDictionary*)messageDict wasOpened:(BOOL)opened;
+ (BOOL) receiveRemoteNotification:(UIApplication*)application UserInfo:(NSDictionary*)userInfo completionHandler:(void (^)(UIBackgroundFetchResult))completionHandler;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated"
+ (void) processLocalActionBasedNotification:(UILocalNotification*) notification identifier:(NSString*)identifier;
#pragma clang diagnostic pop
+ (void) onesignal_Log:(ONE_S_LOG_LEVEL)logLevel message:(NSString*) message;
@end

// This class hooks into the UIApplicationDelegate selectors to receive iOS 9 and older events.
//   - UNUserNotificationCenter is used for iOS 10
//   - Orignal implementations are called so other plugins and the developers AppDelegate is still called.

@implementation OneSignalAppDelegate

+ (void) oneSignalLoadedTagSelector {}

static Class delegateClass = nil;

// Store an array of all UIAppDelegate subclasses to iterate over in cases where UIAppDelegate swizzled methods are not overriden in main AppDelegate
// But rather in one of the subclasses
static NSArray* delegateSubclasses = nil;

+(Class)delegateClass {
    return delegateClass;
}

- (void) setOneSignalDelegate:(id<UIApplicationDelegate>)delegate {
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"ONESIGNAL setOneSignalDelegate CALLED: %@", delegate]];
    
    if (delegateClass) {
        [self setOneSignalDelegate:delegate];
        return;
    }
    
    Class newClass = [OneSignalAppDelegate class];
    
    delegateClass = getClassWithProtocolInHierarchy([delegate class], @protocol(UIApplicationDelegate));
    delegateSubclasses = ClassGetSubclasses(delegateClass);
    
    // Need to keep this one for iOS 10 for content-available notifiations when the app is not in focus
    //   iOS 10 doesn't fire a selector on UNUserNotificationCenter in this cases most likely becuase
    //   UNNotificationServiceExtension (mutable-content) and UNNotificationContentExtension (with category) replaced it.
    injectToProperClass(@selector(oneSignalReceiveRemoteNotification:UserInfo:fetchCompletionHandler:),
                        @selector(application:didReceiveRemoteNotification:fetchCompletionHandler:), delegateSubclasses, newClass, delegateClass);
    
    [OneSignalAppDelegate sizzlePreiOS10MethodsPhase1];

    injectToProperClass(@selector(oneSignalDidFailRegisterForRemoteNotification:error:),
                        @selector(application:didFailToRegisterForRemoteNotificationsWithError:), delegateSubclasses, newClass, delegateClass);
    
    if (NSClassFromString(@"CoronaAppDelegate")) {
        [self setOneSignalDelegate:delegate];
        return;
    }
    
    injectToProperClass(@selector(oneSignalDidRegisterForRemoteNotifications:deviceToken:),
                        @selector(application:didRegisterForRemoteNotificationsWithDeviceToken:), delegateSubclasses, newClass, delegateClass);
    
    [OneSignalAppDelegate sizzlePreiOS10MethodsPhase2];

    // Used to track how long the app has been closed
    injectToProperClass(@selector(oneSignalApplicationWillTerminate:),
                        @selector(applicationWillTerminate:), delegateSubclasses, newClass, delegateClass);

    [self setOneSignalDelegate:delegate];
}

+ (void)sizzlePreiOS10MethodsPhase1 {
    if ([OneSignalHelper isIOSVersionGreaterThanOrEqual:@"10.0"])
        return;
    
    injectToProperClass(@selector(oneSignalLocalNotificationOpened:handleActionWithIdentifier:forLocalNotification:completionHandler:),
                        @selector(application:handleActionWithIdentifier:forLocalNotification:completionHandler:), delegateSubclasses, [OneSignalAppDelegate class], delegateClass);
    
    // iOS 10 requestAuthorizationWithOptions has it's own callback
    //   We also check the permssion status from applicationDidBecomeActive: each time.
    //   Keeping for fallback in case of a race condidion where the focus event fires to soon.
    injectToProperClass(@selector(oneSignalDidRegisterUserNotifications:settings:),
                        @selector(application:didRegisterUserNotificationSettings:), delegateSubclasses, [OneSignalAppDelegate class], delegateClass);
}

+ (void)sizzlePreiOS10MethodsPhase2 {
    if ([OneSignalHelper isIOSVersionGreaterThanOrEqual:@"10.0"])
        return;
    
    injectToProperClass(@selector(oneSignalReceivedRemoteNotification:userInfo:),
                        @selector(application:didReceiveRemoteNotification:), delegateSubclasses, [OneSignalAppDelegate class], delegateClass);
    
    injectToProperClass(@selector(oneSignalLocalNotificationOpened:notification:),
                        @selector(application:didReceiveLocalNotification:), delegateSubclasses, [OneSignalAppDelegate class], delegateClass);
}


- (void)oneSignalDidRegisterForRemoteNotifications:(UIApplication*)app deviceToken:(NSData*)inDeviceToken {
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"oneSignalDidRegisterForRemoteNotifications:deviceToken:"];
    
    [OneSignal didRegisterForRemoteNotifications:app deviceToken:inDeviceToken];
    
    if ([self respondsToSelector:@selector(oneSignalDidRegisterForRemoteNotifications:deviceToken:)])
        [self oneSignalDidRegisterForRemoteNotifications:app deviceToken:inDeviceToken];
}

- (void)oneSignalDidFailRegisterForRemoteNotification:(UIApplication*)app error:(NSError*)err {
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"oneSignalDidFailRegisterForRemoteNotification:error:"];
    
    if ([OneSignal appId])
        [OneSignal handleDidFailRegisterForRemoteNotification:err];
    
    if ([self respondsToSelector:@selector(oneSignalDidFailRegisterForRemoteNotification:error:)])
        [self oneSignalDidFailRegisterForRemoteNotification:app error:err];
}
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated"
// iOS 9 Only
- (void)oneSignalDidRegisterUserNotifications:(UIApplication*)application settings:(UIUserNotificationSettings*)notificationSettings {
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"oneSignalDidRegisterUserNotifications:settings:"];
    
    if ([OneSignal appId])
        [OneSignal updateNotificationTypes:(int)notificationSettings.types];
    
    if ([self respondsToSelector:@selector(oneSignalDidRegisterUserNotifications:settings:)])
        [self oneSignalDidRegisterUserNotifications:application settings:notificationSettings];
}
#pragma clang diagnostic pop
// Fallback method - Normally this would not fire as oneSignalReceiveRemoteNotification below will fire instead. Was needed for iOS 6 support in the past.
- (void)oneSignalReceivedRemoteNotification:(UIApplication*)application userInfo:(NSDictionary*)userInfo {
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"oneSignalReceivedRemoteNotification:userInfo:"];

    if ([OneSignal appId]) {
        [OneSignal notificationReceived:userInfo wasOpened:YES];
    }
    
    if ([self respondsToSelector:@selector(oneSignalReceivedRemoteNotification:userInfo:)])
        [self oneSignalReceivedRemoteNotification:application userInfo:userInfo];
}

// Fires when a notication is opened or recieved while the app is in focus.
//   - Also fires when the app is in the background and a notificaiton with content-available=1 is received.
// NOTE: completionHandler must only be called once!
//          iOS 10 - This crashes the app if it is called twice! Crash will happen when the app is resumed.
//          iOS 9  - Does not have this issue.
- (void) oneSignalReceiveRemoteNotification:(UIApplication*)application UserInfo:(NSDictionary*)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult)) completionHandler {
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"oneSignalReceiveRemoteNotification:UserInfo:fetchCompletionHandler:"];
    
    BOOL callExistingSelector = [self respondsToSelector:@selector(oneSignalReceiveRemoteNotification:UserInfo:fetchCompletionHandler:)];
    BOOL startedBackgroundJob = false;
    
    if ([OneSignal appId]) {
        let appState = [UIApplication sharedApplication].applicationState;
        let isVisibleNotification = userInfo[@"aps"][@"alert"] != nil;
        
        // iOS 9 - Notification was tapped on
        // https://medium.com/posts-from-emmerge/ios-push-notification-background-fetch-demystified-7090358bb66e
        //   - NOTE: We do not have the extra logic for the notifiation center or double tap home button cases
        //           of "inactive" on notification received the link above describes.
        //           Omiting that complex logic as iOS 9 usage stats are very low (12/11/2020) and these are rare cases.
        if ([OneSignalHelper isIOSVersionLessThan:@"10.0"] && appState == UIApplicationStateInactive && isVisibleNotification) {
            [OneSignal notificationReceived:userInfo wasOpened:YES];
        }
        else if (appState == UIApplicationStateActive && isVisibleNotification)
            [OneSignal notificationReceived:userInfo wasOpened:NO];
        else
            startedBackgroundJob = [OneSignal receiveRemoteNotification:application UserInfo:userInfo completionHandler:callExistingSelector ? nil : completionHandler];
    }
    
    if (callExistingSelector) {
        [self oneSignalReceiveRemoteNotification:application UserInfo:userInfo fetchCompletionHandler:completionHandler];
        return;
    }
    
    // Make sure not a cold start from tap on notification (OS doesn't call didReceiveRemoteNotification)
    if ([self respondsToSelector:@selector(oneSignalReceivedRemoteNotification:userInfo:)]
        && ![[OneSignal valueForKey:@"coldStartFromTapOnNotification"] boolValue])
        [self oneSignalReceivedRemoteNotification:application userInfo:userInfo];
    
    if (!startedBackgroundJob)
        completionHandler(UIBackgroundFetchResultNewData);
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated"
- (void) oneSignalLocalNotificationOpened:(UIApplication*)application handleActionWithIdentifier:(NSString*)identifier forLocalNotification:(UILocalNotification*)notification completionHandler:(void(^)()) completionHandler {
#pragma clang diagnostic pop
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"oneSignalLocalNotificationOpened:handleActionWithIdentifier:forLocalNotification:completionHandler:"];
    
    if ([OneSignal appId])
        [OneSignal processLocalActionBasedNotification:notification identifier:identifier];
    
    if ([self respondsToSelector:@selector(oneSignalLocalNotificationOpened:handleActionWithIdentifier:forLocalNotification:completionHandler:)])
        [self oneSignalLocalNotificationOpened:application handleActionWithIdentifier:identifier forLocalNotification:notification completionHandler:completionHandler];
    
    completionHandler();
}
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated"
- (void)oneSignalLocalNotificationOpened:(UIApplication*)application notification:(UILocalNotification*)notification {
#pragma clang diagnostic pop
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"oneSignalLocalNotificationOpened:notification:"];
    
    if ([OneSignal appId])
        [OneSignal processLocalActionBasedNotification:notification identifier:@"__DEFAULT__"];
    
    if([self respondsToSelector:@selector(oneSignalLocalNotificationOpened:notification:)])
        [self oneSignalLocalNotificationOpened:application notification:notification];
}

-(void)oneSignalApplicationWillTerminate:(UIApplication *)application {
    
    if ([OneSignal appId])
        [OneSignalTracker onFocus:YES];
    
    if ([self respondsToSelector:@selector(oneSignalApplicationWillTerminate:)])
        [self oneSignalApplicationWillTerminate:application];
}

@end
