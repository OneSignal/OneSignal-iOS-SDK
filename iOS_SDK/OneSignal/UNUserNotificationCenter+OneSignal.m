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

#import "UNUserNotificationCenter+OneSignal.h"
#import "OneSignal.h"
#import "OneSignalSelectorHelpers.h"


#if XC8_AVAILABLE

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@interface OneSignal (UN_extra)
+ (void)notificationOpened:(NSDictionary*)messageDict isActive:(BOOL)isActive;
@end

// This class hooks into the following iSO 10 UNUserNotificationCenterDelegate selectors:
// - userNotificationCenter:willPresentNotification:withCompletionHandler:
//   - Reads kOSSettingsKeyInFocusDisplayOption to respect it's setting.
// - userNotificationCenter:didReceiveNotificationResponse:withCompletionHandler:
//   - Used to process opening a notifications.
//   - The presents of this selector tells iOS to no longer fire `application:didReceiveRemoteNotification:fetchCompletionHandler:`.
//       We call this to maintain existing behavior.

@implementation swizzleUNUserNotif

static Class delegateUNClass = nil;

// Store an array of all UIAppDelegate subclasses to iterate over in cases where UIAppDelegate swizzled methods are not overriden in main AppDelegate
// But rather in one of the subclasses
static NSArray* delegateUNSubclasses = nil;

// Take the received delegate and swizzle in our own hooks.
//  - Selector will be called once if developer does not set a UNUserNotificationCenter delegate.
//  - Selector will be called a 2nd time if the developer does set one.
- (void) setOneSignalUNDelegate:(id)delegate {
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"swizzleUNUserNotif setOneSignalUNDelegate Fired!"];
    
    delegateUNClass = getClassWithProtocolInHierarchy([delegate class], @protocol(UNUserNotificationCenterDelegate));
    delegateUNSubclasses = ClassGetSubclasses(delegateUNClass);
    
    injectToProperClass(@selector(onesignalUserNotificationCenter:willPresentNotification:withCompletionHandler:),
                        @selector(userNotificationCenter:willPresentNotification:withCompletionHandler:), delegateUNSubclasses, [swizzleUNUserNotif class], delegateUNClass);
    
    injectToProperClass(@selector(onesignalUserNotificationCenter:didReceiveNotificationResponse:withCompletionHandler:),
                        @selector(userNotificationCenter:didReceiveNotificationResponse:withCompletionHandler:), delegateUNSubclasses, [swizzleUNUserNotif class], delegateUNClass);
    
    [self setOneSignalUNDelegate:delegate];
}

