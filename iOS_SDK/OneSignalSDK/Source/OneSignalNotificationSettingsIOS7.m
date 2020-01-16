/**
 Modified MIT License
 
 Copyright 2017 OneSignal
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 
 1. The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.
 
 2. All copies of substantial portions of the Software may only be used in connection
 with services provided by OneSignal.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
 */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "OneSignalNotificationSettingsIOS7.h"
#import "OneSignal.h"
#import "OneSignalHelper.h"
#import "OneSignalInternal.h"
#import "OneSignalUserDefaults.h"
#import "OneSignalCommonDefines.h"


@implementation OneSignalNotificationSettingsIOS7 {
    void (^notificationPromptReponseCallback)(BOOL);
}

- (void)getNotificationPermissionState:(void (^)(OSPermissionState *subscriptionStatus))completionHandler {
    let standardUserDefaults = OneSignalUserDefaults.initStandard;
    OSPermissionState* status = OneSignal.currentPermissionState;
    
    // Don't call getNotificationTypes as this will cause currentSubscriptionState to initialize before currentPermissionState
    status.notificationTypes = [standardUserDefaults getSavedStringForKey:OSUD_PUSH_TOKEN_TO defaultValue:nil] == nil ? 0 : 7;
    status.accepted = status.notificationTypes > 0;
    status.answeredPrompt = [standardUserDefaults getSavedBoolForKey:OSUD_WAS_NOTIFICATION_PROMPT_ANSWERED_TO defaultValue:false];
    status.provisional = false;
    
    completionHandler(status);
}

- (OSPermissionState*)getNotificationPermissionState {
    __block OSPermissionState* returnState = [OSPermissionState alloc];
    
    [self getNotificationPermissionState:^(OSPermissionState *state) {
        returnState = state;
    }];
    
    return returnState;
}

- (int)getNotificationTypes {
    return OneSignal.currentSubscriptionState.pushToken == nil ? 0 : 7;
}


#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"

- (void)promptForNotifications:(void(^)(BOOL accepted))completionHandler {
    notificationPromptReponseCallback = completionHandler;
    [[UIApplication sharedApplication] registerForRemoteNotificationTypes:UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeSound | UIRemoteNotificationTypeAlert];
    [OneSignal setWaitingForApnsResponse:true];
    [OneSignalUserDefaults.initStandard saveBoolForKey:OSUD_REGISTERED_WITH_APPLE withValue:true];
}

#pragma GCC diagnostic pop

// Only iOS 8 & 9
- (void)onNotificationPromptResponse:(int)notificationTypes {}
- (void)registerForProvisionalAuthorization:(void(^)(BOOL accepted))completionHandler {}

// Only iOS 7
- (void)onAPNsResponse:(BOOL)success {
    if (notificationPromptReponseCallback) {
        notificationPromptReponseCallback(success);
        notificationPromptReponseCallback = nil;
    }
    
    OneSignal.currentPermissionState.accepted = success;
    OneSignal.currentPermissionState.answeredPrompt = true;
}


@end
