/**
 Modified MIT License
 
 Copyright 2017 OneSignal
 
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

/**
 ### Setting up the SDK ###
 Follow the documentation from https://documentation.onesignal.com/docs/ios-sdk-setupto setup OneSignal in your app.
 
 ### API Reference ###
 Follow the documentation from https://documentation.onesignal.com/docs/ios-sdk-api for a detailed explanation of the API.
 
 ### Troubleshoot ###
 Follow the documentation from https://documentation.onesignal.com/docs/troubleshooting-ios to fix common problems.
 
 For help on how to upgrade your code from 1.* SDK to 2.*: https://documentation.onesignal.com/docs/upgrading-to-ios-sdk-20
 
 ### More ###
 iOS Push Cert: https://documentation.onesignal.com/docs/generating-an-ios-push-certificate
*/

#import <Foundation/Foundation.h>
#import <UserNotifications/UserNotifications.h>
#import <OneSignalCore/OneSignalCore.h>
#import <OneSignalOutcomes/OneSignalOutcomes.h>
#import <OneSignalUser/OneSignalUser.h>
#import <OneSignalOSCore/OneSignalOSCore.h>
#import <OneSignalNotifications/OneSignalNotifications.h>
#import "OSNotificationsManager.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wstrict-prototypes"
#pragma clang diagnostic ignored "-Wnullability-completeness"

@interface OSInAppMessage : NSObject

@property (strong, nonatomic, nonnull) NSString *messageId;

// Convert the object into a NSDictionary
- (NSDictionary *_Nonnull)jsonRepresentation;

@end


@interface OSInAppMessageTag : NSObject

@property (strong, nonatomic, nullable) NSDictionary *tagsToAdd;
@property (strong, nonatomic, nullable) NSArray *tagsToRemove;

// Convert the class into a NSDictionary
- (NSDictionary *_Nonnull)jsonRepresentation;

@end

@interface OSInAppMessageAction : NSObject

// The action name attached to the IAM action
@property (strong, nonatomic, nullable) NSString *clickName;

// The URL (if any) that should be opened when the action occurs
@property (strong, nonatomic, nullable) NSURL *clickUrl;

//UUID for the page in an IAM Carousel
@property (strong, nonatomic, nullable) NSString *pageId;

// Whether or not the click action is first click on the IAM
@property (nonatomic) BOOL firstClick;

// Whether or not the click action dismisses the message
@property (nonatomic) BOOL closesMessage;

// The outcome to send for this action
@property (strong, nonatomic, nullable) NSArray<OSInAppMessageOutcome *> *outcomes;

// The tags to send for this action
@property (strong, nonatomic, nullable) OSInAppMessageTag *tags;

// Convert the class into a NSDictionary
- (NSDictionary *_Nonnull)jsonRepresentation;

@end

@protocol OSInAppMessageDelegate <NSObject>
@optional
- (void)handleMessageAction:(OSInAppMessageAction * _Nonnull)action NS_SWIFT_NAME(handleMessageAction(action:));
@end

@protocol OSInAppMessageLifecycleHandler <NSObject>
@optional
- (void)onWillDisplayInAppMessage:(OSInAppMessage *)message;
- (void)onDidDisplayInAppMessage:(OSInAppMessage *)message;
- (void)onWillDismissInAppMessage:(OSInAppMessage *)message;
- (void)onDidDismissInAppMessage:(OSInAppMessage *)message;
@end

// Subscription Classes
@interface OSSubscriptionState : NSObject

@property (readonly, nonatomic) BOOL isSubscribed; // (yes only if userId, pushToken, and setSubscription exists / are true)
@property (readonly, nonatomic) BOOL isPushDisabled; // returns value of disablePush.
@property (readonly, nonatomic, nullable) NSString* userId;    // AKA OneSignal PlayerId
@property (readonly, nonatomic, nullable) NSString* pushToken; // AKA Apple Device Token
- (NSDictionary* _Nonnull)toDictionary;

@end

@interface OSSubscriptionStateChanges : NSObject
@property (readonly, nonnull) OSSubscriptionState* to;
@property (readonly, nonnull) OSSubscriptionState* from;
- (NSDictionary* _Nonnull)toDictionary;
@end

