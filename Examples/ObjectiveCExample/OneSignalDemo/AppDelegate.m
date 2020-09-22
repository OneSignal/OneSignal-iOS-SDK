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

#import "AppDelegate.h"
#import <OneSignal/OneSignal.h>
#import "RedViewController.h"
#import "GreenViewController.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication*)application didFinishLaunchingWithOptions:(NSDictionary*)launchOptions {
    
    // (Optional) - Eanble logging to help debug issues. visualLevel will show alert dialog boxes.
    // Remove setLogLevel in the production version of your app.
    [OneSignal setLogLevel:ONE_S_LL_VERBOSE visualLevel:ONE_S_LL_WARN];
    
    // (Optional) - Create block the will fire when a notification is recieved while the app is in focus.
    id notifWillShowInForegroundHandler = ^(OSNotification *notification, OSNotificationDisplayTypeResponse completion) {
        NSLog(@"Received Notification - %@", notification.notificationId);
        if ([notification.notificationId isEqualToString:@"silent_notif"]) {
            completion(OSNotificationDisplayTypeSilent);
        } else {
            completion(OSNotificationDisplayTypeNotification);
        }
    };
    
    // (Optional) - Create block that will fire when a notification is tapped on.
    id notificationOpenedBlock = ^(OSNotificationOpenedResult *result) {
        OSNotification* notification = result.notification;
        
        NSString* messageTitle = @"OneSignal Example";
        NSString* fullMessage = [notification.body copy];
        
        if (notification.additionalData) {
            
            if (notification.title)
                messageTitle = notification.title;
            
            if (result.action.actionId) {
                fullMessage = [fullMessage stringByAppendingString:[NSString stringWithFormat:@"\nPressed ButtonId:%@", result.action.actionId]];
                
                UIViewController *vc;
                
                if ([result.action.actionId isEqualToString: @"id2"]) {
                    RedViewController *redVC = (RedViewController *)[[UIStoryboard storyboardWithName:@"MainStoryboard" bundle:[NSBundle mainBundle]] instantiateViewControllerWithIdentifier:@"redVC"];
                    
                    if (notification.additionalData[@"OpenURL"])
                        redVC.receivedUrl = [NSURL URLWithString:(NSString *)notification.additionalData[@"OpenURL"]];
                    
                    vc = redVC;
                } else if ([result.action.actionId isEqualToString:@"id1"]) {
                    vc = [[UIStoryboard storyboardWithName:@"MainStoryboard" bundle:[NSBundle mainBundle]] instantiateViewControllerWithIdentifier:@"greenVC"];
                }
                
                [self.window.rootViewController presentViewController:vc animated:true completion:nil];
            }
            
            
        }
        
        UIAlertController *controller = [UIAlertController alertControllerWithTitle:@"Push Notification" message:fullMessage preferredStyle:UIAlertControllerStyleAlert];
        [controller addAction:[UIAlertAction actionWithTitle:@"Close" style:UIAlertActionStyleCancel handler:nil]];
        
        [self.window.rootViewController presentViewController:controller animated:true completion:nil];
        
    };
    
    // (Optional) - Configuration options for OneSignal settings.
    id oneSignalSettings = @{kOSSettingsKeyInAppLaunchURL : @NO, kOSSettingsKeyAutoPrompt : @YES};
    
    // (REQUIRED) - Initializes OneSignal
    [OneSignal initWithLaunchOptions:launchOptions];
    [OneSignal setAppId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"];
    //Other optional initialization
    [OneSignal setAppSettings:oneSignalSettings];
    [OneSignal setNotificationWillShowInForegroundHandler:notifWillShowInForegroundHandler];
    [OneSignal setNotificationOpenedHandler:notificationOpenedBlock];
    return YES;
}

@end
