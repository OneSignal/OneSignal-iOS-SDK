/*
 Modified MIT License

 Copyright 2022 OneSignal

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

#import "OSNotificationsManager.h"
#import <OneSignalCore/OneSignalCore.h>
#import <UIKit/UIKit.h>

@implementation OSNotificationsManager
+ (Class<OSNotifications>)Notifications {
    return self;
}

// UIApplication-registerForRemoteNotifications has been called but a success or failure has not triggered yet.
static BOOL _waitingForApnsResponse = false;
static BOOL _providesAppNotificationSettings = false;
static int mSubscriptionStatus = -1;
static int mLastNotificationTypes = -1;
+ (void)setMSubscriptionStatus:(NSNumber*)status {
    mSubscriptionStatus = [status intValue];
}

static OneSignalNotificationSettings *_osNotificationSettings;
+ (OneSignalNotificationSettings *)osNotificationSettings {
    if (!_osNotificationSettings) {
        _osNotificationSettings = [OneSignalNotificationSettings new];
    }
    return _osNotificationSettings;
}

static ObservablePermissionStateChangesType* _permissionStateChangesObserver;
+ (ObservablePermissionStateChangesType*)permissionStateChangesObserver {
    if (!_permissionStateChangesObserver)
        _permissionStateChangesObserver = [[OSObservable alloc] initWithChangeSelector:@selector(onOSPermissionChanged:)];
    return _permissionStateChangesObserver;
}

// static property def for currentPermissionState
static OSPermissionStateInternal* _currentPermissionState;
+ (OSPermissionStateInternal*)currentPermissionState {
    if (!_currentPermissionState) {
        _currentPermissionState = [OSPermissionStateInternal alloc];
        _currentPermissionState = [_currentPermissionState initAsTo];
        [self lastPermissionState]; // Trigger creation
        [_currentPermissionState.observable addObserver:[OSPermissionChangedInternalObserver alloc]];
    }
    return _currentPermissionState;
}

// static property def for previous OSPermissionState
static OSPermissionStateInternal* _lastPermissionState;
+ (OSPermissionStateInternal*)lastPermissionState {
    if (!_lastPermissionState)
        _lastPermissionState = [[OSPermissionStateInternal alloc] initAsFrom];
    return _lastPermissionState;
}

static NSString *_pushToken;

+ (void)setLastPermissionState:(OSPermissionStateInternal *)lastPermissionState {
    _lastPermissionState = lastPermissionState;
}

+ (void)requestPermission:(OSUserResponseBlock)block {
    NSLog(@"🔥 requestPermission:(OSUserResponseBlock)block called");
    // return if the user has not granted privacy permissions
    if ([OSPrivacyConsentController shouldLogMissingPrivacyConsentErrorWithMethodName:@"promptForPushNotificationsWithUserResponse:"])
        return;
    
    [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"registerForPushNotifications Called:waitingForApnsResponse: %d", _waitingForApnsResponse]];
    
    self.currentPermissionState.hasPrompted = true;
    
    [self.osNotificationSettings promptForNotifications:block];
}

// if user has disabled push notifications & fallback == true,
// the SDK will prompt the user to open notification Settings for this app
+ (void)requestPermission:(OSUserResponseBlock)block fallbackToSettings:(BOOL)fallback {
    
    if (self.currentPermissionState.hasPrompted == true && self.osNotificationSettings.getNotificationTypes == 0 && fallback) {
        //show settings

        let localizedTitle = NSLocalizedString(@"Open Settings", @"A title saying that the user can open iOS Settings");
        let localizedSettingsActionTitle = NSLocalizedString(@"Open Settings", @"A button allowing the user to open the Settings app");
        let localizedCancelActionTitle = NSLocalizedString(@"Cancel", @"A button allowing the user to close the Settings prompt");
        
        //the developer can provide a custom message in Info.plist if they choose.
        var localizedMessage = (NSString *)[[NSBundle mainBundle] objectForInfoDictionaryKey:FALLBACK_TO_SETTINGS_MESSAGE];
        
        if (!localizedMessage)
            localizedMessage = NSLocalizedString(@"You currently have notifications turned off for this application. You can open Settings to re-enable them", @"A message explaining that users can open Settings to re-enable push notifications");
        
        /*
         Provide a protocol for this and inject it rather than referencing dialogcontroller directly. This is is because it uses UIApplication sharedApplication
         */
        
        [[OSDialogInstanceManager sharedInstance] presentDialogWithTitle:localizedTitle withMessage:localizedMessage withActions:@[localizedSettingsActionTitle] cancelTitle:localizedCancelActionTitle withActionCompletion:^(int tappedActionIndex) {
            if (block)
                block(false);
            //completion is called on the main thread
            if (tappedActionIndex > -1)
                [self presentAppSettings];
        }];
        
        return;
    }
    
    [self requestPermission:block];
}

+ (void)registerForProvisionalAuthorization:(OSUserResponseBlock)block {
    if ([OSDeviceUtils isIOSVersionGreaterThanOrEqual:@"12.0"])
        [self.osNotificationSettings registerForProvisionalAuthorization:block];
    else
        [OneSignalLog onesignalLog:ONE_S_LL_WARN message:@"registerForProvisionalAuthorization is only available in iOS 12+."];
}

// iOS 12+ only
// A boolean indicating if the app provides its own custom Notifications Settings UI
// If this is set to TRUE via the kOSSettingsKeyProvidesAppNotificationSettings init
// parameter, the SDK will request authorization from the User Notification Center
+ (BOOL)providesAppNotificationSettings {
    return _providesAppNotificationSettings;
}

