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
    
    [OneSignal setLogLevel:ONE_S_LL_VERBOSE visualLevel:ONE_S_LL_NONE];
    _notificationDelegate = [OneSignalNotificationCenterDelegate new];
    
    id openNotificationHandler = ^(OSNotificationOpenedResult *result) {
        NSLog(@"OSNotificationOpenedResult: %@", result.action);
        
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Notifiation Opened In App Delegate" message:@"Notification Opened In App Delegate" delegate:self cancelButtonTitle:@"Delete" otherButtonTitles:@"Cancel", nil];
        [alert show];
    };
    id notificationReceiverBlock = ^(OSNotificationGenerationJob *notifJob, OSNotificationDisplayTypeResponse completion) {
        NSLog(@"Will Receive Notification - %@", notifJob.notificationId);
        completion(OSNotificationDisplayTypeNotification);
    };
    
    // Example block for IAM action click handler
    id inAppMessagingActionClickBlock = ^(OSInAppMessageAction *action) {
        NSString *message = [NSString stringWithFormat:@"Click Action Occurred: %@", [action jsonRepresentation]];
        [OneSignal onesignal_Log:ONE_S_LL_DEBUG message:message];
    };

    // Example setter for IAM action click handler using OneSignal public method
    [OneSignal setInAppMessageClickHandler:inAppMessagingActionClickBlock];
    
    // OneSignal Init with app settings, app id, and lauch options
    [OneSignal setAppSettings:@{
        kOSSettingsKeyAutoPrompt: @false,
        kOSSettingsKeyInAppLaunchURL: @true
    }];
    [OneSignal setAppId:[AppDelegate getOneSignalAppId]];
    [OneSignal setLaunchOptions:launchOptions];

    [OneSignal addPermissionObserver:self];
    [OneSignal addSubscriptionObserver:self];
    [OneSignal addEmailSubscriptionObserver:self];
    
    [OneSignal pauseInAppMessages:true];
    
    [OneSignal setNotificationWillShowInForegroundHandler:notificationReceiverBlock];
    [OneSignal setNotificationOpenedHandler:openNotificationHandler];

    NSLog(@"UNUserNotificationCenter.delegate: %@", UNUserNotificationCenter.currentNotificationCenter.delegate);
    
    return YES;
}

#define ONESIGNAL_APP_ID_KEY_FOR_TESTING @"ONESIGNAL_APP_ID_KEY_FOR_TESTING"

+ (NSString*)getOneSignalAppId {
    NSString* newAppId = @"0ba9731b-33bd-43f4-8b59-61172e27447d";
    NSString* onesignalAppId = [[NSUserDefaults standardUserDefaults] objectForKey:ONESIGNAL_APP_ID_KEY_FOR_TESTING];

    if (![newAppId isEqualToString:onesignalAppId]) {
        [self setOneSignalAppId:newAppId];
        onesignalAppId = newAppId;
    }

    return onesignalAppId;
}

+ (void) setOneSignalAppId:(NSString*)onesignalAppId {
    [[NSUserDefaults standardUserDefaults] setObject:onesignalAppId forKey:ONESIGNAL_APP_ID_KEY_FOR_TESTING];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void) onOSPermissionChanged:(OSPermissionStateChanges*)stateChanges {
    NSLog(@"onOSPermissionChanged: %@", stateChanges);
}

- (void) onOSSubscriptionChanged:(OSSubscriptionStateChanges*)stateChanges {
    NSLog(@"onOSSubscriptionChanged: %@", stateChanges);
    ViewController* mainController = (ViewController*) self.window.rootViewController;
    mainController.subscriptionSegmentedControl.selectedSegmentIndex = (NSInteger) stateChanges.to.subscribed;
}

- (void)onOSEmailSubscriptionChanged:(OSEmailSubscriptionStateChanges *)stateChanges {
    NSLog(@"onOSEmailSubscriptionChanged: %@", stateChanges);
}

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
    completionHandler(nil);
}

@end