// Apple's docs - Called when a notification is delivered to a foreground app.
- (void)onesignalUserNotificationCenter:(UNUserNotificationCenter *)center
                willPresentNotification:(UNNotification *)notification
                  withCompletionHandler:(void (^)(UNNotificationPresentationOptions options))completionHandler {
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"onesignalUserNotificationCenter:willPresentNotification:withCompletionHandler: Fired!"];
    
    // Depercated - [OneSignal notificationCenterDelegate] - Now handled by swizzling.
    //    Proxy to user if listening to delegate and overrides the method.
    if ([[OneSignal notificationCenterDelegate] respondsToSelector:@selector(userNotificationCenter:willPresentNotification:withCompletionHandler:)]) {
        [[OneSignal notificationCenterDelegate] userNotificationCenter:center willPresentNotification:notification withCompletionHandler:completionHandler];
        return;
    }
    
    // Set the completionHandler options based on the ONESIGNAL_ALERT_OPTION value.
    if (![[NSUserDefaults standardUserDefaults] objectForKey:@"ONESIGNAL_ALERT_OPTION"]) {
        [[NSUserDefaults standardUserDefaults] setObject:@(OSNotificationDisplayTypeInAppAlert) forKey:@"ONESIGNAL_ALERT_OPTION"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    
    NSUInteger completionHandlerOptions = 0;
    NSInteger alert_option = [[NSUserDefaults standardUserDefaults] integerForKey:@"ONESIGNAL_ALERT_OPTION"];
    switch (alert_option) {
        case OSNotificationDisplayTypeNone: completionHandlerOptions = 0; break; // Nothing
        case OSNotificationDisplayTypeInAppAlert: completionHandlerOptions = 3; break; // Badge + Sound
        case OSNotificationDisplayTypeNotification: completionHandlerOptions = 7; break; // Badge + Sound + Notification
        default: break;
    }
    
    // Call notificationOpened if no alert (MSB not set)
    [OneSignal notificationOpened:notification.request.content.userInfo isActive:YES];
    
    if ([self respondsToSelector:@selector(onesignalUserNotificationCenter:willPresentNotification:withCompletionHandler:)])
        [self onesignalUserNotificationCenter:center willPresentNotification:notification withCompletionHandler:completionHandler];
    
    // Calling completionHandler for the following reasons:
    //   App dev may have not implented userNotificationCenter:willPresentNotification.
    //   App dev may have implemented this selector but forgot to call completionHandler().
    // Note - iOS only uses the first call to completionHandler().
    completionHandler(completionHandlerOptions);
}

// Apple's docs - Called to let your app know which action was selected by the user for a given notification.
- (void)onesignalUserNotificationCenter:(UNUserNotificationCenter *)center
         didReceiveNotificationResponse:(UNNotificationResponse *)response
                  withCompletionHandler:(void(^)())completionHandler {
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"onesignalUserNotificationCenter:didReceiveNotificationResponse:withCompletionHandler: Fired!"];
    
    [swizzleUNUserNotif processiOS10Open:response];
    
    // For depercated OSUserNotificationCenterDelegate
    [swizzleUNUserNotif tunnelToDelegate:center response:response handler:completionHandler];
    
    // Call orginal selector if one was set.
    if ([self respondsToSelector:@selector(onesignalUserNotificationCenter:didReceiveNotificationResponse:withCompletionHandler:)])
        [self onesignalUserNotificationCenter:center didReceiveNotificationResponse:response withCompletionHandler:completionHandler];
    // Or call a legacy selector AppDelegate selector
    else if (![swizzleUNUserNotif isDismissEvent:response]) // iOS 9 did not have a dismiss event
        [swizzleUNUserNotif callLegacyAppDeletegateSelector:response withCompletionHandler:completionHandler];
    else
        completionHandler();
}

+ (BOOL) isDismissEvent:(UNNotificationResponse *)response {
    return [@"com.apple.UNNotificationDismissActionIdentifier" isEqual:response.actionIdentifier];
}

