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

@implementation OSNotificationOpenedResult
@synthesize notification = _notification, action = _action;

- (id)initWithNotification:(OSNotification*)notification action:(OSNotificationAction*)action {
    self = [super init];
    if(self) {
        _notification = notification;
        _action = action;
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
    NSMutableDictionary* action = [NSMutableDictionary new];
    [action setObject:self.action.actionId forKeyedSubscript:@"actionID"];
    [obj setObject:action forKeyedSubscript:@"action"];
    [obj setObject:notifDict forKeyedSubscript:@"notification"];
    if(self.action.type)
        [obj[@"action"] setObject:@(self.action.type) forKeyedSubscript: @"type"];
    
    return obj;
}

@end

@implementation OSNotificationAction
@synthesize type = _type, actionId = _actionId;

-(id)initWithActionType:(OSNotificationActionType)type :(NSString*)actionID {
    self = [super init];
    if(self) {
        _type = type;
        _actionId = actionID;
    }
    return self;
}

@end

@implementation OSNotificationsManager
+ (Class<OSNotifications>)Notifications {
    return self;
}

// UIApplication-registerForRemoteNotifications has been called but a success or failure has not triggered yet.
static BOOL _waitingForApnsResponse = false;
static BOOL _providesAppNotificationSettings = false;
static int mSubscriptionStatus = -1;

static NSMutableArray<OSNotificationOpenedResult*> *_unprocessedOpenedNotifis;
static OSNotificationOpenedBlock _notificationOpenedHandler;
static OSNotificationWillShowInForegroundBlock _notificationWillShowInForegroundHandler;
static NSDictionary* _lastMessageReceived;
static NSString *_lastMessageID = @"";
static NSString *_lastMessageIdFromAction;
static UIBackgroundTaskIdentifier _mediaBackgroundTask;
static BOOL _disableBadgeClearing = NO;

static NSString *_appId;
+ (void)setAppId:(NSString *)appId {
    _appId = appId;
}

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

static BOOL _pushDisabled = false;
+ (void)setPushDisabled:(BOOL)disabled {
    _pushDisabled = disabled;
}


+ (void)resetLocals {
    _lastMessageReceived = nil;
    _lastMessageIdFromAction = nil;
    _lastMessageID = @"";
    _unprocessedOpenedNotifis = nil;
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
    
    if (_pushDisabled)
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

//TODO: move to notifications
static NSString *_lastAppActiveMessageId;
+ (void)setLastAppActiveMessageId:(NSString*)value { _lastAppActiveMessageId = value; }
//TODO: move to notifications
static NSString *_lastnonActiveMessageId;
+ (void)setLastnonActiveMessageId:(NSString*)value { _lastnonActiveMessageId = value; }


//TODO: move to notifications
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
    
    if (!_appId)
        return;
    
    // This method should not continue to be executed for non-OS push notifications
    if (![OneSignalCoreHelper isOneSignalPayload:messageDict]) //TODO: move from oshelper
        return;
    
    [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"notificationReceived called! opened: %@", opened ? @"YES" : @"NO"]];
    
    NSDictionary* customDict = [messageDict objectForKey:@"os_data"] ?: [messageDict objectForKey:@"custom"];
    
    // Should be called first, other methods relay on this global state below.
    //[OneSignalHelper lastMessageReceived:messageDict]; //TODO: move from OShelper
    
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
        //[OneSignalHelper handleIAMPreview:notification]; //setup a notification center notif for this
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
    if (![OneSignalCoreHelper isOneSignalPayload:payload] // TODO: move from OSHelper
        || UIApplication.sharedApplication.applicationState == UIApplicationStateBackground) {
        completion([OSNotification new]);
        return;
    }
    //Only call the willShowInForegroundHandler for notifications not preview IAMs

    OSNotification *osNotification = [OSNotification parseWithApns:payload];
    if ([osNotification additionalData][ONESIGNAL_IAM_PREVIEW]) {
        completion(nil);
        return;
    }
    [self handleWillShowInForegroundHandlerForNotification:osNotification  completion:completion]; // TODO: move from OSHelper
}


