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
#import "SwizzlingForwarder.h"
#import <objc/runtime.h>

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
@end

// This class hooks into the UIApplicationDelegate selectors to receive iOS 9 and older events.
//   - UNUserNotificationCenter is used for iOS 10
//   - Orignal implementations are called so other plugins and the developers AppDelegate is still called.

@implementation OneSignalAppDelegate

+ (void) oneSignalLoadedTagSelector {}

// A Set to keep track of which classes we have already swizzled so we only
// swizzle each one once. If we swizzled more than once then this will create
// an infinite loop, this includes swizzling with ourselves but also with
// another SDK that swizzles.
static NSMutableSet<Class>* swizzledClasses;

IMP __originalAppWillTerminate;
int loopCount = 0;

- (void) setOneSignalDelegate:(id<UIApplicationDelegate>)delegate {
    [OneSignalAppDelegate traceCall:@"setOneSignalDelegate:"];
    [OneSignal onesignalLog:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"ONESIGNAL setOneSignalDelegate CALLED: %@", delegate]];
    
    if (swizzledClasses == nil)
        swizzledClasses = [NSMutableSet new];
    
    Class delegateClass = [delegate class];
    
    if (delegate == nil || [OneSignalAppDelegate swizzledClassInHeirarchy:delegateClass]) {
        [self setOneSignalDelegate:delegate];
        return;
    }
    
    [swizzledClasses addObject:delegateClass];
    
    Class newClass = [OneSignalAppDelegate class];
    
    // Need to keep this one for iOS 10 for content-available notifiations when the app is not in focus
    //   iOS 10 doesn't fire a selector on UNUserNotificationCenter in this cases most likely becuase
    //   UNNotificationServiceExtension (mutable-content) and UNNotificationContentExtension (with category) replaced it.
    injectSelector(
        delegateClass,
        @selector(application:didReceiveRemoteNotification:fetchCompletionHandler:),
        newClass,
        @selector(oneSignalReceiveRemoteNotification:UserInfo:fetchCompletionHandler:)
    );

    injectSelector(
        delegateClass,
        @selector(application:didFailToRegisterForRemoteNotificationsWithError:),
        newClass,
        @selector(oneSignalDidFailRegisterForRemoteNotification:error:)
    );
    
    injectSelector(
        delegateClass,
        @selector(application:didRegisterForRemoteNotificationsWithDeviceToken:),
        newClass,
        @selector(oneSignalDidRegisterForRemoteNotifications:deviceToken:)
    );
    injectSelector(delegateClass, @selector(applicationWillTerminate:), newClass, @selector(oneSignalApplicationWillTerminate:));
    [OneSignalAppDelegate swizzlePreiOS10Methods:delegateClass];

    [self setOneSignalDelegate:delegate];
}

+ (BOOL)swizzledClassInHeirarchy:(Class)delegateClass {
    if ([swizzledClasses containsObject:delegateClass]) {
        [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"OneSignal already swizzled %@", NSStringFromClass(delegateClass)]];
        return true;
    }
    Class superClass = class_getSuperclass(delegateClass);
    while(superClass) {
        if ([swizzledClasses containsObject:superClass]) {
            [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"OneSignal already swizzled %@ in parent class: %@", NSStringFromClass(delegateClass), NSStringFromClass(superClass)]];
            return true;
        }
        superClass = class_getSuperclass(superClass);
    }
    return false;
}

+ (void)swizzlePreiOS10Methods:(Class)delegateClass {
    if ([OneSignalHelper isIOSVersionGreaterThanOrEqual:@"10.0"])
        return;
    
    injectSelector(
        delegateClass,
        @selector(application:handleActionWithIdentifier:forLocalNotification:completionHandler:),
        [OneSignalAppDelegate class],
        @selector(oneSignalLocalNotificationOpened:handleActionWithIdentifier:forLocalNotification:completionHandler:)
    );
    
    // Starting with iOS 10 requestAuthorizationWithOptions has it's own callback
    //   We also check the permssion status from applicationDidBecomeActive: each time.
    injectSelector(
        delegateClass,
        @selector(application:didRegisterUserNotificationSettings:),
        [OneSignalAppDelegate class],
        @selector(oneSignalDidRegisterUserNotifications:settings:)
    );
    
    injectSelector(
        delegateClass,
        @selector(application:didReceiveLocalNotification:),
        [OneSignalAppDelegate class],
        @selector(oneSignalLocalNotificationOpened:notification:)
    );
}

- (void)oneSignalDidRegisterForRemoteNotifications:(UIApplication*)app deviceToken:(NSData*)inDeviceToken {
    [OneSignalAppDelegate traceCall:@"oneSignalDidRegisterForRemoteNotifications:deviceToken:"];
    
    [OneSignal didRegisterForRemoteNotifications:app deviceToken:inDeviceToken];
    
    SwizzlingForwarder *forwarder = [[SwizzlingForwarder alloc]
        initWithTarget:self
        withYourSelector:@selector(
            oneSignalDidRegisterForRemoteNotifications:deviceToken:
        )
        withOriginalSelector:@selector(
            application:didRegisterForRemoteNotificationsWithDeviceToken:
        )
    ];
    [forwarder invokeWithArgs:@[app, inDeviceToken]];
}

