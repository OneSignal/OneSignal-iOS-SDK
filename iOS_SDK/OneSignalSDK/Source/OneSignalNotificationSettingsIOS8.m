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

#import <UIKit/UIKit.h>

#import "OneSignalNotificationSettingsIOS8.h"

#import "OneSignalInternal.h"


@implementation OneSignalNotificationSettingsIOS8

- (void)getNotificationPermissionStatus:(void (^)(OSPermissionStatus *subcscriptionStatus))completionHandler {
    OSPermissionStatus *status = [OSPermissionStatus alloc];
    
    NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
    status.hasPrompted = [userDefaults boolForKey:@"OS_HAS_PROMPTED_FOR_NOTIFICATIONS"];
    status.anwseredPrompt = [userDefaults boolForKey:@"OS_NOTIFICATION_PROMPT_ANSWERED"];
    status.notificationTypes = [[UIApplication sharedApplication] currentUserNotificationSettings].types;
    status.accepted = status.notificationTypes > 0;
    
    completionHandler(status);
}

- (OSPermissionStatus*)getNotificationPermissionStatus {
    __block OSPermissionStatus* returnStatus = [OSPermissionStatus alloc];
    
    [self getNotificationPermissionStatus:^(OSPermissionStatus *status) {
        returnStatus = status;
    }];
    
    return returnStatus;
}

- (int) getNotificationTypes {
    return [[UIApplication sharedApplication] currentUserNotificationSettings].types;
}

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"

- (void)promptForNotifications {
    UIApplication* shardApp = [UIApplication sharedApplication];
    
    NSSet* categories = [[shardApp currentUserNotificationSettings] categories];
    [shardApp registerUserNotificationSettings:[UIUserNotificationSettings settingsForTypes:NOTIFICATION_TYPE_ALL categories:categories]];
    
    [OneSignal registerForAPNsToken];
}

#pragma GCC diagnostic pop

@end
