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
#import <UserNotifications/UserNotifications.h>

#import "UNUserNotificationCenter+OneSignal.h"
#import "OneSignal.h"
#import "OneSignalInternal.h"
#import "OneSignalHelper.h"
#import "OneSignalSelectorHelpers.h"
#import "UIApplicationDelegate+OneSignal.h"
#import "OneSignalCommonDefines.h"
#import "SwizzlingForwarder.h"
#import <objc/runtime.h>
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

typedef void (^OSUNNotificationCenterCompletionHandler)(UNNotificationPresentationOptions options);

@interface OneSignal (UN_extra)
+ (void)notificationReceived:(NSDictionary*)messageDict wasOpened:(BOOL)opened;
+ (void)handleWillPresentNotificationInForegroundWithPayload:(NSDictionary *)payload withCompletion:(OSNotificationDisplayResponse)completionHandler;
@end

@interface OSUNUserNotificationCenterDelegate : NSObject
+ (OSUNUserNotificationCenterDelegate*)sharedInstance;
@end

@implementation OSUNUserNotificationCenterDelegate
static OSUNUserNotificationCenterDelegate* singleInstance = nil;
+ (OSUNUserNotificationCenterDelegate*)sharedInstance {
    @synchronized(singleInstance) {
        if (!singleInstance)
            singleInstance = [OSUNUserNotificationCenterDelegate new];
    }
    return singleInstance;
}
@end

// This class hooks into the following iSO 10 UNUserNotificationCenterDelegate selectors:
// - userNotificationCenter:willPresentNotification:withCompletionHandler:
//   - Reads OneSignal.inFocusDisplayType to respect it's setting.
// - userNotificationCenter:didReceiveNotificationResponse:withCompletionHandler:
//   - Used to process opening notifications.
//
// NOTE: On iOS 10, when a UNUserNotificationCenterDelegate is set, UIApplicationDelegate notification selectors no longer fire.
//       However, this class maintains firing of UIApplicationDelegate selectors if the app did not setup it's own UNUserNotificationCenterDelegate.
//       This ensures we don't produce any side effects to standard iOS API selectors.
//       The `callLegacyAppDeletegateSelector` selector below takes care of this backwards compatibility handling.

@implementation OneSignalUNUserNotificationCenter

+ (void)setup {
    [OneSignalUNUserNotificationCenter swizzleSelectors];
    [OneSignalUNUserNotificationCenter registerDelegate];
}

+ (void)swizzleSelectors {
    injectSelector(
        [UNUserNotificationCenter class],
        @selector(setDelegate:),
        [OneSignalUNUserNotificationCenter class],
        @selector(setOneSignalUNDelegate:)
   );
    
    // Overrides to work around 10.2.1 bug where getNotificationSettingsWithCompletionHandler: reports as declined if called before
    //  requestAuthorizationWithOptions:'s completionHandler fires when the user accepts notifications.
    injectSelector(
        [UNUserNotificationCenter class],
        @selector(requestAuthorizationWithOptions:completionHandler:),
        [OneSignalUNUserNotificationCenter class],
        @selector(onesignalRequestAuthorizationWithOptions:completionHandler:)
    );
    injectSelector(
        [UNUserNotificationCenter class],
        @selector(getNotificationSettingsWithCompletionHandler:),
        [OneSignalUNUserNotificationCenter class],
        @selector(onesignalGetNotificationSettingsWithCompletionHandler:)
   );
}

+ (void)registerDelegate {
    let curNotifCenter = [UNUserNotificationCenter currentNotificationCenter];

    if (!curNotifCenter.delegate) {
        /*
          Set OSUNUserNotificationCenterDelegate.sharedInstance as a
            UNUserNotificationCenterDelegate.
          Note that OSUNUserNotificationCenterDelegate does not contain the methods such as
            "willPresentNotification" as this assigment triggers setOneSignalUNDelegate which
            will attach the selectors to the class at runtime.
         */
        curNotifCenter.delegate = (id)OSUNUserNotificationCenterDelegate.sharedInstance;
    }
    else {
        /*
         This handles the case where a delegate may have already been assigned before
           OneSignal is loaded into memory.
         This re-assignment triggers setOneSignalUNDelegate providing it with the
           existing delegate instance so OneSignal can swizzle in its logic.
         */
        curNotifCenter.delegate = curNotifCenter.delegate;
    }
}

