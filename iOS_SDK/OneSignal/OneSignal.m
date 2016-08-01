/**
 * Copyright 2015 OneSignal
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import "OneSignal.h"
#import "OneSignalHTTPClient.h"
#import "OneSignalTrackIAP.h"
#import "OneSignalLocation.h"
#import "OneSignalReachability.h"
#import "OneSignalJailbreakDetection.h"
#import "OneSignalMobileProvision.h"
#import "OneSignalAlertViewDelegate.h"
#import "OneSignalHelper.h"
#import "NSObject+Extras.h"
#import "NSString+Hash.h"

#import <stdlib.h>
#import <stdio.h>
#import <sys/types.h>
#import <sys/utsname.h>
#import <sys/sysctl.h>
#import <objc/runtime.h>

#define DEFAULT_PUSH_HOST @"https://onesignal.com/api/v1/"

#define NOTIFICATION_TYPE_BADGE 1
#define NOTIFICATION_TYPE_SOUND 2
#define NOTIFICATION_TYPE_ALERT 4
#define NOTIFICATION_TYPE_ALL 7

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

typedef struct os_location_coordinate {
    double latitude;
    double longitude;
} os_location_coordinate;

typedef struct os_last_location {
    os_location_coordinate cords;
    double verticalAccuracy;
    double horizontalAccuracy;
} os_last_location;

static ONE_S_LOG_LEVEL _nsLogLevel = ONE_S_LL_WARN;
static ONE_S_LOG_LEVEL _visualLogLevel = ONE_S_LL_NONE;

NSString * const kOSSettingsKeyAutoPrompt = @"kOSSettingsKeyAutoPrompt";

/*Enable the default in-app alerts*/
NSString * const kOSSettingsKeyInAppAlerts = @"kOSSettingsKeyInAppAlerts";


@implementation OneSignal
    
NSString* const ONESIGNAL_VERSION = @"020000";

static bool registeredWithApple = false; //Has attempted to register for push notifications with Apple.
static OneSignalTrackIAP* trackIAPPurchase;
static NSString* app_id;
    
NSNumber* lastTrackedTime;
NSNumber* unSentActiveTime;
NSString* emailToSet;
NSMutableDictionary* tagsToSend;
os_last_location *lastLocation;
BOOL location_event_fired;
NSString* mUserId;
NSString* mDeviceToken;
BOOL waitingForOneSReg = NO;
OneSignalHTTPClient *httpClient;
OSResultSuccessBlock tokenUpdateSuccessBlock;
OSFailureBlock tokenUpdateFailureBlock;
int mNotificationTypes = -1;
OSIdsAvailableBlock idsAvailableBlockWhenReady;
NSString* mSDKType = @"native";
UIBackgroundTaskIdentifier focusBackgroundTask;
NSNumber* timeToPingWith;
bool disableBadgeClearing = NO;
bool mSubscriptionSet;

//Set to yes whenever a high priority registration fails ... need to make the next one a high priority to disregard the 1 hour timer delay
bool nextRegistrationIsHighPriority = NO;
    
+ (NSString*)app_id {
    return app_id;
}
    
+ (id)initWithLaunchOptions:(NSDictionary*)launchOptions appId:(NSString*)appId {
    return [self initWithLaunchOptions: launchOptions appId: appId handleNotificationReceived: NULL handleNotificationAction : NULL settings: @{kOSSettingsKeyAutoPrompt : @YES, kOSSettingsKeyInAppAlerts : @YES}];
}

+ (id)initWithLaunchOptions:(NSDictionary*)launchOptions appId:(NSString*)appId handleNotificationAction:(OSHandleNotificationActionBlock)actionCallback {
    return [self initWithLaunchOptions: launchOptions appId: appId handleNotificationReceived: NULL handleNotificationAction : actionCallback settings: @{kOSSettingsKeyAutoPrompt : @YES, kOSSettingsKeyInAppAlerts : @YES}];
}

+ (id)initWithLaunchOptions:(NSDictionary*)launchOptions appId:(NSString*)appId handleNotificationAction:(OSHandleNotificationActionBlock)actionCallback settings:(NSDictionary*)settings {
    return [self initWithLaunchOptions: launchOptions appId: appId handleNotificationReceived: NULL handleNotificationAction : actionCallback settings: settings];
}