+ (void) processiOS10Open:(UNNotificationResponse *)response {
    if (![OneSignal app_id])
        return;
    
    if ([swizzleUNUserNotif isDismissEvent:response])
        return;
    
    BOOL isActive = [UIApplication sharedApplication].applicationState == UIApplicationStateActive &&
                    [[[NSUserDefaults standardUserDefaults] objectForKey:@"ONESIGNAL_ALERT_OPTION"] intValue] != OSNotificationDisplayTypeNotification;
    
    
    NSDictionary* remoteUserInfo = response.notification.request.content.userInfo;
    NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] init],
    *customDict = [[NSMutableDictionary alloc] init],
    *additionalData = [[NSMutableDictionary alloc] init];
    NSMutableArray *optionsDict = [[NSMutableArray alloc] init];
    
    NSMutableDictionary* buttonsDict = remoteUserInfo[@"os_data"][@"buttons"];
    NSMutableDictionary* custom = remoteUserInfo[@"custom"];
    if (buttonsDict) {
        [userInfo addEntriesFromDictionary:remoteUserInfo];
        NSArray* o = buttonsDict[@"o"];
        if (o)
            [optionsDict addObjectsFromArray:o];
    }
    else if (custom) {
        [userInfo addEntriesFromDictionary:remoteUserInfo];
        [customDict addEntriesFromDictionary:custom];
        NSDictionary *a = customDict[@"a"];
        NSArray *o = userInfo[@"o"];
        if (a)
            [additionalData addEntriesFromDictionary:a];
        if (o)
            [optionsDict addObjectsFromArray:o];
    }
    
    NSMutableArray* buttonArray = [[NSMutableArray alloc] init];
    for (NSDictionary* button in optionsDict) {
        NSString * text = button[@"n"] != nil ? button[@"n"] : @"";
        NSString * buttonID = button[@"i"] != nil ? button[@"i"] : text;
        NSDictionary * buttonToAppend = [[NSDictionary alloc] initWithObjects:@[text, buttonID] forKeys:@[@"text", @"id"]];
        [buttonArray addObject:buttonToAppend];
    }
    
    additionalData[@"actionSelected"] = [response valueForKey:@"actionIdentifier"];
    additionalData[@"actionButtons"] = buttonArray;
    
    NSDictionary* os_data = remoteUserInfo[@"os_data"];
    if (os_data) {
        [userInfo addEntriesFromDictionary:os_data];
        if (userInfo[@"os_data"][@"buttons"][@"m"])
            userInfo[@"aps"] = @{@"alert" : userInfo[@"os_data"][@"buttons"][@"m"]};
        [userInfo addEntriesFromDictionary:additionalData];
    }
    else {
        customDict[@"a"] = additionalData;
        userInfo[@"custom"] = customDict;
        if (userInfo[@"m"])
            userInfo[@"aps"] = @{ @"alert": userInfo[@"m"] };
    }
    
    [OneSignal notificationOpened:userInfo isActive:isActive];
}

// Depercated - [OneSignal notificationCenterDelegate] - Now handled by swizzling.
+ (BOOL)tunnelToDelegate:(id)center response:(id)response handler:(void (^)())handler {
    if ([[OneSignal notificationCenterDelegate] respondsToSelector:@selector(userNotificationCenter:didReceiveNotificationResponse:withCompletionHandler:)]) {
        [[OneSignal notificationCenterDelegate] userNotificationCenter:center didReceiveNotificationResponse:response withCompletionHandler:handler];
        return true;
    }
    
    return false;
}

