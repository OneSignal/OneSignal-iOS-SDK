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


@implementation sizzleUNUserNotif

static Class delegateUNClass = nil;

// Store an array of all UIAppDelegate subclasses to iterate over in cases where UIAppDelegate swizzled methods are not overriden in main AppDelegate
// But rather in one of the subclasses
static NSArray* delegateUNSubclasses = nil;

// Take the received delegate and swizzle in our own hooks.
//  - Selector will be called once if developer does not set a UNUserNotificationCenter delegate.
//  - Selector will be called a 2nd time if the developer does set one.
- (void) setOneSignalUNDelegate:(id)delegate {
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"sizzleUNUserNotif setOneSignalUNDelegate Fired!"];
    
    delegateUNClass = getClassWithProtocolInHierarchy([delegate class], @protocol(UNUserNotificationCenterDelegate));
    delegateUNSubclasses = ClassGetSubclasses(delegateUNClass);
    
    injectToProperClass(@selector(onesignalUserNotificationCenter:willPresentNotification:withCompletionHandler:),
                        @selector(userNotificationCenter:willPresentNotification:withCompletionHandler:), delegateUNSubclasses, [sizzleUNUserNotif class], delegateUNClass);
    
    injectToProperClass(@selector(onesignalUserNotificationCenter:didReceiveNotificationResponse:withCompletionHandler:),
                        @selector(userNotificationCenter:didReceiveNotificationResponse:withCompletionHandler:), delegateUNSubclasses, [sizzleUNUserNotif class], delegateUNClass);
    
    [self setOneSignalUNDelegate:delegate];
}

// Apples docs - Called when a notification is delivered to a foreground app.
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
- (void)onesignalUserNotificationCenter:(id)center didReceiveNotificationResponse:(id)response withCompletionHandler:(void(^)())completionHandler {
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"onesignalUserNotificationCenter:didReceiveNotificationResponse:withCompletionHandler: Fired!"];
    
    NSDictionary* usrInfo = [[[[response performSelector:@selector(notification)] valueForKey:@"request"] valueForKey:@"content"] valueForKey:@"userInfo"];
    if (!usrInfo || [usrInfo count] == 0) {
        [sizzleUNUserNotif tunnelToDelegate:center :response :completionHandler];
        return;
    }
    
    NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] init],
    *customDict = [[NSMutableDictionary alloc] init],
    *additionalData = [[NSMutableDictionary alloc] init];
    NSMutableArray *optionsDict = [[NSMutableArray alloc] init];
    
    NSMutableDictionary* buttonsDict = usrInfo[@"os_data"][@"buttons"];
    NSMutableDictionary* custom = usrInfo[@"custom"];
    if (buttonsDict) {
        [userInfo addEntriesFromDictionary:usrInfo];
        NSArray* o = buttonsDict[@"o"];
        if (o)
            [optionsDict addObjectsFromArray:o];
    }
    else if (custom) {
        [userInfo addEntriesFromDictionary:usrInfo];
        [customDict addEntriesFromDictionary:custom];
        NSDictionary *a = customDict[@"a"];
        NSArray *o = userInfo[@"o"];
        if (a)
            [additionalData addEntriesFromDictionary:a];
        if (o)
            [optionsDict addObjectsFromArray:o];
    }
    else {
        BOOL isActive = [UIApplication sharedApplication].applicationState == UIApplicationStateActive &&
        [[[NSUserDefaults standardUserDefaults] objectForKey:@"ONESIGNAL_ALERT_OPTION"] intValue] != OSNotificationDisplayTypeNotification;
        [OneSignal notificationOpened:usrInfo isActive:isActive];
        [sizzleUNUserNotif tunnelToDelegate:center :response :completionHandler];
        return;
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
    
    NSDictionary* os_data = usrInfo[@"os_data"];
    if (os_data) {
        [userInfo addEntriesFromDictionary:os_data];
        if (userInfo[@"os_data"][@"buttons"][@"m"])
            userInfo[@"aps"] = @{@"alert" : userInfo[@"os_data"][@"buttons"][@"m"]};
        [userInfo addEntriesFromDictionary:additionalData];
    }
    else {
        customDict[@"a"] = additionalData;
        userInfo[@"custom"] = customDict;
        if(userInfo[@"m"])
            userInfo[@"aps"] = @{ @"alert" : userInfo[@"m"] };
    }
    
    BOOL isActive = [UIApplication sharedApplication].applicationState == UIApplicationStateActive &&
    [[[NSUserDefaults standardUserDefaults] objectForKey:@"ONESIGNAL_ALERT_OPTION"] intValue] != OSNotificationDisplayTypeNotification;
    
    
    [OneSignal notificationOpened:userInfo isActive:isActive];
    [sizzleUNUserNotif tunnelToDelegate:center :response :completionHandler];
    
    if ([self respondsToSelector:@selector(onesignalUserNotificationCenter:didReceiveNotificationResponse:withCompletionHandler:)])
        [self onesignalUserNotificationCenter:center didReceiveNotificationResponse:response withCompletionHandler:completionHandler];
}

+ (void)tunnelToDelegate:(id)center :(id)response :(void (^)())handler {
    
    if ([[OneSignal notificationCenterDelegate] respondsToSelector:@selector(userNotificationCenter:didReceiveNotificationResponse:withCompletionHandler:)])
        [[OneSignal notificationCenterDelegate] userNotificationCenter:center didReceiveNotificationResponse:response withCompletionHandler:handler];
    else
        handler();
}

@end

#pragma clang diagnostic pop
#pragma clang diagnostic pop

#endif