@protocol OSSubscriptionObserver <NSObject>
- (void)onOSSubscriptionChanged:(OSSubscriptionStateChanges* _Nonnull)stateChanges;
@end

// TODO: These are moved to user model
@interface OSDeviceState : NSObject
/**
 * Get the app's notification permission
 * @return false if the user disabled notifications for the app, otherwise true
 */
@property (readonly) BOOL hasNotificationPermission;
/**
 * Get whether the user is subscribed to OneSignal notifications or not
 * @return false if the user is not subscribed to OneSignal notifications, otherwise true
 */
@property (readonly) BOOL isPushDisabled;
/**
 * Get whether the user is subscribed
 * @return true if  isNotificationEnabled,  isUserSubscribed, getUserId and getPushToken are true, otherwise false
 */
@property (readonly) BOOL isSubscribed;
/**
 * Get  the user notification permision status
 * @return OSNotificationPermission
*/
@property (readonly) OSNotificationPermission notificationPermissionStatus;
/**
 * Get user id from registration (player id)
 * @return user id if user is registered, otherwise null
 */
@property (readonly, nullable) NSString* userId;
/**
 * Get apple deice push token
 * @return push token if available, otherwise null
 */
@property (readonly, nullable) NSString* pushToken;
/**
 * Get the user email id
 * @return email id if user address was registered, otherwise null
 */
@property (readonly, nullable) NSString* emailUserId;
/**
 * Get the user email
 * @return email address if set, otherwise null
 */
@property (readonly, nullable) NSString* emailAddress;

@property (readonly) BOOL isEmailSubscribed;

/**
 * Get the user sms id
 * @return sms id if user sms number was registered, otherwise null
 */
@property (readonly, nullable) NSString* smsUserId;
/**
 * Get the user sms number, number may start with + and continue with numbers or contain only numbers
 * e.g: +11231231231 or 11231231231
 * @return sms number if set, otherwise null
 */
@property (readonly, nullable) NSString* smsNumber;

@property (readonly) BOOL isSMSSubscribed;

// Convert the class into a NSDictionary
- (NSDictionary *_Nonnull)jsonRepresentation;

@end

typedef void (^OSWebOpenURLResultBlock)(BOOL shouldOpen);

/*Block for generic results on success and errors on failure*/
typedef void (^OSResultSuccessBlock)(NSDictionary* result);
typedef void (^OSFailureBlock)(NSError* error);


// ======= OneSignal Class Interface =========
@interface OneSignal : NSObject

+ (NSString*)appId;
+ (NSString* _Nonnull)sdkVersionRaw;
+ (NSString* _Nonnull)sdkSemanticVersion;

+ (void)disablePush:(BOOL)disable;

// Only used for wrapping SDKs, such as Unity, Cordova, Xamarin, etc.
+ (void)setMSDKType:(NSString* _Nonnull)type;

#pragma mark User Model 🔥

#pragma mark User Model - User Identity 🔥
+ (Class<OSUser>)User NS_REFINED_FOR_SWIFT;
+ (void)login:(NSString * _Nonnull)externalId;
+ (void)login:(NSString * _Nonnull)externalId withToken:(NSString * _Nullable)token
NS_SWIFT_NAME(login(externalId:token:));
+ (void)logout;

#pragma mark User Model - Notifications namespace 🔥
+ (Class<OSNotifications>)Notifications NS_REFINED_FOR_SWIFT;

#pragma mark Initialization
+ (void)setAppId:(NSString* _Nonnull)newAppId; // TODO: UM renamed to just 1 method: initialize()
+ (void)initWithLaunchOptions:(NSDictionary* _Nullable)launchOptions;
+ (void)setLaunchURLsInApp:(BOOL)launchInApp;
+ (void)setProvidesNotificationSettingsView:(BOOL)providesView;

#pragma mark Logging
+ (void)setLogLevel:(ONE_S_LOG_LEVEL)logLevel visualLevel:(ONE_S_LOG_LEVEL)visualLogLevel; // TODO: UM split up into 2?
+ (void)onesignalLog:(ONE_S_LOG_LEVEL)logLevel message:(NSString* _Nonnull)message;


