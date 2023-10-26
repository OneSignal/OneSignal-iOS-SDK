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
#import <UserNotifications/UserNotifications.h>
#import "OSNotification+OneSignal.h"
#import <OneSignalExtension/OneSignalAttachmentHandler.h>
#import "OneSignalWebViewManager.h"
#import "UNUserNotificationCenter+OneSignalNotifications.h"
#import "UIApplicationDelegate+OneSignalNotifications.h"
#import <OneSignalOutcomes/OSSessionManager.h>

@implementation OSNotificationClickEvent
@synthesize notification = _notification, result = _result;

- (id)initWithNotification:(OSNotification*)notification result:(OSNotificationClickResult*)result {
    self = [super init];
    if(self) {
        _notification = notification;
        _result = result;
    }
    return self;
}

- (NSString*)stringify {
    NSError * err;
    NSDictionary *jsonDictionary = [self jsonRepresentation];
    NSData * jsonData = [NSJSONSerialization  dataWithJSONObject:jsonDictionary options:0 error:&err];
    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}

// Convert the class into a NSDictionary
- (NSDictionary *_Nonnull)jsonRepresentation {
    NSError * jsonError = nil;
    NSData *objectData = [[self.notification stringify] dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *notifDict = [NSJSONSerialization JSONObjectWithData:objectData
                                                              options:NSJSONReadingMutableContainers
                                                                error:&jsonError];
    
    NSMutableDictionary* obj = [NSMutableDictionary new];
    NSMutableDictionary* result = [NSMutableDictionary new];
    [result setObject:self.result.actionId forKeyedSubscript:@"actionID"];
    [result setObject:self.result.url forKeyedSubscript:@"url"];
    [obj setObject:result forKeyedSubscript:@"result"];
    [obj setObject:notifDict forKeyedSubscript:@"notification"];

    return obj;
}

@end

@implementation OSNotificationClickResult
@synthesize url = _url, actionId = _actionId;

-(id)initWithUrl:(NSString*)url :(NSString*)actionID {
    self = [super init];
    if(self) {
        _url = url;
        _actionId = actionID;
    }
    return self;
}

@end

@interface OSDisplayableNotification ()
- (void)startTimeoutTimer;
- (void)setCompletionBlock:(OSNotificationDisplayResponse)completion;
- (void)complete:(OSDisplayableNotification *)notification;
- (BOOL)wantsToDisplay;
- (void)setWantsToDisplay:(BOOL)display;
@end

@implementation OSNotificationWillDisplayEvent

- (id)initWithDisplayableNotification:(OSDisplayableNotification*)notification {
    self = [super init];
    if(self) {
        _notification = notification;
    }
    return self;
}

- (BOOL)isPreventDefault {
    return !_notification.wantsToDisplay;
}

- (void)preventDefault {
    [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"OSNotificationWillDisplayEvent.preventDefault called."]];
    _notification.wantsToDisplay = false;
}

@end

@implementation OSNotificationsManager

+ (Class<OSNotifications>)Notifications {
    return self;
}

static id<OneSignalNotificationsDelegate> _delegate;
+ (id<OneSignalNotificationsDelegate>)delegate {
    return _delegate;
}
+(void)setDelegate:(id<OneSignalNotificationsDelegate>)delegate {
    _delegate = delegate;
}

static NSMutableArray<NSObject<OSNotificationLifecycleListener> *> *_lifecycleListeners;
+ (NSMutableArray<NSObject<OSNotificationLifecycleListener> *>*)lifecycleListeners {
    if (!_lifecycleListeners)
        _lifecycleListeners = [NSMutableArray new];
    return _lifecycleListeners;
}

// UIApplication-registerForRemoteNotifications has been called but a success or failure has not triggered yet.
static BOOL _waitingForApnsResponse = false;
static BOOL _providesAppNotificationSettings = false;
BOOL requestedProvisionalAuthorization = false;

static int mSubscriptionStatus = -1;