+ (id)initWithLaunchOptions:(NSDictionary*)launchOptions appId:(NSString*)appId handleNotificationReceived:(OSHandleNotificationReceivedBlock)receivedCallback handleNotificationAction:(OSHandleNotificationActionBlock)actionCallback settings:(NSDictionary*)settings {
    
    if (![[NSUUID alloc] initWithUUIDString:appId]) {
        onesignal_Log(ONE_S_LL_FATAL, @"OneSignal AppId format is invalid.\nExample: 'b2f7f966-d8cc-11eg-bed1-df8f05be55ba'\n");
        return self;
    }
    
    if ([@"b2f7f966-d8cc-11eg-bed1-df8f05be55ba" isEqualToString:appId] || [@"5eb5a37e-b458-11e3-ac11-000c2940e62c" isEqualToString:appId])
        onesignal_Log(ONE_S_LL_WARN, @"OneSignal Example AppID detected, please update to your app's id found on OneSignal.com");
    
    [OneSignalLocation getLocation:self prompt:false];
    
    if (self) {
        
        [OneSignalHelper notificationBlocks: receivedCallback : actionCallback];
        lastTrackedTime = [NSNumber numberWithLongLong:[[NSDate date] timeIntervalSince1970]];
        
        if (appId)
            app_id = appId;
        else {
            app_id =[[NSBundle mainBundle] objectForInfoDictionaryKey:@"OneSignal_APPID"];
            if (app_id == nil)
                app_id = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"GameThrive_APPID"];
        }
        
        NSURL* url = [NSURL URLWithString:[NSString stringWithFormat:@"%@", DEFAULT_PUSH_HOST]];
        httpClient = [[OneSignalHTTPClient alloc] initWithBaseURL:url];
        
        // Handle changes to the app id. This might happen on a developer's device when testing.
        if (app_id == nil)
            app_id  = [[NSUserDefaults standardUserDefaults] stringForKey:@"GT_APP_ID"];
        else if (![app_id isEqualToString:[[NSUserDefaults standardUserDefaults] stringForKey:@"GT_APP_ID"]]) {
            [[NSUserDefaults standardUserDefaults] setObject:app_id forKey:@"GT_APP_ID"];
            [[NSUserDefaults standardUserDefaults] setObject:nil forKey:@"GT_PLAYER_ID"];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }
        
        mUserId = [[NSUserDefaults standardUserDefaults] stringForKey:@"GT_PLAYER_ID"];
        mDeviceToken = [[NSUserDefaults standardUserDefaults] stringForKey:@"GT_DEVICE_TOKEN"];
        if (([[UIApplication sharedApplication] respondsToSelector:@selector(currentUserNotificationSettings)]))
            registeredWithApple = [[UIApplication sharedApplication] currentUserNotificationSettings].types != (NSUInteger)nil;
        else
            registeredWithApple = mDeviceToken != nil || [[NSUserDefaults standardUserDefaults] boolForKey:@"GT_REGISTERED_WITH_APPLE"];
        mSubscriptionSet = [[NSUserDefaults standardUserDefaults] objectForKey:@"ONESIGNAL_SUBSCRIPTION"] == nil;
        mNotificationTypes = [self getNotificationTypes];
        
        //Check if in-app setting passed assigned
        if([settings[kOSSettingsKeyInAppAlerts] isKindOfClass:[NSNumber class]])
            [self enableInAppAlertNotification:[settings[kOSSettingsKeyInAppAlerts] boolValue]];
        
        // Register this device with Apple's APNS server.
        if (settings[kOSSettingsKeyAutoPrompt] || registeredWithApple)
            [self registerForPushNotifications];
        // iOS 8 - Register for remote notifications to get a token now since registerUserNotificationSettings is what shows the prompt.
        else if ([[UIApplication sharedApplication] respondsToSelector:@selector(registerForRemoteNotifications)])
            [[UIApplication sharedApplication] registerForRemoteNotifications];
        
        if (mUserId != nil) {
            if(nextRegistrationIsHighPriority || (mDeviceToken == nil && mNotificationTypes > 0) )
                [OneSignal registerUser:@YES];
            else [OneSignal registerUser:@NO];
        }
        else // Fall back incase Apple does not responsed in time.
            [self performSelector:@selector(registerUser:) withObject:@NO afterDelay:30.0f];
    }
    
    //If app opened from tap on notification or action
    NSDictionary* userInfo = [launchOptions objectForKey:UIApplicationLaunchOptionsRemoteNotificationKey];
    if(userInfo) {
        OSNotificationActionType type = Opened;
        if(userInfo[@"custom"][@"a"][@"actionSelected"] || userInfo[@"actionSelected"])
            type = ActionTaken;
        [self handleNotificationOpened:userInfo isActive:NO actionType:type displayType:Notification];
    }
    
    [self clearBadgeCount:false];
    
    if ([OneSignalTrackIAP canTrack])
        trackIAPPurchase = [[OneSignalTrackIAP alloc] init];
    
    if (NSFoundationVersionNumber >= NSFoundationVersionNumber10_0) {
        [OneSignalHelper registerAsUNNotificationCenterDelegate];
        [OneSignalHelper clearCachedMedia];
    }
    
    return self;
}

+ (void)setLogLevel:(ONE_S_LOG_LEVEL)nsLogLevel visualLevel:(ONE_S_LOG_LEVEL)visualLogLevel {
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
        UIAlertView* alertView = [[UIAlertView alloc] initWithTitle:levelString
                                                            message:message
                                                           delegate:nil
                                                  cancelButtonTitle:@"Close"
                                                  otherButtonTitles:nil, nil];
        [alertView show];
    }
    
}

// "registerForRemoteNotifications*" calls didRegisterForRemoteNotificationsWithDeviceToken
// in the implementation UIApplication(OneSignalPush) below after contacting Apple's server.
+ (void)registerForPushNotifications {

    [OneSignalHelper requestAuthorization];
    
    // For iOS 8 devices
    if ([[UIApplication sharedApplication] respondsToSelector:@selector(registerUserNotificationSettings:)]) {
        // ClassFromString to work around pre Xcode 6 link errors when building an app using the OneSignal framework.
        Class uiUserNotificationSettings = NSClassFromString(@"UIUserNotificationSettings");
        NSUInteger notificationTypes = NOTIFICATION_TYPE_ALL;
        
        [[UIApplication sharedApplication] registerUserNotificationSettings:[uiUserNotificationSettings settingsForTypes:notificationTypes categories:nil]];
        [[UIApplication sharedApplication] registerForRemoteNotifications];
    }
    else { // For iOS 6 & 7 devices
        [[UIApplication sharedApplication] registerForRemoteNotificationTypes:UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeSound | UIRemoteNotificationTypeAlert];
        if (!registeredWithApple) {
            [[NSUserDefaults standardUserDefaults] setObject:@YES forKey:@"GT_REGISTERED_WITH_APPLE"];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }
    }
}