// Calls depercated pre-iOS 10 selector if one is set on the AppDelegate.
//   Even though they are deperated in iOS 10 they should still be called in iOS 10
// - application:didReceiveLocalNotification:
// - application:didReceiveRemoteNotification:fetchCompletionHandler:
// - application:handleActionWithIdentifier:forLocalNotification:withResponseInfo:completionHandler:
// - application:handleActionWithIdentifier:forRemoteNotification:withResponseInfo:completionHandler:
// - application:handleActionWithIdentifier:forLocalNotification:completionHandler:
// - application:handleActionWithIdentifier:forRemoteNotification:completionHandler:
+ (void)callLegacyAppDeletegateSelector:(UNNotificationResponse *)response
                  withCompletionHandler:(void(^)())completionHandler {
    UIApplication *sharedApp = [UIApplication sharedApplication];
    
    BOOL isTextReply = [response isKindOfClass:NSClassFromString(@"UNTextInputNotificationResponse")];
    BOOL isLegacyLocalNotif = [response.notification.request.trigger isKindOfClass:NSClassFromString(@"UNLegacyNotificationTrigger")];
    BOOL isCustomAction = ![@"com.apple.UNNotificationDefaultActionIdentifier" isEqualToString:response.actionIdentifier];
   // BOOL isRemote = [response.notification.request.trigger isKindOfClass:NSClassFromString(@"UNPushNotificationTrigger")];
    
    if (isLegacyLocalNotif) {
        UILocalNotification *localNotif = [NSClassFromString(@"UIConcreteLocalNotification") alloc];
        localNotif.alertBody = response.notification.request.content.body;
        localNotif.alertTitle = response.notification.request.content.title;
        localNotif.applicationIconBadgeNumber = [response.notification.request.content.badge integerValue];
        NSString* soundName = [response.notification.request.content.sound valueForKey:@"_toneFileName"];
        if (!soundName)
            soundName = @"UILocalNotificationDefaultSoundName";
        localNotif.soundName = soundName;
        localNotif.alertLaunchImage = response.notification.request.content.launchImageName;
        localNotif.userInfo = response.notification.request.content.userInfo;
        localNotif.category = response.notification.request.content.categoryIdentifier;
        localNotif.hasAction = true; // Defaults to true, UNLocalNotification doesn't seem to have a flag for this.
        localNotif.fireDate = response.notification.date;
        localNotif.timeZone = [response.notification.request.trigger valueForKey:@"_timeZone"];
        localNotif.repeatInterval = (NSCalendarUnit)[response.notification.request.trigger valueForKey:@"_repeatInterval"];
        localNotif.repeatCalendar = [response.notification.request.trigger valueForKey:@"_repeatCalendar"];
        // localNotif.region =
        // localNotif.regionTriggersOnce =
        
        if (isTextReply &&
            [sharedApp.delegate respondsToSelector:@selector(application:handleActionWithIdentifier:forLocalNotification:withResponseInfo:completionHandler:)]) {
            NSDictionary* dict = @{UIUserNotificationActionResponseTypedTextKey: [response valueForKey:@"userText"]};
            [sharedApp.delegate application:sharedApp handleActionWithIdentifier:response.actionIdentifier forLocalNotification:localNotif withResponseInfo:dict completionHandler:^() {
                completionHandler();
            }];
        }
        else if (isCustomAction &&
                 [sharedApp.delegate respondsToSelector:@selector(application:handleActionWithIdentifier:forLocalNotification:completionHandler:)])
            [sharedApp.delegate application:sharedApp handleActionWithIdentifier:response.actionIdentifier forLocalNotification:localNotif completionHandler:^() {
                completionHandler();
            }];
        else if ([sharedApp.delegate respondsToSelector:@selector(application:didReceiveLocalNotification:)]) {
            [sharedApp.delegate application:sharedApp didReceiveLocalNotification:localNotif];
            completionHandler();
        }
        else
            completionHandler();
    }
    else {
        NSDictionary* remoteUserInfo = response.notification.request.content.userInfo;
        
        if (isTextReply &&
            [sharedApp.delegate respondsToSelector:@selector(application:handleActionWithIdentifier:forRemoteNotification:withResponseInfo:completionHandler:)]) {
            NSDictionary* responseInfo = @{UIUserNotificationActionResponseTypedTextKey: [response valueForKey:@"userText"]};
            [sharedApp.delegate application:sharedApp handleActionWithIdentifier:response.actionIdentifier forRemoteNotification:remoteUserInfo withResponseInfo:responseInfo completionHandler:^() {
                completionHandler();
            }];
        }
        else if (isCustomAction &&
                 [sharedApp.delegate respondsToSelector:@selector(application:handleActionWithIdentifier:forRemoteNotification:completionHandler:)])
            [sharedApp.delegate application:sharedApp handleActionWithIdentifier:response.actionIdentifier forRemoteNotification:remoteUserInfo completionHandler:^() {
                completionHandler();
            }];
        else if ([sharedApp.delegate respondsToSelector:@selector(application:didReceiveRemoteNotification:fetchCompletionHandler:)]) {
            //   NOTE: Should always be true as our AppDelegate swizzling should be there unless something else unswizzled it.
            [sharedApp.delegate application:sharedApp didReceiveRemoteNotification:remoteUserInfo fetchCompletionHandler:^(UIBackgroundFetchResult result) {
                // Call iOS 10's compleationHandler from iOS 9's completion handler.
                completionHandler();
            }];
        }
        else
            completionHandler();
    }
}

@end

#pragma clang diagnostic pop
#pragma clang diagnostic pop

#endif
