/**
 * Modified MIT License
 *
 * Copyright 2017 OneSignal
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

// Please see the root Example folder of this repo for an Example project.
// This project exisits to make testing OneSignal SDK changes.

#import "AppDelegate.h"
#import "ViewController.h"

@interface OneSignalNotificationCenterDelegate: NSObject<UNUserNotificationCenterDelegate>
@end
@implementation OneSignalNotificationCenterDelegate

- (void)userNotificationCenter:(UNUserNotificationCenter *)center willPresentNotification:(UNNotification *)notification withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completionHandler {
    NSLog(@"Appdelegatewillpresentdelegate");
}

@end

@implementation AppDelegate

OneSignalNotificationCenterDelegate *_notificationDelegate;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
//    [FIRApp configure];
    
    NSLog(@"Bundle URL: %@", [[NSBundle mainBundle] bundleURL]);
    [OneSignal.Debug setLogLevel:ONE_S_LL_VERBOSE];
    [OneSignal.Debug setVisualLevel:ONE_S_LL_NONE];
    
    [OneSignal initialize:[AppDelegate getOneSignalAppId] withLaunchOptions:launchOptions];
    
    _notificationDelegate = [OneSignalNotificationCenterDelegate new];
    
    id openNotificationHandler = ^(OSNotificationOpenedResult *result) {
        NSLog(@"OSNotificationOpenedResult: %@", result.action);
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wdeprecated"
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Notifiation Opened In App Delegate" message:@"Notification Opened In App Delegate" delegate:self cancelButtonTitle:@"Delete" otherButtonTitles:@"Cancel", nil];
        [alert show];
        #pragma clang diagnostic pop
    };
    id notificationReceiverBlock = ^(OSNotification *notif, OSNotificationDisplayResponse completion) {
        NSLog(@"Will Receive Notification - %@", notif.notificationId);
        completion(notif);
    };
    
    // Example block for IAM action click handler
    id inAppMessagingActionClickBlock = ^(OSInAppMessageAction *action) {
        NSString *message = [NSString stringWithFormat:@"Click Action Occurred: %@", [action jsonRepresentation]];
        [OneSignalLog onesignalLog:ONE_S_LL_DEBUG message:message];
    };

    // Example setter for IAM action click handler using OneSignal public method
    [OneSignal.InAppMessages setClickHandler:inAppMessagingActionClickBlock];
    
    // OneSignal Init with app id and lauch options
    [OneSignal setLaunchURLsInApp:YES];
    [OneSignal setProvidesNotificationSettingsView:NO];
    
    
    [OneSignal.Notifications requestPermission:^(BOOL accepted) {
        NSLog(@"OneSignal Demo App requestPermission: %d", accepted);
    }];
    
    [OneSignal.InAppMessages setLifecycleHandler:self];
    [OneSignal.InAppMessages paused:true];

    [OneSignal.Notifications setNotificationWillShowInForegroundHandler:notificationReceiverBlock];
    [OneSignal.Notifications setNotificationOpenedHandler:openNotificationHandler];

    OSPushSubscriptionState* state = [OneSignal.User.pushSubscription addObserver:self];
    NSLog(@"OneSignal Demo App push subscription observer added, current state: %@", state);
    
    [OneSignal.Notifications addPermissionObserver:self];
    
    NSLog(@"UNUserNotificationCenter.delegate: %@", UNUserNotificationCenter.currentNotificationCenter.delegate);
    
    return YES;
}

#define ONESIGNAL_APP_ID_DEFAULT @"1688d8f2-da7f-4815-8ee3-9d13788482c8"
#define ONESIGNAL_APP_ID_KEY_FOR_TESTING @"1688d8f2-da7f-4815-8ee3-9d13788482c8"

+ (NSString*)getOneSignalAppId {
    NSString* userDefinedAppId = [[NSUserDefaults standardUserDefaults] objectForKey:ONESIGNAL_APP_ID_KEY_FOR_TESTING];
    if (userDefinedAppId) {
        return userDefinedAppId;
    }
    return ONESIGNAL_APP_ID_DEFAULT;
}

+ (void) setOneSignalAppId:(NSString*)onesignalAppId {
    [[NSUserDefaults standardUserDefaults] setObject:onesignalAppId forKey:ONESIGNAL_APP_ID_KEY_FOR_TESTING];
    [[NSUserDefaults standardUserDefaults] synchronize];
    // [OneSignal setAppId:onesignalAppId];
}

- (void) onOSPermissionChanged:(OSPermissionStateChanges*)stateChanges {
    NSLog(@"onOSPermissionChanged: %@", stateChanges);
}

- (void)onOSPushSubscriptionChangedWithStateChanges:(OSPushSubscriptionStateChanges *)stateChanges {
    NSLog(@"onOSPushSubscriptionChangedWithStateChanges: %@", stateChanges);
    ViewController* mainController = (ViewController*) self.window.rootViewController;
    mainController.subscriptionSegmentedControl.selectedSegmentIndex = (NSInteger) stateChanges.to.optedIn;
}

#pragma mark OSInAppMessageDelegate

- (void)handleMessageAction:(OSInAppMessageAction *)action {
    NSLog(@"OSInAppMessageDelegate: handling message action: %@",action);
    return;
}

- (void)onWillDisplayInAppMessage:(OSInAppMessage *)message {
    NSLog(@"OSInAppMessageDelegate: onWillDisplay Message: %@",message);
    return;
}

- (void)onDidDisplayInAppMessage:(OSInAppMessage *)message {
    NSLog(@"OSInAppMessageDelegate: onDidDisplay Message: %@",message);
    return;
}

- (void)onWillDismissInAppMessage:(OSInAppMessage *)message {
    NSLog(@"OSInAppMessageDelegate: onWillDismiss Message: %@",message);
    return;
}

- (void)onDidDismissInAppMessage:(OSInAppMessage *)message {
    NSLog(@"OSInAppMessageDelegate: onDidDismiss Message: %@",message);
    return;
}

#pragma mark UIApplicationDelegate methods

- (void)applicationWillResignActive:(UIApplication *)application {
}


- (void)applicationDidEnterBackground:(UIApplication *)application {
}


- (void)applicationWillEnterForeground:(UIApplication *)application {
}


- (void)applicationDidBecomeActive:(UIApplication *)application {
    
//    [FIRAnalytics logEventWithName:@"os_notification_opened"
//                        parameters:@{
//                                     kFIRParameterSource: @"OneSignal",
//                                     kFIRParameterMedium: @"notification",
//                                     @"notification_id": @"b2f7f966-d8cc-11e4-bed1-df8f05be55ba",
//                                     kFIRParameterCampaign: @"some title"
//                                     }];
    
}


- (void)applicationWillTerminate:(UIApplication *)application {
}

// Remote
- (void)application:(UIApplication *)application
didReceiveRemoteNotification:(NSDictionary *)userInfo
fetchCompletionHandler:(void (^)(UIBackgroundFetchResult result))completionHandler {
    
    NSLog(@"application:didReceiveRemoteNotification:fetchCompletionHandler: %@", userInfo);
    completionHandler(UIBackgroundFetchResultNoData);
}

@end