+ (void)IdsAvailable:(OSIdsAvailableBlock)idsAvailableBlock {
    if (mUserId)
        idsAvailableBlock(mUserId, [self getUsableDeviceToken]);
    
    if (mUserId == nil || [self getUsableDeviceToken] == nil)
        idsAvailableBlockWhenReady = idsAvailableBlock;
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
   
    if (mUserId == nil) {
        if (tagsToSend == nil)
            tagsToSend = [keyValuePair mutableCopy];
        else
            [tagsToSend addEntriesFromDictionary:keyValuePair];
        return;
    }
    
    NSMutableURLRequest* request = [httpClient requestWithMethod:@"PUT" path:[NSString stringWithFormat:@"players/%@", mUserId]];
    
    NSDictionary* dataDic = [NSDictionary dictionaryWithObjectsAndKeys:
                             app_id, @"app_id",
                             keyValuePair, @"tags",
                             [OneSignalHelper getNetType], @"net_type",
                             nil];
    
    NSData* postData = [NSJSONSerialization dataWithJSONObject:dataDic options:0 error:nil];
    [request setHTTPBody:postData];
    
    [OneSignalHelper enqueueRequest:request
               onSuccess:successBlock
               onFailure:failureBlock];
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

+ (void)deleteTags:(NSArray*)keys onSuccess:(OSResultSuccessBlock)successBlock onFailure:(OSFailureBlock)failureBlock {
    
    if (mUserId == nil)
        return;
    
    NSMutableURLRequest* request;
    request = [httpClient requestWithMethod:@"PUT" path:[NSString stringWithFormat:@"players/%@", mUserId]];
    
    NSMutableDictionary* deleteTagsDict = [NSMutableDictionary dictionary];
    for(id key in keys)
        [deleteTagsDict setObject:@"" forKey:key];
    
    NSDictionary* dataDic = [NSDictionary dictionaryWithObjectsAndKeys:
                             app_id, @"app_id",
                             deleteTagsDict, @"tags",
                             nil];
    
    NSData* postData = [NSJSONSerialization dataWithJSONObject:dataDic options:0 error:nil];
    [request setHTTPBody:postData];
    
    [OneSignalHelper enqueueRequest:request onSuccess:successBlock onFailure:failureBlock];
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
        onesignal_Log(ONE_S_LL_WARN,[NSString stringWithFormat: @"postNotification JSON Parse Error: %@", jsonError]);
        onesignal_Log(ONE_S_LL_WARN,[NSString stringWithFormat: @"postNotification JSON Parse Error, JSON: %@", jsonString]);
    }
}