static BOOL useiOS10_2_workaround = true;
+ (void)setUseiOS10_2_workaround:(BOOL)enable {
    useiOS10_2_workaround = enable;
}
static BOOL useCachedUNNotificationSettings;
static UNNotificationSettings* cachedUNNotificationSettings;

// This is a swizzled implementation of requestAuthorizationWithOptions:
// in case developers call it directly instead of using our prompt method
- (void)onesignalRequestAuthorizationWithOptions:(UNAuthorizationOptions)options completionHandler:(void (^)(BOOL granted, NSError *__nullable error))completionHandler {
    
    // check options for UNAuthorizationOptionProvisional membership
    BOOL notProvisionalRequest = (options & PROVISIONAL_UNAUTHORIZATIONOPTION) == 0;
    
    //we don't want to modify these settings if the authorization is provisional (iOS 12 'Direct to History')
    if (notProvisionalRequest)
        OSNotificationsManager.currentPermissionState.hasPrompted = true;
    useCachedUNNotificationSettings = true;
    id wrapperBlock = ^(BOOL granted, NSError* error) {
        useCachedUNNotificationSettings = false;
        if (notProvisionalRequest) {
            OSNotificationsManager.currentPermissionState.accepted = granted;
            OSNotificationsManager.currentPermissionState.answeredPrompt = true;
        }
        completionHandler(granted, error);
    };
    
    [self onesignalRequestAuthorizationWithOptions:options completionHandler:wrapperBlock];
}

- (void)onesignalGetNotificationSettingsWithCompletionHandler:(void(^)(UNNotificationSettings *settings))completionHandler {
    if (useCachedUNNotificationSettings && cachedUNNotificationSettings && useiOS10_2_workaround) {
        completionHandler(cachedUNNotificationSettings);
        return;
    }
    
    id wrapperBlock = ^(UNNotificationSettings* settings) {
        cachedUNNotificationSettings = settings;
        completionHandler(settings);
    };
    
    [self onesignalGetNotificationSettingsWithCompletionHandler:wrapperBlock];
}


// A Set to keep track of which classes we have already swizzled so we only
// swizzle each one once. If we swizzled more than once then this will create
// an infinite loop, this includes swizzling with ourselves but also with
// another SDK that swizzles.
static NSMutableSet<Class>* swizzledClasses;

// Take the received delegate and swizzle in our own hooks.
//  - Selector will be called once if developer does not set a UNUserNotificationCenter delegate.
//  - Selector will be called a 2nd time if the developer does set one.
- (void) setOneSignalUNDelegate:(id)delegate {
    if (swizzledClasses == nil)
        swizzledClasses = [NSMutableSet new];
    
    Class delegateClass = [delegate class];
    
    if (delegate == nil || [OneSignalUNUserNotificationCenter swizzledClassInHeirarchy:delegateClass]) {
        [self setOneSignalUNDelegate:delegate];
        return;
    }
    [swizzledClasses addObject:delegateClass];

    [OneSignal onesignalLog:ONE_S_LL_VERBOSE message:@"OneSignalUNUserNotificationCenter setOneSignalUNDelegate Fired!"];

    [OneSignalUNUserNotificationCenter swizzleSelectorsOnDelegate:delegate];

    // Call orignal iOS implemenation
    [self setOneSignalUNDelegate:delegate];
}

+ (BOOL)swizzledClassInHeirarchy:(Class)delegateClass {
    if ([swizzledClasses containsObject:delegateClass]) {
        [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"OneSignal already swizzled %@", NSStringFromClass(delegateClass)]];
        return true;
    }
    Class superClass = class_getSuperclass(delegateClass);
    while(superClass) {
        if ([swizzledClasses containsObject:superClass]) {
            [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"OneSignal already swizzled %@ in super class: %@", NSStringFromClass(delegateClass), NSStringFromClass(superClass)]];
            return true;
        }
        superClass = class_getSuperclass(superClass);
    }
    return false;
}

