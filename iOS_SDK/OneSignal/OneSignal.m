/**
 * Copyright 2015 OneSignal
 * Portions Copyright 2014 StackMob
 *
 * This file includes portions from the StackMob iOS SDK and distributed under an Apache 2.0 license.
 * StackMob was acquired by PayPal and ceased operation on May 22, 2014.
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
#import "OneSignalJailbreakDetection.h"
#import "OneSignalReachability.h"
#import "OneSignalMobileProvision.h"

#import <stdlib.h>
#import <stdio.h>
#import <sys/types.h>
#import <sys/sysctl.h>
#import <sys/utsname.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#define DEFAULT_PUSH_HOST @"https://onesignal.com/api/v1/"

NSString* const VERSION = @"010902";

#define NOTIFICATION_TYPE_BADGE 1
#define NOTIFICATION_TYPE_SOUND 2
#define NOTIFICATION_TYPE_ALERT 4
#define NOTIFICATION_TYPE_ALL 7

static OneSignal* defaultClient = nil;
static ONE_S_LOG_LEVEL _nsLogLevel = ONE_S_LL_WARN;
static ONE_S_LOG_LEVEL _visualLogLevel = ONE_S_LL_NONE;

@interface OneSignalAlertViewDelegate : NSObject<UIAlertViewDelegate>
- (id)initWithMessageDict:(NSDictionary*)messageDict OneSignal:oneSignal;
@end

@interface OneSignal ()

@property(nonatomic, readwrite, copy) NSString *app_id;
@property(nonatomic, readwrite, copy) NSDictionary *lastMessageReceived;
@property(nonatomic, readwrite, copy) NSString *deviceModel;
@property(nonatomic, readwrite, copy) NSString *systemVersion;
@property(nonatomic, retain) OneSignalHTTPClient *httpClient;

@end

@implementation OneSignal

@synthesize app_id = _GT_publicKey;
@synthesize httpClient = _GT_httpRequest;
@synthesize lastMessageReceived;

NSMutableDictionary* tagsToSend;

NSString* mDeviceToken;
OneSignalResultSuccessBlock tokenUpdateSuccessBlock;
OneSignalFailureBlock tokenUpdateFailureBlock;
NSString* mUserId;

OneSignalIdsAvailableBlock idsAvailableBlockWhenReady;
OneSignalHandleNotificationBlock handleNotification;

UIBackgroundTaskIdentifier focusBackgroundTask;

OneSignalTrackIAP* trackIAPPurchase;

bool registeredWithApple = false; // Has attempted to register for push notifications with Apple.
bool oneSignalReg = false;
bool waitingForOneSReg = false;
NSNumber* lastTrackedTime;
NSNumber* unSentActiveTime;
NSNumber* timeToPingWith;
int mNotificationTypes = -1;
bool mSubscriptionSet = true;
static NSString* mSDKType = @"native";

+ (void)setMSDKType:(NSString*)str {
    mSDKType = str;
}

- (id)initWithLaunchOptions:(NSDictionary*)launchOptions {
    return [self initWithLaunchOptions:launchOptions appId:nil handleNotification:nil autoRegister:true];
}

- (id)initWithLaunchOptions:(NSDictionary*)launchOptions autoRegister:(BOOL)autoRegister {
    return [self initWithLaunchOptions:launchOptions appId:nil handleNotification:nil autoRegister:autoRegister];
}

- (id)initWithLaunchOptions:(NSDictionary*)launchOptions handleNotification:(OneSignalHandleNotificationBlock)callback {
    return [self initWithLaunchOptions:launchOptions appId:nil handleNotification:callback autoRegister:true];
}

- (id)initWithLaunchOptions:(NSDictionary*)launchOptions appId:(NSString*)appId handleNotification:(OneSignalHandleNotificationBlock)callback {
    return [self initWithLaunchOptions:launchOptions appId:appId handleNotification:callback autoRegister:true];
}

- (id)initWithLaunchOptions:(NSDictionary*)launchOptions appId:(NSString*)appId handleNotification:(OneSignalHandleNotificationBlock)callback autoRegister:(BOOL)autoRegister {
    self = [super init];
    
    if (NSFoundationVersionNumber < NSFoundationVersionNumber_iOS_6_0)
        return self;
    
    if (![[NSUUID alloc] initWithUUIDString:appId]) {
        Log(ONE_S_LL_FATAL, @"OneSignal AppId format is invalid.\nExample: 'b2f7f966-d8cc-11eg-bed1-df8f05be55ba'\n");
        return self;
    }
    
    if ([@"b2f7f966-d8cc-11eg-bed1-df8f05be55ba" isEqualToString:appId] || [@"5eb5a37e-b458-11e3-ac11-000c2940e62c" isEqualToString:appId])
        Log(ONE_S_LL_WARN, @"OneSignal Example AppID detected, please update to your app's id found on OneSignal.com");

    
    if (self) {
        
        handleNotification = callback;
        unSentActiveTime = [NSNumber numberWithInteger:-1];

        lastTrackedTime = [NSNumber numberWithLongLong:[[NSDate date] timeIntervalSince1970]];
        
        if (appId)
            self.app_id = appId;
        else
            self.app_id = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"GameThrive_APPID"];
        
        NSURL* url = [NSURL URLWithString:[NSString stringWithFormat:@"%@", DEFAULT_PUSH_HOST]];
        self.httpClient = [[OneSignalHTTPClient alloc] initWithBaseURL:url];
        
        struct utsname systemInfo;
        uname(&systemInfo);
        self.deviceModel   = [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
        self.systemVersion = [[UIDevice currentDevice] systemVersion];
        
        if ([OneSignal defaultClient] == nil)
            [OneSignal setDefaultClient:self];
        
        // Handle changes to the app id. This might happen on a developer's device when testing.
        NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
        if (self.app_id == nil)
            self.app_id = [defaults stringForKey:@"GT_APP_ID"];
        else if (![self.app_id isEqualToString:[defaults stringForKey:@"GT_APP_ID"]]) {
            [defaults setObject:self.app_id forKey:@"GT_APP_ID"];
            [defaults setObject:nil forKey:@"GT_PLAYER_ID"];
            [defaults synchronize];
        }
        
        mUserId = [defaults stringForKey:@"GT_PLAYER_ID"];
        mDeviceToken = [defaults stringForKey:@"GT_DEVICE_TOKEN"];
        if (([[UIApplication sharedApplication] respondsToSelector:@selector(currentUserNotificationSettings)]))
            registeredWithApple = [[UIApplication sharedApplication] currentUserNotificationSettings].types != (NSUInteger)nil;
        else
            registeredWithApple = mDeviceToken != nil || [defaults boolForKey:@"GT_REGISTERED_WITH_APPLE"];
        mSubscriptionSet = [defaults objectForKey:@"ONESIGNAL_SUBSCRIPTION"] == nil;
        mNotificationTypes = getNotificationTypes();
        
        // Register this device with Apple's APNS server.
        if (autoRegister || registeredWithApple)
            [self registerForPushNotifications];
        // iOS 8 - Register for remote notifications to get a token now since registerUserNotificationSettings is what shows the prompt.
        else if ([[UIApplication sharedApplication] respondsToSelector:@selector(registerForRemoteNotifications)])
            [[UIApplication sharedApplication] registerForRemoteNotifications];
        
        if (mUserId != nil)
            [self registerUser];
        else // Fall back incase Apple does not responsed in time.
            [self performSelector:@selector(registerUser) withObject:nil afterDelay:30.0f];
    }
    
    NSDictionary* userInfo = [launchOptions objectForKey:UIApplicationLaunchOptionsRemoteNotificationKey];
    if (userInfo && NSFoundationVersionNumber < NSFoundationVersionNumber_iOS_7_0) {
        // Only call for iOS 6.
        // In iOS 7 & 8 the fetchCompletionHandler gets called inaddition to userInfo being filled here.
        [self notificationOpened:userInfo isActive:false];
    }
    
    clearBadgeCount();
    
    if ([OneSignalTrackIAP canTrack])
        trackIAPPurchase = [[OneSignalTrackIAP alloc] init];
    
    return self;
}

+ (void)setLogLevel:(ONE_S_LOG_LEVEL)nsLogLevel visualLevel:(ONE_S_LOG_LEVEL)visualLogLevel {
    _nsLogLevel = nsLogLevel; _visualLogLevel = visualLogLevel;
}

void Log(ONE_S_LOG_LEVEL logLevel, NSString* message) {
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
- (void)registerForPushNotifications {
    if (NSFoundationVersionNumber < NSFoundationVersionNumber_iOS_6_0)
        return;
    
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
            NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
            [defaults setObject:@YES forKey:@"GT_REGISTERED_WITH_APPLE"];
            [defaults synchronize];
        }
    }
}

- (void)registerDeviceToken:(id)inDeviceToken onSuccess:(OneSignalResultSuccessBlock)successBlock onFailure:(OneSignalFailureBlock)failureBlock {
    [self updateDeviceToken:inDeviceToken onSuccess:successBlock onFailure:failureBlock];
    
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:mDeviceToken forKey:@"GT_DEVICE_TOKEN"];
    [defaults synchronize];
}

- (void)updateDeviceToken:(NSString*)deviceToken onSuccess:(OneSignalResultSuccessBlock)successBlock onFailure:(OneSignalFailureBlock)failureBlock {
    
    if (mUserId == nil) {
        mDeviceToken = deviceToken;
        tokenUpdateSuccessBlock = successBlock;
        tokenUpdateFailureBlock = failureBlock;
        
        // iOS 8 - We get a token right away but give the user 30 sec to responsed to the system prompt.
        // Also check mNotificationTypes so there is no waiting if user has already answered the system prompt.
        // The goal is to only have 1 server call.
        if (isCapableOfGettingNotificationTypes() && mNotificationTypes == -1) {
            [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(registerUser) object:nil];
            [self performSelector:@selector(registerUser) withObject:nil afterDelay:30.0f];
        }
        else
            [self registerUser];
        return;
    }
    
    if ([deviceToken isEqualToString:mDeviceToken]) {
        if (successBlock)
            successBlock(nil);
        return;
    }
    
    mDeviceToken = deviceToken;
    
    NSMutableURLRequest* request;
    request = [self.httpClient requestWithMethod:@"PUT" path:[NSString stringWithFormat:@"players/%@", mUserId]];
    
    NSDictionary* dataDic = [NSDictionary dictionaryWithObjectsAndKeys:
                             self.app_id, @"app_id",
                             deviceToken, @"identifier",
                             nil];
    
    Log(ONE_S_LL_VERBOSE, @"Calling OneSignal PUT updated pushToken!");
    NSData* postData = [NSJSONSerialization dataWithJSONObject:dataDic options:0 error:nil];
    [request setHTTPBody:postData];
    
    [self enqueueRequest:request onSuccess:successBlock onFailure:failureBlock];
    
    if (idsAvailableBlockWhenReady) {
        mNotificationTypes = getNotificationTypes();
        if (getUsableDeviceToken())
            idsAvailableBlockWhenReady(mUserId, getUsableDeviceToken());
        idsAvailableBlockWhenReady = nil;
    }
}


- (NSArray*)getSoundFiles {
    NSFileManager* fm = [NSFileManager defaultManager];
    NSError* error = nil;
    
    NSArray* allFiles = [fm contentsOfDirectoryAtPath:[[NSBundle mainBundle] resourcePath] error:&error];
    NSMutableArray* soundFiles = [NSMutableArray new];
    if (error == nil) {
        for(id file in allFiles) {
            if ([file hasSuffix:@".wav"] || [file hasSuffix:@".mp3"])
                [soundFiles addObject:file];
        }
    }
    
    return soundFiles;
}

NSNumber* getNetType() {
    OneSignalReachability* reachability = [OneSignalReachability reachabilityForInternetConnection];
    NetworkStatus status = [reachability currentReachabilityStatus];
    if (status == ReachableViaWiFi)
        return @0;
    return @1;
}

- (void)registerUser {
    // Make sure we only call create or on_session once per run of the app.
    if (oneSignalReg || waitingForOneSReg)
        return;
    
    waitingForOneSReg = true;
    
    NSMutableURLRequest* request;
    if (mUserId == nil)
        request = [self.httpClient requestWithMethod:@"POST" path:@"players"];
    else
        request = [self.httpClient requestWithMethod:@"POST" path:[NSString stringWithFormat:@"players/%@/on_session", mUserId]];
    
    NSDictionary* infoDictionary = [[NSBundle mainBundle]infoDictionary];
    NSString* build = infoDictionary[(NSString*)kCFBundleVersionKey];
    
    NSMutableDictionary* dataDic = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                             self.app_id, @"app_id",
                             self.deviceModel, @"device_model",
                             self.systemVersion, @"device_os",
                             [[NSLocale preferredLanguages] objectAtIndex:0], @"language",
                             [NSNumber numberWithInt:(int)[[NSTimeZone localTimeZone] secondsFromGMT]], @"timezone",
                             build, @"game_version",
                             [NSNumber numberWithInt:0], @"device_type",
                             [[[UIDevice currentDevice] identifierForVendor] UUIDString], @"ad_id",
                             [self getSoundFiles], @"sounds",
                             VERSION, @"sdk",
                             mDeviceToken, @"identifier", // identifier MUST be at the end as it could be nil.
                             nil];
    
    mNotificationTypes = getNotificationTypes();
    
    if ([OneSignalJailbreakDetection isJailbroken])
        dataDic[@"rooted"] = @YES;
    
    dataDic[@"net_type"] = getNetType();
    
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
    }
    
    UIApplicationReleaseMode releaseMode = [OneSignalMobileProvision releaseMode];
    if (releaseMode == UIApplicationReleaseDev || releaseMode == UIApplicationReleaseAdHoc)
        dataDic[@"test_type"] = [NSNumber numberWithInt:releaseMode];
    
    Log(ONE_S_LL_VERBOSE, @"Calling OneSignal create/on_session");
    NSData* postData = [NSJSONSerialization dataWithJSONObject:dataDic options:0 error:nil];
    [request setHTTPBody:postData];
    
    [self enqueueRequest:request onSuccess:^(NSDictionary* results) {
        oneSignalReg = true;
        waitingForOneSReg = false;
        if ([results objectForKey:@"id"] != nil) {
            NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
            mUserId = [results objectForKey:@"id"];
            [defaults setObject:mUserId forKey:@"GT_PLAYER_ID"];
            [defaults synchronize];
            
            if (mDeviceToken)
                [self updateDeviceToken:mDeviceToken onSuccess:tokenUpdateSuccessBlock onFailure:tokenUpdateFailureBlock];
            
            if (tagsToSend != nil) {
                [self sendTags:tagsToSend];
                tagsToSend = nil;
            }
            
            if (idsAvailableBlockWhenReady) {
                idsAvailableBlockWhenReady(mUserId, getUsableDeviceToken());
                if (getUsableDeviceToken())
                    idsAvailableBlockWhenReady = nil;
            }
        }
    } onFailure:^(NSError* error) {
        oneSignalReg = false;
        waitingForOneSReg = false;
        Log(ONE_S_LL_ERROR, [NSString stringWithFormat: @"Error registering with OneSignal: %@", error]);
    }];
}

- (void)IdsAvailable:(OneSignalIdsAvailableBlock)idsAvailableBlock {
    if (mUserId)
        idsAvailableBlock(mUserId, getUsableDeviceToken());
    
    if (mUserId == nil || getUsableDeviceToken() == nil)
        idsAvailableBlockWhenReady = idsAvailableBlock;
}

NSString* getUsableDeviceToken() {
    if (mNotificationTypes > 0)
        return mDeviceToken;
    return nil;
}

- (void)sendTagsWithJsonString:(NSString*)jsonString {
    NSError* jsonError;
    
    NSData* data = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary* keyValuePairs = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&jsonError];
    if (jsonError == nil)
        [self sendTags:keyValuePairs];
    else {
        Log(ONE_S_LL_WARN,[NSString stringWithFormat: @"sendTags JSON Parse Error: %@", jsonError]);
        Log(ONE_S_LL_WARN,[NSString stringWithFormat: @"sendTags JSON Parse Error, JSON: %@", jsonString]);
    }
}

- (void)sendTags:(NSDictionary*)keyValuePair {
    [self sendTags:keyValuePair onSuccess:nil onFailure:nil];
}

- (void)sendTags:(NSDictionary*)keyValuePair onSuccess:(OneSignalResultSuccessBlock)successBlock onFailure:(OneSignalFailureBlock)failureBlock {
    if (NSFoundationVersionNumber < NSFoundationVersionNumber_iOS_6_0)
        return;
    
    if (mUserId == nil) {
        if (tagsToSend == nil)
            tagsToSend = [keyValuePair mutableCopy];
        else
            [tagsToSend addEntriesFromDictionary:keyValuePair];
        return;
    }
    
    NSMutableURLRequest* request = [self.httpClient requestWithMethod:@"PUT" path:[NSString stringWithFormat:@"players/%@", mUserId]];
    
    NSDictionary* dataDic = [NSDictionary dictionaryWithObjectsAndKeys:
                             self.app_id, @"app_id",
                             keyValuePair, @"tags",
                             getNetType(), @"net_type",
                             nil];
    
    NSData* postData = [NSJSONSerialization dataWithJSONObject:dataDic options:0 error:nil];
    [request setHTTPBody:postData];
    
    [self enqueueRequest:request
               onSuccess:successBlock
               onFailure:failureBlock];
}

- (void)sendTag:(NSString*)key value:(NSString*)value {
    [self sendTag:key value:value onSuccess:nil onFailure:nil];
}

- (void)sendTag:(NSString*)key value:(NSString*)value onSuccess:(OneSignalResultSuccessBlock)successBlock onFailure:(OneSignalFailureBlock)failureBlock {
    [self sendTags:[NSDictionary dictionaryWithObjectsAndKeys: value, key, nil] onSuccess:successBlock onFailure:failureBlock];
}

- (void)getTags:(OneSignalResultSuccessBlock)successBlock onFailure:(OneSignalFailureBlock)failureBlock {
    if (NSFoundationVersionNumber < NSFoundationVersionNumber_iOS_6_0 || mUserId == nil)
        return;
    
    NSMutableURLRequest* request;
    request = [self.httpClient requestWithMethod:@"GET" path:[NSString stringWithFormat:@"players/%@", mUserId]];
    
    [self enqueueRequest:request onSuccess:^(NSDictionary* results) {
        if ([results objectForKey:@"tags"] != nil)
            successBlock([results objectForKey:@"tags"]);
    } onFailure:failureBlock];
}

- (void)getTags:(OneSignalResultSuccessBlock)successBlock {
    [self getTags:successBlock onFailure:nil];
}


- (void)deleteTag:(NSString*)key onSuccess:(OneSignalResultSuccessBlock)successBlock onFailure:(OneSignalFailureBlock)failureBlock {
    [self deleteTags:@[key] onSuccess:successBlock onFailure:failureBlock];
}

- (void)deleteTag:(NSString*)key {
    [self deleteTags:@[key] onSuccess:nil onFailure:nil];
}

- (void)deleteTags:(NSArray*)keys onSuccess:(OneSignalResultSuccessBlock)successBlock onFailure:(OneSignalFailureBlock)failureBlock {
    if (NSFoundationVersionNumber < NSFoundationVersionNumber_iOS_6_0 || mUserId == nil)
        return;
    
    NSMutableURLRequest* request;
    request = [self.httpClient requestWithMethod:@"PUT" path:[NSString stringWithFormat:@"players/%@", mUserId]];
    
    NSMutableDictionary* deleteTagsDict = [NSMutableDictionary dictionary];
    for(id key in keys)
        [deleteTagsDict setObject:@"" forKey:key];
    
    NSDictionary* dataDic = [NSDictionary dictionaryWithObjectsAndKeys:
                             self.app_id, @"app_id",
                             deleteTagsDict, @"tags",
                             nil];
    
    NSData* postData = [NSJSONSerialization dataWithJSONObject:dataDic options:0 error:nil];
    [request setHTTPBody:postData];
    
    [self enqueueRequest:request onSuccess:successBlock onFailure:failureBlock];
}

- (void)deleteTags:(NSArray*)keys {
    [self deleteTags:keys onSuccess:nil onFailure:nil];
}

- (void)deleteTagsWithJsonString:(NSString*)jsonString {
    NSError* jsonError;
    
    NSData* data = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSArray* keys = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&jsonError];
    if (jsonError == nil)
        [self deleteTags:keys];
    else {
        Log(ONE_S_LL_WARN,[NSString stringWithFormat: @"deleteTags JSON Parse Error: %@", jsonError]);
        Log(ONE_S_LL_WARN,[NSString stringWithFormat: @"deleteTags JSON Parse Error, JSON: %@", jsonString]);
    }
}

- (void) sendNotificationTypesUpdateIsConfirmed:(BOOL)isConfirm {
    // User changed notification settings for the app.
    if (mNotificationTypes != -1 && mUserId && (isConfirm || mNotificationTypes != getNotificationTypes()) ) {
        mNotificationTypes = getNotificationTypes();
        NSMutableURLRequest* request = [self.httpClient requestWithMethod:@"PUT" path:[NSString stringWithFormat:@"players/%@", mUserId]];
        
        NSDictionary* dataDic = [NSDictionary dictionaryWithObjectsAndKeys:
                                 self.app_id, @"app_id",
                                 [NSNumber numberWithInt:mNotificationTypes], @"notification_types",
                                 nil];
        
        NSData* postData = [NSJSONSerialization dataWithJSONObject:dataDic options:0 error:nil];
        [request setHTTPBody:postData];
        
        [self enqueueRequest:request onSuccess:nil onFailure:nil];
        
        if (getUsableDeviceToken() && idsAvailableBlockWhenReady) {
            idsAvailableBlockWhenReady(mUserId, getUsableDeviceToken());
            idsAvailableBlockWhenReady = nil;
        }
    }

}


- (void) beginBackgroundFocusTask {
    focusBackgroundTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [self endBackgroundFocusTask];
    }];
}

- (void) endBackgroundFocusTask {
    [[UIApplication sharedApplication] endBackgroundTask: focusBackgroundTask];
    focusBackgroundTask = UIBackgroundTaskInvalid;
}

- (void)onFocus:(NSString*)state {
    bool wasBadgeSet = false;
    
    if ([state isEqualToString:@"resume"]) {
        lastTrackedTime = [NSNumber numberWithLongLong:[[NSDate date] timeIntervalSince1970]];
        
        [self sendNotificationTypesUpdateIsConfirmed:false];
        wasBadgeSet = clearBadgeCount();
    }
    else {
        NSNumber* timeElapsed = @(([[NSDate date] timeIntervalSince1970] - [lastTrackedTime longLongValue]) + 0.5);
        if ([timeElapsed intValue] < 0 || [timeElapsed intValue] > 604800)
            return;
        
        NSNumber* unSentActiveTime = [self getUnsentActiveTime];
        NSNumber* totalTimeActive = @([unSentActiveTime intValue] + [timeElapsed intValue]);
        
        if ([totalTimeActive intValue] < 30) {
            [self saveUnsentActiveTime:totalTimeActive];
            return;
        }
        
        timeToPingWith = totalTimeActive;
    }
    
    if (mUserId == nil)
        return;
    
    // If resuming and badge was set, clear it on the server as well.
    if (wasBadgeSet && [state isEqualToString:@"resume"]) {
        NSMutableURLRequest* request = [self.httpClient requestWithMethod:@"PUT" path:[NSString stringWithFormat:@"players/%@", mUserId]];
        
        NSDictionary* dataDic = [NSDictionary dictionaryWithObjectsAndKeys:
                                 self.app_id, @"app_id",
                                 @0, @"badge_count",
                                 nil];
        
        NSData* postData = [NSJSONSerialization dataWithJSONObject:dataDic options:0 error:nil];
        [request setHTTPBody:postData];
        
        [self enqueueRequest:request onSuccess:nil onFailure:nil];
        return;
    }
    
    // Update the playtime on the server when the app put into the background or the device goes to sleep mode.
    if ([state isEqualToString:@"suspend"]) {
        [self saveUnsentActiveTime:0];
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self beginBackgroundFocusTask];
        
            
            
            NSMutableURLRequest* request = [self.httpClient requestWithMethod:@"POST" path:[NSString stringWithFormat:@"players/%@/on_focus", mUserId]];
            NSDictionary* dataDic = [NSDictionary dictionaryWithObjectsAndKeys:
                                     self.app_id, @"app_id",
                                     @"ping", @"state",
                                     timeToPingWith, @"active_time",
                                     getNetType(), @"net_type",
                                     nil];
            
            NSData* postData = [NSJSONSerialization dataWithJSONObject:dataDic options:0 error:nil];
            [request setHTTPBody:postData];
        
            // We are already running in a thread so send the request synchronous to keep the thread alive.
            [self enqueueRequest:request
                       onSuccess:nil
                       onFailure:nil
                   isSynchronous:true];
            [self endBackgroundFocusTask];
        });
    }
}

- (NSNumber*)getUnsentActiveTime {
    if ([unSentActiveTime intValue] == -1) {
        NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
        unSentActiveTime = [defaults objectForKey:@"GT_UNSENT_ACTIVE_TIME"];
        if (unSentActiveTime == nil)
            unSentActiveTime = 0;
    }
    
    return unSentActiveTime;
}

- (void)saveUnsentActiveTime:(NSNumber*)time {
    unSentActiveTime = time;
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:time forKey:@"GT_UNSENT_ACTIVE_TIME"];
    [defaults synchronize];

}

- (void)sendPurchases:(NSArray*)purchases {
    if (mUserId == nil)
        return;
    
    NSMutableURLRequest* request = [self.httpClient requestWithMethod:@"POST" path:[NSString stringWithFormat:@"players/%@/on_purchase", mUserId]];
    
    NSDictionary *dataDic = [NSDictionary dictionaryWithObjectsAndKeys:
                             self.app_id, @"app_id",
                             purchases, @"purchases",
                             nil];
    
    NSData *postData = [NSJSONSerialization dataWithJSONObject:dataDic options:0 error:nil];
    [request setHTTPBody:postData];
    
    [self enqueueRequest:request
               onSuccess:nil
               onFailure:nil];
}

- (void)notificationOpened:(NSDictionary*)messageDict isActive:(BOOL)isActive {
    
    BOOL inAppAlert = false;
    if (isActive) {
        NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
        inAppAlert = [defaults boolForKey:@"ONESIGNAL_INAPP_ALERT"];
        
        if (inAppAlert) {
            self.lastMessageReceived = messageDict;
            NSDictionary* additionalData = [self getAdditionalData];
            NSString* title = additionalData[@"title"];
            if (!title)
                title = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"];
            
            id oneSignalAlertViewDelegate = [[OneSignalAlertViewDelegate alloc] initWithMessageDict:messageDict OneSignal:self];
            
            UIAlertView* alertView = [[UIAlertView alloc] initWithTitle:title
                                                                message:[self getMessageString]
                                                               delegate:oneSignalAlertViewDelegate
                                                      cancelButtonTitle:@"Close"
                                                      otherButtonTitles:nil, nil];
            
            if (additionalData[@"actionButtons"]) {
                for(id button in additionalData[@"actionButtons"])
                    [alertView addButtonWithTitle:button[@"text"]];
            }
            
            [alertView show];
            return;
        }
    }
    
    [self handleNotificationOpened:messageDict isActive:isActive];

}

- (void) handleNotificationOpened:(NSDictionary*)messageDict isActive:(BOOL)isActive {
    NSDictionary* customDict = [messageDict objectForKey:@"custom"];
    NSString* messageId = [customDict objectForKey:@"i"];
    
    NSMutableURLRequest* request = [self.httpClient requestWithMethod:@"PUT" path:[NSString stringWithFormat:@"notifications/%@", messageId]];
    
    NSDictionary* dataDic = [NSDictionary dictionaryWithObjectsAndKeys:
                             self.app_id, @"app_id",
                             mUserId, @"player_id",
                             @(YES), @"opened",
                             nil];
    
    NSData* postData = [NSJSONSerialization dataWithJSONObject:dataDic options:0 error:nil];
    [request setHTTPBody:postData];
    
    [self enqueueRequest:request onSuccess:nil onFailure:nil];
    
    if ([[UIApplication sharedApplication] applicationState] != UIApplicationStateActive && [customDict objectForKey:@"u"] != nil) {
        NSURL *url = [NSURL URLWithString:[customDict objectForKey:@"u"]];
        [[UIApplication sharedApplication] openURL:url];
    }
    
    self.lastMessageReceived = messageDict;
    
    clearBadgeCount();
    [[UIApplication sharedApplication] cancelAllLocalNotifications];
    
    
    
    if (handleNotification)
        handleNotification([self getMessageString], [self getAdditionalData], isActive);
}

bool clearBadgeCount() {
    if (mNotificationTypes == -1 || (mNotificationTypes & NOTIFICATION_TYPE_BADGE) == 0)
        return false;
    
    bool wasBadgeSet = false;
    
    if ([UIApplication sharedApplication].applicationIconBadgeNumber > 0)
        wasBadgeSet = true;
    
    // Clear bages and nofiications from this app. Setting to 1 then 0 was needed to clear the notifications.
    [[UIApplication sharedApplication] setApplicationIconBadgeNumber:1];
    [[UIApplication sharedApplication] setApplicationIconBadgeNumber:0];
    
    return wasBadgeSet;
}

bool isCapableOfGettingNotificationTypes() {
    return [[UIApplication sharedApplication] respondsToSelector:@selector(currentUserNotificationSettings)];
}

int getNotificationTypes() {
    if (!mSubscriptionSet)
        return -2;
    
    if (mDeviceToken) {
        if (isCapableOfGettingNotificationTypes())
            return [[UIApplication sharedApplication] currentUserNotificationSettings].types;
        else
            return NOTIFICATION_TYPE_ALL;
    }
    
    return -1;
}

// iOS 8.0+ only
- (void) updateNotificationTypes:(int)notificationTypes {
    if (mNotificationTypes == -2)
        return;
    
    BOOL changed = (mNotificationTypes != notificationTypes);
    
    mNotificationTypes = notificationTypes;
    
    if (mUserId == nil && mDeviceToken)
        [self registerUser];
    else if (mDeviceToken)
        [self sendNotificationTypesUpdateIsConfirmed:changed];
    
    if (idsAvailableBlockWhenReady && mUserId && getUsableDeviceToken())
        idsAvailableBlockWhenReady(mUserId, getUsableDeviceToken());
}

- (NSDictionary*)getAdditionalData {
    NSMutableDictionary* additionalData;
    NSDictionary* orgAdditionalData = [[self.lastMessageReceived objectForKey:@"custom"] objectForKey:@"a"];
    
    additionalData = [[NSMutableDictionary alloc] initWithDictionary:orgAdditionalData];
    
    // TODO: Add sound when notification sent with buttons.
    if (self.lastMessageReceived[@"aps"][@"sound"] != nil)
        additionalData[@"sound"] = self.lastMessageReceived[@"aps"][@"sound"];
    if (self.lastMessageReceived[@"custom"][@"u"] != nil)
        additionalData[@"launchURL"] = self.lastMessageReceived[@"custom"][@"u"];
    
    return additionalData;
}

- (NSString*)getMessageString {
    return self.lastMessageReceived[@"aps"][@"alert"];
}

- (void)postNotification:(NSDictionary*)jsonData {
    [self postNotification:jsonData onSuccess:nil onFailure:nil];
}

- (void)postNotification:(NSDictionary*)jsonData onSuccess:(OneSignalResultSuccessBlock)successBlock onFailure:(OneSignalFailureBlock)failureBlock {
    NSMutableURLRequest* request = [self.httpClient requestWithMethod:@"POST" path:@"notifications"];
    
    NSMutableDictionary* dataDic = [[NSMutableDictionary alloc] initWithDictionary:jsonData];
    dataDic[@"app_id"] = self.app_id;
    
    NSData* postData = [NSJSONSerialization dataWithJSONObject:dataDic options:0 error:nil];
    [request setHTTPBody:postData];
    
    [self enqueueRequest:request
               onSuccess:^(NSDictionary* results) {
                   NSData* jsonData = [NSJSONSerialization dataWithJSONObject:results options:0 error:nil];
                   NSString* jsonResultsString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
                   
                   Log(ONE_S_LL_DEBUG, [NSString stringWithFormat: @"HTTP create notification success %@", jsonResultsString]);
                   if (successBlock)
                       successBlock(results);
               }
               onFailure:^(NSError* error) {
                   Log(ONE_S_LL_ERROR, @"Create notification failed");
                   Log(ONE_S_LL_INFO, [NSString stringWithFormat: @"%@", error]);
                   if (failureBlock)
                       failureBlock(error);
               }];
}

- (void)postNotificationWithJsonString:(NSString*)jsonString onSuccess:(OneSignalResultSuccessBlock)successBlock onFailure:(OneSignalFailureBlock)failureBlock {
    NSError* jsonError;
    
    NSData* data = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary* jsonData = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&jsonError];
    if (jsonError == nil)
        [self postNotification:jsonData onSuccess:successBlock onFailure:failureBlock];
    else {
        Log(ONE_S_LL_WARN,[NSString stringWithFormat: @"postNotification JSON Parse Error: %@", jsonError]);
        Log(ONE_S_LL_WARN,[NSString stringWithFormat: @"postNotification JSON Parse Error, JSON: %@", jsonString]);
    }
}

- (void)enqueueRequest:(NSURLRequest*)request onSuccess:(OneSignalResultSuccessBlock)successBlock onFailure:(OneSignalFailureBlock)failureBlock {
    [self enqueueRequest:request onSuccess:successBlock onFailure:failureBlock isSynchronous:false];
}

- (void)enqueueRequest:(NSURLRequest*)request onSuccess:(OneSignalResultSuccessBlock)successBlock onFailure:(OneSignalFailureBlock)failureBlock isSynchronous:(BOOL)isSynchronous {
    if (isSynchronous) {
        NSURLResponse* response = nil;
        NSError* error = nil;
        
        [NSURLConnection sendSynchronousRequest:request
            returningResponse:&response
            error:&error];
        
        [self handleJSONNSURLResponse:response data:nil error:error onSuccess:successBlock onFailure:failureBlock];
    }
    else {
		[NSURLConnection
            sendAsynchronousRequest:request
            queue:[[NSOperationQueue alloc] init]
            completionHandler:^(NSURLResponse* response,
                                NSData* data,
                                NSError* error) {
                [self handleJSONNSURLResponse:response data:data error:error onSuccess:successBlock onFailure:failureBlock];
            }];
    }
}

- (void)handleJSONNSURLResponse:(NSURLResponse*) response data:(NSData*) data error:(NSError*) error onSuccess:(OneSignalResultSuccessBlock)successBlock onFailure:(OneSignalFailureBlock)failureBlock {
    NSHTTPURLResponse* HTTPResponse = (NSHTTPURLResponse*)response;
    NSInteger statusCode = [HTTPResponse statusCode];
    NSError* jsonError;
    NSMutableDictionary* innerJson;
    
    if (data != nil && [data length] > 0) {
        innerJson = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&jsonError];
        if (jsonError != nil) {
            if (failureBlock != nil)
                failureBlock([NSError errorWithDomain:@"OneSignal Error" code:statusCode userInfo:@{@"returned" : jsonError}]);
            return;
        }
    }
    
    if (error == nil && statusCode == 200) {
        if (successBlock != nil) {
            if (innerJson != nil)
                successBlock(innerJson);
            else
                successBlock(nil);
        }
    }
    else if (failureBlock != nil) {
        if (innerJson != nil && error == nil)
            failureBlock([NSError errorWithDomain:@"OneSignalError" code:statusCode userInfo:@{@"returned" : innerJson}]);
        else if (error != nil)
            failureBlock([NSError errorWithDomain:@"OneSignalError" code:statusCode userInfo:@{@"error" : error}]);
        else
            failureBlock([NSError errorWithDomain:@"OneSignalError" code:statusCode userInfo:nil]);
    }
}


+ (void)setDefaultClient:(OneSignal*)client {
    defaultClient = client;
}

+ (OneSignal*)defaultClient {
    return defaultClient;
}

- (void)enableInAppAlertNotification:(BOOL)enable {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:enable forKey:@"ONESIGNAL_INAPP_ALERT"];
    [defaults synchronize];
}

- (void)setSubscription:(BOOL)enable {
    NSString* value = nil;
    if (!enable)
        value = @"no";
    
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:value forKey:@"ONESIGNAL_SUBSCRIPTION"];
    [defaults synchronize];
    
    mSubscriptionSet = enable;
    
    [self sendNotificationTypesUpdateIsConfirmed:false];
}

- (void)didRegisterForRemoteNotifications:(UIApplication*)app deviceToken:(NSData*)inDeviceToken {
    NSString* trimmedDeviceToken = [[inDeviceToken description] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"<>"]];
    NSString* parsedDeviceToken = [[trimmedDeviceToken componentsSeparatedByString:@" "] componentsJoinedByString:@""];
    Log((ONE_S_LOG_LEVEL)ONE_S_LL_INFO, [NSString stringWithFormat:@"Device Registered with Apple: %@", parsedDeviceToken]);
    [self registerDeviceToken:parsedDeviceToken onSuccess:^(NSDictionary* results) {
        Log(ONE_S_LL_INFO, [NSString stringWithFormat: @"Device Registered with OneSignal: %@", mUserId]);
    } onFailure:^(NSError* error) {
        Log(ONE_S_LL_ERROR, [NSString stringWithFormat: @"Error in OneSignal Registration: %@", error]);
    }];
}

- (void) remoteSilentNotification:(UIApplication*)application UserInfo:(NSDictionary*)userInfo {
    if (userInfo[@"m"]) {
        NSDictionary* data = userInfo;
        
        id category = [[NSClassFromString(@"UIMutableUserNotificationCategory") alloc] init];
        [category setIdentifier:@"dynamic"];
        
        Class UIMutableUserNotificationActionClass = NSClassFromString(@"UIMutableUserNotificationAction");
        NSMutableArray* actionArray = [[NSMutableArray alloc] init];
        for (NSDictionary* button in data[@"o"]) {
            id action = [[UIMutableUserNotificationActionClass alloc] init];
            [action setTitle:button[@"n"]];
            [action setIdentifier:button[@"i"] ? button[@"i"] : [action title]];
            [action setActivationMode:UIUserNotificationActivationModeForeground];
            [action setDestructive:NO];
            [action setAuthenticationRequired:NO];
            
            [actionArray addObject:action];
            // iOS 8 shows notification buttons in reverse in all cases but alerts. This flips it so the frist button is on the left.
            if (actionArray.count == 2)
                [category setActions:@[actionArray[1], actionArray[0]] forContext:UIUserNotificationActionContextMinimal];
        }
        
        [category setActions:actionArray forContext:UIUserNotificationActionContextDefault];
        
        Class uiUserNotificationSettings = NSClassFromString(@"UIUserNotificationSettings");
        NSUInteger notificationTypes = NOTIFICATION_TYPE_ALL;
        
        [[UIApplication sharedApplication] registerUserNotificationSettings:[uiUserNotificationSettings settingsForTypes:notificationTypes categories:[NSSet setWithObject:category]]];
        
        UILocalNotification* notification = [[UILocalNotification alloc] init];
        notification.category = [category identifier];
        notification.alertBody = data[@"m"];
        notification.userInfo = userInfo;
        notification.soundName = data[@"s"];
        if (notification.soundName == nil)
            notification.soundName = UILocalNotificationDefaultSoundName;
        if (data[@"b"])
            notification.applicationIconBadgeNumber = [data[@"b"] intValue];
        
        [[UIApplication sharedApplication] scheduleLocalNotification:notification];
    }
    else
        [self notificationOpened:userInfo isActive:[application applicationState] == UIApplicationStateActive];
}

- (void)processLocalActionBasedNotification:(UILocalNotification*) notification identifier:(NSString*)identifier {
    if (notification.userInfo && notification.userInfo[@"custom"]) {
        NSMutableDictionary* userInfo = [notification.userInfo mutableCopy];
        NSMutableDictionary* customDict = [userInfo[@"custom"] mutableCopy];
        NSMutableDictionary* additionalData = [[NSMutableDictionary alloc] initWithDictionary:customDict[@"a"]];
        
        NSMutableArray* buttonArray = [[NSMutableArray alloc] init];
        for (NSDictionary* button in userInfo[@"o"]) {
            [buttonArray addObject: @{@"text" : button[@"n"],
                                      @"id" : (button[@"i"] ? button[@"i"] : button[@"n"])}];
        }
        
        additionalData[@"actionSelected"] = identifier;
        additionalData[@"actionButtons"] = buttonArray;
        
        customDict[@"a"] = additionalData;
        userInfo[@"custom"] = customDict;
        
        userInfo[@"aps"] = @{@"alert" : userInfo[@"m"]};
        
        [self notificationOpened:userInfo isActive:[[UIApplication sharedApplication] applicationState] == UIApplicationStateActive];
    }
}

@end


@implementation OneSignalAlertViewDelegate

NSDictionary* mMessageDict;
OneSignal* mOneSignal;

// delegateReference exist to keep ARC from cleaning up this object when it goes out of scope.
// This is becuase UIAlertView delegate is set to weak instead of strong
static NSMutableArray* delegateReference;

- (id)initWithMessageDict:(NSDictionary*)messageDict OneSignal:oneSignal {
    mMessageDict = messageDict;
    mOneSignal = oneSignal;
    
    if (delegateReference == nil)
        delegateReference = [NSMutableArray array];
    
    [delegateReference addObject:self];
    
    return self;
}

- (void)alertView:(UIAlertView*)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex != 0) {
        NSMutableDictionary* userInfo = [mMessageDict mutableCopy];
        NSMutableDictionary* customDict = [userInfo[@"custom"] mutableCopy];
        NSMutableDictionary* additionalData = [[NSMutableDictionary alloc] initWithDictionary:customDict[@"a"]];
    
        additionalData[@"actionSelected"] = additionalData[@"actionButtons"][buttonIndex - 1][@"id"];
    
        customDict[@"a"] = additionalData;
        userInfo[@"custom"] = customDict;
        mMessageDict = userInfo;
    }
    
    [mOneSignal handleNotificationOpened:mMessageDict isActive:true];
    [delegateReference removeObject:self];
}

@end



static Class getClassWithProtocolInHierarchy(Class searchClass, Protocol* protocolToFind) {
    if (!class_conformsToProtocol(searchClass, protocolToFind)) {
        if ([searchClass superclass] == nil)
            return nil;
        
        Class foundClass = getClassWithProtocolInHierarchy([searchClass superclass], protocolToFind);
        if (foundClass)
            return foundClass;
        
        return searchClass;
    }
    
    return searchClass;
}

static void injectSelector(Class newClass, SEL newSel, Class addToClass, SEL makeLikeSel) {
    Method newMeth = class_getInstanceMethod(newClass, newSel);
    IMP imp = method_getImplementation(newMeth);
    const char* methodTypeEncoding = method_getTypeEncoding(newMeth);
    
    BOOL successful = class_addMethod(addToClass, makeLikeSel, imp, methodTypeEncoding);
    if (!successful) {
        class_addMethod(addToClass, newSel, imp, methodTypeEncoding);
        newMeth = class_getInstanceMethod(addToClass, newSel);
        
        Method orgMeth = class_getInstanceMethod(addToClass, makeLikeSel);
        
        method_exchangeImplementations(orgMeth, newMeth);
    }
}



@implementation UIApplication(OneSignalPush)

- (void)oneSignalDidRegisterForRemoteNotifications:(UIApplication*)app deviceToken:(NSData*)inDeviceToken {
    [[OneSignal defaultClient] didRegisterForRemoteNotifications:app deviceToken:inDeviceToken];
    
    if ([self respondsToSelector:@selector(oneSignalDidRegisterForRemoteNotifications:deviceToken:)])
        [self oneSignalDidRegisterForRemoteNotifications:app deviceToken:inDeviceToken];
}

- (void)oneSignalDidFailRegisterForRemoteNotification:(UIApplication*)app error:(NSError*)err {
    Log(ONE_S_LL_ERROR, [NSString stringWithFormat: @"Error registering for Apple push notifications. Error: %@", err]);
    
    if ([self respondsToSelector:@selector(oneSignalDidFailRegisterForRemoteNotification:error:)])
        [self oneSignalDidFailRegisterForRemoteNotification:app error:err];
}

- (void)oneSignalDidRegisterUserNotifications:(UIApplication*)application settings:(UIUserNotificationSettings*)notificationSettings {
    if ([OneSignal defaultClient])
        [[OneSignal defaultClient] updateNotificationTypes:notificationSettings.types];
    
    if ([self respondsToSelector:@selector(oneSignalDidRegisterUserNotifications:settings:)])
        [self oneSignalDidRegisterUserNotifications:application settings:notificationSettings];
}


// Notification opened! iOS 6 ONLY!
- (void)oneSignalReceivedRemoteNotification:(UIApplication*)application userInfo:(NSDictionary*)userInfo {
    [[OneSignal defaultClient] notificationOpened:userInfo isActive:[application applicationState] == UIApplicationStateActive];
    
    if ([self respondsToSelector:@selector(oneSignalReceivedRemoteNotification:userInfo:)])
        [self oneSignalReceivedRemoteNotification:application userInfo:userInfo];
}

// Notification opened or silent one received on iOS 7 & 8
- (void) oneSignalRemoteSilentNotification:(UIApplication*)application UserInfo:(NSDictionary*)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult)) completionHandler {
    
    [[OneSignal defaultClient] remoteSilentNotification:application UserInfo:userInfo];
    
    
    if ([self respondsToSelector:@selector(oneSignalRemoteSilentNotification:UserInfo:fetchCompletionHandler:)])
        [self oneSignalRemoteSilentNotification:application UserInfo:userInfo fetchCompletionHandler:completionHandler];
    else
        completionHandler(UIBackgroundFetchResultNewData);
}

- (void) oneSignalLocalNotificationOpened:(UIApplication*)application handleActionWithIdentifier:(NSString*)identifier forLocalNotification:(UILocalNotification*)notification completionHandler:(void(^)()) completionHandler {
    
    [[OneSignal defaultClient] processLocalActionBasedNotification:notification identifier:identifier];
    
    if ([self respondsToSelector:@selector(oneSignalLocalNotificationOpened:handleActionWithIdentifier:forLocalNotification:completionHandler:)])
        [self oneSignalLocalNotificationOpened:application handleActionWithIdentifier:identifier forLocalNotification:notification completionHandler:completionHandler];
    else
        completionHandler();
}

- (void)oneSignalLocalNotificaionOpened:(UIApplication*)application notification:(UILocalNotification*)notification {
    [[OneSignal defaultClient] processLocalActionBasedNotification:notification identifier:@"__DEFAULT__"];
    
    if ([self respondsToSelector:@selector(oneSignalLocalNotificaionOpened:notification:)])
        [self oneSignalLocalNotificaionOpened:application notification:notification];
}

- (void)oneSignalApplicationWillResignActive:(UIApplication*)application {
    if ([OneSignal defaultClient])
        [[OneSignal defaultClient] onFocus:@"suspend"];
    
    if ([self respondsToSelector:@selector(oneSignalApplicationWillResignActive:)])
        [self oneSignalApplicationWillResignActive:application];
}

- (void)oneSignalApplicationDidBecomeActive:(UIApplication*)application {
    if ([OneSignal defaultClient])
        [[OneSignal defaultClient] onFocus:@"resume"];

    if ([self respondsToSelector:@selector(oneSignalApplicationDidBecomeActive:)])
        [self oneSignalApplicationDidBecomeActive:application];
}



+ (void)load {
    if (NSFoundationVersionNumber < NSFoundationVersionNumber_iOS_6_0)
        return;
    
    method_exchangeImplementations(class_getInstanceMethod(self, @selector(setDelegate:)), class_getInstanceMethod(self, @selector(setOneSignalDelegate:)));
}

static Class delegateClass = nil;

- (void) setOneSignalDelegate:(id<UIApplicationDelegate>)delegate {
    if (delegateClass != nil) {
        [self setOneSignalDelegate:delegate];
        return;
    }
    
    
	delegateClass = getClassWithProtocolInHierarchy([delegate class], @protocol(UIApplicationDelegate));
    
    
    injectSelector(self.class, @selector(oneSignalRemoteSilentNotification:UserInfo:fetchCompletionHandler:),
                    delegateClass, @selector(application:didReceiveRemoteNotification:fetchCompletionHandler:));
    
    injectSelector(self.class, @selector(oneSignalLocalNotificationOpened:handleActionWithIdentifier:forLocalNotification:completionHandler:),
                   delegateClass, @selector(application:handleActionWithIdentifier:forLocalNotification:completionHandler:));
    
    injectSelector(self.class, @selector(oneSignalDidFailRegisterForRemoteNotification:error:),
                   delegateClass, @selector(application:didFailToRegisterForRemoteNotificationsWithError:));
    
    injectSelector(self.class, @selector(oneSignalDidRegisterUserNotifications:settings:),
                   delegateClass, @selector(application:didRegisterUserNotificationSettings:));
    
    if (NSClassFromString(@"CoronaAppDelegate")) {
        [self setOneSignalDelegate:delegate];
        return;
    }
    
    injectSelector(self.class, @selector(oneSignalReceivedRemoteNotification:userInfo:),
                   delegateClass, @selector(application:didReceiveRemoteNotification:));
    
    injectSelector(self.class, @selector(oneSignalDidRegisterForRemoteNotifications:deviceToken:),
                    delegateClass, @selector(application:didRegisterForRemoteNotificationsWithDeviceToken:));
    
    injectSelector(self.class, @selector(oneSignalLocalNotificaionOpened:notification:),
                    delegateClass, @selector(application:didReceiveLocalNotification:));
    
    injectSelector(self.class, @selector(oneSignalApplicationWillResignActive:),
                   delegateClass, @selector(applicationWillResignActive:));
    
    injectSelector(self.class, @selector(oneSignalApplicationDidBecomeActive:),
                   delegateClass, @selector(applicationDidBecomeActive:));
    
    
    [self setOneSignalDelegate:delegate];
}

@end

