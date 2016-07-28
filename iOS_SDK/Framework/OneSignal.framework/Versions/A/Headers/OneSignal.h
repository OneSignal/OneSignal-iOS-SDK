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

#import <Foundation/Foundation.h>

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 100000
#define XC8_AVAILABLE 1
#import <UserNotifications/UserNotifications.h>

@protocol OSUserNotificationCenterDelegate <NSObject>
@optional
- (void)userNotificationCenter:(id)center willPresentNotification:(id)notification withCompletionHandler:(void (^)(NSUInteger options))completionHandler;
- (void)userNotificationCenter:(id)center didReceiveNotificationResponse:(id)response withCompletionHandler:(void (^)())completionHandler;
@end

#endif

@interface OSNotificationPayload : NSObject

// Unique Message Identifier
@property(readonly)NSString* identifier;

// Provide this key with a value of 1 to indicate that new content is available.
//Including this key and value means that when your app is launched in the background or resumed application:didReceiveRemoteNotification:fetchCompletionHandler: is called.
@property(readonly)BOOL contentAvailable;

// The badge assigned to the application icon
@property(readonly)NSUInteger badge;

// The sound parameter passed to the notification
// By default set to UILocalNotificationDefaultSoundName
@property(readonly)NSString* sound;

// Main push content
@property(readonly)NSString* title;
@property(readonly)NSString* subtitle;
@property(readonly)NSString* body;

// Web address to launch within the app via a UIWebView
@property(readonly)NSString* launchURL;

// Additional key value properties set within the payload
@property(readonly)NSDictionary* additionalData;

//Action buttons passed
@property(readonly)NSDictionary *actionButtons;

// Holds the original payload received
// Keep the raw value for users that would like to root the push
@property(readonly)NSDictionary *rawMessage;

@end

@interface OSNotificationResult : NSObject

// Notification Payload
@property(readonly)OSNotificationPayload* payload;

// Set to true when notification is opened while the app is in foreground
//For all other cases, irt is set to false.
@property(readonly, getter=isActive)BOOL active;

// Set to true when the user was able to see the notification and reacted to it
//Set to false when app is in focus and in-app alerts are disabled, or the remote notification is silent.
@property(readonly, getter=wasShown)BOOL shown;

// Set to true when the received notification is silent
// Silent means there is no alert, sound, or badge payload in the aps dictionary
// requires remote-notification within UIBackgroundModes array of the Info.plist
@property(readonly, getter=isSilentNotification)BOOL silentNotification;

@end

typedef void (^OSResultSuccessBlock)(NSDictionary* result);
typedef void (^OSFailureBlock)(NSError* error);
typedef void (^OSIdsAvailableBlock)(NSString* userId, NSString* pushToken);
typedef void (^OSHandleNotificationBlock)(OSNotificationResult* notification);

/**
 `OneSignal` provides a high level interface to interact with OneSignal's push service.
 
 `OneSignal` exposes a defaultClient for applications which use a globally available client to share configuration settings.
 
 Include `#import "OneSignal/OneSignal.h"` in your application files to access OneSignal's methods.
 
 ### Setting up the SDK ###
 
 Follow the documentation from http://documentation.gamethrive.com/v1.0/docs/installing-the-gamethrive-ios-sdk to setup with your game.
 
 */
@interface OneSignal : NSObject

extern NSString* const ONESIGNAL_VERSION;

typedef NS_ENUM(NSUInteger, ONE_S_LOG_LEVEL) {
    ONE_S_LL_NONE, ONE_S_LL_FATAL, ONE_S_LL_ERROR, ONE_S_LL_WARN, ONE_S_LL_INFO, ONE_S_LL_DEBUG, ONE_S_LL_VERBOSE
};

///--------------------
/// @name Initialize
///--------------------

/**
 Initialize OneSignal. Sends push token to OneSignal so you can later send notifications.
 
*/