+ (void)swizzleSelectorsOnDelegate:(id)delegate {
    Class delegateUNClass = [delegate class];
    injectSelector(
        delegateUNClass,
        @selector(userNotificationCenter:willPresentNotification:withCompletionHandler:),
        [OneSignalUNUserNotificationCenter class],
        @selector(onesignalUserNotificationCenter:willPresentNotification:withCompletionHandler:)
    );
    injectSelector(
        delegateUNClass,
        @selector(userNotificationCenter:didReceiveNotificationResponse:withCompletionHandler:),
        [OneSignalUNUserNotificationCenter class],
        @selector(onesignalUserNotificationCenter:didReceiveNotificationResponse:withCompletionHandler:)
    );
}

+ (BOOL)forwardNotificationWithCenter:(UNUserNotificationCenter *)center
                         notification:(UNNotification *)notification
                      OneSignalCenter:(id)instance
                    completionHandler:(void (^)(UNNotificationPresentationOptions options))completionHandler {
    SwizzlingForwarder *forwarder = [[SwizzlingForwarder alloc]
        initWithTarget:instance
        withYourSelector:@selector(
            onesignalUserNotificationCenter:willPresentNotification:withCompletionHandler:
        )
        withOriginalSelector:@selector(
            userNotificationCenter:willPresentNotification:withCompletionHandler:
        )
    ];
    if (forwarder.hasReceiver) {
        [forwarder invokeWithArgs:@[center, notification, completionHandler]];
        return true;
    } else {
        // call a legacy AppDelegate selector
        [OneSignalUNUserNotificationCenter callLegacyAppDeletegateSelector:notification
                                                isTextReply:false
                                           actionIdentifier:nil
                                                   userText:nil
                                    fromPresentNotification:true
                                      withCompletionHandler:^() {}];
        return false;
    }
}

// Apple's docs - Called when a notification is delivered to a foreground app.
// NOTE: iOS behavior - Calling completionHandler with 0 means userNotificationCenter:didReceiveNotificationResponse:withCompletionHandler: does not trigger.
//  - callLegacyAppDeletegateSelector is called from here due to this case.
- (void)onesignalUserNotificationCenter:(UNUserNotificationCenter *)center
                willPresentNotification:(UNNotification *)notification
                  withCompletionHandler:(void (^)(UNNotificationPresentationOptions options))completionHandler {
    
    [OneSignalUNUserNotificationCenter traceCall:@"onesignalUserNotificationCenter:willPresentNotification:withCompletionHandler:"];
    
    // return if the user has not granted privacy permissions or if not a OneSignal payload
    if ([OSPrivacyConsentController shouldLogMissingPrivacyConsentErrorWithMethodName:nil] || ![OneSignalHelper isOneSignalPayload:notification.request.content.userInfo]) {
        BOOL hasReceiver = [OneSignalUNUserNotificationCenter forwardNotificationWithCenter:center notification:notification OneSignalCenter:self completionHandler:completionHandler];
        if (!hasReceiver) {
            completionHandler(7);
        }
        return;
    }

    [OneSignal onesignalLog:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"onesignalUserNotificationCenter:willPresentNotification:withCompletionHandler: Fired! %@", notification.request.content.body]];
    
    [OneSignal handleWillPresentNotificationInForegroundWithPayload:notification.request.content.userInfo withCompletion:^(OSNotification *responseNotif) {
        UNNotificationPresentationOptions displayType = responseNotif != nil ? (UNNotificationPresentationOptions)7 : (UNNotificationPresentationOptions)0;
        finishProcessingNotification(notification, center, displayType, completionHandler, self);
    }];
}