+ (void)enableInAppAlertNotification:(BOOL)enable {
    [[NSUserDefaults standardUserDefaults] setBool:enable forKey:@"ONESIGNAL_INAPP_ALERT"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (void)setSubscription:(BOOL)enable {
    NSString* value = nil;
    if (!enable)
        value = @"no";

    [[NSUserDefaults standardUserDefaults] setObject:value forKey:@"ONESIGNAL_SUBSCRIPTION"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    mSubscriptionSet = enable;
    
    [OneSignal sendNotificationTypesUpdateIsConfirmed:false];
}

+ (void) promptLocation {
    [OneSignalLocation getLocation:self prompt:true];
}
    
+ (void)registerDeviceToken:(id)inDeviceToken onSuccess:(OSResultSuccessBlock)successBlock onFailure:(OSFailureBlock)failureBlock {
    [self updateDeviceToken:inDeviceToken onSuccess:successBlock onFailure:failureBlock];
    
    [[NSUserDefaults standardUserDefaults] setObject:mDeviceToken forKey:@"GT_DEVICE_TOKEN"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}
    
+ (void)updateDeviceToken:(NSString*)deviceToken onSuccess:(OSResultSuccessBlock)successBlock onFailure:(OSFailureBlock)failureBlock {
    
    if (mUserId == nil) {
        mDeviceToken = deviceToken;
        tokenUpdateSuccessBlock = successBlock;
        tokenUpdateFailureBlock = failureBlock;
        
        // iOS 8 - We get a token right away but give the user 20 sec to responsed to the system prompt.
        // Also check mNotificationTypes so there is no waiting if user has already answered the system prompt.
        // The goal is to only have 1 server call.
        if ([OneSignalHelper isCapableOfGettingNotificationTypes] && mNotificationTypes == -1) {
            [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(registerUser:) object:@YES];
            [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(registerUser:) object:@NO];
            [self performSelector:@selector(registerUser:) withObject:@YES afterDelay:20.0f];
        }
        else
            [OneSignal registerUser:@YES];
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
    
    NSDictionary* dataDic = [NSDictionary dictionaryWithObjectsAndKeys:
                             app_id, @"app_id",
                             deviceToken, @"identifier",
                             nil];
    
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"Calling OneSignal PUT updated pushToken!"];
    
    NSData* postData = [NSJSONSerialization dataWithJSONObject:dataDic options:0 error:nil];
    [request setHTTPBody:postData];
    
    [OneSignalHelper enqueueRequest:request onSuccess:successBlock onFailure:failureBlock];
    
    if (idsAvailableBlockWhenReady) {
        mNotificationTypes = [self getNotificationTypes];
        if ([self getUsableDeviceToken])
        idsAvailableBlockWhenReady(mUserId, [self getUsableDeviceToken]);
        idsAvailableBlockWhenReady = nil;
    }
}
    
+ (void)registerUser:(NSNumber*)isHighPriority {
    
    // Make sure we only call create or on_session once per run of the app.
    if (waitingForOneSReg)
        return;
    
    
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    if(![isHighPriority boolValue] && mUserId) {
        //Make sure last time we called on_session was no more than an hour ago
        const NSTimeInterval minTimeThreshold = 3600;
        NSTimeInterval lastTimeRegistered = [[NSUserDefaults standardUserDefaults] doubleForKey:@"LAST_REGISTERED_TIME"];
        if(lastTimeRegistered)
            if((now - lastTimeRegistered) < minTimeThreshold) return;
        
    }
    
    
    waitingForOneSReg = true;
    
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
                                    [[NSLocale preferredLanguages] objectAtIndex:0], @"language",
                                    [NSNumber numberWithInt:(int)[[NSTimeZone localTimeZone] secondsFromGMT]], @"timezone",
                                    [NSNumber numberWithInt:0], @"device_type",
                                    [[[UIDevice currentDevice] identifierForVendor] UUIDString], @"ad_id",
                                    ONESIGNAL_VERSION, @"sdk",
                                    mDeviceToken, @"identifier", // identifier MUST be at the end as it could be nil.
                                    nil];
    
    if (build)
        dataDic[@"game_version"] = build;
    
    mNotificationTypes = [self getNotificationTypes];
    
    if ([OneSignalJailbreakDetection isJailbroken])
        dataDic[@"rooted"] = @YES;
    
    dataDic[@"net_type"] = [OneSignalHelper getNetType];
    
    if (mUserId == nil) {
        dataDic[@"sdk_type"] = mSDKType;
        dataDic[@"ios_bundle"] = [[NSBundle mainBundle] bundleIdentifier];
    }
    
    
    if (mNotificationTypes != -1)
        dataDic[@"notification_types"] = [NSNumber numberWithInt:mNotificationTypes];
    
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
    
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"Calling OneSignal create/on_session"];
    
    NSData* postData = [NSJSONSerialization dataWithJSONObject:dataDic options:0 error:nil];
    [request setHTTPBody:postData];
    
    if (lastLocation) {
        dataDic[@"lat"] = [NSNumber numberWithDouble:lastLocation->cords.latitude];
        dataDic[@"long"] = [NSNumber numberWithDouble:lastLocation->cords.longitude];
        dataDic[@"loc_acc_vert"] = [NSNumber numberWithDouble:lastLocation->verticalAccuracy];
        dataDic[@"loc_acc"] = [NSNumber numberWithDouble:lastLocation->horizontalAccuracy];
        lastLocation = nil;
    }
    
    [OneSignalHelper enqueueRequest:request onSuccess:^(NSDictionary* results) {
        
        waitingForOneSReg = false;
        
        //Success, no more high priority
        nextRegistrationIsHighPriority = NO;
        
        
        //Set last time registered
        [[NSUserDefaults standardUserDefaults] setDouble:now forKey:@"LAST_REGISTERED_TIME"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        if ([results objectForKey:@"id"] != nil) {
            
            mUserId = [results objectForKey:@"id"];
            [[NSUserDefaults standardUserDefaults] setObject:mUserId forKey:@"GT_PLAYER_ID"];
            [[NSUserDefaults standardUserDefaults] synchronize];
            
            if (mDeviceToken)
            [self updateDeviceToken:mDeviceToken onSuccess:tokenUpdateSuccessBlock onFailure:tokenUpdateFailureBlock];
            
            
            if (tagsToSend) {
                [OneSignal sendTags:tagsToSend];
                tagsToSend = nil;
            }
            
            if (lastLocation) {
                [self sendLocation:lastLocation];
                lastLocation = nil;
            }
            
            if (emailToSet) {
                [OneSignal syncHashedEmail:emailToSet];
                emailToSet = nil;
            }
            
            if (idsAvailableBlockWhenReady) {
                idsAvailableBlockWhenReady(mUserId, [self getUsableDeviceToken]);
                if ([self getUsableDeviceToken])
                idsAvailableBlockWhenReady = nil;
            }
        }
    } onFailure:^(NSError* error) {
        waitingForOneSReg = false;
        [OneSignal onesignal_Log:ONE_S_LL_ERROR message:[NSString stringWithFormat: @"Error registering with OneSignal: %@", error]];
        
        //If the failed regiatration is priority, force the next one to be a high priority
        nextRegistrationIsHighPriority = YES;
    }];
}
    
+(NSString*) getUsableDeviceToken {
    if (mNotificationTypes > 0)
        return mDeviceToken;
    return nil;
}
    
+ (void) sendNotificationTypesUpdateIsConfirmed:(BOOL)isConfirm {
    // User changed notification settings for the app.
    if (mNotificationTypes != -1 && mUserId && (isConfirm || mNotificationTypes != [self getNotificationTypes])) {
        mNotificationTypes = [self getNotificationTypes];
        NSMutableURLRequest* request = [httpClient requestWithMethod:@"PUT" path:[NSString stringWithFormat:@"players/%@", mUserId]];
        
        NSDictionary* dataDic = [NSDictionary dictionaryWithObjectsAndKeys:
                                 app_id, @"app_id",
                                 [NSNumber numberWithInt:mNotificationTypes], @"notification_types",
                                 nil];
        
        NSData* postData = [NSJSONSerialization dataWithJSONObject:dataDic options:0 error:nil];
        [request setHTTPBody:postData];
        
        [OneSignalHelper enqueueRequest:request onSuccess:nil onFailure:nil];
        
        if ([self getUsableDeviceToken] && idsAvailableBlockWhenReady) {
            idsAvailableBlockWhenReady(mUserId, [self getUsableDeviceToken]);
            idsAvailableBlockWhenReady = nil;
        }
    }
    
}
    
+ (void) beginBackgroundFocusTask {
    focusBackgroundTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [OneSignal endBackgroundFocusTask];
    }];
}
    
+ (void) endBackgroundFocusTask {
    [[UIApplication sharedApplication] endBackgroundTask: focusBackgroundTask];
    focusBackgroundTask = UIBackgroundTaskInvalid;
}
    
+ (void)onFocus:(NSString*)state {
    bool wasBadgeSet = false;
    
    if ([state isEqualToString:@"resume"]) {
        lastTrackedTime = [NSNumber numberWithLongLong:[[NSDate date] timeIntervalSince1970]];
        
        [self sendNotificationTypesUpdateIsConfirmed:false];
        wasBadgeSet = [self clearBadgeCount:false];
        
        //Try to register user.
        if(nextRegistrationIsHighPriority || !mUserId)
            [OneSignal registerUser:@YES];
        else [OneSignal registerUser:@NO];
    }
    else {
        NSNumber* timeElapsed = @(([[NSDate date] timeIntervalSince1970] - [lastTrackedTime longLongValue]) + 0.5);
        if ([timeElapsed intValue] < 0 || [timeElapsed intValue] > 604800)
        return;
        
        NSNumber* unsentActive = [OneSignal getUnsentActiveTime];
        NSNumber* totalTimeActive = @([unsentActive intValue] + [timeElapsed intValue]);
        
        if ([totalTimeActive intValue] < 30) {
            [OneSignal saveUnsentActiveTime:totalTimeActive];
            return;
        }
        
        timeToPingWith = totalTimeActive;
    }
    
    if (mUserId == nil)
    return;
    
    // If resuming and badge was set, clear it on the server as well.
    if (wasBadgeSet && [state isEqualToString:@"resume"]) {
        NSMutableURLRequest* request = [httpClient requestWithMethod:@"PUT" path:[NSString stringWithFormat:@"players/%@", mUserId]];
        
        NSDictionary* dataDic = [NSDictionary dictionaryWithObjectsAndKeys:
                                 app_id, @"app_id",
                                 @0, @"badge_count",
                                 nil];
        
        NSData* postData = [NSJSONSerialization dataWithJSONObject:dataDic options:0 error:nil];
        [request setHTTPBody:postData];
        
        [OneSignalHelper enqueueRequest:request onSuccess:nil onFailure:nil];
        return;
    }
    
    // Update the playtime on the server when the app put into the background or the device goes to sleep mode.
    if ([state isEqualToString:@"suspend"]) {
        [self saveUnsentActiveTime:0];
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self beginBackgroundFocusTask];
            
            
            
            NSMutableURLRequest* request = [httpClient requestWithMethod:@"POST" path:[NSString stringWithFormat:@"players/%@/on_focus", mUserId]];
            NSDictionary* dataDic = [NSDictionary dictionaryWithObjectsAndKeys:
                                     app_id, @"app_id",
                                     @"ping", @"state",
                                     timeToPingWith, @"active_time",
                                     [OneSignalHelper getNetType], @"net_type",
                                     nil];
            
            NSData* postData = [NSJSONSerialization dataWithJSONObject:dataDic options:0 error:nil];
            [request setHTTPBody:postData];
            
            // We are already running in a thread so send the request synchronous to keep the thread alive.
            [OneSignalHelper enqueueRequest:request
                       onSuccess:nil
                       onFailure:nil
                   isSynchronous:true];
            [self endBackgroundFocusTask];
        });
    }
}
    