static NSMutableArray<OSNotificationClickEvent*> *_unprocessedClickEvents;
static NSMutableArray<NSObject<OSNotificationClickListener> *> *_clickListeners;
+ (NSMutableArray<NSObject<OSNotificationClickListener> *>*)clickListeners {
    if (!_clickListeners)
        _clickListeners = [NSMutableArray new];
    return _clickListeners;
}

static NSDictionary* _lastMessageReceived;
static NSString *_lastMessageID = @"";
static NSString *_lastMessageIdFromAction;
static UIBackgroundTaskIdentifier _mediaBackgroundTask;
static BOOL _disableBadgeClearing = NO;


static BOOL _coldStartFromTapOnNotification = NO;
// Set to false as soon as it's read.
+ (BOOL)getColdStartFromTapOnNotification {
    BOOL val = _coldStartFromTapOnNotification;
    _coldStartFromTapOnNotification = NO;
    return val;
}
+ (void)setColdStartFromTapOnNotification:(BOOL)coldStartFromTapOnNotification {
    _coldStartFromTapOnNotification = coldStartFromTapOnNotification;
}

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

// static property def to add developer's OSPermissionStateChanges observers to.
static ObservablePermissionStateChangesType* _permissionStateChangesObserver;
+ (ObservablePermissionStateChangesType*)permissionStateChangesObserver {
    if (!_permissionStateChangesObserver)
        _permissionStateChangesObserver = [[OSBoolObservable alloc] initWithChangeSelector:@selector(onNotificationPermissionDidChange:)];
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

// TODO: pushToken, pushSubscriptionId needs to be available... is this the right setup
static NSString *_pushToken;
+ (NSString*)pushToken {
    if (!_pushToken) {
        _pushToken = [OneSignalUserDefaults.initShared getSavedStringForKey:OSUD_PUSH_TOKEN defaultValue:nil];
    }
    return _pushToken;
}

static NSString *_pushSubscriptionId;
+ (NSString*)pushSubscriptionId {
    if (!_pushSubscriptionId) {
        _pushSubscriptionId = [OneSignalUserDefaults.initShared getSavedStringForKey:OSUD_PUSH_SUBSCRIPTION_ID defaultValue:nil];
    }
    return _pushSubscriptionId;
}
+ (void)setPushSubscriptionId:(NSString *)pushSubscriptionId {
    _pushSubscriptionId = pushSubscriptionId;
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
+ (void)start {
    // Swizzle - UIApplication delegate
    //TODO: do the equivalent in the notificaitons module
    injectSelector(
        [UIApplication class],
        @selector(setDelegate:),
        [OneSignalNotificationsAppDelegate class],
        @selector(setOneSignalDelegate:)
   );
    //TODO: This swizzling is done from notifications module
    injectSelector(
        [UIApplication class],
        @selector(setApplicationIconBadgeNumber:),
        [OneSignalNotificationsAppDelegate class],
        @selector(onesignalSetApplicationIconBadgeNumber:)
    );
    [OneSignalNotificationsUNUserNotificationCenter setup];
}
#pragma clang diagnostic pop

+ (void)resetLocals {
    _lastMessageReceived = nil;
    _lastMessageIdFromAction = nil;
    _lastMessageID = @"";
    _unprocessedClickEvents = nil;
}

+ (void)setLastPermissionState:(OSPermissionStateInternal *)lastPermissionState {
    _lastPermissionState = lastPermissionState;
}

+ (BOOL)permission {
    return self.currentPermissionState.reachable;
}

+ (BOOL)canRequestPermission {
    return !self.currentPermissionState.answeredPrompt;
}

+ (OSNotificationPermission)permissionNative {
    return self.currentPermissionState.status;
}

+ (void)requestPermission:(OSUserResponseBlock)block {
    // return if the user has not granted privacy permissions
    if ([OSPrivacyConsentController shouldLogMissingPrivacyConsentErrorWithMethodName:@"requestPermission:"])
        return;
    
    [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"requestPermission Called"]];
    
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

// Checks to see if we should register for APNS' new Provisional authorization
// (also known as Direct to History).
// This behavior is determined by the OneSignal Parameters request
+ (void)checkProvisionalAuthorizationStatus {
    if ([OSPrivacyConsentController shouldLogMissingPrivacyConsentErrorWithMethodName:nil])
        return;
    
    BOOL usesProvisional = [OneSignalUserDefaults.initStandard getSavedBoolForKey:OSUD_USES_PROVISIONAL_PUSH_AUTHORIZATION defaultValue:false];
    
    // if iOS parameters for this app have never downloaded, this method
    // should return
    if (!usesProvisional || requestedProvisionalAuthorization)
        return;
    
    requestedProvisionalAuthorization = true;
    
    [self.osNotificationSettings registerForProvisionalAuthorization:nil];
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

+ (void)clearAll {
    [[UNUserNotificationCenter currentNotificationCenter] removeAllDeliveredNotifications];
    // TODO: Determine if we also need to call clearBadgeCount
    [self clearBadgeCount:false];
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

+ (void)didRegisterForRemoteNotifications:(UIApplication *)app
                              deviceToken:(NSData *)inDeviceToken {
    let parsedDeviceToken = [NSString hexStringFromData:inDeviceToken];

    [OneSignalLog onesignalLog:ONE_S_LL_INFO message: [NSString stringWithFormat:@"Device Registered with Apple: %@", parsedDeviceToken]];

    if (!parsedDeviceToken) {
        [OneSignalLog onesignalLog:ONE_S_LL_ERROR message:@"Unable to convert APNS device token to a string"];
        return;
    }

    self.waitingForApnsResponse = false;

    _pushToken = parsedDeviceToken;
    
    // Cache push token
    [OneSignalUserDefaults.initShared saveStringForKey:OSUD_PUSH_TOKEN withValue:_pushToken];

    [self sendPushTokenToDelegate];
}

+ (void)handleDidFailRegisterForRemoteNotification:(NSError*)err {
    OSNotificationsManager.waitingForApnsResponse = false;
    
    if (err.code == 3000) {
        [self setSubscriptionErrorStatus:ERROR_PUSH_CAPABLILITY_DISABLED];
        [OneSignalLog onesignalLog:ONE_S_LL_ERROR message:@"ERROR! 'Push Notifications' capability missing! Add the capability in Xcode under 'Target' -> '<MyAppName(MainTarget)>' -> 'Signing & Capabilities' then click the '+ Capability' button."];
    }
    else if (err.code == 3010) {
        [self setSubscriptionErrorStatus:ERROR_PUSH_SIMULATOR_NOT_SUPPORTED];
        [OneSignalLog onesignalLog:ONE_S_LL_ERROR message:[NSString stringWithFormat:@"Error! iOS Simulator does not support push! Please test on a real iOS device. Error: %@", err]];
    }
    else {
        [self setSubscriptionErrorStatus:ERROR_PUSH_UNKNOWN_APNS_ERROR];
        [OneSignalLog onesignalLog:ONE_S_LL_ERROR message:[NSString stringWithFormat:@"Error registering for Apple push notifications! Error: %@", err]];
    }
}

+ (void)sendPushTokenToDelegate {
    // TODO: Keep this as a check on _pushToken instead of self.pushToken?
    if (_pushToken != nil && self.delegate && [self.delegate respondsToSelector:@selector(setPushToken:)]) {
        [self.delegate setPushToken:_pushToken];
    }
}

+ (void)setSubscriptionErrorStatus:(int)errorType {
    [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message: [NSString stringWithFormat:@"setSubscriptionErrorStatus: %d", errorType]];
    
    mSubscriptionStatus = errorType;
    [self sendNotificationTypesUpdateToDelegate];
}

// onNotificationPermissionDidChange should only fire if the reachable property changed.
+ (void)addPermissionObserver:(NSObject<OSNotificationPermissionObserver>*)observer {
    [self.permissionStateChangesObserver addObserver:observer];
    
    if (self.currentPermissionState.reachable != self.lastPermissionState.reachable)
        [OSPermissionChangedInternalObserver fireChangesObserver:self.currentPermissionState];
}

+ (void)removePermissionObserver:(NSObject<OSNotificationPermissionObserver>*)observer {
    [self.permissionStateChangesObserver removeObserver:observer];
}

//    User just responed to the iOS native notification permission prompt.
+ (void)updateNotificationTypes:(int)notificationTypes {
    [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"updateNotificationTypes called: %d", notificationTypes]];
    
    // TODO: Dropped support, can remove below?
    if ([OSDeviceUtils isIOSVersionLessThan:@"10.0"])
        [OneSignalUserDefaults.initStandard saveBoolForKey:OSUD_WAS_NOTIFICATION_PROMPT_ANSWERED_TO withValue:true];
    
    BOOL startedRegister = [OSNotificationsManager registerForAPNsToken];
    
    [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"startedRegister: %d", startedRegister]];
    
    // TODO: Dropped support, can remove below?
    [self.osNotificationSettings onNotificationPromptResponse:notificationTypes]; // iOS 9 only
    
    // TODO: This can be called before the User Manager sets itself as the delegate
    [self sendNotificationTypesUpdateToDelegate];
}

+ (void)sendNotificationTypesUpdateToDelegate {
    // We don't delay observer update to wait until the OneSignal server is notified
    // TODO: We can do the above and delay observers until server is updated.
    if (self.delegate && [self.delegate respondsToSelector:@selector(setNotificationTypes:)]) {
        [self.delegate setNotificationTypes:[self getNotificationTypes]];
    }
}

// Accounts for manual disabling by the app developer
+ (int)getNotificationTypes:(BOOL)pushDisabled {
    if (pushDisabled) {
        return -2;
    }
    
    return [self getNotificationTypes];
}

// Device notification types, that doesn't account for manual disabling by the app developer
+ (int)getNotificationTypes {
    [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message: [NSString stringWithFormat:@"getNotificationTypes:mSubscriptionStatus: %d", mSubscriptionStatus]];
    
    if (mSubscriptionStatus < -9)
        return mSubscriptionStatus;
    
    // This was previously nil if just accessing _pushToken
    if (OSNotificationsManager.waitingForApnsResponse && !self.pushToken)
        return ERROR_PUSH_DELEGATE_NEVER_FIRED;
    
    OSPermissionStateInternal* permissionStatus = [OSNotificationsManager.osNotificationSettings getNotificationPermissionState];
    
    //only return the error statuses if not provisional
    if (!permissionStatus.provisional && !permissionStatus.hasPrompted)
        return ERROR_PUSH_NEVER_PROMPTED;
    
    if (!permissionStatus.provisional && !permissionStatus.answeredPrompt)
        return ERROR_PUSH_PROMPT_NEVER_ANSWERED;

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
    requestedProvisionalAuthorization = false;

    // and more...
}

static NSString *_lastAppActiveMessageId;
+ (void)setLastAppActiveMessageId:(NSString*)value { _lastAppActiveMessageId = value; }
static NSString *_lastnonActiveMessageId;
+ (void)setLastnonActiveMessageId:(NSString*)value { _lastnonActiveMessageId = value; }


// Entry point for the following:
//  - 1. (iOS all) - Opening notifications
//  - 2. Notification received
//    - 2A. iOS 9  - Notification received while app is in focus.
//    - 2B. iOS 10 - Notification received/displayed while app is in focus.
// isActive is not always true for when the application is on foreground, we need differentiation
// between foreground and isActive
+ (void)notificationReceived:(NSDictionary*)messageDict wasOpened:(BOOL)opened {
    if ([OSPrivacyConsentController shouldLogMissingPrivacyConsentErrorWithMethodName:nil])
        return;
    
    if (![OneSignalConfigManager getAppId]) {
        return;
    }
    
    // This method should not continue to be executed for non-OS push notifications
    if (![OneSignalCoreHelper isOneSignalPayload:messageDict])
        return;
    
    [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"notificationReceived called! opened: %@", opened ? @"YES" : @"NO"]];
    
    NSDictionary* customDict = [messageDict objectForKey:@"os_data"] ?: [messageDict objectForKey:@"custom"];
    
    // Should be called first, other methods relay on this global state below.
    [self lastMessageReceived:messageDict];
    
    BOOL isPreview = [[OSNotification parseWithApns:messageDict] additionalData][ONESIGNAL_IAM_PREVIEW] != nil;

    if (opened) {
        // Prevent duplicate calls
        let newId = [self checkForProcessedDups:customDict lastMessageId:_lastnonActiveMessageId];
        if ([@"dup" isEqualToString:newId]) {
            [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:@"Duplicate notif received. Not calling opened handler."];
            return;
        }
        if (newId)
            _lastnonActiveMessageId = newId;
        //app was in background / not running and opened due to a tap on a notification or an action check what type
        OSNotificationActionType type = OSNotificationActionTypeOpened;

        if (messageDict[@"custom"][@"a"][@"actionSelected"] || messageDict[@"actionSelected"])
            type = OSNotificationActionTypeActionTaken;

        // Call Action Block
        [self handleNotificationOpened:messageDict actionType:type];
    } else if (isPreview && [OSDeviceUtils isIOSVersionGreaterThanOrEqual:@"10.0"]) {
        let notification = [OSNotification parseWithApns:messageDict];
        [self handleIAMPreview:notification];
    }
}

+ (NSString*)checkForProcessedDups:(NSDictionary*)customDict lastMessageId:(NSString*)lastMessageId {
    if (customDict && customDict[@"i"]) {
        NSString* currentNotificationId = customDict[@"i"];
        if ([currentNotificationId isEqualToString:lastMessageId])
            return @"dup";
        return customDict[@"i"];
    }
    return nil;
}

+ (void)handleWillPresentNotificationInForegroundWithPayload:(NSDictionary *)payload withCompletion:(OSNotificationDisplayResponse)completion {
    // check to make sure the app is in focus and it's a OneSignal notification
    if (![OneSignalCoreHelper isOneSignalPayload:payload]
        || UIApplication.sharedApplication.applicationState == UIApplicationStateBackground) {
        completion([OSNotification new]);
        return;
    }
    //Only call the OSNotificationLifecycleListener for notifications not preview IAMs

    OSDisplayableNotification *osNotification = [OSDisplayableNotification parseWithApns:payload];
    if ([osNotification additionalData][ONESIGNAL_IAM_PREVIEW]) {
        completion(nil);
        return;
    }
    [self handleWillShowInForegroundForNotification:osNotification completion:completion];
}

+ (void)handleWillShowInForegroundForNotification:(OSDisplayableNotification *)notification completion:(OSNotificationDisplayResponse)completion {
    [notification setCompletionBlock:completion];
    if (self.lifecycleListeners.count == 0) {
        completion(notification);
        return;
    }
    
    [notification startTimeoutTimer];
    OSNotificationWillDisplayEvent *event = [[OSNotificationWillDisplayEvent alloc] initWithDisplayableNotification:notification];
    
    for (NSObject<OSNotificationLifecycleListener> *listener in self.lifecycleListeners) {
        if ([listener respondsToSelector:@selector(onWillDisplayNotification:)]) {
            [listener onWillDisplayNotification:event];
        }
    }

    if (![event isPreventDefault]) {
        [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"OSNotificationWillDisplayEvent's preventDefault not called, now display notification with notificationId %@.", notification.notificationId]];
        [notification complete:notification];
    }
}