// To avoid a crash caused by using the swizzled OneSignalUNUserNotificationCenter type this is implemented as a C function
void finishProcessingNotification(UNNotification *notification,
                                  UNUserNotificationCenter *center,
                                  UNNotificationPresentationOptions displayType,
                                  OSUNNotificationCenterCompletionHandler completionHandler,
                                  OneSignalUNUserNotificationCenter *instance) {
    [OneSignal onesignalLog:ONE_S_LL_VERBOSE message:@"finishProcessingNotification: Fired!"];
    NSUInteger completionHandlerOptions = displayType;
    
    [OneSignal onesignalLog:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"Notification display type: %lu", (unsigned long)displayType]];
    
    if ([OneSignal appId])
        [OneSignal notificationReceived:notification.request.content.userInfo wasOpened:NO];

    
    [OneSignalUNUserNotificationCenter forwardNotificationWithCenter:center notification:notification OneSignalCenter:instance completionHandler:completionHandler];
    
    // Calling completionHandler for the following reasons:
    //   App dev may have not implented userNotificationCenter:willPresentNotification.
    //   App dev may have implemented this selector but forgot to call completionHandler().
    // Note - iOS only uses the first call to completionHandler().
    [OneSignal onesignalLog:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"finishProcessingNotification: call completionHandler with options: %lu",(unsigned long)completionHandlerOptions]];
    completionHandler(completionHandlerOptions);
}

+ (void)forwardReceivedNotificationResponseWithCenter:(UNUserNotificationCenter *)center
                       didReceiveNotificationResponse:(UNNotificationResponse *)response
                                      OneSignalCenter:(id)instance
                                withCompletionHandler:(void(^)())completionHandler {
    // Call original selector if one was set.
    SwizzlingForwarder *forwarder = [[SwizzlingForwarder alloc]
        initWithTarget:instance
        withYourSelector:@selector(
            onesignalUserNotificationCenter:didReceiveNotificationResponse:withCompletionHandler:
        )
        withOriginalSelector:@selector(
            userNotificationCenter:didReceiveNotificationResponse:withCompletionHandler:
        )
    ];
    if (forwarder.hasReceiver) {
        [forwarder invokeWithArgs:@[center, response, completionHandler]];
    }
    // Or call a legacy AppDelegate selector
    //  - If not a dismiss event as their isn't a iOS 9 selector for it.
    else if (![OneSignalUNUserNotificationCenter isDismissEvent:response]) {
        BOOL isTextReply = [response isKindOfClass:NSClassFromString(@"UNTextInputNotificationResponse")];
        NSString* userText = isTextReply ? [response valueForKey:@"userText"] : nil;
        [OneSignalUNUserNotificationCenter callLegacyAppDeletegateSelector:response.notification
                                                isTextReply:isTextReply
                                           actionIdentifier:response.actionIdentifier
                                                   userText:userText
                                    fromPresentNotification:false
                                      withCompletionHandler:completionHandler];
    }
    else
        completionHandler();
}


// Apple's docs - Called to let your app know which action was selected by the user for a given notification.
- (void)onesignalUserNotificationCenter:(UNUserNotificationCenter *)center
         didReceiveNotificationResponse:(UNNotificationResponse *)response
                  withCompletionHandler:(void(^)())completionHandler {
    [OneSignalUNUserNotificationCenter traceCall:@"onesignalUserNotificationCenter:didReceiveNotificationResponse:withCompletionHandler:"];
    
    if (![OSPrivacyConsentController shouldLogMissingPrivacyConsentErrorWithMethodName:nil] && [OneSignalHelper isOneSignalPayload:response.notification.request.content.userInfo]) {
        [OneSignal onesignalLog:ONE_S_LL_VERBOSE message:@"onesignalUserNotificationCenter:didReceiveNotificationResponse:withCompletionHandler: Fired!"];
        
        [OneSignalUNUserNotificationCenter processiOS10Open:response];
    }
    
    [OneSignalUNUserNotificationCenter forwardReceivedNotificationResponseWithCenter:center didReceiveNotificationResponse:response OneSignalCenter:self withCompletionHandler:completionHandler];
}

+ (BOOL)isDismissEvent:(UNNotificationResponse *)response {
    return [@"com.apple.UNNotificationDismissActionIdentifier" isEqual:response.actionIdentifier];
}

+ (void)processiOS10Open:(UNNotificationResponse*)response {
    if (![OneSignal appId])
        return;
    
    if ([OneSignalUNUserNotificationCenter isDismissEvent:response])
        return;
    
    if (![OneSignalHelper isOneSignalPayload:response.notification.request.content.userInfo])
        return;
    
    let userInfo = [OneSignalHelper formatApsPayloadIntoStandard:response.notification.request.content.userInfo
                                                      identifier:response.actionIdentifier];

    [OneSignal notificationReceived:userInfo wasOpened:YES];
}

