/**
 * Modified MIT License
 *
 * Copyright 2016 OneSignal
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

#import "OneSignal.h"
#import "OneSignalTracker.h"
#import "OneSignalHTTPClient.h"
#import "OneSignalTrackIAP.h"
#import "OneSignalLocation.h"
#import "OneSignalReachability.h"
#import "OneSignalJailbreakDetection.h"
#import "OneSignalMobileProvision.h"
#import "OneSignalAlertViewDelegate.h"
#import "OneSignalHelper.h"
#import "UNUserNotificationCenter+OneSignal.h"
#import "OneSignalSelectorHelpers.h"
#import "UIApplicationDelegate+OneSignal.h"
#import "NSString+OneSignal.h"

#import "OneSignalNotificationSettings.h"
#import "OneSignalNotificationSettingsIOS10.h"
#import "OneSignalNotificationSettingsIOS8.h"
#import "OneSignalNotificationSettingsIOS7.h"

#import <stdlib.h>
#import <stdio.h>
#import <sys/types.h>
#import <sys/utsname.h>
#import <sys/sysctl.h>
#import <objc/runtime.h>
#import <UIKit/UIKit.h>


#ifdef XC8_AVAILABLE
#import <UserNotifications/UserNotifications.h>
#endif


#define NOTIFICATION_TYPE_NONE 0
#define NOTIFICATION_TYPE_BADGE 1
#define NOTIFICATION_TYPE_SOUND 2
#define NOTIFICATION_TYPE_ALERT 4
#define NOTIFICATION_TYPE_ALL 7

#define ERROR_PUSH_CAPABLILITY_DISABLED    -13
#define ERROR_PUSH_DELEGATE_NEVER_FIRED    -14
#define ERROR_PUSH_SIMULATOR_NOT_SUPPORTED -15
#define ERROR_PUSH_UNKOWN_APNS_ERROR       -16
#define ERROR_PUSH_OTHER_3000_ERROR        -17
#define ERROR_PUSH_NEVER_PROMPTED          -18
#define ERROR_PUSH_PROMPT_NEVER_ANWSERED   -19

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

static ONE_S_LOG_LEVEL _nsLogLevel = ONE_S_LL_WARN;
static ONE_S_LOG_LEVEL _visualLogLevel = ONE_S_LL_NONE;

NSString* const kOSSettingsKeyAutoPrompt = @"kOSSettingsKeyAutoPrompt";

/* Enable the default in-app alerts*/
NSString* const kOSSettingsKeyInAppAlerts = @"kOSSettingsKeyInAppAlerts";

/* Enable the default in-app launch urls*/
NSString* const kOSSettingsKeyInAppLaunchURL = @"kOSSettingsKeyInAppLaunchURL";

/* Set InFocusDisplayOption value must be an OSNotificationDisplayType enum*/
NSString* const kOSSettingsKeyInFocusDisplayOption = @"kOSSettingsKeyInFocusDisplayOption";

/* Omit no app_id error logging, for use with wrapper SDKs. */
NSString* const kOSSettingsKeyInOmitNoAppIdLogging = @"kOSSettingsKeyInOmitNoAppIdLogging";


@implementation OSPermissionStatus
// Override Getters
// Returns logical turths so the comsumer of the object don't have to check more than one property

- (BOOL) hasPrompted {
    // If we know they anwsered turned notificaitons on then were prompted at some point.
    if (self.anwseredPrompt) // self. calls getter method below
        return true;
    return _hasPrompted;
}

- (BOOL) anwseredPrompt {
    // If we got an accepted permission then they anwsered the prompt.
    if (_accepted)
        return true;
    return _anwseredPrompt;
}

@end

@interface OSPendingCallbacks : NSObject
 @property OSResultSuccessBlock successBlock;
 @property OSFailureBlock failureBlock;
@end

@implementation OSPendingCallbacks
@end

@implementation OneSignal

NSString* const ONESIGNAL_VERSION = @"020403";
static NSString* mSDKType = @"native";
static BOOL coldStartFromTapOnNotification = NO;

static NSMutableArray* pendingSendTagCallbacks;

// Has attempted to register for push notifications with Apple since app was installed.
static BOOL registeredWithApple = NO;

// UIApplication-registerForRemoteNotifications has been called but a success or failure has not triggered yet.
static BOOL waitingForApnsResponse = false;

// Under Capabilities is "Background Modes" > "Remote notifications" enabled.
static BOOL backgroundModesEnabled = false;

static OneSignalTrackIAP* trackIAPPurchase;
static NSString* app_id;
NSString* emailToSet;
NSMutableDictionary* tagsToSend;
NSString* mUserId;
NSString* mDeviceToken;
OneSignalHTTPClient *httpClient;
OSResultSuccessBlock tokenUpdateSuccessBlock;
OSFailureBlock tokenUpdateFailureBlock;

int mLastNotificationTypes = -1;
static int mSubscriptionStatus = -1;

OSIdsAvailableBlock idsAvailableBlockWhenReady;
BOOL disableBadgeClearing = NO;
BOOL mSubscriptionSet;
BOOL mShareLocation = YES;

NSObject<OneSignalNotificationSettings>* osNotificationSettings;

+ (void) setMSubscriptionStatus:(NSNumber*)status {
    mSubscriptionStatus = [status intValue];
}
    
+ (NSString*)app_id {
    return app_id;
}

+ (NSString*)sdk_version_raw {
	return ONESIGNAL_VERSION;
}

+ (NSString*)sdk_semantic_version {

	// examples:
	// ONESIGNAL_VERSION = @"020402" returns 2.4.2
	// ONESIGNAL_VERSION = @"001000" returns 0.10.0
	// so that's 6 digits, where the first two are the major version
	// the second two are the minor version and that last two, the patch.
	// c.f. http://semver.org/

	return [ONESIGNAL_VERSION one_getSemanticVersion];
}

+ (NSString*)mUserId {
    return mUserId;
}

+ (void) setMSDKType:(NSString*)type {
    mSDKType = type;
}

+ (NSString*)getDeviceToken {
    return mDeviceToken;
}

+ (void) setWaitingForApnsResponse:(BOOL)value {
    waitingForApnsResponse = value;
}

+(void)clearStatics {
    osNotificationSettings = nil;
    waitingForApnsResponse = false;
}

//Set to false as soon as it's read.
+ (BOOL)coldStartFromTapOnNotification {
    BOOL val = coldStartFromTapOnNotification;
    coldStartFromTapOnNotification = NO;
    return val;
}
    
+ (id)initWithLaunchOptions:(NSDictionary*)launchOptions appId:(NSString*)appId {
    return [self initWithLaunchOptions: launchOptions appId: appId handleNotificationReceived: NULL handleNotificationAction : NULL settings: @{kOSSettingsKeyAutoPrompt : @YES, kOSSettingsKeyInAppAlerts : @YES, kOSSettingsKeyInAppLaunchURL : @YES}];
}

+ (id)initWithLaunchOptions:(NSDictionary*)launchOptions appId:(NSString*)appId handleNotificationAction:(OSHandleNotificationActionBlock)actionCallback {
    return [self initWithLaunchOptions: launchOptions appId: appId handleNotificationReceived: NULL handleNotificationAction : actionCallback settings: @{kOSSettingsKeyAutoPrompt : @YES, kOSSettingsKeyInAppAlerts : @YES, kOSSettingsKeyInAppLaunchURL : @YES}];
}

+ (id)initWithLaunchOptions:(NSDictionary*)launchOptions appId:(NSString*)appId handleNotificationAction:(OSHandleNotificationActionBlock)actionCallback settings:(NSDictionary*)settings {
    return [self initWithLaunchOptions: launchOptions appId: appId handleNotificationReceived: NULL handleNotificationAction : actionCallback settings: settings];
}

