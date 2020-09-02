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

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

typedef void (^OSUNNotificationCenterCompletionHandler)(UNNotificationPresentationOptions options);

@interface OneSignal (UN_extra)
+ (void)notificationReceived:(NSDictionary*)messageDict foreground:(BOOL)foreground isActive:(BOOL)isActive wasOpened:(BOOL)opened;
+ (BOOL)shouldLogMissingPrivacyConsentErrorWithMethodName:(NSString *)methodName;
+ (void)handleWillPresentNotificationInForegroundWithPayload:(NSDictionary *)payload withCompletion:(OSNotificationDisplayTypeResponse)completion;
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

static Class delegateUNClass = nil;

// Store an array of all UIAppDelegate subclasses to iterate over in cases where UIAppDelegate swizzled methods are not overriden in main AppDelegate
// But rather in one of the subclasses
static NSArray* delegateUNSubclasses = nil;

//ensures setDelegate: swizzles will never get executed twice for the same delegate object
//captures a weak reference to avoid retain cycles
__weak static id previousDelegate;

+ (void)swizzleSelectors {
    injectToProperClass(@selector(setOneSignalUNDelegate:), @selector(setDelegate:), @[], [OneSignalUNUserNotificationCenter class], [UNUserNotificationCenter class]);
    
    // Overrides to work around 10.2.1 bug where getNotificationSettingsWithCompletionHandler: reports as declined if called before
    //  requestAuthorizationWithOptions:'s completionHandler fires when the user accepts notifications.
    injectToProperClass(@selector(onesignalRequestAuthorizationWithOptions:completionHandler:),
                        @selector(requestAuthorizationWithOptions:completionHandler:), @[],
                        [OneSignalUNUserNotificationCenter class], [UNUserNotificationCenter class]);
    injectToProperClass(@selector(onesignalGetNotificationSettingsWithCompletionHandler:),
                        @selector(getNotificationSettingsWithCompletionHandler:), @[],
                        [OneSignalUNUserNotificationCenter class], [UNUserNotificationCenter class]);
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
        OneSignal.currentPermissionState.hasPrompted = true;
    
    useCachedUNNotificationSettings = true;
    id wrapperBlock = ^(BOOL granted, NSError* error) {
        useCachedUNNotificationSettings = false;
        if (notProvisionalRequest) {
            OneSignal.currentPermissionState.accepted = granted;
            OneSignal.currentPermissionState.answeredPrompt = true;
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

// Take the received delegate and swizzle in our own hooks.
//  - Selector will be called once if developer does not set a UNUserNotificationCenter delegate.
//  - Selector will be called a 2nd time if the developer does set one.
- (void) setOneSignalUNDelegate:(id)delegate {
    if (previousDelegate == delegate) {
        [self setOneSignalUNDelegate:delegate];
        return;
    }
    
    previousDelegate = delegate;
    
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"OneSignalUNUserNotificationCenter setOneSignalUNDelegate Fired!"];
    
    delegateUNClass = getClassWithProtocolInHierarchy([delegate class], @protocol(UNUserNotificationCenterDelegate));
    delegateUNSubclasses = ClassGetSubclasses(delegateUNClass);
    
    injectToProperClass(@selector(onesignalUserNotificationCenter:willPresentNotification:withCompletionHandler:),
                        @selector(userNotificationCenter:willPresentNotification:withCompletionHandler:), delegateUNSubclasses, [OneSignalUNUserNotificationCenter class], delegateUNClass);
    
    injectToProperClass(@selector(onesignalUserNotificationCenter:didReceiveNotificationResponse:withCompletionHandler:),
                        @selector(userNotificationCenter:didReceiveNotificationResponse:withCompletionHandler:), delegateUNSubclasses, [OneSignalUNUserNotificationCenter class], delegateUNClass);
    
    [self setOneSignalUNDelegate:delegate];
}

// Apple's docs - Called when a notification is delivered to a foreground app.
// NOTE: iOS behavior - Calling completionHandler with 0 means userNotificationCenter:didReceiveNotificationResponse:withCompletionHandler: does not trigger.
//  - callLegacyAppDeletegateSelector is called from here due to this case.
- (void)onesignalUserNotificationCenter:(UNUserNotificationCenter *)center
                willPresentNotification:(UNNotification *)notification
                  withCompletionHandler:(void (^)(UNNotificationPresentationOptions options))completionHandler {
    
    // return if the user has not granted privacy permissions or if not a OneSignal payload
    if ([OneSignal shouldLogMissingPrivacyConsentErrorWithMethodName:nil] || ![OneSignalHelper isOneSignalPayload:notification.request.content.userInfo]) {
        if ([self respondsToSelector:@selector(onesignalUserNotificationCenter:willPresentNotification:withCompletionHandler:)])
            [self onesignalUserNotificationCenter:center willPresentNotification:notification withCompletionHandler:completionHandler];
        else
            completionHandler(7);
        return;
    }

    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"onesignalUserNotificationCenter:willPresentNotification:withCompletionHandler: Fired! %@", notification.request.content.body]];
    
    [OneSignal handleWillPresentNotificationInForegroundWithPayload:notification.request.content.userInfo withCompletion:^(OSNotificationDisplayType displayType) {
        finishProcessingNotification(notification, center, displayType, completionHandler, self);
    }];
}