+ (void)handleWillShowInForegroundHandlerForNotification:(OSNotification *)notification completion:(OSNotificationDisplayResponse)completion {
    [notification setCompletionBlock:completion];
    if (_notificationWillShowInForegroundHandler) {
        [notification startTimeoutTimer];
        _notificationWillShowInForegroundHandler(notification, [notification getCompletionBlock]);
    } else {
        completion(notification);
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
    //[OneSignal submitNotificationOpened:messageId]; // TODO: either handle here or have UM handle it
    
    let isActive = [UIApplication sharedApplication].applicationState == UIApplicationStateActive;
    
    [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"handleNotificationOpened called! isActive: %@ notificationId: %@",
                                     isActive ? @"YES" : @"NO", messageId]];

    if (![self shouldSuppressURL]) {
        // Try to fetch the open url to launch
        [OneSignal launchWebURL:notification.launchURL]; //TODO: where should this live?
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
//    if (!isActive) { TODO: Figure out session stuff from notif opened
//        OneSignal.appEntryState = NOTIFICATION_CLICK;
//        [[OSSessionManager sharedSessionManager] onDirectInfluenceFromNotificationOpen:_appEntryState withNotificationId:messageId];
//    }

    [self handleNotificationAction:actionType actionID:actionID];
}

+ (BOOL)clearBadgeCount:(BOOL)fromNotifOpened {
    
    NSNumber *disableBadgeNumber = [[NSBundle mainBundle] objectForInfoDictionaryKey:ONESIGNAL_DISABLE_BADGE_CLEARING];
    
    if (disableBadgeNumber)
        _disableBadgeClearing = [disableBadgeNumber boolValue];
    else
        _disableBadgeClearing = NO;
    
    if (_disableBadgeClearing)
        return false;
    
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
//        OSInAppMessageInternal *message = [OSInAppMessageInternal instancePreviewFromNotification:notification];
//        [[OSMessagingController sharedInstance] presentInAppPreviewMessage:message]; //TODO: Post to notification center for IAM to handle
        return YES;
    }
    return NO;
}

+ (void)handleNotificationAction:(OSNotificationActionType)actionType actionID:(NSString*)actionID {
    if (![OneSignalCoreHelper isOneSignalPayload:_lastMessageReceived])
        return;
    
    OSNotificationAction *action = [[OSNotificationAction alloc] initWithActionType:actionType :actionID];
    OSNotification *notification = [OSNotification parseWithApns:_lastMessageReceived];
    OSNotificationOpenedResult *result = [[OSNotificationOpenedResult alloc] initWithNotification:notification action:action];
    
    // Prevent duplicate calls to same action
    if ([notification.notificationId isEqualToString:_lastMessageIdFromAction])
        return;
    _lastMessageIdFromAction = notification.notificationId;
    
    [OneSignalTrackFirebaseAnalytics trackOpenEvent:result];
    
    if (!_notificationOpenedHandler) {
        [self addUnprocessedOpenedNotifi:result];
        return;
    }
    _notificationOpenedHandler(result);
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

+ (void)setNotificationOpenedHandler:(OSNotificationOpenedBlock)block {
    _notificationOpenedHandler = block;
    [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:@"Notification opened handler set successfully"];
    [self fireNotificationOpenedHandlerForUnprocessedEvents];
    
}

+ (void)setNotificationWillShowInForegroundHandler:(OSNotificationWillShowInForegroundBlock _Nullable)block {
    _notificationWillShowInForegroundHandler = block;
    [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:@"Notification will show in foreground handler set successfully"];
}

+ (NSMutableArray<OSNotificationOpenedResult*>*)getUnprocessedOpenedNotifis {
    if (!_unprocessedOpenedNotifis)
        _unprocessedOpenedNotifis = [NSMutableArray new];
    return _unprocessedOpenedNotifis;
}

+ (void)addUnprocessedOpenedNotifi:(OSNotificationOpenedResult*)result {
    [[self getUnprocessedOpenedNotifis] addObject:result];
}

+ (void)fireNotificationOpenedHandlerForUnprocessedEvents {
    if (!_notificationOpenedHandler)
        return;
    
    for (OSNotificationOpenedResult* notification in [self getUnprocessedOpenedNotifis]) {
        _notificationOpenedHandler(notification);
    }
    _unprocessedOpenedNotifis = [NSMutableArray new];
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