- (void)oneSignalDidFailRegisterForRemoteNotification:(UIApplication*)app error:(NSError*)err {
    [OneSignalAppDelegate traceCall:@"oneSignalDidFailRegisterForRemoteNotification:error:"];
    
    if ([OneSignal appId])
        [OneSignal handleDidFailRegisterForRemoteNotification:err];
    
    SwizzlingForwarder *forwarder = [[SwizzlingForwarder alloc]
        initWithTarget:self
        withYourSelector:@selector(
            oneSignalDidFailRegisterForRemoteNotification:error:
        )
        withOriginalSelector:@selector(
           application:didFailToRegisterForRemoteNotificationsWithError:
        )
    ];
    [forwarder invokeWithArgs:@[app, err]];
}
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated"
// iOS 9 Only
- (void)oneSignalDidRegisterUserNotifications:(UIApplication*)application settings:(UIUserNotificationSettings*)notificationSettings {
    [OneSignalAppDelegate traceCall:@"oneSignalDidRegisterUserNotifications:settings:"];
    
    if ([OneSignal appId])
        [OneSignal updateNotificationTypes:(int)notificationSettings.types];
    
    if ([self respondsToSelector:@selector(oneSignalDidRegisterUserNotifications:settings:)])
        [self oneSignalDidRegisterUserNotifications:application settings:notificationSettings];
}
#pragma clang diagnostic pop

// Fires when a notication is opened or recieved while the app is in focus.
//   - Also fires when the app is in the background and a notificaiton with content-available=1 is received.
// NOTE: completionHandler must only be called once!
//          iOS 10 - This crashes the app if it is called twice! Crash will happen when the app is resumed.
//          iOS 9  - Does not have this issue.
- (void) oneSignalReceiveRemoteNotification:(UIApplication*)application UserInfo:(NSDictionary*)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult)) completionHandler {
    [OneSignalAppDelegate traceCall:@"oneSignalReceiveRemoteNotification:UserInfo:fetchCompletionHandler:"];
    SwizzlingForwarder *forwarder = [[SwizzlingForwarder alloc]
        initWithTarget:self
        withYourSelector:@selector(
            oneSignalReceiveRemoteNotification:UserInfo:fetchCompletionHandler:
        )
        withOriginalSelector:@selector(
            application:didReceiveRemoteNotification:fetchCompletionHandler:
        )
    ];

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
            startedBackgroundJob = [OneSignal receiveRemoteNotification:application UserInfo:userInfo completionHandler:forwarder.hasReceiver ? nil : completionHandler];
    }
    
    if (forwarder.hasReceiver) {
        [forwarder invokeWithArgs:@[application, userInfo, completionHandler]];
        return;
    }
    
    [OneSignalAppDelegate
        forwardToDepercatedApplication:application
        didReceiveRemoteNotification:userInfo];
    
    if (!startedBackgroundJob)
        completionHandler(UIBackgroundFetchResultNewData);
}

// Forwards to application:didReceiveRemoteNotification: in the rare case
// that the app happens to use this BUT doesn't use
// UNUserNotificationCenterDelegate OR
// application:didReceiveRemoteNotification:fetchCompletionHandler:
// https://developer.apple.com/documentation/uikit/uiapplicationdelegate/1623117-application?language=objc
+(void)forwardToDepercatedApplication:(UIApplication*)application didReceiveRemoteNotification:(NSDictionary*)userInfo {
    id<UIApplicationDelegate> originalDelegate = UIApplication.sharedApplication.delegate;
    if (![originalDelegate respondsToSelector:@selector(application:didReceiveRemoteNotification:)])
        return;
    
    // Make sure we don't forward to this depreated selector on cold start
    // from a notification open, since iOS itself doesn't call this either
    if ([[OneSignal valueForKey:@"coldStartFromTapOnNotification"] boolValue])
        return;
    
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wdeprecated-declarations"
    [originalDelegate application:application didReceiveRemoteNotification:userInfo];
    #pragma clang diagnostic pop
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated"
- (void) oneSignalLocalNotificationOpened:(UIApplication*)application handleActionWithIdentifier:(NSString*)identifier forLocalNotification:(UILocalNotification*)notification completionHandler:(void(^)()) completionHandler {
#pragma clang diagnostic pop
    [OneSignalAppDelegate traceCall:@"oneSignalLocalNotificationOpened:handleActionWithIdentifier:forLocalNotification:completionHandler:"];
    
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
    [OneSignalAppDelegate traceCall:@"oneSignalLocalNotificationOpened:notification:"];
    
    if ([OneSignal appId])
        [OneSignal processLocalActionBasedNotification:notification identifier:@"__DEFAULT__"];
    
    if([self respondsToSelector:@selector(oneSignalLocalNotificationOpened:notification:)])
        [self oneSignalLocalNotificationOpened:application notification:notification];
}

-(void)oneSignalApplicationWillTerminate:(UIApplication *)application {
    [OneSignalAppDelegate traceCall:@"oneSignalApplicationWillTerminate:"];

    if ([OneSignal appId])
        [OneSignalTracker onFocus:YES];



    SwizzlingForwarder *forwarder = [[SwizzlingForwarder alloc]
        initWithTarget:self
        withYourSelector:@selector(
            oneSignalApplicationWillTerminate:
        )
        withOriginalSelector:@selector(
            applicationWillTerminate:
        )
    ];
    [forwarder invokeWithArgs:@[application]];
}

// Used to log all calls, also used in unit tests to observer
// the OneSignalAppDelegate selectors get called.
+(void) traceCall:(NSString*)selector {
    [OneSignal onesignalLog:ONE_S_LL_VERBOSE message:selector];
}

@end