+ (NSNumber*)getUnsentActiveTime {
    if (unSentActiveTime == NULL) {
        unSentActiveTime = [NSNumber numberWithInteger:-1];
    }
    
    
    if ([unSentActiveTime intValue] == -1) {
        unSentActiveTime = [[NSUserDefaults standardUserDefaults] objectForKey:@"GT_UNSENT_ACTIVE_TIME"];
        if (unSentActiveTime == nil)
        unSentActiveTime = 0;
    }
    
    return unSentActiveTime;
}
    
+ (void)saveUnsentActiveTime:(NSNumber*)time {
    unSentActiveTime = time;
    [[NSUserDefaults standardUserDefaults] setObject:time forKey:@"GT_UNSENT_ACTIVE_TIME"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
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
    
+ (void)notificationOpened:(NSDictionary*)messageDict isActive:(BOOL)isActive {
    
    BOOL inAppAlert = false;
    if (isActive) {
        
        if(![[NSUserDefaults standardUserDefaults] objectForKey:@"ONESIGNAL_INAPP_ALERT"]) {
            [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"ONESIGNAL_INAPP_ALERT"];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }
        
        inAppAlert = [[NSUserDefaults standardUserDefaults] boolForKey:@"ONESIGNAL_INAPP_ALERT"];
        
        if (inAppAlert) {
            [OneSignalHelper lastMessageReceived:messageDict];
            
            NSArray<NSString*>* titleAndBody = [OneSignalHelper getPushTitleBody:messageDict];
            

            id oneSignalAlertViewDelegate = [[OneSignalAlertViewDelegate alloc] initWithMessageDict:messageDict];
            
            UIAlertView* alertView = [[UIAlertView alloc] initWithTitle:titleAndBody[0] ? titleAndBody[0] : @""
                                                                message:titleAndBody[1] ? titleAndBody[1] : @""
                                                               delegate:oneSignalAlertViewDelegate
                                                      cancelButtonTitle:@"Close"
                                                      otherButtonTitles:nil, nil];
            
            //Add Buttons
            NSArray *additionalData = [OneSignalHelper getActionButtons];
            if (additionalData) {
                for(id button in additionalData)
                [alertView addButtonWithTitle:button[@"n"]];
            }
            
            [alertView show];
            
            //message received that was displayed (Foreground + InAppAlert is true)
            [OneSignalHelper handleNotificationReceived:InAppAlert];
            
            return;
        }
    }
    else {
        
        
        //app was in background and opened due to a tap on a notification or an action check what type
        NSString* actionSelected = NULL;
        OSNotificationActionType type = Opened;
        if(messageDict[@"custom"][@"a"][@"actionSelected"]) {
            actionSelected = messageDict[@"custom"][@"a"][@"actionSelected"];
            type = ActionTaken;
        }
        if(messageDict[@"actionSelected"]) {
            actionSelected = messageDict[@"actionSelected"];
            type = ActionTaken;
        }
        
        [OneSignalHelper handleNotificationAction:type actionID:actionSelected displayType:Notification];
    }
    
}
    
+ (void) handleNotificationOpened:(NSDictionary*)messageDict isActive:(BOOL)isActive actionType : (OSNotificationActionType)actionType displayType:(OSNotificationDisplayType)displayType{
    
    NSString *messageId, *openUrl;
    
    NSDictionary* customDict = [messageDict objectForKey:@"os_data"];
    if (customDict == nil)
        customDict = [messageDict objectForKey:@"custom"];
    
    messageId = [customDict objectForKey:@"i"];
    openUrl = [customDict objectForKey:@"u"];
    
    NSMutableURLRequest* request = [httpClient requestWithMethod:@"PUT" path:[NSString stringWithFormat:@"notifications/%@", messageId]];
    
    NSDictionary* dataDic = [NSDictionary dictionaryWithObjectsAndKeys:
                             app_id, @"app_id",
                             mUserId, @"player_id",
                             @(YES), @"opened",
                             nil];
    
    NSData* postData = [NSJSONSerialization dataWithJSONObject:dataDic options:0 error:nil];
    [request setHTTPBody:postData];
    
    [OneSignalHelper enqueueRequest:request onSuccess:nil onFailure:nil];
    
    if ([[UIApplication sharedApplication] applicationState] != UIApplicationStateActive && openUrl) {
        
        if ([OneSignalHelper verifyURL:openUrl])
        dispatch_async(dispatch_get_main_queue(), ^{
            NSURL *url = [NSURL URLWithString:openUrl];
            [OneSignalHelper displayWebView:url];
        });
    }
    
    [OneSignalHelper lastMessageReceived:messageDict];
    
    [self clearBadgeCount:true];
    
    
    NSString* actionID = NULL;
    if (actionType == ActionTaken) {
        actionID = messageDict[@"custom"][@"a"][@"actionSelected"];
        if(!actionID)
            actionID = messageDict[@"actionSelected"];
        
        
    }
    
     [OneSignalHelper handleNotificationAction:actionType actionID:actionID displayType:displayType];
}
    
+ (BOOL) clearBadgeCount:(BOOL)fromNotifOpened {
    
    disableBadgeClearing = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"OneSignal_disable_badge_clearing"];
    
    if (disableBadgeClearing || mNotificationTypes == -1 || (mNotificationTypes & NOTIFICATION_TYPE_BADGE) == 0)
    return false;
    
    bool wasBadgeSet = [UIApplication sharedApplication].applicationIconBadgeNumber > 0;
    
    if ((!(NSFoundationVersionNumber > NSFoundationVersionNumber_iOS_7_1) && fromNotifOpened) || wasBadgeSet) {
        // Clear bages and nofiications from this app.
        // Setting to 1 then 0 was needed to clear the notifications on iOS 6 & 7. (Otherwise you can click the notification multiple times.)
        // iOS 8+ auto dismisses the notificaiton you tap on so only clear the badge (and notifications [side-effect]) if it was set.
        [[UIApplication sharedApplication] setApplicationIconBadgeNumber:1];
        [[UIApplication sharedApplication] setApplicationIconBadgeNumber:0];
    }
    
    return wasBadgeSet;
}
    
+ (int) getNotificationTypes {
    if (!mSubscriptionSet)
    return -2;
    
    if (mDeviceToken) {
        if ([OneSignalHelper isCapableOfGettingNotificationTypes])
        return [[UIApplication sharedApplication] currentUserNotificationSettings].types;
        else
        return NOTIFICATION_TYPE_ALL;
    }
    
    return -1;
}

// iOS 8.0+ only
+ (void) updateNotificationTypes:(int)notificationTypes {
    if (mNotificationTypes == -2)
    return;
    
    BOOL changed = (mNotificationTypes != notificationTypes);
    
    mNotificationTypes = notificationTypes;
    
    if (mUserId == nil && mDeviceToken)
        [OneSignal registerUser:@YES];
    else if (mDeviceToken)
        [self sendNotificationTypesUpdateIsConfirmed:changed];
    
    if (idsAvailableBlockWhenReady && mUserId && [self getUsableDeviceToken])
    idsAvailableBlockWhenReady(mUserId, [self getUsableDeviceToken]);
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
    
+ (void) remoteSilentNotification:(UIApplication*)application UserInfo:(NSDictionary*)userInfo {
    // If 'm' present then the notification has action buttons attached to it.
    NSDictionary* data = nil;
    
    if (userInfo[@"os_data"])
        data = userInfo[@"os_data"][@"buttons"];
    else if (userInfo[@"m"])
        data = userInfo;
    
    // - TEMP until server sends special field for attachments
    else if (userInfo[@"custom"][@"a"])
        data = userInfo;
    
    //If buttons -> Data is buttons
    //Otherwise if titles or body or attachment -> data is everything
    if (data) {
        
        if(NSFoundationVersionNumber >= NSFoundationVersionNumber10_0) {
            if([[OneSignalHelper class] respondsToSelector:NSSelectorFromString(@"addnotificationRequest::")]) {
                SEL selector = NSSelectorFromString(@"addnotificationRequest::");
                typedef void(*func)(id, SEL, NSDictionary*, NSDictionary*);
                func methodToCall;
                methodToCall = (func)[[OneSignalHelper class] methodForSelector:selector];
                methodToCall([OneSignalHelper class], selector, data, userInfo);
            }
        }
        else {
            UILocalNotification* notification = [OneSignalHelper prepareUILocalNotification:data :userInfo];
            [[UIApplication sharedApplication] scheduleLocalNotification:notification];
        }
        
    }
    
    else if (application.applicationState != UIApplicationStateBackground)
        [OneSignal notificationOpened:userInfo isActive:YES];
    
    /* Handle the notification reception*/
    [OneSignalHelper lastMessageReceived:userInfo];
    if([OneSignalHelper isRemoteSilentNotification:userInfo])
        [OneSignalHelper handleNotificationReceived:None];
    else [OneSignalHelper handleNotificationReceived:Notification];
}
    
+ (void)processLocalActionBasedNotification:(UILocalNotification*) notification identifier:(NSString*)identifier {
    if (notification.userInfo) {
        NSMutableDictionary* userInfo, *customDict, *additionalData, *optionsDict;
        
        if (notification.userInfo[@"os_data"][@"buttons"]) {
            userInfo = [notification.userInfo mutableCopy];
            additionalData = [NSMutableDictionary dictionary];
            optionsDict = userInfo[@"os_data"][@"buttons"][@"o"];
        }
        else if (notification.userInfo[@"custom"]) {
            userInfo = [notification.userInfo mutableCopy];
            customDict = [userInfo[@"custom"] mutableCopy];
            additionalData = [[NSMutableDictionary alloc] initWithDictionary:customDict[@"a"]];
            optionsDict = userInfo[@"o"];
        }
        else return;
        
        NSMutableArray* buttonArray = [[NSMutableArray alloc] init];
        for (NSDictionary* button in optionsDict) {
            [buttonArray addObject: @{@"text" : button[@"n"],
                                      @"id" : (button[@"i"] ? button[@"i"] : button[@"n"])}];
        }
        additionalData[@"actionSelected"] = identifier;
        additionalData[@"actionButtons"] = buttonArray;
        
        if (notification.userInfo[@"os_data"]) {
            [userInfo addEntriesFromDictionary:additionalData];
            userInfo[@"aps"] = @{@"alert" : userInfo[@"os_data"][@"buttons"][@"m"]};
        }
        else {
            customDict[@"a"] = additionalData;
            userInfo[@"custom"] = customDict;
            
            userInfo[@"aps"] = @{@"alert" : userInfo[@"m"]};
        }
        
        BOOL isActive = [[UIApplication sharedApplication] applicationState] == UIApplicationStateActive;
        [OneSignal notificationOpened:userInfo isActive:isActive];
        //Notification Tapped or notification Action Tapped
        [self handleNotificationOpened:userInfo isActive:isActive actionType:ActionTaken displayType:Notification];
    }
    
}
    
- (void)locationManager:(id)manager didUpdateLocations:(NSArray*)locations {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
    [manager performSelector:@selector(stopUpdatingLocation)];
#pragma clang diagnostic pop
    
    if (location_event_fired)
    return;
    
    location_event_fired = true;
    
    id location = locations.lastObject;
    
    SEL cord_selector = NSSelectorFromString(@"coordinate");
    os_location_coordinate cords;
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[[location class] instanceMethodSignatureForSelector:cord_selector]];
    
    [invocation setTarget:locations.lastObject];
    [invocation setSelector:cord_selector];
    [invocation invoke];
    [invocation getReturnValue:&cords];
    
    os_last_location *currentLocation = (os_last_location*)malloc(sizeof(os_last_location));
    currentLocation->verticalAccuracy = [[location valueForKey:@"verticalAccuracy"] doubleValue];
    currentLocation->horizontalAccuracy = [[location valueForKey:@"horizontalAccuracy"] doubleValue];
    currentLocation->cords = cords;
    
    if (mUserId == nil) {
        lastLocation = currentLocation;
        return;
    }
    
    [OneSignal sendLocation:currentLocation];
}
    
+ (void) sendLocation:(os_last_location*)location {
    
    NSMutableURLRequest* request = [httpClient requestWithMethod:@"PUT" path:[NSString stringWithFormat:@"players/%@", mUserId]];
    
    NSDictionary* dataDic = [NSDictionary dictionaryWithObjectsAndKeys:
                             app_id, @"app_id",
                             [NSNumber numberWithDouble:location->cords.latitude], @"lat",
                             [NSNumber numberWithDouble:location->cords.longitude], @"long",
                             [NSNumber numberWithDouble:location->verticalAccuracy], @"loc_acc_vert",
                             [NSNumber numberWithDouble:location->horizontalAccuracy], @"loc_acc",
                             [OneSignalHelper getNetType], @"net_type",
                             nil];
    
    NSData* postData = [NSJSONSerialization dataWithJSONObject:dataDic options:0 error:nil];
    [request setHTTPBody:postData];
    
    [OneSignalHelper enqueueRequest:request
               onSuccess:nil
               onFailure:nil];
}

static id<OSUserNotificationCenterDelegate> notificationCenterDelegate;

+ (void) setNotificationCenterDelegate:(id<OSUserNotificationCenterDelegate>)delegate {
    if(!NSClassFromString(@"UNNotification")) {
        onesignal_Log(ONE_S_LL_ERROR, @"Cannot assign delegate. Please make sure you are running on iOS 10+.");
        return;
    }
    notificationCenterDelegate = delegate;
}

+ (id<OSUserNotificationCenterDelegate>)notificationCenterDelegate {
    return notificationCenterDelegate;
}

- (void)userNotificationCenter:(id)center didReceiveNotificationResponse:(id)response withCompletionHandler:(void (^)())completionHandler {
    
    NSDictionary* usrInfo = [[[[response performSelector:@selector(notification)] valueForKey:@"request"] valueForKey:@"content"] valueForKey:@"userInfo"];
    if (!usrInfo || [usrInfo count] == 0) {
        [OneSignal tunnelToDelegate:center :response :completionHandler];
        return;
    }
    
    NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] init],
    *customDict = [[NSMutableDictionary alloc] init],
    *additionalData = [[NSMutableDictionary alloc] init];
    NSMutableArray *optionsDict = [[NSMutableArray alloc] init];
    
    NSMutableDictionary* buttonsDict = usrInfo[@"os_data"][@"buttons"];
    NSMutableDictionary* custom = usrInfo[@"custom"];
    if (buttonsDict) {
        [userInfo addEntriesFromDictionary:usrInfo];
        NSArray* o = buttonsDict[@"o"];
        if (o)
            [optionsDict addObjectsFromArray:o];
    }
    
    else if (custom) {
        [userInfo addEntriesFromDictionary:usrInfo];
        [customDict addEntriesFromDictionary:custom];
        NSDictionary *a = customDict[@"a"];
        NSArray *o = userInfo[@"o"];
        if (a)
            [additionalData addEntriesFromDictionary:a];
        if (o)
            [optionsDict addObjectsFromArray:o];
    }
    
    else {
        [OneSignal tunnelToDelegate:center :response :completionHandler];
        return;
    }
    
    NSMutableArray* buttonArray = [[NSMutableArray alloc] init];
    for (NSDictionary* button in optionsDict) {
        NSString * text = button[@"n"] != nil ? button[@"n"] : @"";
        NSString * buttonID = button[@"i"] != nil ? button[@"i"] : text;
        NSDictionary * buttonToAppend = [[NSDictionary alloc] initWithObjects:@[text, buttonID] forKeys:@[@"text", @"id"]];
        [buttonArray addObject:buttonToAppend];
    }
    
    additionalData[@"actionSelected"] = [response valueForKey:@"actionIdentifier"];
    additionalData[@"actionButtons"] = buttonArray;
    
    NSDictionary* os_data = usrInfo[@"os_data"];
    if (os_data) {
        [userInfo addEntriesFromDictionary:os_data];
        if(userInfo[@"os_data"][@"buttons"][@"m"])
            userInfo[@"aps"] = @{@"alert" : userInfo[@"os_data"][@"buttons"][@"m"]};
        [userInfo addEntriesFromDictionary:additionalData];
    }
    else {
        customDict[@"a"] = additionalData;
        userInfo[@"custom"] = customDict;
        if(userInfo[@"m"])
            userInfo[@"aps"] = @{ @"alert" : userInfo[@"m"] };
    }

    BOOL isActive = [UIApplication sharedApplication].applicationState == UIApplicationStateActive;
    
    [OneSignal notificationOpened:userInfo isActive:isActive];
    [OneSignal tunnelToDelegate:center :response :completionHandler];
    
}

