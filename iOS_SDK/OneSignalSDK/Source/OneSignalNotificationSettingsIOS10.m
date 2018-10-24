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

#import "OneSignalNotificationSettingsIOS10.h"

#import "OneSignalInternal.h"

#import <Foundation/Foundation.h>
#import <UserNotifications/UserNotifications.h>

#import "OneSignalHelper.h"
#import "OneSignalCommonDefines.h"

@interface OneSignalNotificationSettingsIOS10 ()
// Used as both an optimization and to prevent queue deadlocks.
@property (atomic) BOOL useCachedStatus;

@end

@implementation OneSignalNotificationSettingsIOS10

// Used to run all calls to getNotificationSettingsWithCompletionHandler sequentially
//   This prevents any possible deadlocks due to race condiditions.
static dispatch_queue_t serialQueue;
+(dispatch_queue_t)getQueue {
    return serialQueue;
}

- (instancetype)init {
    serialQueue = dispatch_queue_create("com.onesignal.notification.settings.ios10", DISPATCH_QUEUE_SERIAL);
    return [super init];
}

- (void)getNotificationPermissionState:(void (^)(OSPermissionState *subscriptionStatus))completionHandler {
    if (self.useCachedStatus) {
        completionHandler(OneSignal.currentPermissionState);
        return;
    }
    
    // NOTE1: Never call currentUserNotificationSettings from the callback below! It will lock the main thread.
    // NOTE2: Apple runs the callback on a background serial queue
    dispatch_async(serialQueue, ^{
        [[UNUserNotificationCenter currentNotificationCenter] getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings* settings) {
            OSPermissionState* status = OneSignal.currentPermissionState;
            
            //to avoid 'undeclared identifier' errors in older versions of Xcode,
            //we do not directly reference UNAuthorizationStatusProvisional (which is only available in iOS 12/Xcode 10
            UNAuthorizationStatus provisionalStatus = (UNAuthorizationStatus)3;
            
            status.answeredPrompt = settings.authorizationStatus != UNAuthorizationStatusNotDetermined && settings.authorizationStatus != provisionalStatus;
            status.provisional = (settings.authorizationStatus == 3);
            status.accepted = settings.authorizationStatus == UNAuthorizationStatusAuthorized && !status.provisional;
            
            status.notificationTypes = (settings.badgeSetting == UNNotificationSettingEnabled ? 1 : 0)
                                     + (settings.soundSetting == UNNotificationSettingEnabled ? 2 : 0)
                                     + (settings.alertSetting == UNNotificationSettingEnabled ? 4 : 0)
                                     + (settings.lockScreenSetting == UNNotificationSettingEnabled ? 8 : 0);
            
            // check if using provisional notifications
            if ([OneSignalHelper isIOSVersionGreaterOrEqual:12.0] && settings.authorizationStatus == provisionalStatus)
                status.notificationTypes += PROVISIONAL_UNAUTHORIZATIONOPTION;
            
            // also check if 'deliver quietly' is enabled.
            if ([OneSignalHelper isIOSVersionGreaterOrEqual:10.0] && settings.notificationCenterSetting == UNNotificationSettingEnabled)
                status.notificationTypes += 16;
            
            self.useCachedStatus = true;
            completionHandler(status);
            self.useCachedStatus = false;
        }];
    });
}

// used only in cases where UNUserNotificationCenter getNotificationSettingsWith...
// callback does not get executed in a timely fashion. Rather than returning nil,
- (OSPermissionState *)defaultPermissionState {
    if (OneSignal.currentPermissionState != nil) {
        return OneSignal.currentPermissionState;
    }
    
    OSPermissionState *defaultState = [OSPermissionState new];
    
    defaultState.notificationTypes = 0;
    
    return defaultState;
}

- (OSPermissionState*)getNotificationPermissionState {
    if (self.useCachedStatus)
        return OneSignal.currentPermissionState;
    
    __block OSPermissionState* returnStatus = OneSignal.currentPermissionState;
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    dispatch_sync(serialQueue, ^{
        [self getNotificationPermissionState:^(OSPermissionState *status) {
            returnStatus = status;
            dispatch_semaphore_signal(semaphore);
        }];
    });
    
    dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(100 * NSEC_PER_MSEC)));
    
    return returnStatus ?: self.defaultPermissionState;
}

- (int)getNotificationTypes {
    return [self getNotificationPermissionState].notificationTypes;
}

// Prompt then run updateNotificationTypes on the main thread with the response.
// FUTURE: Add a 2nd seloctor with 'withOptions' for UNAuthorizationOptions*'s
- (void)promptForNotifications:(void(^)(BOOL accepted))completionHandler {
    
    id responseBlock = ^(BOOL granted, NSError* error) {
        // Run callback on main / UI thread
        [OneSignalHelper dispatch_async_on_main_queue: ^{
            OneSignal.currentPermissionState.provisional = false;
            OneSignal.currentPermissionState.accepted = granted;
            OneSignal.currentPermissionState.answeredPrompt = true;
            [OneSignal updateNotificationTypes: granted ? 15 : 0];
            if (completionHandler)
                completionHandler(granted);
        }];
    };
    
    UNAuthorizationOptions options = (UNAuthorizationOptionAlert + UNAuthorizationOptionSound + UNAuthorizationOptionBadge);
    
    if ([OneSignalHelper isIOSVersionGreaterOrEqual:12.0] && [OneSignal providesAppNotificationSettings]) {
        options += PROVIDES_SETTINGS_UNAUTHORIZATIONOPTION;
    }
    
    UNUserNotificationCenter* center = [UNUserNotificationCenter currentNotificationCenter];
    [center requestAuthorizationWithOptions:options completionHandler:responseBlock];
    
    [OneSignal registerForAPNsToken];
}

- (void)registerForProvisionalAuthorization:(void(^)(BOOL accepted))completionHandler {
    
    if (![OneSignalHelper isIOSVersionGreaterOrEqual:12.0]) {
        return;
    }
    
    OSPermissionState *state = [self getNotificationPermissionState];
    
    //don't register for provisional if the user has already accepted the prompt
    if (state.status != OSNotificationPermissionNotDetermined || state.answeredPrompt) {
        if (completionHandler)
            completionHandler(true);
        return;
    }
    
    UNUserNotificationCenter* center = [UNUserNotificationCenter currentNotificationCenter];
    
    id responseBlock = ^(BOOL granted, NSError *error) {
        [OneSignalHelper dispatch_async_on_main_queue:^{
            OneSignal.currentPermissionState.provisional = granted;
            [OneSignal updateNotificationTypes: granted ? PROVISIONAL_UNAUTHORIZATIONOPTION : 0];
            if (completionHandler)
                completionHandler(granted);
        }];
    };
    
    let options = PROVISIONAL_UNAUTHORIZATIONOPTION + UNAuthorizationOptionSound + UNAuthorizationOptionBadge + UNAuthorizationOptionAlert;
    
    [center requestAuthorizationWithOptions:options completionHandler:responseBlock];
}

// Ignore these 2 events, promptForNotifications: already takes care of these.
// Only iOS 8 & 9
- (void)onNotificationPromptResponse:(int)notificationTypes { }
// Only iOS 7
- (void)onAPNsResponse:(BOOL)success {}

@end