+ (void)handleNotificationOpened:(NSDictionary*)messageDict
                      actionType:(OSNotificationActionType)actionType {
    
    // return if the user has not granted privacy permissions
    if ([OSPrivacyConsentController shouldLogMissingPrivacyConsentErrorWithMethodName:@"handleNotificationOpened:actionType:"])
        return;

    OSNotification *notification = [OSNotification parseWithApns:messageDict];
    if ([self handleIAMPreview:notification])
        return;

    NSDictionary* customDict = [messageDict objectForKey:@"custom"] ?: [messageDict objectForKey:@"os_data"];
    // Notify backend that user opened the notification
    NSString* messageId = [customDict objectForKey:@"i"];
    [self submitNotificationOpened:messageId];
    
    let isActive = [UIApplication sharedApplication].applicationState == UIApplicationStateActive;
    
    [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"handleNotificationOpened called! isActive: %@ notificationId: %@",
                                     isActive ? @"YES" : @"NO", messageId]];

    if (![self shouldSuppressURL]) {
        // Try to fetch the open url to launch
        [self launchWebURL:notification.launchURL]; //TODO: where should this live?
    }
        
    [self clearBadgeCount:true];
    
    NSString* actionID = NULL;
    if (actionType == OSNotificationActionTypeActionTaken) {
        actionID = messageDict[@"custom"][@"a"][@"actionSelected"];
        if(!actionID)
            actionID = messageDict[@"actionSelected"];
    }
    
    // Call Action Block
    [self lastMessageReceived:messageDict];
    if (!isActive) {
        OSSessionManager.sharedSessionManager.appEntryState = NOTIFICATION_CLICK;
        [[OSSessionManager sharedSessionManager] onDirectInfluenceFromNotificationOpen:NOTIFICATION_CLICK withNotificationId:messageId];
    }

    [self handleNotificationActionWithUrl:notification.launchURL actionID:actionID];
}