// NOTE: Wrapper SDKs such as Unity3D will call this method with appId set to nil so open events are not lost.
//         Ensure a 2nd call can be made later with the appId from the developer's code.
+ (id)initWithLaunchOptions:(NSDictionary*)launchOptions appId:(NSString*)appId handleNotificationReceived:(OSHandleNotificationReceivedBlock)receivedCallback handleNotificationAction:(OSHandleNotificationActionBlock)actionCallback settings:(NSDictionary*)settings {
    
    if (![[NSUUID alloc] initWithUUIDString:appId]) {
        onesignal_Log(ONE_S_LL_FATAL, @"OneSignal AppId format is invalid.\nExample: 'b2f7f966-d8cc-11eg-bed1-df8f05be55ba'\n");
        return self;
    }
    
    if ([@"b2f7f966-d8cc-11eg-bed1-df8f05be55ba" isEqualToString:appId] || [@"5eb5a37e-b458-11e3-ac11-000c2940e62c" isEqualToString:appId])
        onesignal_Log(ONE_S_LL_WARN, @"OneSignal Example AppID detected, please update to your app's id found on OneSignal.com");
    
    
    if (!osNotificationSettings) {
        if ([OneSignalHelper isIOSVersionGreaterOrEqual:10])
            osNotificationSettings = [OneSignalNotificationSettingsIOS10 alloc];
        else if ([OneSignalHelper isIOSVersionGreaterOrEqual:8])
            osNotificationSettings = [OneSignalNotificationSettingsIOS8 alloc];
        else
            osNotificationSettings = [OneSignalNotificationSettingsIOS7 alloc];
    }
    
    if (mShareLocation)
       [OneSignalLocation getLocation:false];
    
    if (self) {
        NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
        
        httpClient = [[OneSignalHTTPClient alloc] init];
        
        [OneSignalHelper notificationBlocks: receivedCallback : actionCallback];
        
        if (appId)
            app_id = appId;
        else {
            // Read from .plist if not passed in with this method call.
            app_id = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"OneSignal_APPID"];
            if (app_id == nil)
                app_id = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"GameThrive_APPID"];
        }
        
        // Handle changes to the app id. This might happen on a developer's device when testing.
        if (app_id == nil)
            app_id  = [userDefaults stringForKey:@"GT_APP_ID"];
        else if (![app_id isEqualToString:[userDefaults stringForKey:@"GT_APP_ID"]]) {
            // Will run the first time OneSignal is initialized or if the dev changes the app_id.
            [userDefaults setObject:app_id forKey:@"GT_APP_ID"];
            [userDefaults setObject:nil forKey:@"GT_PLAYER_ID"];
            [userDefaults synchronize];
        }
        
        if (!app_id) {
            if (![settings[kOSSettingsKeyInOmitNoAppIdLogging] boolValue])
                onesignal_Log(ONE_S_LL_FATAL, @"OneSignal AppId never set!");
            return self;
        }
        
        mUserId = [userDefaults stringForKey:@"GT_PLAYER_ID"];
        mDeviceToken = [userDefaults stringForKey:@"GT_DEVICE_TOKEN"];
        
        if ([OneSignalHelper isIOSVersionGreaterOrEqual:8])
            registeredWithApple = [osNotificationSettings getNotificationPermissionStatus].accepted;
        else
            registeredWithApple = mDeviceToken != nil || [userDefaults boolForKey:@"GT_REGISTERED_WITH_APPLE"];
        
        
        mSubscriptionSet = [userDefaults objectForKey:@"ONESIGNAL_SUBSCRIPTION"] == nil;
        
        // Check if disabled in-app launch url if passed a NO
        if (settings[kOSSettingsKeyInAppLaunchURL] && [settings[kOSSettingsKeyInAppLaunchURL] isKindOfClass:[NSNumber class]])
            [self enableInAppLaunchURL:settings[kOSSettingsKeyInAppLaunchURL]];
        else
            [self enableInAppLaunchURL:@YES];
        
        
        BOOL autoPrompt = YES;
        if (settings[kOSSettingsKeyAutoPrompt] && [settings[kOSSettingsKeyAutoPrompt] isKindOfClass:[NSNumber class]])
            autoPrompt = [settings[kOSSettingsKeyAutoPrompt] boolValue];
        
        // Register with Apple's APNS server if we registed once before or if auto-prompt hasn't been disabled.
        if (autoPrompt || registeredWithApple)
            [self registerForPushNotifications];
        else
            [self registerForAPNsToken];
        
        /* Check if in-app setting passed assigned
            LOGIC: Default - InAppAlerts enabled / InFocusDisplayOption InAppAlert.
            Priority for kOSSettingsKeyInFocusDisplayOption.
        */
        
        NSNumber *IAASetting = settings[kOSSettingsKeyInAppAlerts];
        BOOL inAppAlertsPassed = IAASetting && (IAASetting.integerValue == 0 || IAASetting.integerValue == 1);
        
        NSNumber *IFDSetting = settings[kOSSettingsKeyInFocusDisplayOption];
        BOOL inFocusDisplayPassed = IFDSetting && IFDSetting.integerValue > -1 && IFDSetting.integerValue < 3;
        
        if (!inAppAlertsPassed && !inFocusDisplayPassed)
            [self setNotificationDisplayOptions:@(OSNotificationDisplayTypeInAppAlert)];
        else if (!inFocusDisplayPassed)
            [self setNotificationDisplayOptions:IAASetting];
        else
            [self setNotificationDisplayOptions:IFDSetting];
        

        if (mUserId != nil)
            [self registerUser];
        else {
            [osNotificationSettings getNotificationPermissionStatus:^(OSPermissionStatus *status) {
                if (status.anwseredPrompt)
                    [self registerUser];
                else
                    [self performSelector:@selector(registerUser) withObject:nil afterDelay:30.0f];
            }];
        }
    }
 
    /*
     * No need to call the handleNotificationOpened:userInfo as it will be called from one of the following selectors
     *  - application:didReceiveRemoteNotification:fetchCompletionHandler
     *  - userNotificationCenter:didReceiveNotificationResponse:withCompletionHandler (iOS10)
     */
    
    // Cold start from tap on a remote notification
    //  NOTE: launchOptions may be nil if tapping on an action button on a notification.
    NSDictionary* userInfo = [launchOptions objectForKey:UIApplicationLaunchOptionsRemoteNotificationKey];
    if (userInfo)
        coldStartFromTapOnNotification = YES;

    [self clearBadgeCount:false];
    
    if (!trackIAPPurchase && [OneSignalTrackIAP canTrack])
        trackIAPPurchase = [[OneSignalTrackIAP alloc] init];
    
    #if XC8_AVAILABLE
    if (NSClassFromString(@"UNUserNotificationCenter"))
       [OneSignalHelper clearCachedMedia];
    #endif
    
    return self;
}

+ (void)setLogLevel:(ONE_S_LOG_LEVEL)nsLogLevel visualLevel:(ONE_S_LOG_LEVEL)visualLogLevel {
    NSLog(@"ONESIGNAL - Setting log level: %d", (int)nsLogLevel);
    _nsLogLevel = nsLogLevel; _visualLogLevel = visualLogLevel;
}

+ (void) onesignal_Log:(ONE_S_LOG_LEVEL)logLevel message:(NSString*) message {
    onesignal_Log(logLevel, message);
}

void onesignal_Log(ONE_S_LOG_LEVEL logLevel, NSString* message) {
    NSString* levelString;
    switch (logLevel) {
        case ONE_S_LL_FATAL:
            levelString = @"FATAL: ";
            break;
        case ONE_S_LL_ERROR:
            levelString = @"ERROR: ";
            break;
        case ONE_S_LL_WARN:
            levelString = @"WARNING: ";
            break;
        case ONE_S_LL_INFO:
            levelString = @"INFO: ";
            break;
        case ONE_S_LL_DEBUG:
            levelString = @"DEBUG: ";
            break;
        case ONE_S_LL_VERBOSE:
            levelString = @"VERBOSE: ";
            break;
            
        default:
            break;
    }

    if (logLevel <= _nsLogLevel)
        NSLog(@"%@", [levelString stringByAppendingString:message]);
    
    if (logLevel <= _visualLogLevel) {
        [OneSignalHelper runOnMainThread:^{
            UIAlertView* alertView = [[UIAlertView alloc] initWithTitle:levelString
                                                                message:message
                                                               delegate:nil
                                                      cancelButtonTitle:@"Close"
                                                      otherButtonTitles:nil, nil];
            [alertView show];
        }];
    }
}


