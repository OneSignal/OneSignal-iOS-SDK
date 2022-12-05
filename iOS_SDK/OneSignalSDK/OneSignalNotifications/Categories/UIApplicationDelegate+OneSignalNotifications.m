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
#import "OneSignalNotifications.h"
#import "UIApplicationDelegate+OneSignalNotifications.h"
#import "OSNotification+Internal.h"
#import "OneSignalCommonDefines.h"
#import "OneSignalSelectorHelpers.h"
#import "SwizzlingForwarder.h"
#import "OSNotificationsManager.h"

// This class hooks into the UIApplicationDelegate selectors to receive iOS 9 and older events.
//   - UNUserNotificationCenter is used for iOS 10
//   - Orignal implementations are called so other plugins and the developers AppDelegate is still called.

@implementation OneSignalNotificationsAppDelegate

+ (void) oneSignalLoadedTagSelector {}

// A Set to keep track of which classes we have already swizzled so we only
// swizzle each one once. If we swizzled more than once then this will create
// an infinite loop, this includes swizzling with ourselves but also with
// another SDK that swizzles.
static NSMutableSet<Class>* swizzledClasses;

- (void) setOneSignalDelegate:(id<UIApplicationDelegate>)delegate {
    [OneSignalNotificationsAppDelegate traceCall:@"setOneSignalDelegate:"];
    [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"ONESIGNAL setOneSignalDelegate CALLED: %@", delegate]];
    
    if (swizzledClasses == nil)
        swizzledClasses = [NSMutableSet new];
    
    Class delegateClass = [delegate class];
    
    if (delegate == nil || [swizzledClasses containsObject:delegateClass]) {
        [self setOneSignalDelegate:delegate];
        return;
    }
    [swizzledClasses addObject:delegateClass];
    
    Class newClass = [OneSignalNotificationsAppDelegate class];
    
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

    [self setOneSignalDelegate:delegate];
}

- (void)oneSignalDidRegisterForRemoteNotifications:(UIApplication*)app deviceToken:(NSData*)inDeviceToken {
    [OneSignalNotificationsAppDelegate traceCall:@"oneSignalDidRegisterForRemoteNotifications:deviceToken:"];
    
    [OSNotificationsManager didRegisterForRemoteNotifications:app deviceToken:inDeviceToken];
    
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
    [OneSignalNotificationsAppDelegate traceCall:@"oneSignalDidFailRegisterForRemoteNotification:error:"];
    
    if ([OSNotificationsManager getAppId])
        [OSNotificationsManager handleDidFailRegisterForRemoteNotification:err];
    
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

// Fires when a notication is opened or recieved while the app is in focus.
//   - Also fires when the app is in the background and a notificaiton with content-available=1 is received.
// NOTE: completionHandler must only be called once!
//          iOS 10 - This crashes the app if it is called twice! Crash will happen when the app is resumed.
//          iOS 9  - Does not have this issue.
- (void) oneSignalReceiveRemoteNotification:(UIApplication*)application UserInfo:(NSDictionary*)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult)) completionHandler {
    [OneSignalNotificationsAppDelegate traceCall:@"oneSignalReceiveRemoteNotification:UserInfo:fetchCompletionHandler:"];
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
    
    if ([OSNotificationsManager getAppId]) {
        let appState = [UIApplication sharedApplication].applicationState;
        let isVisibleNotification = userInfo[@"aps"][@"alert"] != nil;
        
        // iOS 9 - Notification was tapped on
        // https://medium.com/posts-from-emmerge/ios-push-notification-background-fetch-demystified-7090358bb66e
        //   - NOTE: We do not have the extra logic for the notifiation center or double tap home button cases
        //           of "inactive" on notification received the link above describes.
        //           Omiting that complex logic as iOS 9 usage stats are very low (12/11/2020) and these are rare cases.
        if ([OSDeviceUtils isIOSVersionLessThan:@"10.0"] && appState == UIApplicationStateInactive && isVisibleNotification) {
            [OSNotificationsManager notificationReceived:userInfo wasOpened:YES];
        }
        else if (appState == UIApplicationStateActive && isVisibleNotification)
            [OSNotificationsManager notificationReceived:userInfo wasOpened:NO];
        else
            startedBackgroundJob = [OSNotificationsManager receiveRemoteNotification:application UserInfo:userInfo completionHandler:forwarder.hasReceiver ? nil : completionHandler];
    }
    
    if (forwarder.hasReceiver) {
        [forwarder invokeWithArgs:@[application, userInfo, completionHandler]];
        return;
    }
    
    [OneSignalNotificationsAppDelegate
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
    if ([OSNotificationsManager getColdStartFromTapOnNotification])
        return;
    
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wdeprecated-declarations"
    [originalDelegate application:application didReceiveRemoteNotification:userInfo];
    #pragma clang diagnostic pop
}

// Used to log all calls, also used in unit tests to observer
// the OneSignalNotificationsAppDelegate selectors get called.
+(void) traceCall:(NSString*)selector {
    [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:selector];
}

@end