+ (void)submitNotificationOpened:(NSString*)messageId {
    // return if the user has not granted privacy permissions
    if ([OSPrivacyConsentController shouldLogMissingPrivacyConsentErrorWithMethodName:nil])
        return;
    
    let standardUserDefaults = OneSignalUserDefaults.initStandard;
    //(DUPLICATE Fix): Make sure we do not upload a notification opened twice for the same messageId
    //Keep track of the Id for the last message sent
    NSString* lastMessageId = [standardUserDefaults getSavedStringForKey:OSUD_LAST_MESSAGE_OPENED defaultValue:nil];
    //Only submit request if messageId not nil and: (lastMessage is nil or not equal to current one)
    if(messageId && (!lastMessageId || ![lastMessageId isEqualToString:messageId])) {
        [OneSignalClient.sharedClient executeRequest:[OSRequestSubmitNotificationOpened withUserId:[self pushSubscriptionId]
                                                                                             appId:[OneSignalConfigManager getAppId]
                                                                                         wasOpened:YES
                                                                                         messageId:messageId
                                                                                    withDeviceType:[NSNumber numberWithInt:DEVICE_TYPE_PUSH]]
                                           onSuccess:nil
                                           onFailure:nil];
        [standardUserDefaults saveStringForKey:OSUD_LAST_MESSAGE_OPENED withValue:messageId];
    }
}