// iOS 8+, only tries to register for an APNs token
+ (BOOL)registerForAPNsToken {
    if (![OneSignalHelper isIOSVersionGreaterOrEqual:8])
        return false;
    
    if (waitingForApnsResponse)
        return true;
    
    id backgroundModes = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"UIBackgroundModes"];
    backgroundModesEnabled = (backgroundModes && [backgroundModes containsObject:@"remote-notification"]);
    
    // Only try to register for a pushToken if:
    //  - The user accepted notifications
    //  - "Background Modes" > "Remote Notifications" are enabled in Xcode
    if (![osNotificationSettings getNotificationPermissionStatus].accepted && !backgroundModesEnabled)
        return false;
    
    // Don't attempt to register again if there was a non-recoverable error.
    if (mSubscriptionStatus < -9)
        return false;
    
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"Firing registerForRemoteNotifications"];
    
    waitingForApnsResponse = true;
    [[UIApplication sharedApplication] registerForRemoteNotifications];
    
    return true;
}

// This registers for a push token and prompts the user for notifiations permisions
//    Will trigger didRegisterForRemoteNotificationsWithDeviceToken on the AppDelegate when APNs responses.
+ (void)registerForPushNotifications {
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"registerForPushNotifications Called:waitingForApnsResponse: %d", waitingForApnsResponse]];
    
    NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setBool:true forKey:@"OS_HAS_PROMPTED_FOR_NOTIFICATIONS"];
    [userDefaults synchronize];
    
    [osNotificationSettings promptForNotifications];
}

// Block not assigned if userID nil and there is a device token
+ (void)IdsAvailable:(OSIdsAvailableBlock)idsAvailableBlock {
    idsAvailableBlockWhenReady = idsAvailableBlock;
    [self fireIdsAvailableCallback];
}

+ (void) fireIdsAvailableCallback {
    if (!idsAvailableBlockWhenReady)
        return;
    if (!mUserId)
        return;
    
    // Ensure we are on the main thread incase app developer updates UI from the callback.
    [OneSignalHelper dispatch_async_on_main_queue: ^{
        id pushToken = [self getUsableDeviceToken];
        if (!idsAvailableBlockWhenReady)
            return;
        idsAvailableBlockWhenReady(mUserId, pushToken);
        if (pushToken)
           idsAvailableBlockWhenReady = nil;
    }];
}

+ (void)sendTagsWithJsonString:(NSString*)jsonString {
    NSError* jsonError;
    
    NSData* data = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary* keyValuePairs = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&jsonError];
    if (jsonError == nil)
        [self sendTags:keyValuePairs];
    else {
        onesignal_Log(ONE_S_LL_WARN,[NSString stringWithFormat: @"sendTags JSON Parse Error: %@", jsonError]);
        onesignal_Log(ONE_S_LL_WARN,[NSString stringWithFormat: @"sendTags JSON Parse Error, JSON: %@", jsonString]);
    }
}

+ (void)sendTags:(NSDictionary*)keyValuePair {
    [self sendTags:keyValuePair onSuccess:nil onFailure:nil];
}

+ (void)sendTags:(NSDictionary*)keyValuePair onSuccess:(OSResultSuccessBlock)successBlock onFailure:(OSFailureBlock)failureBlock {
   
    if (tagsToSend == nil)
        tagsToSend = [keyValuePair mutableCopy];
    else
        [tagsToSend addEntriesFromDictionary:keyValuePair];
    
    if (successBlock || failureBlock) {
        if (!pendingSendTagCallbacks)
            pendingSendTagCallbacks = [[NSMutableArray alloc] init];
        OSPendingCallbacks* pendingCallbacks = [OSPendingCallbacks alloc];
        pendingCallbacks.successBlock = successBlock;
        pendingCallbacks.failureBlock = failureBlock;
        [pendingSendTagCallbacks addObject:pendingCallbacks];
    }
    
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(sendTagsToServer) object:nil];
    
    // Can't send tags yet as their isn't a player_id.
    if (mUserId)
        [self performSelector:@selector(sendTagsToServer) withObject:nil afterDelay:5];
}

// Called only with a delay to batch network calls.
+ (void) sendTagsToServer {
    if (!tagsToSend)
        return;
    
    NSDictionary* nowSendingTags = tagsToSend;
    tagsToSend = nil;
    
    NSArray* nowProcessingCallbacks = pendingSendTagCallbacks;
    pendingSendTagCallbacks = nil;
    
    
    NSMutableURLRequest* request = [httpClient requestWithMethod:@"PUT" path:[NSString stringWithFormat:@"players/%@", mUserId]];
    
    NSDictionary* dataDic = [NSDictionary dictionaryWithObjectsAndKeys:
                             app_id, @"app_id",
                             nowSendingTags, @"tags",
                             [OneSignalHelper getNetType], @"net_type",
                             nil];
    
    NSData* postData = [NSJSONSerialization dataWithJSONObject:dataDic options:0 error:nil];
    [request setHTTPBody:postData];
    
    [OneSignalHelper enqueueRequest:request
                          onSuccess:^(NSDictionary *result) {
                              if (nowProcessingCallbacks) {
                                  for(OSPendingCallbacks* callbackSet in nowProcessingCallbacks) {
                                      if (callbackSet.successBlock)
                                          callbackSet.successBlock(result);
                                  }
                              }
                          }
                          onFailure:^(NSError *error) {
                              if (nowProcessingCallbacks) {
                                  for(OSPendingCallbacks* callbackSet in nowProcessingCallbacks) {
                                      if (callbackSet.failureBlock)
                                          callbackSet.failureBlock(error);
                                  }
                              }
                          }];
}

+ (void)sendTag:(NSString*)key value:(NSString*)value {
    [self sendTag:key value:value onSuccess:nil onFailure:nil];
}

+ (void)sendTag:(NSString*)key value:(NSString*)value onSuccess:(OSResultSuccessBlock)successBlock onFailure:(OSFailureBlock)failureBlock {
    [self sendTags:[NSDictionary dictionaryWithObjectsAndKeys: value, key, nil] onSuccess:successBlock onFailure:failureBlock];
}

+ (void)getTags:(OSResultSuccessBlock)successBlock onFailure:(OSFailureBlock)failureBlock {
    if (mUserId == nil)
        return;
    
    NSMutableURLRequest* request;
    request = [httpClient requestWithMethod:@"GET" path:[NSString stringWithFormat:@"players/%@", mUserId]];
    
    [OneSignalHelper enqueueRequest:request onSuccess:^(NSDictionary* results) {
        if ([results objectForKey:@"tags"] != nil)
            successBlock([results objectForKey:@"tags"]);
    } onFailure:failureBlock];
}

+ (void)getTags:(OSResultSuccessBlock)successBlock {
    [self getTags:successBlock onFailure:nil];
}


+ (void)deleteTag:(NSString*)key onSuccess:(OSResultSuccessBlock)successBlock onFailure:(OSFailureBlock)failureBlock {
    [self deleteTags:@[key] onSuccess:successBlock onFailure:failureBlock];
}

+ (void)deleteTag:(NSString*)key {
    [self deleteTags:@[key] onSuccess:nil onFailure:nil];
}

+ (void)deleteTags:(NSArray*)keys {
    [self deleteTags:keys onSuccess:nil onFailure:nil];
}