// To avoid a crash caused by using the swizzled OneSignalUNUserNotificationCenter type this is implemented as a C function
void finishProcessingNotification(UNNotification *notification,
                                  UNUserNotificationCenter *center,
                                  OSNotificationDisplayType displayType,
                                  OSUNNotificationCenterCompletionHandler completionHandler,
                                  OneSignalUNUserNotificationCenter *instance) {
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"finishProcessingNotification: Fired!"];
    NSUInteger completionHandlerOptions = 7;
    
    switch (displayType) {
        case OSNotificationDisplayTypeSilent: completionHandlerOptions = 0; break; // Nothing
        case OSNotificationDisplayTypeNotification: completionHandlerOptions = 7; break; // Badge + Sound + Notification
        default: break;
    }
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"Notification display type: %lu", (unsigned long)displayType]];
    
    if ([OneSignal appId])
        [OneSignal notificationReceived:notification.request.content.userInfo foreground:YES isActive:YES wasOpened:NO];

    
    // Call orginal selector if one was set.
    if ([instance respondsToSelector:@selector(onesignalUserNotificationCenter:willPresentNotification:withCompletionHandler:)])
        [instance onesignalUserNotificationCenter:center willPresentNotification:notification withCompletionHandler:completionHandler];
    // Or call a legacy AppDelegate selector
    else {
        [OneSignalUNUserNotificationCenter callLegacyAppDeletegateSelector:notification
                                                               isTextReply:false
                                                          actionIdentifier:nil
                                                                  userText:nil
                                                   fromPresentNotification:true
                                                     withCompletionHandler:^() {}];
    }
    
    // Calling completionHandler for the following reasons:
    //   App dev may have not implented userNotificationCenter:willPresentNotification.
    //   App dev may have implemented this selector but forgot to call completionHandler().
    // Note - iOS only uses the first call to completionHandler().
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"finishProcessingNotification: call completionHandler with options: %lu",(unsigned long)completionHandlerOptions]];
    completionHandler(completionHandlerOptions);
}

// Apple's docs - Called to let your app know which action was selected by the user for a given notification.
- (void)onesignalUserNotificationCenter:(UNUserNotificationCenter *)center
         didReceiveNotificationResponse:(UNNotificationResponse *)response
                  withCompletionHandler:(void(^)())completionHandler {
    // return if the user has not granted privacy permissions or if not a OneSignal payload
    if ([OneSignal shouldLogMissingPrivacyConsentErrorWithMethodName:nil] || ![OneSignalHelper isOneSignalPayload:response.notification.request.content.userInfo]) {
        if ([self respondsToSelector:@selector(onesignalUserNotificationCenter:didReceiveNotificationResponse:withCompletionHandler:)])
            [self onesignalUserNotificationCenter:center didReceiveNotificationResponse:response withCompletionHandler:completionHandler];
        else
            completionHandler();
        return;
    }
    
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"onesignalUserNotificationCenter:didReceiveNotificationResponse:withCompletionHandler: Fired!"];
    
    [OneSignalUNUserNotificationCenter processiOS10Open:response];
    
    // Call orginal selector if one was set.
    if ([self respondsToSelector:@selector(onesignalUserNotificationCenter:didReceiveNotificationResponse:withCompletionHandler:)])
        [self onesignalUserNotificationCenter:center didReceiveNotificationResponse:response withCompletionHandler:completionHandler];
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
    
    let isActive = [UIApplication sharedApplication].applicationState == UIApplicationStateActive;
    
    let userInfo = [OneSignalHelper formatApsPayloadIntoStandard:response.notification.request.content.userInfo
                                                      identifier:response.actionIdentifier];
    let isAppForeground = [[UIApplication sharedApplication] applicationState] != UIApplicationStateBackground;

    [OneSignal notificationReceived:userInfo foreground:isAppForeground isActive:isActive wasOpened:YES];
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
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"callLegacyAppDeletegateSelector:withCompletionHandler: Fired!"];
    
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

@end

#pragma clang diagnostic pop
#pragma clang diagnostic pop