// Calls depercated pre-iOS 10 selector if one is set on the AppDelegate.
//   Even though they are deperated in iOS 10 they should still be called in iOS 10
//     As long as they didn't setup their own UNUserNotificationCenterDelegate
// - application:didReceiveLocalNotification:
// - application:didReceiveRemoteNotification:fetchCompletionHandler:
// - application:handleActionWithIdentifier:forLocalNotification:withResponseInfo:completionHandler:
// - application:handleActionWithIdentifier:forRemoteNotification:withResponseInfo:completionHandler:
// - application:handleActionWithIdentifier:forLocalNotification:completionHandler:
// - application:handleActionWithIdentifier:forRemoteNotification:completionHandler:
+ (void)callLegacyAppDeletegateSelector:(UNNotification *)notification
                            isTextReply:(BOOL)isTextReply
                       actionIdentifier:(NSString*)actionIdentifier
                               userText:(NSString*)userText
                fromPresentNotification:(BOOL)fromPresentNotification
                  withCompletionHandler:(void(^)())completionHandler {
    [OneSignal onesignalLog:ONE_S_LL_VERBOSE message:@"callLegacyAppDeletegateSelector:withCompletionHandler: Fired!"];
    
    UIApplication *sharedApp = [UIApplication sharedApplication];
    
    /*
     The iOS SDK used to call some local notification selectors (such as didReceiveLocalNotification)
     as a convenience but has stopped due to concerns about private API usage
     the SDK will now print warnings when a developer's app implements these selectors
     */
    BOOL isCustomAction = actionIdentifier && ![@"com.apple.UNNotificationDefaultActionIdentifier" isEqualToString:actionIdentifier];
    BOOL isRemote = [notification.request.trigger isKindOfClass:NSClassFromString(@"UNPushNotificationTrigger")];
    
    if (isRemote) {
        NSDictionary* remoteUserInfo = notification.request.content.userInfo;
        
        if (isTextReply &&
            [sharedApp.delegate respondsToSelector:@selector(application:handleActionWithIdentifier:forRemoteNotification:withResponseInfo:completionHandler:)]) {
            NSDictionary* responseInfo = @{UIUserNotificationActionResponseTypedTextKey: userText};
            [sharedApp.delegate application:sharedApp handleActionWithIdentifier:actionIdentifier forRemoteNotification:remoteUserInfo withResponseInfo:responseInfo completionHandler:^() {
                completionHandler();
            }];
        }
        else if (isCustomAction &&
                 [sharedApp.delegate respondsToSelector:@selector(application:handleActionWithIdentifier:forRemoteNotification:completionHandler:)])
            [sharedApp.delegate application:sharedApp handleActionWithIdentifier:actionIdentifier forRemoteNotification:remoteUserInfo completionHandler:^() {
                completionHandler();
            }];
        // Always trigger selector for open events and for non-content-available receive events.
        //  content-available seems to be an odd expection to iOS 10's fallback rules for legacy selectors.
        else if ([sharedApp.delegate respondsToSelector:@selector(application:didReceiveRemoteNotification:fetchCompletionHandler:)] &&
                 (!fromPresentNotification ||
                 ![[notification.request.trigger valueForKey:@"_isContentAvailable"] boolValue])) {
            // NOTE: Should always be true as our AppDelegate swizzling should be there unless something else unswizzled it.
            [sharedApp.delegate application:sharedApp didReceiveRemoteNotification:remoteUserInfo fetchCompletionHandler:^(UIBackgroundFetchResult result) {
                // Call iOS 10's compleationHandler from iOS 9's completion handler.
                completionHandler();
            }];
        }
        else
            completionHandler();
    }
    else
        completionHandler();
}

// Used to log all calls, also used in unit tests to observer
// the OneSignalUserNotificationCenter selectors get called.
+(void) traceCall:(NSString*)selector {
    [OneSignal onesignalLog:ONE_S_LL_VERBOSE message:selector];
}

@end

#pragma clang diagnostic pop
#pragma clang diagnostic pop