+ (void)deleteTagsWithJsonString:(NSString*)jsonString {
    NSError* jsonError;
    
    NSData* data = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSArray* keys = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&jsonError];
    if (jsonError == nil)
        [self deleteTags:keys];
    else {
        onesignal_Log(ONE_S_LL_WARN,[NSString stringWithFormat: @"deleteTags JSON Parse Error: %@", jsonError]);
        onesignal_Log(ONE_S_LL_WARN,[NSString stringWithFormat: @"deleteTags JSON Parse Error, JSON: %@", jsonString]);
    }
}

+ (void)deleteTags:(NSArray*)keys onSuccess:(OSResultSuccessBlock)successBlock onFailure:(OSFailureBlock)failureBlock {
    NSMutableDictionary* tags = [[NSMutableDictionary alloc] init];
    
    for(NSString* key in keys) {
        if (tagsToSend && tagsToSend[key]) {
            if (![tagsToSend[key] isEqualToString:@""])
                [tagsToSend removeObjectForKey:key];
        }
        else
            tags[key] = @"";
    }
    
    [self sendTags:tags onSuccess:successBlock onFailure:failureBlock];
}


+ (void)postNotification:(NSDictionary*)jsonData {
    [self postNotification:jsonData onSuccess:nil onFailure:nil];
}

+ (void)postNotification:(NSDictionary*)jsonData onSuccess:(OSResultSuccessBlock)successBlock onFailure:(OSFailureBlock)failureBlock {
    NSMutableURLRequest* request = [httpClient requestWithMethod:@"POST" path:@"notifications"];
    
    NSMutableDictionary* dataDic = [[NSMutableDictionary alloc] initWithDictionary:jsonData];
    dataDic[@"app_id"] = app_id;
    
    NSData* postData = [NSJSONSerialization dataWithJSONObject:dataDic options:0 error:nil];
    [request setHTTPBody:postData];
    
    [OneSignalHelper enqueueRequest:request
               onSuccess:^(NSDictionary* results) {
                   NSData* jsonData = [NSJSONSerialization dataWithJSONObject:results options:0 error:nil];
                   NSString* jsonResultsString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
                   
                   onesignal_Log(ONE_S_LL_DEBUG, [NSString stringWithFormat: @"HTTP create notification success %@", jsonResultsString]);
                   if (successBlock)
                       successBlock(results);
               }
               onFailure:^(NSError* error) {
                   onesignal_Log(ONE_S_LL_ERROR, @"Create notification failed");
                   onesignal_Log(ONE_S_LL_INFO, [NSString stringWithFormat: @"%@", error]);
                   if (failureBlock)
                       failureBlock(error);
               }];
}

+ (void)postNotificationWithJsonString:(NSString*)jsonString onSuccess:(OSResultSuccessBlock)successBlock onFailure:(OSFailureBlock)failureBlock {
    NSError* jsonError;
    
    NSData* data = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary* jsonData = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&jsonError];
    if (jsonError == nil && jsonData != nil)
        [self postNotification:jsonData onSuccess:successBlock onFailure:failureBlock];
    else {
        onesignal_Log(ONE_S_LL_WARN, [NSString stringWithFormat: @"postNotification JSON Parse Error: %@", jsonError]);
        onesignal_Log(ONE_S_LL_WARN, [NSString stringWithFormat: @"postNotification JSON Parse Error, JSON: %@", jsonString]);
    }
}

+ (NSString*)parseNSErrorAsJsonString:(NSError*)error {
    NSString* jsonResponse;
    
    if (error.userInfo && error.userInfo[@"returned"]) {
        @try {
            NSData* jsonData = [NSJSONSerialization dataWithJSONObject:error.userInfo[@"returned"] options:0 error:nil];
            jsonResponse = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        } @catch(NSException* e) {
            onesignal_Log(ONE_S_LL_ERROR, [NSString stringWithFormat:@"%@", e]);
            onesignal_Log(ONE_S_LL_ERROR, [NSString stringWithFormat:@"%@",  [NSThread callStackSymbols]]);
            jsonResponse = @"{\"error\": \"Unkown error parsing error response.\"}";
        }
    }
    else
        jsonResponse = @"{\"error\": \"HTTP no response error\"}";
    
    return jsonResponse;
}