+ (void)launchWebURL:(NSString*)openUrl {
    
    NSString* toOpenUrl = [OneSignalCoreHelper trimURLSpacing:openUrl];
    
    if (toOpenUrl && [OneSignalCoreHelper verifyURL:toOpenUrl]) {
        NSURL *url = [NSURL URLWithString:toOpenUrl];
        // Give the app resume animation time to finish when tapping on a notification from the notification center.
        // Isn't a requirement but improves visual flow.
        [self performSelector:@selector(displayWebView:) withObject:url afterDelay:0.5];
    }
    
}

+ (void)displayWebView:(NSURL*)url {
    __block let openUrlBlock = ^void(BOOL shouldOpen) {
        if (!shouldOpen)
            return;
        
        [OneSignalCoreHelper dispatch_async_on_main_queue: ^{
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                // Keep dispatch_async. Without this the url can take an extra 2 to 10 secounds to open.
                [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
            });
        }];
    };
    openUrlBlock(true);
}

+ (BOOL)clearBadgeCount:(BOOL)fromNotifOpened {
    
    NSNumber *disableBadgeNumber = [[NSBundle mainBundle] objectForInfoDictionaryKey:ONESIGNAL_DISABLE_BADGE_CLEARING];
    
    if (disableBadgeNumber)
        _disableBadgeClearing = [disableBadgeNumber boolValue];
    else
        _disableBadgeClearing = NO;
    
    if (_disableBadgeClearing) {
        // The customer could have manually changed the badge value. We must ensure our cached value will match the current state.
        [OneSignalUserDefaults.initShared saveIntegerForKey:ONESIGNAL_BADGE_KEY withValue:[UIApplication sharedApplication].applicationIconBadgeNumber];
        return false;
    }
    
    bool wasBadgeSet = [UIApplication sharedApplication].applicationIconBadgeNumber > 0;
    
    if (fromNotifOpened || wasBadgeSet) {
        [OneSignalCoreHelper runOnMainThread:^{
            [[UIApplication sharedApplication] setApplicationIconBadgeNumber:0];
        }];
    }

    return wasBadgeSet;
}