+ (void)setProvidesNotificationSettingsView:(BOOL)providesView {
    _providesAppNotificationSettings = providesView;
}

//presents the settings page to control/customize push notification settings
+ (void)presentAppSettings {
    
    //only supported in 10+
    if ([OSDeviceUtils isIOSVersionLessThan:@"10.0"])
        return;
    
    let url = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
    
    if (!url)
        return;
    
    if ([[UIApplication sharedApplication] canOpenURL:url]) {
        [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
    } else {
        [OneSignalLog onesignalLog:ONE_S_LL_ERROR message:@"Unable to open settings for this application"];
    }
}

+ (BOOL)registerForAPNsToken {
    if (self.waitingForApnsResponse)
        return true;
    
    id backgroundModes = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"UIBackgroundModes"];
    BOOL backgroundModesEnabled = (backgroundModes && [backgroundModes containsObject:@"remote-notification"]);
    
    // Only try to register for a pushToken if:
    //  - The user accepted notifications
    //  - "Background Modes" > "Remote Notifications" are enabled in Xcode
    if (![self.osNotificationSettings getNotificationPermissionState].accepted && !backgroundModesEnabled)
        return false;
    
    // Don't attempt to register again if there was a non-recoverable error.
    if (mSubscriptionStatus < -9)
        return false;
    
    [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:@"Firing registerForRemoteNotifications"];
    
    self.waitingForApnsResponse = true;
    [OneSignalCoreHelper dispatch_async_on_main_queue:^{
        [[UIApplication sharedApplication] registerForRemoteNotifications];
    }];
    
    return true;
}

//    User just responed to the iOS native notification permission prompt.
//    Also extra calls to registerUserNotificationSettings will fire this without prompting again.
//+ (void)updateNotificationTypes:(int)notificationTypes {
//    [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"updateNotificationTypes called: %d", notificationTypes]];
//    
//    if ([OSDeviceUtils isIOSVersionLessThan:@"10.0"])
//        [OneSignalUserDefaults.initStandard saveBoolForKey:OSUD_WAS_NOTIFICATION_PROMPT_ANSWERED_TO withValue:true];
//    
//    BOOL startedRegister = [OSNotificationsManager registerForAPNsToken];
//    
//    [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"startedRegister: %d", startedRegister]];
//    
//    [self.osNotificationSettings onNotificationPromptResponse:notificationTypes];
//    
//    if (mSubscriptionStatus == -2)
//        return;
//    
////    if (!startedRegister && [self shouldRegisterNow])
////        [self registerUser];
////    else
//    [self sendNotificationTypesUpdate];
//}

//// Updates the server with the new user's notification setting or subscription status changes
//+ (BOOL)sendNotificationTypesUpdate {
//
//    // return if the user has not granted privacy permissions
//    if ([OSPrivacyConsentController shouldLogMissingPrivacyConsentErrorWithMethodName:nil])
//        return false;
//
//    // User changed notification settings for the app.
//    if ([self getNotificationTypes] != -1 && [OneSignalUserManagerImpl currentOneSignalId] && mLastNotificationTypes != [self getNotificationTypes]) {
//        if (!_pushToken) {
//            if ([OSNotificationsManager registerForAPNsToken])
//                return true;
//        }
//
//        mLastNotificationTypes = [self getNotificationTypes];
//
//        //delays observer update until the OneSignal server is notified
//        //shouldDelaySubscriptionUpdate = true;
//
//        [OneSignalClient.sharedClient executeRequest:[OSRequestUpdateNotificationTypes withUserId:[OneSignalUserManagerImpl currentOneSignalId] appId:self.appId notificationTypes:@([self getNotificationTypes])] onSuccess:^(NSDictionary *result) {
//
//            //shouldDelaySubscriptionUpdate = false;
//
//            if (self.currentSubscriptionState.delayedObserverUpdate)
//                [self.currentSubscriptionState setAccepted:[self getNotificationTypes] > 0];
//
//        } onFailure:nil];
//
//        return true;
//    }
//
//    return false;
//}

+ (int)getNotificationTypes {
    [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message: [NSString stringWithFormat:@"getNotificationTypes:mSubscriptionStatus: %d", mSubscriptionStatus]];
    
    if (mSubscriptionStatus < -9)
        return mSubscriptionStatus;
    
    if (OSNotificationsManager.waitingForApnsResponse && !_pushToken)
        return ERROR_PUSH_DELEGATE_NEVER_FIRED;
    
    OSPermissionStateInternal* permissionStatus = [OSNotificationsManager.osNotificationSettings getNotificationPermissionState];
    
    //only return the error statuses if not provisional
    if (!permissionStatus.provisional && !permissionStatus.hasPrompted)
        return ERROR_PUSH_NEVER_PROMPTED;
    
    if (!permissionStatus.provisional && !permissionStatus.answeredPrompt)
        return ERROR_PUSH_PROMPT_NEVER_ANSWERED;
    
    if (self.pushDisabled)
        return -2;

    return permissionStatus.notificationTypes;
}

+ (BOOL)waitingForApnsResponse {
    return _waitingForApnsResponse;
}

+ (void)setWaitingForApnsResponse:(BOOL)value {
    _waitingForApnsResponse = value;
}

+ (void)clearStatics {
    _waitingForApnsResponse = false;
    _currentPermissionState = nil;
    _lastPermissionState = nil;

    // and more...
}

@end