+ (void)tunnelToDelegate:(id)center :(id)response :(void (^)())handler {

    if ([[OneSignal notificationCenterDelegate] respondsToSelector:@selector(userNotificationCenter:didReceiveNotificationResponse:withCompletionHandler:)])
        [[OneSignal notificationCenterDelegate] userNotificationCenter:center didReceiveNotificationResponse:response withCompletionHandler:handler];
    else
        handler();
}

-(void)userNotificationCenter:(id)center willPresentNotification:(id)notification withCompletionHandler:(void (^)(NSUInteger options))completionHandler {
    /* Nothing interesting to do here, proxy to user only */
    if ([[OneSignal notificationCenterDelegate] respondsToSelector:@selector(userNotificationCenter:willPresentNotification:withCompletionHandler:)])
        [[OneSignal notificationCenterDelegate] userNotificationCenter:center willPresentNotification:notification withCompletionHandler:completionHandler];        
    else
        //Call the completion handler ourselves
        completionHandler(7);
}

+ (void)syncHashedEmail:(NSString *)email {
    
    if(mUserId == nil) {
        emailToSet = email;
        return;
    }
    
    const NSString* lowEmail = [email lowercaseString];
    const NSString* md5 = [lowEmail md5];
    const NSString* sha1 = [lowEmail sha1];
    
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

#pragma clang diagnostic pop
#pragma clang diagnostic pop
@end