/* Option:0, 1 or 2 */
+ (void)setNotificationDisplayOptions:(NSNumber*)option {
   
    // Special Case: If iOS version < 10 && Option passed is 2, default to inAppAlerts.
    NSInteger op = option.integerValue;
    if (![OneSignalHelper isIOSVersionGreaterOrEqual:10] && OSNotificationDisplayTypeNotification == op)
        op = OSNotificationDisplayTypeInAppAlert;
    
    [[NSUserDefaults standardUserDefaults] setObject:@(op) forKey:@"ONESIGNAL_ALERT_OPTION"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (void)enableInAppLaunchURL:(NSNumber*)enable {
    [[NSUserDefaults standardUserDefaults] setObject:enable forKey:@"ONESIGNAL_INAPP_LAUNCH_URL"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (void)setSubscription:(BOOL)enable {
    NSString* value = nil;
    if (!enable)
        value = @"no";

    [[NSUserDefaults standardUserDefaults] setObject:value forKey:@"ONESIGNAL_SUBSCRIPTION"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    mSubscriptionSet = enable;
    
    [OneSignal sendNotificationTypesUpdate];
}


+ (void)setLocationShared:(BOOL)enable {
   mShareLocation = enable;
}

+ (void) promptLocation {
    [OneSignalLocation getLocation:true];
}


+ (void) handleDidFailRegisterForRemoteNotification:(NSError*)err {
    waitingForApnsResponse = false;
    
    if (err.code == 3000) {
        if ([((NSString*)[err.userInfo objectForKey:NSLocalizedDescriptionKey]) rangeOfString:@"no valid 'aps-environment'"].location != NSNotFound) {
            // User did not enable push notification capability
            [OneSignal setSubscriptionErrorStatus:ERROR_PUSH_CAPABLILITY_DISABLED];
            [OneSignal onesignal_Log:ONE_S_LL_ERROR message:@"ERROR! 'Push Notification' capability not turned on! Enable it in Xcode under 'Project Target' -> Capability."];
        }
        else {
            [OneSignal setSubscriptionErrorStatus:ERROR_PUSH_OTHER_3000_ERROR];
            [OneSignal onesignal_Log:ONE_S_LL_ERROR message:[NSString stringWithFormat:@"ERROR! Unkown 3000 error returned from APNs when getting a push token: %@", err]];
        }
    }
    else if (err.code == 3010) {
        [OneSignal setSubscriptionErrorStatus:ERROR_PUSH_SIMULATOR_NOT_SUPPORTED];
        [OneSignal onesignal_Log:ONE_S_LL_ERROR message:[NSString stringWithFormat:@"Error! iOS Simulator does not support push! Please test on a real iOS device. Error: %@", err]];
    }
    else {
        [OneSignal setSubscriptionErrorStatus:ERROR_PUSH_UNKOWN_APNS_ERROR];
        [OneSignal onesignal_Log:ONE_S_LL_ERROR message:[NSString stringWithFormat:@"Error registering for Apple push notifications! Error: %@", err]];
    }
}

+ (void)registerDeviceToken:(id)inDeviceToken onSuccess:(OSResultSuccessBlock)successBlock onFailure:(OSFailureBlock)failureBlock {
    waitingForApnsResponse = false;
    
    [self updateDeviceToken:inDeviceToken onSuccess:successBlock onFailure:failureBlock];
    
    [[NSUserDefaults standardUserDefaults] setObject:mDeviceToken forKey:@"GT_DEVICE_TOKEN"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (void)updateDeviceToken:(NSString*)deviceToken onSuccess:(OSResultSuccessBlock)successBlock onFailure:(OSFailureBlock)failureBlock {
    onesignal_Log(ONE_S_LL_VERBOSE, @"updateDeviceToken:onSuccess:onFailure:");
    
    // Do not block next registration as there's a new token in hand
    nextRegistrationIsHighPriority = ![deviceToken isEqualToString:mDeviceToken] || [self getNotificationTypes] != mLastNotificationTypes;
    
    if (mUserId == nil) {
        mDeviceToken = deviceToken;
        tokenUpdateSuccessBlock = successBlock;
        tokenUpdateFailureBlock = failureBlock;
        
        // iOS 8+ - We get a token right away but give the user 30 sec to respond notification permission prompt.
        // The goal is to only have 1 server call.
        [osNotificationSettings getNotificationPermissionStatus:^(OSPermissionStatus *status) {
            if (status.anwseredPrompt)
                [OneSignal registerUser];
            else {
                [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(registerUser) object:nil];
                [OneSignalHelper performSelector:@selector(registerUser) onMainThreadOnObject:self withObject:nil afterDelay:30.0f];
            }
        }];
        return;
    }
    
    if ([deviceToken isEqualToString:mDeviceToken]) {
        if (successBlock)
            successBlock(nil);
        return;
    }
    
    mDeviceToken = deviceToken;
    
    NSMutableURLRequest* request;
    request = [httpClient requestWithMethod:@"PUT" path:[NSString stringWithFormat:@"players/%@", mUserId]];
    
    int notificationTypes = [self getNotificationTypes];
    
    NSDictionary* dataDic = [NSDictionary dictionaryWithObjectsAndKeys:
                             app_id, @"app_id",
                             deviceToken, @"identifier",
                             [NSNumber numberWithInt:notificationTypes], @"notification_types",
                             nil];
    
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"Calling OneSignal PUT updated pushToken!"];
    
    NSData* postData = [NSJSONSerialization dataWithJSONObject:dataDic options:0 error:nil];
    [request setHTTPBody:postData];
    
    [OneSignalHelper enqueueRequest:request onSuccess:successBlock onFailure:failureBlock];
    
    [self fireIdsAvailableCallback];
}

// Set to yes whenever a high priority registration fails ... need to make the next one a high priority to disregard the timer delay
bool nextRegistrationIsHighPriority = NO;

+ (BOOL)isHighPriorityCall {
    return mUserId == nil || nextRegistrationIsHighPriority;
}

static BOOL waitingForOneSReg = false;


+ (void) updateLastSessionDateTime {
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    [[NSUserDefaults standardUserDefaults] setDouble:now forKey:@"GT_LAST_CLOSED_TIME"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+(BOOL)shouldRegisterNow {
    if (waitingForOneSReg)
        return false;
    
    // Figure out if should pass or not
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    NSTimeInterval lastTimeClosed = [[NSUserDefaults standardUserDefaults] doubleForKey:@"GT_LAST_CLOSED_TIME"];
    if (!lastTimeClosed) {
        [self updateLastSessionDateTime];
        return true;
    }
    
    if ([self isHighPriorityCall])
        return true;
    
    // Make sure last time we closed app was more than 30 secs ago
    const int minTimeThreshold = 30;
    NSTimeInterval delta = now - lastTimeClosed;
    return delta > minTimeThreshold;
}

static dispatch_queue_t serialQueue;

+ (dispatch_queue_t) getRegisterQueue {
    return serialQueue;
}

+ (void)registerUser {
    if (!serialQueue)
        serialQueue = dispatch_queue_create("com.onesignal.regiseruser", DISPATCH_QUEUE_SERIAL);
   
   dispatch_async(serialQueue, ^{
        [self registerUserInternal];
    });
}

+ (void)registerUserInternal {
    // Make sure we only call create or on_session once per open of the app.
    if (![self shouldRegisterNow])
        return;
    waitingForOneSReg = true;

    
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(registerUser) object:nil];
    
    NSMutableURLRequest* request;
    if (mUserId == nil)
        request = [httpClient requestWithMethod:@"POST" path:@"players"];
    else
        request = [httpClient requestWithMethod:@"POST" path:[NSString stringWithFormat:@"players/%@/on_session", mUserId]];
    
    NSDictionary* infoDictionary = [[NSBundle mainBundle]infoDictionary];
    NSString* build = infoDictionary[(NSString*)kCFBundleVersionKey];
    
    struct utsname systemInfo;
    uname(&systemInfo);
    NSString *deviceModel   = [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
    
    NSMutableDictionary* dataDic = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                    app_id, @"app_id",
                                    deviceModel, @"device_model",
                                    [[UIDevice currentDevice] systemVersion], @"device_os",
                                    [NSNumber numberWithInt:(int)[[NSTimeZone localTimeZone] secondsFromGMT]], @"timezone",
                                    [NSNumber numberWithInt:0], @"device_type",
                                    [[[UIDevice currentDevice] identifierForVendor] UUIDString], @"ad_id",
                                    ONESIGNAL_VERSION, @"sdk",
                                    mDeviceToken, @"identifier", // identifier MUST be at the end as it could be nil.
                                    nil];
    
    if (build)
        dataDic[@"game_version"] = build;
    
    int notificationTypes = [self getNotificationTypes];
    
    if ([OneSignalJailbreakDetection isJailbroken])
        dataDic[@"rooted"] = @YES;
    
    dataDic[@"net_type"] = [OneSignalHelper getNetType];
    
    if (mUserId == nil) {
        dataDic[@"sdk_type"] = mSDKType;
        dataDic[@"ios_bundle"] = [[NSBundle mainBundle] bundleIdentifier];
    }
    
    
    NSArray* preferredLanguages = [NSLocale preferredLanguages];
    if (preferredLanguages && [preferredLanguages count] > 0)
        dataDic[@"language"] = [preferredLanguages objectAtIndex:0];
    
    mLastNotificationTypes = notificationTypes;
    dataDic[@"notification_types"] = [NSNumber numberWithInt:notificationTypes];
    
    Class ASIdentifierManagerClass = NSClassFromString(@"ASIdentifierManager");
    if (ASIdentifierManagerClass) {
        id asIdManager = [ASIdentifierManagerClass valueForKey:@"sharedManager"];
        if ([[asIdManager valueForKey:@"advertisingTrackingEnabled"] isEqual:[NSNumber numberWithInt:1]])
            dataDic[@"as_id"] = [[asIdManager valueForKey:@"advertisingIdentifier"] UUIDString];
        else
            dataDic[@"as_id"] = @"OptedOut";
    }
    
    UIApplicationReleaseMode releaseMode = [OneSignalMobileProvision releaseMode];
    if (releaseMode == UIApplicationReleaseDev || releaseMode == UIApplicationReleaseAdHoc || releaseMode == UIApplicationReleaseWildcard)
        dataDic[@"test_type"] = [NSNumber numberWithInt:releaseMode];
    
    if (tagsToSend) {
        dataDic[@"tags"] = tagsToSend;
        tagsToSend = nil;
    }
    
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"Calling OneSignal create/on_session"];
    
    NSData* postData = [NSJSONSerialization dataWithJSONObject:dataDic options:0 error:nil];
    [request setHTTPBody:postData];
    
    if (mShareLocation && [OneSignalLocation lastLocation]) {
        dataDic[@"lat"] = [NSNumber numberWithDouble:[OneSignalLocation lastLocation]->cords.latitude];
        dataDic[@"long"] = [NSNumber numberWithDouble:[OneSignalLocation lastLocation]->cords.longitude];
        dataDic[@"loc_acc_vert"] = [NSNumber numberWithDouble:[OneSignalLocation lastLocation]->verticalAccuracy];
        dataDic[@"loc_acc"] = [NSNumber numberWithDouble:[OneSignalLocation lastLocation]->horizontalAccuracy];
        [OneSignalLocation clearLastLocation];
    }
    
    [OneSignalHelper enqueueRequest:request onSuccess:^(NSDictionary* results) {
        
        waitingForOneSReg = false;
        
        // Success, no more high priority
        nextRegistrationIsHighPriority = NO;
        
        [self updateLastSessionDateTime];
        
        if ([results objectForKey:@"id"] != nil) {
            
            mUserId = [results objectForKey:@"id"];
            [[NSUserDefaults standardUserDefaults] setObject:mUserId forKey:@"GT_PLAYER_ID"];
            [[NSUserDefaults standardUserDefaults] synchronize];
            
            if (mDeviceToken)
               [self updateDeviceToken:mDeviceToken onSuccess:tokenUpdateSuccessBlock onFailure:tokenUpdateFailureBlock];
            
            if (tagsToSend)
                [self performSelector:@selector(sendTagsToServer) withObject:nil afterDelay:5];
            
            // try to send location
            [OneSignalLocation sendLocation];
            
            if (emailToSet) {
                [OneSignal syncHashedEmail:emailToSet];
                emailToSet = nil;
            }
            
            [self fireIdsAvailableCallback];
            
            [self sendNotificationTypesUpdate];
        }
    } onFailure:^(NSError* error) {
        waitingForOneSReg = false;
        [OneSignal onesignal_Log:ONE_S_LL_ERROR message:[NSString stringWithFormat: @"Error registering with OneSignal: %@", error]];
        
        //If the failed registration is priority, force the next one to be a high priority
        nextRegistrationIsHighPriority = YES;
    }];
}

+(NSString*) getUsableDeviceToken {
    if (mSubscriptionStatus < -1)
        return NULL;
    
    return [osNotificationSettings getNotificationPermissionStatus].accepted ? mDeviceToken : NULL;
}

// Updates the server with the new user's notification setting or subscription status changes
+ (BOOL) sendNotificationTypesUpdate {
    // User changed notification settings for the app.
    if ([self getNotificationTypes] != -1 && mUserId && mLastNotificationTypes != [self getNotificationTypes]) {
        if (mDeviceToken == nil) {
            if ([self registerForAPNsToken])
               return true;
        }
        
        mLastNotificationTypes = [self getNotificationTypes];
        NSMutableURLRequest* request = [httpClient requestWithMethod:@"PUT" path:[NSString stringWithFormat:@"players/%@", mUserId]];
        NSDictionary* dataDic = [NSDictionary dictionaryWithObjectsAndKeys:
                                 app_id, @"app_id",
                                 @([self getNotificationTypes]), @"notification_types",
                                 nil];
        NSData* postData = [NSJSONSerialization dataWithJSONObject:dataDic options:0 error:nil];
        [request setHTTPBody:postData];
        
        [OneSignalHelper enqueueRequest:request onSuccess:nil onFailure:nil];
        
        if ([self getUsableDeviceToken])
            [self fireIdsAvailableCallback];
        
        return true;
    }
    
    return false;
}

+ (void)sendPurchases:(NSArray*)purchases {
    if (mUserId == nil)
        return;
    
    NSMutableURLRequest* request = [httpClient requestWithMethod:@"POST" path:[NSString stringWithFormat:@"players/%@/on_purchase", mUserId]];
    
    NSDictionary *dataDic = [NSDictionary dictionaryWithObjectsAndKeys:
                             app_id, @"app_id",
                             purchases, @"purchases",
                             nil];
    
    NSData *postData = [NSJSONSerialization dataWithJSONObject:dataDic options:0 error:nil];
    [request setHTTPBody:postData];
    
    [OneSignalHelper enqueueRequest:request
               onSuccess:nil
               onFailure:nil];
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
+ (void)notificationOpened:(NSDictionary*)messageDict isActive:(BOOL)isActive {
    if (!app_id)
        return;
    
    onesignal_Log(ONE_S_LL_VERBOSE, @"notificationOpened:isActive called!");
    
    NSDictionary* customDict = [messageDict objectForKey:@"os_data"];
    if (!customDict)
        customDict = [messageDict objectForKey:@"custom"];
    
    // Should be called first, other methods relay on this global state below.
    [OneSignalHelper lastMessageReceived:messageDict];
    
    BOOL inAppAlert = false;
    if (isActive) {
        // Prevent duplicate calls
        NSString* newId = [self checkForProcessedDups:customDict lastMessageId:_lastAppActiveMessageId];
        if ([@"dup" isEqualToString:newId])
            return;
        if (newId)
            _lastAppActiveMessageId = newId;
        
        if (![[NSUserDefaults standardUserDefaults] objectForKey:@"ONESIGNAL_ALERT_OPTION"]) {
            [[NSUserDefaults standardUserDefaults] setObject:@(OSNotificationDisplayTypeInAppAlert) forKey:@"ONESIGNAL_ALERT_OPTION"];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }
        
        int iaaoption = [[[NSUserDefaults standardUserDefaults] objectForKey:@"ONESIGNAL_ALERT_OPTION"] intValue];
        inAppAlert = iaaoption == OSNotificationDisplayTypeInAppAlert;
        
        // Make sure it is not a silent one do display, if inAppAlerts are enabled
        if (inAppAlert && ![OneSignalHelper isRemoteSilentNotification:messageDict]) {
            
            NSDictionary* titleAndBody = [OneSignalHelper getPushTitleBody:messageDict];
            id oneSignalAlertViewDelegate = [[OneSignalAlertViewDelegate alloc] initWithMessageDict:messageDict];
            
            UIAlertView* alertView = [[UIAlertView alloc] initWithTitle:titleAndBody[@"title"]
                                                                message:titleAndBody[@"body"]
                                                               delegate:oneSignalAlertViewDelegate
                                                      cancelButtonTitle:@"Close"
                                                      otherButtonTitles:nil, nil];
            // Add Buttons
            NSArray *actionButons = [OneSignalHelper getActionButtons:messageDict];
            if (actionButons) {
                for(id button in actionButons)
                   [alertView addButtonWithTitle:button[@"n"]];
            }
            
            [alertView show];
            
            // Message received that was displayed (Foreground + InAppAlert is true)
            // Call Received Block
            [OneSignalHelper handleNotificationReceived:OSNotificationDisplayTypeInAppAlert];
            
            return;
        }
        
        // App is active and a notification was received without inApp display. Display type is none or notification
        // Call Received Block
        [OneSignalHelper handleNotificationReceived:iaaoption];
        
        // Notify backend that user opened the notification
        NSString* messageId = [customDict objectForKey:@"i"];
        [OneSignal submitNotificationOpened:messageId];
    }
    else {
        // Prevent duplicate calls
        NSString* newId = [self checkForProcessedDups:customDict lastMessageId:_lastnonActiveMessageId];
        if ([@"dup" isEqualToString:newId])
            return;
        if (newId)
            _lastnonActiveMessageId = newId;
        
        //app was in background / not running and opened due to a tap on a notification or an action check what type
        NSString* actionSelected = NULL;
        OSNotificationActionType type = OSNotificationActionTypeOpened;
        if (messageDict[@"custom"][@"a"][@"actionSelected"]) {
            actionSelected = messageDict[@"custom"][@"a"][@"actionSelected"];
            type = OSNotificationActionTypeActionTaken;
        }
        if (messageDict[@"actionSelected"]) {
            actionSelected = messageDict[@"actionSelected"];
            type = OSNotificationActionTypeActionTaken;
        }
        
        // Call Action Block
        [OneSignalHelper handleNotificationAction:type actionID:actionSelected displayType:OSNotificationDisplayTypeNotification];
        [OneSignal handleNotificationOpened:messageDict isActive:isActive actionType:type displayType:OSNotificationDisplayTypeNotification];
    }
}

+ (NSString*) checkForProcessedDups:(NSDictionary*)customDict lastMessageId:(NSString*)lastMessageId {
    if (customDict && customDict[@"i"]) {
        NSString* currentNotificationId = customDict[@"i"];
        if ([currentNotificationId isEqualToString:lastMessageId])
            return @"dup";
        return customDict[@"i"];
    }
    return nil;
}


+ (void) handleNotificationOpened:(NSDictionary*)messageDict isActive:(BOOL)isActive actionType : (OSNotificationActionType)actionType displayType:(OSNotificationDisplayType)displayType {
    NSDictionary* customDict = [messageDict objectForKey:@"os_data"];
    if (customDict == nil)
        customDict = [messageDict objectForKey:@"custom"];
    
    // Notify backend that user opened the notification
    NSString* messageId = [customDict objectForKey:@"i"];
    [OneSignal submitNotificationOpened:messageId];
    
    //Try to fetch the open url to launch
    [OneSignal launchWebURL:[customDict objectForKey:@"u"]];
    
    [self clearBadgeCount:true];
    
    NSString* actionID = NULL;
    if (actionType == OSNotificationActionTypeActionTaken) {
        actionID = messageDict[@"custom"][@"a"][@"actionSelected"];
        if(!actionID)
            actionID = messageDict[@"actionSelected"];
    }
    
    //Call Action Block
    [OneSignalHelper lastMessageReceived:messageDict];
    [OneSignalHelper handleNotificationAction:actionType actionID:actionID displayType:displayType];
}

+ (void)launchWebURL:(NSString*)openUrl {

    if (openUrl && [OneSignalHelper verifyURL:openUrl]) {
        NSURL *url = [NSURL URLWithString:openUrl];
        // Give the app resume animation time to finish when tapping on a notification from the notification center.
        // Isn't a requirement but improves visual flow.
        [OneSignalHelper performSelector:@selector(displayWebView:) withObject:url afterDelay:0.5];
    }
    
}

+ (void)submitNotificationOpened:(NSString*)messageId {
    //(DUPLICATE Fix): Make sure we do not upload a notification opened twice for the same messageId
    //Keep track of the Id for the last message sent
    NSString* lastMessageId = [[NSUserDefaults standardUserDefaults] objectForKey:@"GT_LAST_MESSAGE_OPENED_"];
    //Only submit request if messageId not nil and: (lastMessage is nil or not equal to current one)
    if(messageId && (!lastMessageId || ![lastMessageId isEqualToString:messageId])) {
        NSMutableURLRequest* request = [httpClient requestWithMethod:@"PUT" path:[NSString stringWithFormat:@"notifications/%@", messageId]];
        NSDictionary* dataDic = [NSDictionary dictionaryWithObjectsAndKeys:
                                 app_id, @"app_id",
                                 mUserId, @"player_id",
                                 @(YES), @"opened",
                                 nil];
        
        NSData* postData = [NSJSONSerialization dataWithJSONObject:dataDic options:0 error:nil];
        [request setHTTPBody:postData];
        [OneSignalHelper enqueueRequest:request onSuccess:nil onFailure:nil];
        [[NSUserDefaults standardUserDefaults] setObject:messageId forKey:@"GT_LAST_MESSAGE_OPENED_"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}
    
+ (BOOL) clearBadgeCount:(BOOL)fromNotifOpened {
    
    NSNumber *disableBadgeNumber = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"OneSignal_disable_badge_clearing"];
    
    if (disableBadgeNumber)
        disableBadgeClearing = [disableBadgeNumber boolValue];
    else
        disableBadgeClearing = NO;
    
    if (disableBadgeClearing ||
        ([OneSignalHelper isIOSVersionGreaterOrEqual:8] && [osNotificationSettings getNotificationPermissionStatus].notificationTypes & NOTIFICATION_TYPE_BADGE) == 0)
        return false;
    
    bool wasBadgeSet = [UIApplication sharedApplication].applicationIconBadgeNumber > 0;
    
    if ((!(NSFoundationVersionNumber > NSFoundationVersionNumber_iOS_7_1) && fromNotifOpened) || wasBadgeSet) {
        // Clear badges and notifications from this app.
        // Setting to 1 then 0 was needed to clear the notifications on iOS 6 & 7. (Otherwise you can click the notification multiple times.)
        // iOS 8+ auto dismisses the notification you tap on so only clear the badge (and notifications [side-effect]) if it was set.
        [[UIApplication sharedApplication] setApplicationIconBadgeNumber:1];
        [[UIApplication sharedApplication] setApplicationIconBadgeNumber:0];
    }
    
    return wasBadgeSet;
}

+ (int) getNotificationTypes {
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message: [NSString stringWithFormat:@"getNotificationTypes:mSubscriptionStatus: %d", mSubscriptionStatus]];
    
    if (mSubscriptionStatus < -9)
        return mSubscriptionStatus;
    
    if (waitingForApnsResponse && !mDeviceToken)
        return ERROR_PUSH_DELEGATE_NEVER_FIRED;
    
    OSPermissionStatus* permissionStatus = [osNotificationSettings getNotificationPermissionStatus];
    
    if (!permissionStatus.hasPrompted)
        return ERROR_PUSH_NEVER_PROMPTED;
    if (!permissionStatus.anwseredPrompt)
        return ERROR_PUSH_PROMPT_NEVER_ANWSERED;
    
    
    if (!mSubscriptionSet)
        return -2;

    return permissionStatus.notificationTypes;
}

+ (void)setSubscriptionErrorStatus:(int)errorType {
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message: [NSString stringWithFormat:@"setSubscriptionErrorStatus: %d", errorType]];
    
    mSubscriptionStatus = errorType;
    if (mUserId)
        [self sendNotificationTypesUpdate];
    else
        [self registerUser];
}

// iOS 8.0+ only
//    User just responed to the iOS native notification permission prompt.
//    Also extra calls to registerUserNotificationSettings will fire this without prompting again.
+ (void)updateNotificationTypes:(int)notificationTypes {
    
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"updateNotificationTypes called: %d", notificationTypes]];
    
    if (![OneSignalHelper isIOSVersionGreaterOrEqual:10]) {
        NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
        [userDefaults setBool:true forKey:@"OS_NOTIFICATION_PROMPT_ANSWERED"];
        [userDefaults synchronize];
    }
    
    BOOL startedRegister = [self registerForAPNsToken];
    
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"startedRegister: %d", startedRegister]];
    
    if (mSubscriptionStatus == -2)
        return;
    
    if (!mUserId && !startedRegister)
        [OneSignal registerUser];
    else if (mDeviceToken)
        [self sendNotificationTypesUpdate];
    
    if ([self getUsableDeviceToken])
        [self fireIdsAvailableCallback];
}

+ (void)didRegisterForRemoteNotifications:(UIApplication*)app deviceToken:(NSData*)inDeviceToken {
    NSString* trimmedDeviceToken = [[inDeviceToken description] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"<>"]];
    NSString* parsedDeviceToken = [[trimmedDeviceToken componentsSeparatedByString:@" "] componentsJoinedByString:@""];
    [OneSignal onesignal_Log:ONE_S_LL_INFO message: [NSString stringWithFormat:@"Device Registered with Apple: %@", parsedDeviceToken]];
    [OneSignal registerDeviceToken:parsedDeviceToken onSuccess:^(NSDictionary* results) {
        [OneSignal onesignal_Log:ONE_S_LL_INFO message:[NSString stringWithFormat: @"Device Registered with OneSignal: %@", mUserId]];
    } onFailure:^(NSError* error) {
        [OneSignal onesignal_Log:ONE_S_LL_ERROR message:[NSString stringWithFormat: @"Error in OneSignal Registration: %@", error]];
    }];
}
    
+ (BOOL)remoteSilentNotification:(UIApplication*)application UserInfo:(NSDictionary*)userInfo completionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
    BOOL startedBackgroundJob = false;
    
    NSDictionary* data = nil;
    
    // Check for buttons or attachments pre-2.4.0 version
    if ((userInfo[@"os_data"][@"buttons"] && [userInfo[@"os_data"][@"buttons"] isKindOfClass:[NSDictionary class]]) || userInfo[@"at"] || userInfo[@"o"])
        data = userInfo;
    
    // Generate local notification for action button and/or attachments.
    if (data) {
        // iOS 10
        if (NSClassFromString(@"UNUserNotificationCenter")) {
            startedBackgroundJob = true;
            #if XC8_AVAILABLE
            [OneSignalHelper addnotificationRequest:data userInfo:userInfo completionHandler:completionHandler];
            #endif
        }
        else { // Pre-iOS 10
            UILocalNotification* notification = [OneSignalHelper prepareUILocalNotification:data :userInfo];
            [[UIApplication sharedApplication] scheduleLocalNotification:notification];
        }
    }
    // Method was called due to a tap on a notification - Fire open notification
    else if (application.applicationState != UIApplicationStateBackground) {
        [OneSignalHelper lastMessageReceived:userInfo];
        if (application.applicationState == UIApplicationStateActive)
            [OneSignalHelper handleNotificationReceived:OSNotificationDisplayTypeNotification];
        [OneSignal notificationOpened:userInfo isActive:NO];
        return startedBackgroundJob;
    }
    // content-available notification received in the background - Fire handleNotificationReceived block in app
    else {
        [OneSignalHelper lastMessageReceived:userInfo];
        if ([OneSignalHelper isRemoteSilentNotification:userInfo])
            [OneSignalHelper handleNotificationReceived:OSNotificationDisplayTypeNone];
        else
            [OneSignalHelper handleNotificationReceived:OSNotificationDisplayTypeNotification];
    }
    
    return startedBackgroundJob;
}