// - Initialization
+ (id)initWithLaunchOptions:(NSDictionary*)launchOptions;
+ (id)initWithLaunchOptions:(NSDictionary*)launchOptions autoRegister:(BOOL)autoRegister;
+ (id)initWithLaunchOptions:(NSDictionary*)launchOptions appId:(NSString*)appId;
+ (id)initWithLaunchOptions:(NSDictionary*)launchOptions handleNotification:(OSHandleNotificationBlock)callback;
+ (id)initWithLaunchOptions:(NSDictionary*)launchOptions appId:(NSString*)appId handleNotification:(OSHandleNotificationBlock)callback;
+ (id)initWithLaunchOptions:(NSDictionary*)launchOptions handleNotification:(OSHandleNotificationBlock)callback autoRegister:(BOOL)autoRegister;
+ (id)initWithLaunchOptions:(NSDictionary*)launchOptions appId:(NSString*)appId handleNotification:(OSHandleNotificationBlock)callback autoRegister:(BOOL)autoRegister;

+ (NSString*)app_id;
    
// Only use if you passed FALSE to autoRegister
+ (void)registerForPushNotifications;

// - Logging
+ (void)setLogLevel:(ONE_S_LOG_LEVEL)logLevel visualLevel:(ONE_S_LOG_LEVEL)visualLogLevel;
+ (void) onesignal_Log:(ONE_S_LOG_LEVEL)logLevel message:(NSString*)message;

// - Tagging
+ (void)sendTag:(NSString*)key value:(NSString*)value onSuccess:(OSResultSuccessBlock)successBlock onFailure:(OSFailureBlock)failureBlock;
+ (void)sendTag:(NSString*)key value:(NSString*)value;
+ (void)sendTags:(NSDictionary*)keyValuePair onSuccess:(OSResultSuccessBlock)successBlock onFailure:(OSFailureBlock)failureBlock;
+ (void)sendTags:(NSDictionary*)keyValuePair;
+ (void)sendTagsWithJsonString:(NSString*)jsonString;
//+ (void)setEmail:(NSString*)email;
+ (void)getTags:(OSResultSuccessBlock)successBlock onFailure:(OSFailureBlock)failureBlock;
+ (void)getTags:(OSResultSuccessBlock)successBlock;
+ (void)deleteTag:(NSString*)key onSuccess:(OSResultSuccessBlock)successBlock onFailure:(OSFailureBlock)failureBlock;
+ (void)deleteTag:(NSString*)key;
+ (void)deleteTags:(NSArray*)keys onSuccess:(OSResultSuccessBlock)successBlock onFailure:(OSFailureBlock)failureBlock;
+ (void)deleteTags:(NSArray*)keys;
+ (void)deleteTagsWithJsonString:(NSString*)jsonString;

// - Get user ID & Push Token
+ (void)IdsAvailable:(OSIdsAvailableBlock)idsAvailableBlock;

// - Alerting
+ (void)enableInAppAlertNotification:(BOOL)enable;
+ (void)setSubscription:(BOOL)enable;

// - Posting Notification
+ (void)postNotification:(NSDictionary*)jsonData;
+ (void)postNotification:(NSDictionary*)jsonData onSuccess:(OSResultSuccessBlock)successBlock onFailure:(OSFailureBlock)failureBlock;
+ (void)postNotificationWithJsonString:(NSString*)jsonData onSuccess:(OSResultSuccessBlock)successBlock onFailure:(OSFailureBlock)failureBlock;

// - Request and track user's location
+ (void)promptLocation;

// - Sends the MD5 and SHA1 of the provided email
// Optional method that sends us the user's email as an anonymized hash so that we can better target and personalize notifications sent to that user across their devices.
+ (void)syncHashedEmail:(NSString*)email;

// - iOS 10 BETA features currently only available on XCode 8 & iOS 10.0+
#if XC8_AVAILABLE
+ (void)setNotificationCenterDelegate:(id<OSUserNotificationCenterDelegate>)delegate;
+ (id<OSUserNotificationCenterDelegate>)notificationCenterDelegate;
#endif

@end
