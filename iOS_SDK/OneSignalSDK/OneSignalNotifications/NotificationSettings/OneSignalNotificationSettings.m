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

#import "OneSignalNotificationSettings.h"

#import <Foundation/Foundation.h>
#import <UserNotifications/UserNotifications.h>

#import "OneSignalCommonDefines.h"
#import "OSNotificationsManager.h"
#import <OneSignalCore/OSDeviceUtils.h>
#import <OneSignalCore/OSMacros.h>
#import <OneSignalCore/OneSignalCoreHelper.h>

@interface OneSignalNotificationSettings ()
// Used as both an optimization and to prevent queue deadlocks.
@property (atomic) BOOL useCachedStatus;

@end

@implementation OneSignalNotificationSettings

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

- (void)getNotificationPermissionState:(void (^)(OSPermissionStateInternal *subscriptionStatus))completionHandler {
    if (self.useCachedStatus) {
        completionHandler(OSNotificationsManager.currentPermissionState);
        return;
    }
    
    // NOTE1: Never call currentUserNotificationSettings from the callback below! It will lock the main thread.
    // NOTE2: Apple runs the callback on a background serial queue
    dispatch_async(serialQueue, ^{
        [[UNUserNotificationCenter currentNotificationCenter] getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings* settings) {
            OSPermissionStateInternal* status = OSNotificationsManager.currentPermissionState;
            
            //to avoid 'undeclared identifier' errors in older versions of Xcode,
            //we do not directly reference UNAuthorizationStatusProvisional (which is only available in iOS 12/Xcode 10
            UNAuthorizationStatus provisionalStatus = (UNAuthorizationStatus)3;
            
            status.answeredPrompt = settings.authorizationStatus != UNAuthorizationStatusNotDetermined && settings.authorizationStatus != provisionalStatus;
            status.provisional = (settings.authorizationStatus == 3);
            status.accepted = settings.authorizationStatus == UNAuthorizationStatusAuthorized && !status.provisional;
            if (@available(iOS 14.0, *)) {
                status.ephemeral = (settings.authorizationStatus == AUTH_STATUS_EPHEMERAL);
                status.accepted = status.accepted || status.ephemeral;
            } else {
                status.ephemeral = false;
            }
            
            status.notificationTypes = (settings.badgeSetting == UNNotificationSettingEnabled ? 1 : 0)
                                     + (settings.soundSetting == UNNotificationSettingEnabled ? 2 : 0)
                                     + (settings.alertSetting == UNNotificationSettingEnabled ? 4 : 0)
                                     + (settings.lockScreenSetting == UNNotificationSettingEnabled ? 8 : 0);
            
            // check if using provisional notifications
            if ([OSDeviceUtils isIOSVersionGreaterThanOrEqual:@"12.0"] && settings.authorizationStatus == provisionalStatus)
                status.notificationTypes += PROVISIONAL_UNAUTHORIZATIONOPTION;
            
            // also check if 'deliver quietly' is enabled.
            if ([OSDeviceUtils isIOSVersionGreaterThanOrEqual:@"10.0"] && settings.notificationCenterSetting == UNNotificationSettingEnabled)
                status.notificationTypes += 16;
            
            self.useCachedStatus = true;
            completionHandler(status);
            self.useCachedStatus = false;
        }];
    });
}

// used only in cases where UNUserNotificationCenter getNotificationSettingsWith...
// callback does not get executed in a timely fashion. Rather than returning nil,
- (OSPermissionStateInternal *)defaultPermissionState {
    if (OSNotificationsManager.currentPermissionState != nil) {
        return OSNotificationsManager.currentPermissionState;
    }
    
    OSPermissionStateInternal *defaultState = [OSPermissionStateInternal new];
    
    defaultState.notificationTypes = 0;
    
    return defaultState;
}

- (OSPermissionStateInternal*)getNotificationPermissionState {
    if (self.useCachedStatus)
        return OSNotificationsManager.currentPermissionState;
    
    __block OSPermissionStateInternal* returnState = OSNotificationsManager.currentPermissionState;
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    dispatch_sync(serialQueue, ^{
        [self getNotificationPermissionState:^(OSPermissionStateInternal *state) {
            returnState = state;
            dispatch_semaphore_signal(semaphore);
        }];
    });
    
    dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(100 * NSEC_PER_MSEC)));
    
    return returnState ?: self.defaultPermissionState;
}

- (int)getNotificationTypes {
    return [self getNotificationPermissionState].notificationTypes;
}

// Prompt then run updateNotificationTypes on the main thread with the response.
// FUTURE: Add a 2nd seloctor with 'withOptions' for UNAuthorizationOptions*'s
- (void)promptForNotifications:(void(^)(BOOL accepted))completionHandler {
    
    id responseBlock = ^(BOOL granted, NSError* error) {
        // Run callback on main / UI thread
        [OneSignalCoreHelper dispatch_async_on_main_queue: ^{ // OneSignalCoreHelper.dispatch_async_on_main_queue ??
            OSNotificationsManager.currentPermissionState.provisional = false;
            OSNotificationsManager.currentPermissionState.accepted = granted;
            OSNotificationsManager.currentPermissionState.answeredPrompt = true;
            [OSNotificationsManager updateNotificationTypes: granted ? 15 : 0];
            if (completionHandler)
                completionHandler(granted);
        }];
    };
    
    UNAuthorizationOptions options = (UNAuthorizationOptionAlert + UNAuthorizationOptionSound + UNAuthorizationOptionBadge);
    
    if ([OSDeviceUtils isIOSVersionGreaterThanOrEqual:@"12.0"] && [OSNotificationsManager providesAppNotificationSettings]) {
        options += PROVIDES_SETTINGS_UNAUTHORIZATIONOPTION;
    }
    
    UNUserNotificationCenter* center = [UNUserNotificationCenter currentNotificationCenter];
    [center requestAuthorizationWithOptions:options completionHandler:responseBlock];
    
    [OSNotificationsManager registerForAPNsToken];
}

- (void)registerForProvisionalAuthorization:(OSUserResponseBlock)block {
    
    if ([OSDeviceUtils isIOSVersionLessThan:@"12.0"]) {
        return;
    }
    
    OSPermissionStateInternal *state = [self getNotificationPermissionState];
    
    //don't register for provisional if the user has already accepted the prompt
    if (state.status != OSNotificationPermissionNotDetermined || state.answeredPrompt) {
        if (block)
            block(true);
        return;
    }
    
    UNUserNotificationCenter* center = [UNUserNotificationCenter currentNotificationCenter];
    
    let options = PROVISIONAL_UNAUTHORIZATIONOPTION + DEFAULT_UNAUTHORIZATIONOPTIONS;
    
    id responseBlock = ^(BOOL granted, NSError *error) {
        [OneSignalCoreHelper dispatch_async_on_main_queue:^{  // OneSignalCoreHelper.dispatch_async_on_main_queue ??
            OSNotificationsManager.currentPermissionState.provisional = true;
            [OSNotificationsManager updateNotificationTypes: options];
            if (block)
                block(granted);
        }];
    };
    
    [center requestAuthorizationWithOptions:options completionHandler:responseBlock];
}

// Ignore these 2 events, promptForNotifications: already takes care of these.
// Only iOS 9
- (void)onNotificationPromptResponse:(int)notificationTypes { }

@end