+ (OSDeviceState*)getDeviceState;

#pragma mark Privacy Consent
+ (void)setPrivacyConsent:(BOOL)granted;
// TODO: add getPrivacyConsent method
// Tells your application if privacy consent is still needed from the current user
+ (BOOL)requiresPrivacyConsent;
+ (void)setRequiresPrivacyConsent:(BOOL)required;

#pragma mark Public Handlers

typedef void (^OSInAppMessageClickBlock)(OSInAppMessageAction * _Nonnull action);
+ (void)setInAppMessageClickHandler:(OSInAppMessageClickBlock _Nullable)block;
+ (void)setInAppMessageLifecycleHandler:(NSObject<OSInAppMessageLifecycleHandler> *_Nullable)delegate;


#pragma mark Location
// - Request and track user's location
+ (void)promptLocation;
+ (void)setLocationShared:(BOOL)enable;
+ (BOOL)isLocationShared;

#pragma mark Permission, Subscription, and Email Observers
// TODO: UM observers are rescoped
NS_ASSUME_NONNULL_BEGIN

// TODO: Moved to User.pushSubscription.
+ (void)addSubscriptionObserver:(NSObject<OSPushSubscriptionObserver>*)observer;
+ (void)removeSubscriptionObserver:(NSObject<OSPushSubscriptionObserver>*)observer;

NS_ASSUME_NONNULL_END

#pragma mark In-App Messaging
+ (BOOL)isInAppMessagingPaused;
+ (void)pauseInAppMessages:(BOOL)pause;
// TODO: UM triggers are rescoped to user
+ (void)addTrigger:(NSString * _Nonnull)key withValue:(id _Nonnull)value;
+ (void)addTriggers:(NSDictionary<NSString *, id> * _Nonnull)triggers;
+ (void)removeTriggerForKey:(NSString * _Nonnull)key;
+ (void)removeTriggersForKeys:(NSArray<NSString *> * _Nonnull)keys;
+ (NSDictionary<NSString *, id> * _Nonnull)getTriggers;
+ (id _Nullable)getTriggerValueForKey:(NSString * _Nonnull)key;

#pragma mark Outcomes
// TODO: UM these are rescoped to user
+ (void)sendOutcome:(NSString * _Nonnull)name;
+ (void)sendOutcome:(NSString * _Nonnull)name onSuccess:(OSSendOutcomeSuccess _Nullable)success;
+ (void)sendUniqueOutcome:(NSString * _Nonnull)name;
+ (void)sendUniqueOutcome:(NSString * _Nonnull)name onSuccess:(OSSendOutcomeSuccess _Nullable)success;
+ (void)sendOutcomeWithValue:(NSString * _Nonnull)name value:(NSNumber * _Nonnull)value;
+ (void)sendOutcomeWithValue:(NSString * _Nonnull)name value:(NSNumber * _Nonnull)value onSuccess:(OSSendOutcomeSuccess _Nullable)success;

#pragma mark Extension
// iOS 10 only
// Process from Notification Service Extension.
// Used for iOS Media Attachemtns and Action Buttons.
+ (UNMutableNotificationContent*)didReceiveNotificationExtensionRequest:(UNNotificationRequest* _Nonnull)request withMutableNotificationContent:(UNMutableNotificationContent* _Nullable)replacementContent __deprecated_msg("Please use didReceiveNotificationExtensionRequest:withMutableNotificationContent:withContentHandler: instead.");
+ (UNMutableNotificationContent*)didReceiveNotificationExtensionRequest:(UNNotificationRequest* _Nonnull)request withMutableNotificationContent:(UNMutableNotificationContent* _Nullable)replacementContent withContentHandler:(void (^)(UNNotificationContent *_Nonnull))contentHandler;
+ (UNMutableNotificationContent*)serviceExtensionTimeWillExpireRequest:(UNNotificationRequest* _Nonnull)request withMutableNotificationContent:(UNMutableNotificationContent* _Nullable)replacementContent;
@end

#pragma clang diagnostic pop