// iOS 8-9 - Entry point when OneSignal action button notification is displayed or opened.
+ (void)processLocalActionBasedNotification:(UILocalNotification*) notification identifier:(NSString*)identifier {
    if (notification.userInfo) {
        
        NSMutableDictionary* userInfo = [OneSignalHelper formatApsPayloadIntoStandard:notification.userInfo identifier:identifier];
        
        if (!userInfo)
            return;
        
        BOOL isActive = [[UIApplication sharedApplication] applicationState] == UIApplicationStateActive;
        [OneSignal notificationOpened:userInfo isActive:isActive];
        
        // Notification Tapped or notification Action Tapped
        if (!isActive)
            [self handleNotificationOpened:userInfo isActive:isActive actionType:OSNotificationActionTypeActionTaken displayType:OSNotificationDisplayTypeNotification];
    }
    
}

+ (void)syncHashedEmail:(NSString *)email {
    if (!email)
        return;
    
    NSString *trimmedEmail = [email stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    
    if (![OneSignalHelper isValidEmail:trimmedEmail])
        return;
    
    if (mUserId == nil) {
        emailToSet = email;
        return;
    }
    
    NSString* lowEmail = [trimmedEmail lowercaseString];
    NSString* md5 = [OneSignalHelper hashUsingMD5:lowEmail];
    NSString* sha1 = [OneSignalHelper hashUsingSha1:lowEmail];
    
    onesignal_Log(ONE_S_LL_DEBUG, [NSString stringWithFormat:@"%@ - MD5: %@, SHA1:%@", lowEmail, md5, sha1]);
    
    NSMutableURLRequest* request = [httpClient requestWithMethod:@"PUT" path:[NSString stringWithFormat:@"players/%@", mUserId]];
    NSDictionary* dataDic = [NSDictionary dictionaryWithObjectsAndKeys:
                            app_id, @"app_id",
                            md5, @"em_m",
                            sha1, @"em_s",
                            [OneSignalHelper getNetType], @"net_type",
                            nil];
    NSData* postData = [NSJSONSerialization dataWithJSONObject:dataDic options:0 error:nil];
    [request setHTTPBody:postData];
    
    [OneSignalHelper enqueueRequest:request
                onSuccess:nil
               onFailure:nil];
}

+ (void)addActionButtonsToExtentionRequest:(UNNotificationRequest *)request withMutableNotificationContent:(UNMutableNotificationContent*)replacementContent {
    if (request.content.categoryIdentifier && ![request.content.categoryIdentifier isEqualToString:@""])
        return;
    
    NSArray* buttonsPayloadList = request.content.userInfo[@"os_data"][@"buttons"];
    if (!buttonsPayloadList)
        buttonsPayloadList = request.content.userInfo[@"buttons"];
    
    if (buttonsPayloadList)
        [OneSignalHelper addActionButtons:buttonsPayloadList toNotificationContent:replacementContent];
}

// Called from the app's Notification Service Extension
+ (UNMutableNotificationContent*)didReceiveNotificationExtensionRequest:(UNNotificationRequest *)request withMutableNotificationContent:(UNMutableNotificationContent*)replacementContent {
    if (!replacementContent)
        replacementContent = [request.content mutableCopy];
    
    // Action Buttons
    [self addActionButtonsToExtentionRequest:request withMutableNotificationContent:replacementContent];
    
    // Media Attachments
    NSDictionary* attachments = request.content.userInfo[@"os_data"][@"att"];
    if (!attachments)
        attachments = request.content.userInfo[@"att"];
    if (attachments)
        [OneSignalHelper addAttachments:attachments toNotificationContent:replacementContent];
    
    return replacementContent;
}


// Called from the app's Notification Service Extension
+ (UNMutableNotificationContent*)serviceExtensionTimeWillExpireRequest:(UNNotificationRequest *)request withMutableNotificationContent:(UNMutableNotificationContent*)replacementContent {
    if (!replacementContent)
        replacementContent = [request.content mutableCopy];
    
    [self addActionButtonsToExtentionRequest:request withMutableNotificationContent:replacementContent];
    
    return replacementContent;
}


@end

// Swizzles UIApplication class to swizzling the following:
//   - UIApplication
//      - setDelegate:
//        - Used to swizzle all UIApplicationDelegate selectors on the passed in class.
//        - Almost always this is the AppDelegate class but since UIApplicationDelegate is an "interface" this could be any class.
//   - UNUserNotificationCenter
//     - setDelegate:
//        - For iOS 10 only, swizzle all UNUserNotificationCenterDelegate selectors on the passed in class.
//         -  This may or may not be set so we set our own now in registerAsUNNotificationCenterDelegate to an empty class.
//
//  Note1: Do NOT move this category to it's own file. This is required so when the app developer calls OneSignal.initWithLaunchOptions this load+
//            will fire along with it. This is due to how iOS loads .m files into memory instead of classes.
//  Note2: Do NOT directly add swizzled selectors to this category as if this class is loaded into the runtime twice unexpected results will occur.
//            The oneSignalLoadedTagSelector: selector is used a flag to prevent double swizzling if this library is loaded twice.
@implementation UIApplication (OneSignal)
#define SYSTEM_VERSION_LESS_THAN_OR_EQUAL_TO(v)     ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedDescending)
+ (void)load {
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"UIApplication(OneSignal) LOADED!"];
    
    // Prevent Xcode storyboard rendering process from crashing with custom IBDesignable Views
    // https://github.com/OneSignal/OneSignal-iOS-SDK/issues/160
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    if ([[processInfo processName] isEqualToString:@"IBDesignablesAgentCocoaTouch"])
        return;
    
    if (SYSTEM_VERSION_LESS_THAN_OR_EQUAL_TO(@"7.0"))
        return;

    // Double loading of class detection.
    BOOL existing = injectSelector([OneSignalAppDelegate class], @selector(oneSignalLoadedTagSelector:), self, @selector(oneSignalLoadedTagSelector:));
    if (existing) {
        [OneSignal onesignal_Log:ONE_S_LL_WARN message:@"Already swizzled UIApplication.setDelegate. Make sure the OneSignal library wasn't loaded into the runtime twice!"];
        return;
    }

    // Swizzle - UIApplication delegate
    injectToProperClass(@selector(setOneSignalDelegate:), @selector(setDelegate:), @[], [OneSignalAppDelegate class], [UIApplication class]);
    
    // Swizzle - iOS 10 - UNUserNotificationCenter delegate
    #if XC8_AVAILABLE
    Class UNUserNotificationCenterClass = NSClassFromString(@"UNUserNotificationCenter");
    if (!UNUserNotificationCenterClass)
        return;
    
    injectToProperClass(@selector(setOneSignalUNDelegate:), @selector(setDelegate:), @[], [swizzleUNUserNotif class], UNUserNotificationCenterClass);
    
    // Set our own delegate if one hasn't been set already from something else.
    [OneSignalHelper registerAsUNNotificationCenterDelegate];
    #endif
}

@end


#pragma clang diagnostic pop
#pragma clang diagnostic pop
