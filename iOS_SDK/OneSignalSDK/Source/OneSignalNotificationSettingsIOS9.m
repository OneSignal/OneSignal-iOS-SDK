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
#import "OneSignalNotificationSettingsIOS9.h"
#import "OneSignalInternal.h"
#import "OneSignalUserDefaults.h"

#define NOTIFICATION_TYPE_ALL 7

@implementation OneSignalNotificationSettingsIOS9 {
    void (^notificationPromptReponseCallback)(BOOL);
}

- (void)getNotificationPermissionState:(void (^)(OSPermissionState *subscriptionStatus))completionHandler {
    OSPermissionState* status = OneSignal.currentPermissionState;
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wdeprecated"
    status.notificationTypes = (int)UIApplication.sharedApplication.currentUserNotificationSettings.types;
    #pragma clang diagnostic pop
    status.accepted = status.notificationTypes > 0;
    status.answeredPrompt = [OneSignalUserDefaults.initStandard getSavedBoolForKey:OSUD_WAS_NOTIFICATION_PROMPT_ANSWERED_TO defaultValue:false];
    status.provisional = false;
    
    completionHandler(status);
}

- (OSPermissionState*)getNotificationPermissionState {
    __block OSPermissionState* returnStatus = [OSPermissionState alloc];
    
    [self getNotificationPermissionState:^(OSPermissionState *status) {
        returnStatus = status;
    }];
    
    return returnStatus;
}

- (int)getNotificationTypes {
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wdeprecated"
    return (int)UIApplication.sharedApplication.currentUserNotificationSettings.types;
    #pragma clang diagnostic pop
}

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"

- (void)promptForNotifications:(void(^)(BOOL accepted))completionHandler {
    UIApplication* sharedApp = [UIApplication sharedApplication];
    
    NSSet* categories = sharedApp.currentUserNotificationSettings.categories;
    [sharedApp registerUserNotificationSettings:[UIUserNotificationSettings settingsForTypes:NOTIFICATION_TYPE_ALL categories:categories]];
    
    notificationPromptReponseCallback = completionHandler;
    
    [OneSignal registerForAPNsToken];
}

- (void)onNotificationPromptResponse:(int)notificationTypes {
    BOOL accepted = notificationTypes > 0;
    
    if (notificationPromptReponseCallback) {
        notificationPromptReponseCallback(accepted);
        notificationPromptReponseCallback = nil;
    }
    
    OneSignal.currentPermissionState.accepted = accepted;
    OneSignal.currentPermissionState.answeredPrompt = true;
}

- (void)registerForProvisionalAuthorization:(OSUserResponseBlock)block {
    //empty implementation
}


#pragma GCC diagnostic pop

@end
