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

// iOS version implementation
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

+ (void)registerForAPNsToken {
        //TODO: implement
}

+ (void)updateNotificationTypes:(int)notificationTypes {
    //TODO: implement
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