+ (BOOL)handleIAMPreview:(OSNotification *)notification {
    NSString *uuid = [notification additionalData][ONESIGNAL_IAM_PREVIEW];
    if (uuid) {
        [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:@"IAM Preview Detected, Begin Handling"];
        NSDictionary *userInfo = [NSDictionary dictionaryWithObject:notification forKey:@"notification"];
        [[NSNotificationCenter defaultCenter] postNotificationName:ONESIGNAL_POST_PREVIEW_IAM object:nil userInfo:userInfo];
        return YES;
    }
    return NO;
}

+ (void)handleNotificationActionWithUrl:(NSString*)url actionID:(NSString*)actionID {
    if (![OneSignalCoreHelper isOneSignalPayload:_lastMessageReceived])
        return;
    
    OSNotificationClickResult *result = [[OSNotificationClickResult alloc] initWithUrl:url :actionID];
    OSNotification *notification = [OSNotification parseWithApns:_lastMessageReceived];
    OSNotificationClickEvent *event = [[OSNotificationClickEvent alloc] initWithNotification:notification result:result];
    
    // Prevent duplicate calls to same action
    if ([notification.notificationId isEqualToString:_lastMessageIdFromAction])
        return;
    _lastMessageIdFromAction = notification.notificationId;
    
    [OneSignalTrackFirebaseAnalytics trackOpenEvent:event];
  
    if (self.clickListeners.count == 0) {
        [self addUnprocessedClickEvent:event];
        return;
    }
    [self fireClickListenersForEvent:event];
}

