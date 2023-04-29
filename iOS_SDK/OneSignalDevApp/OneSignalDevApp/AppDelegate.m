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
    [OneSignal.Debug setAlertLevel:ONE_S_LL_NONE];
    
    [OneSignal initialize:[AppDelegate getOneSignalAppId] withLaunchOptions:launchOptions];
    
    _notificationDelegate = [OneSignalNotificationCenterDelegate new];
    
    id openNotificationHandler = ^(OSNotificationOpenedResult *result) {
        // TODO: opened handler Not triggered
        NSLog(@"OSNotificationOpenedResult: %@", result.action);
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wdeprecated"
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Notifiation Opened In App Delegate" message:@"Notification Opened In App Delegate" delegate:self cancelButtonTitle:@"Delete" otherButtonTitles:@"Cancel", nil];
        [alert show];
        #pragma clang diagnostic pop
    };
    
    // OneSignal Init with app id and lauch options
    [OneSignal setLaunchURLsInApp:YES];
    [OneSignal setProvidesNotificationSettingsView:NO];
    
    [OneSignal.InAppMessages addLifecycleListener:self];
    [OneSignal.InAppMessages paused:true];

    [OneSignal.Notifications addForegroundLifecycleListener:self];
    [OneSignal.Notifications setNotificationOpenedHandler:openNotificationHandler];

    [OneSignal.User.pushSubscription addObserver:self];
    NSLog(@"OneSignal Demo App push subscription observer added");
    
    [OneSignal.Notifications addPermissionObserver:self];
    [OneSignal.InAppMessages addClickListener:self];

    NSLog(@"UNUserNotificationCenter.delegate: %@", UNUserNotificationCenter.currentNotificationCenter.delegate);
    
    return YES;
}

#define ONESIGNAL_APP_ID_DEFAULT @"YOUR_APP_ID_HERE"
#define ONESIGNAL_APP_ID_KEY_FOR_TESTING @"YOUR_APP_ID_HERE"

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

- (void)onNotificationPermissionDidChange:(BOOL)permission {
    NSLog(@"Dev App onNotificationPermissionDidChange: %d", permission);
}

- (void)onPushSubscriptionDidChangeWithState:(OSPushSubscriptionChangedState *)state {
    NSLog(@"Dev App onPushSubscriptionDidChange: %@", state);
    ViewController* mainController = (ViewController*) self.window.rootViewController;
    mainController.subscriptionSegmentedControl.selectedSegmentIndex = (NSInteger) state.current.optedIn;
}

#pragma mark OSInAppMessageDelegate

- (void)onClickInAppMessage:(OSInAppMessageClickEvent * _Nonnull)event {
    NSLog(@"Dev App onClickInAppMessage event: %@", [event jsonRepresentation]);
}

- (void)onWillDisplayNotification:(OSNotificationWillDisplayEvent *)event {
    NSLog(@"Dev App OSNotificationWillDisplayEvent with event: %@",event);
    [event preventDefault];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [event.notification display];
    });
}

- (void)onWillDisplayInAppMessage:(OSInAppMessageWillDisplayEvent *)event {
    NSLog(@"Dev App OSInAppMessageLifecycleListener: onWillDisplay Message: %@",event.message);
    return;
}

- (void)onDidDisplayInAppMessage:(OSInAppMessageDidDisplayEvent *)event {
    NSLog(@"Dev App OSInAppMessageLifecycleListener: onDidDisplay Message: %@",event.message);
    return;
}

- (void)onWillDismissInAppMessage:(OSInAppMessageWillDismissEvent *)event {
    NSLog(@"Dev App OSInAppMessageLifecycleListener: onWillDismiss Message: %@",event.message);
    return;
}

- (void)onDidDismissInAppMessage:(OSInAppMessageDidDismissEvent *)event {
    NSLog(@"Dev App OSInAppMessageLifecycleListener: onDidDismiss Message: %@",event.message);
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