+ (void)fireClickListenersForEvent:(OSNotificationClickEvent*)event {
    for (NSObject<OSNotificationClickListener> *listener in self.clickListeners) {
        if ([listener respondsToSelector:@selector(onClickNotification:)]) {
            [listener onClickNotification:event];
        }
    }
}

+ (void)lastMessageReceived:(NSDictionary*)message {
    _lastMessageReceived = message;
}

+ (BOOL)shouldSuppressURL {
    // if the plist key does not exist default to false
    // the plist value specifies whether the user wants to open an url using default browser or OSWebView
    NSDictionary *bundleDict = [[NSBundle mainBundle] infoDictionary];
    BOOL shouldSuppress = [bundleDict[ONESIGNAL_SUPRESS_LAUNCH_URLS] boolValue];
    return shouldSuppress ?: false;
}

+ (void)addClickListener:(NSObject<OSNotificationClickListener>*)listener {
    [self.clickListeners addObject:listener];
    [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:@"Notification click listener added successfully"];
    [self fireClickListenersForUnprocessedEvents];
}

+ (void)removeClickListener:(NSObject<OSNotificationClickListener>*)listener {
    [self.clickListeners removeObject:listener];
    [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:@"Notification click listener removed successfully"];
}

+ (void)addForegroundLifecycleListener:(NSObject<OSNotificationLifecycleListener> *_Nullable)listener {
    [self.lifecycleListeners addObject:listener];
    [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:@"ForegroundLifecycleListener added successfully"];
}

+ (void)removeForegroundLifecycleListener:(NSObject<OSNotificationLifecycleListener> * _Nullable)listener {
    [self.lifecycleListeners removeObject:listener];
    [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:@"ForegroundLifecycleListener removed successfully"];
}

+ (NSMutableArray<OSNotificationClickEvent*>*)getUnprocessedClickEvents {
    if (!_unprocessedClickEvents)
        _unprocessedClickEvents = [NSMutableArray new];
    return _unprocessedClickEvents;
}

+ (void)addUnprocessedClickEvent:(OSNotificationClickEvent*)event {
    [[self getUnprocessedClickEvents] addObject:event];
}

+ (void)fireClickListenersForUnprocessedEvents {
    if (self.clickListeners.count == 0) {
        return;
    }
    for (OSNotificationClickEvent* event in [self getUnprocessedClickEvents]) {
        [self fireClickListenersForEvent:event];
    }
    _unprocessedClickEvents = [NSMutableArray new];
}

+ (BOOL)receiveRemoteNotification:(UIApplication*)application UserInfo:(NSDictionary*)userInfo completionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
   var startedBackgroundJob = false;
   
   NSDictionary* richData = nil;
   // TODO: Look into why the userInfo payload would be different here for displaying vs opening....
   // Check for buttons or attachments pre-2.4.0 version
   if ((userInfo[@"os_data"][@"buttons"] && [userInfo[@"os_data"][@"buttons"] isKindOfClass:[NSDictionary class]]) || userInfo[@"at"] || userInfo[@"o"])
       richData = userInfo;

   // Generate local notification for action button and/or attachments.
   if (richData) {
       let osNotification = [OSNotification parseWithApns:userInfo];
       
       if ([OSDeviceUtils isIOSVersionGreaterThanOrEqual:@"10.0"]) {
           startedBackgroundJob = true;
           [self addNotificationRequest:osNotification completionHandler:completionHandler];
       }
   }
   // Method was called due to a tap on a notification - Fire open notification
   else if (application.applicationState == UIApplicationStateActive) {
       _lastMessageReceived = userInfo;

       if ([OneSignalCoreHelper isDisplayableNotification:userInfo]) {
            [self notificationReceived:userInfo wasOpened:YES];
       }
       return startedBackgroundJob;
   }
   // content-available notification received in the background
   else {
       _lastMessageReceived = userInfo;
   }
   
   return startedBackgroundJob;
}

+ (void)addNotificationRequest:(OSNotification*)notification
             completionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
    
    // Start background thread to download media so we don't lock the main UI thread.
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self beginBackgroundMediaTask];
        
        let notificationRequest = [self prepareUNNotificationRequest:notification];
        [[UNUserNotificationCenter currentNotificationCenter]
         addNotificationRequest:notificationRequest
         withCompletionHandler:^(NSError * _Nullable error) {}];
        if (completionHandler)
            completionHandler(UIBackgroundFetchResultNewData);
        
        [self endBackgroundMediaTask];
    });

}

+ (void)beginBackgroundMediaTask {
    _mediaBackgroundTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [self endBackgroundMediaTask];
    }];
}

+ (void)endBackgroundMediaTask {
    [[UIApplication sharedApplication] endBackgroundTask: _mediaBackgroundTask];
    _mediaBackgroundTask = UIBackgroundTaskInvalid;
}

+ (UNNotificationRequest*)prepareUNNotificationRequest:(OSNotification*)notification {
    let content = [UNMutableNotificationContent new];
    
    [OneSignalAttachmentHandler addActionButtons:notification toNotificationContent:content];
    
    content.title = notification.title;
    content.subtitle = notification.subtitle;
    content.body = notification.body;
    
    content.userInfo = notification.rawPayload;
    
    if (notification.sound)
        content.sound = [UNNotificationSound soundNamed:notification.sound];
    else
        content.sound = UNNotificationSound.defaultSound;
    
    if (notification.badge != 0)
        content.badge = [NSNumber numberWithInteger:notification.badge];
    
    // Check if media attached
    [OneSignalAttachmentHandler addAttachments:notification toNotificationContent:content];
    
    let trigger = [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:0.25 repeats:NO];
    let identifier = [OneSignalCoreHelper randomStringWithLength:16];
    return [UNNotificationRequest requestWithIdentifier:identifier content:content trigger:trigger];
}


@end

