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

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wstrict-prototypes"
#pragma clang diagnostic ignored "-Wnullability-completeness"

/* The action type associated to an OSNotificationAction object */
typedef NS_ENUM(NSUInteger, OSNotificationActionType)  {
    OSNotificationActionTypeOpened,
    OSNotificationActionTypeActionTaken
};

@interface OSNotificationAction : NSObject

/* The type of the notification action */
@property(readonly)OSNotificationActionType type;

/* The ID associated with the button tapped. NULL when the actionType is NotificationTapped */
@property(readonly, nullable)NSString* actionId;

@end

/* OneSignal OSNotification */
@interface OSNotification : NSObject

/* Unique Message Identifier */
@property(readonly, nullable)NSString* notificationId;

/* Unique Template Identifier */
@property(readonly, nullable)NSString* templateId;

/* Name of Template */
@property(readonly, nullable)NSString* templateName;

/* True when the key content-available is set to 1 in the apns payload.
   content-available is used to wake your app when the payload is received.
   See Apple's documenation for more details.
  https://developer.apple.com/documentation/uikit/uiapplicationdelegate/1623013-application
*/
@property(readonly)BOOL contentAvailable;

/* True when the key mutable-content is set to 1 in the apns payload.
 mutable-content is used to wake your Notification Service Extension to modify a notification.
 See Apple's documenation for more details.
 https://developer.apple.com/documentation/usernotifications/unnotificationserviceextension
 */
@property(readonly, getter=hasMutableContent)BOOL mutableContent;

/*
 Notification category key previously registered to display with.
 This overrides OneSignal's actionButtons.
 See Apple's documenation for more details.
 https://developer.apple.com/library/content/documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/SupportingNotificationsinYourApp.html#//apple_ref/doc/uid/TP40008194-CH4-SW26
*/
@property(readonly, nullable)NSString* category;

/* The badge assigned to the application icon */
@property(readonly)NSInteger badge;
@property(readonly)NSInteger badgeIncrement;

/* The sound parameter passed to the notification
 By default set to UILocalNotificationDefaultSoundName */
@property(readonly, nullable)NSString* sound;

/* Main push content */
@property(readonly, nullable)NSString* title;
@property(readonly, nullable)NSString* subtitle;
@property(readonly, nullable)NSString* body;

/* Web address to launch within the app via a WKWebView */
@property(readonly, nullable)NSString* launchURL;

/* Additional key value properties set within the payload */
@property(readonly, nullable)NSDictionary* additionalData;

/* iOS 10+ : Attachments sent as part of the rich notification */
@property(readonly, nullable)NSDictionary* attachments;

/* Action buttons passed */
@property(readonly, nullable)NSArray *actionButtons;

/* Holds the original payload received
 Keep the raw value for users that would like to root the push */
@property(readonly, nonnull)NSDictionary *rawPayload;

/* iOS 10+ : Groups notifications into threads */
@property(readonly, nullable)NSString *threadId;

/* Parses an APNS push payload into a OSNotification object.
   Useful to call from your NotificationServiceExtension when the
      didReceiveNotificationRequest:withContentHandler: method fires. */
+ (instancetype)parseWithApns:(nonnull NSDictionary*)message;

/* Convert object into a custom Dictionary / JSON Object */
- (NSDictionary* _Nonnull)jsonRepresentation;

/* Convert object into an NSString that can be convertible into a custom Dictionary / JSON Object */
- (NSString* _Nonnull)stringify;

@end

@interface OSNotificationOpenedResult : NSObject

@property(readonly, nonnull)OSNotification* notification;
@property(readonly, nonnull)OSNotificationAction *action;

/* Convert object into an NSString that can be convertible into a custom Dictionary / JSON Object */
- (NSString* _Nonnull)stringify;

// Convert the class into a NSDictionary
- (NSDictionary *_Nonnull)jsonRepresentation;

@end;

@interface OSInAppMessageOutcome : NSObject

@property (strong, nonatomic, nonnull) NSString *name;
@property (strong, nonatomic, nonnull) NSNumber *weight;
@property (nonatomic) BOOL unique;

// Convert the class into a NSDictionary
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

// Pass in nil means a notification will not display
typedef void (^OSNotificationDisplayResponse)(OSNotification* _Nullable  notification);
/* OneSignal Influence Types */
typedef NS_ENUM(NSUInteger, OSInfluenceType) {
    DIRECT,
    INDIRECT,
    UNATTRIBUTED,
    DISABLED
};
/* OneSignal Influence Channels */
typedef NS_ENUM(NSUInteger, OSInfluenceChannel) {
    IN_APP_MESSAGE,
    NOTIFICATION,
};

@interface OSOutcomeEvent : NSObject

// Session enum (DIRECT, INDIRECT, UNATTRIBUTED, or DISABLED) to determine code route and request params
@property (nonatomic) OSInfluenceType session;

// Notification ids for the current session
@property (strong, nonatomic, nullable) NSArray *notificationIds;

// Id or name of the event
@property (strong, nonatomic, nonnull) NSString *name;

// Time of the event occurring
@property (strong, nonatomic, nonnull) NSNumber *timestamp;

// A weight to attach to the outcome name
@property (strong, nonatomic, nonnull) NSDecimalNumber *weight;

// Convert the object into a NSDictionary
- (NSDictionary * _Nonnull)jsonRepresentation;

@end

typedef NS_ENUM(NSInteger, OSNotificationPermission) {
    // The user has not yet made a choice regarding whether your app can show notifications.
    OSNotificationPermissionNotDetermined = 0,
    
    // The application is not authorized to post user notifications.
    OSNotificationPermissionDenied,
    
    // The application is authorized to post user notifications.
    OSNotificationPermissionAuthorized,
    
    // the application is only authorized to post Provisional notifications (direct to history)
    OSNotificationPermissionProvisional,
    
    // the application is authorized to send notifications for 8 hours. Only used by App Clips.
    OSNotificationPermissionEphemeral
};

// Permission Classes
@interface OSPermissionState : NSObject

@property (readonly, nonatomic) BOOL reachable;
@property (readonly, nonatomic) BOOL hasPrompted;
@property (readonly, nonatomic) BOOL providesAppNotificationSettings;
@property (readonly, nonatomic) OSNotificationPermission status;
- (NSDictionary* _Nonnull)toDictionary;

@end

@interface OSPermissionStateChanges : NSObject

@property (readonly, nonnull) OSPermissionState* to;
@property (readonly, nonnull) OSPermissionState* from;
- (NSDictionary* _Nonnull)toDictionary;

@end

// Subscription Classes
@interface OSSubscriptionState : NSObject

@property (readonly, nonatomic) BOOL isSubscribed; // (yes only if userId, pushToken, and setSubscription exists / are true)
@property (readonly, nonatomic) BOOL isPushDisabled; // returns value of disablePush.
@property (readonly, nonatomic, nullable) NSString* userId;    // AKA OneSignal PlayerId
@property (readonly, nonatomic, nullable) NSString* pushToken; // AKA Apple Device Token
- (NSDictionary* _Nonnull)toDictionary;

@end

@interface OSEmailSubscriptionState : NSObject
@property (readonly, nonatomic, nullable) NSString* emailUserId; // The new Email user ID
@property (readonly, nonatomic, nullable) NSString *emailAddress;
@property (readonly, nonatomic) BOOL isSubscribed;
- (NSDictionary* _Nonnull)toDictionary;
@end

@interface OSSubscriptionStateChanges : NSObject
@property (readonly, nonnull) OSSubscriptionState* to;
@property (readonly, nonnull) OSSubscriptionState* from;
- (NSDictionary* _Nonnull)toDictionary;
@end

@interface OSEmailSubscriptionStateChanges : NSObject
@property (readonly, nonnull) OSEmailSubscriptionState* to;
@property (readonly, nonnull) OSEmailSubscriptionState* from;
- (NSDictionary* _Nonnull)toDictionary;
@end

@protocol OSSubscriptionObserver <NSObject>
- (void)onOSSubscriptionChanged:(OSSubscriptionStateChanges* _Nonnull)stateChanges;
@end

@protocol OSEmailSubscriptionObserver <NSObject>
- (void)onOSEmailSubscriptionChanged:(OSEmailSubscriptionStateChanges* _Nonnull)stateChanges;
@end

@protocol OSPermissionObserver <NSObject>
- (void)onOSPermissionChanged:(OSPermissionStateChanges* _Nonnull)stateChanges;
@end

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

// Convert the class into a NSDictionary
- (NSDictionary *_Nonnull)jsonRepresentation;

@end

typedef void (^OSWebOpenURLResultBlock)(BOOL shouldOpen);

/*Block for generic results on success and errors on failure*/
typedef void (^OSResultSuccessBlock)(NSDictionary* result);
typedef void (^OSFailureBlock)(NSError* error);

/*Block for handling outcome event being sent successfully*/
typedef void (^OSSendOutcomeSuccess)(OSOutcomeEvent* outcome);

// ======= OneSignal Class Interface =========
@interface OneSignal : NSObject

extern NSString* const ONESIGNAL_VERSION;

+ (NSString*)appId;
+ (NSString* _Nonnull)sdkVersionRaw;
+ (NSString* _Nonnull)sdkSemanticVersion;

+ (void)disablePush:(BOOL)disable;

// Only used for wrapping SDKs, such as Unity, Cordova, Xamarin, etc.
+ (void)setMSDKType:(NSString* _Nonnull)type;

#pragma mark Initialization
+ (void)setAppId:(NSString* _Nonnull)newAppId;
+ (void)initWithLaunchOptions:(NSDictionary* _Nullable)launchOptions;
+ (void)setLaunchURLsInApp:(BOOL)launchInApp;
+ (void)setProvidesNotificationSettingsView:(BOOL)providesView;

#pragma mark Logging
typedef NS_ENUM(NSUInteger, ONE_S_LOG_LEVEL) {
    ONE_S_LL_NONE,
    ONE_S_LL_FATAL,
    ONE_S_LL_ERROR,
    ONE_S_LL_WARN,
    ONE_S_LL_INFO,
    ONE_S_LL_DEBUG,
    ONE_S_LL_VERBOSE
};

+ (void)setLogLevel:(ONE_S_LOG_LEVEL)logLevel visualLevel:(ONE_S_LOG_LEVEL)visualLogLevel;
+ (void)onesignalLog:(ONE_S_LOG_LEVEL)logLevel message:(NSString* _Nonnull)message;

#pragma mark Prompt For Push
typedef void(^OSUserResponseBlock)(BOOL accepted);

+ (void)promptForPushNotificationsWithUserResponse:(OSUserResponseBlock)block;
+ (void)promptForPushNotificationsWithUserResponse:(OSUserResponseBlock)block fallbackToSettings:(BOOL)fallback;
+ (void)registerForProvisionalAuthorization:(OSUserResponseBlock)block;
+ (OSDeviceState*)getDeviceState;

#pragma mark Privacy Consent
+ (void)consentGranted:(BOOL)granted;
// Tells your application if privacy consent is still needed from the current user
+ (BOOL)requiresUserPrivacyConsent;
+ (void)setRequiresUserPrivacyConsent:(BOOL)required;

#pragma mark Public Handlers

// If the completion block is not called within 25 seconds of this block being called in notificationWillShowInForegroundHandler then the completion will be automatically fired.
typedef void (^OSNotificationWillShowInForegroundBlock)(OSNotification * _Nonnull notification, OSNotificationDisplayResponse _Nonnull completion);
typedef void (^OSNotificationOpenedBlock)(OSNotificationOpenedResult * _Nonnull result);
typedef void (^OSInAppMessageClickBlock)(OSInAppMessageAction * _Nonnull action);

+ (void)setNotificationWillShowInForegroundHandler:(OSNotificationWillShowInForegroundBlock _Nullable)block;
+ (void)setNotificationOpenedHandler:(OSNotificationOpenedBlock _Nullable)block;
+ (void)setInAppMessageClickHandler:(OSInAppMessageClickBlock _Nullable)block;

#pragma mark Post Notification
+ (void)postNotification:(NSDictionary* _Nonnull)jsonData;
+ (void)postNotification:(NSDictionary* _Nonnull)jsonData onSuccess:(OSResultSuccessBlock _Nullable)successBlock onFailure:(OSFailureBlock _Nullable)failureBlock;
+ (void)postNotificationWithJsonString:(NSString* _Nonnull)jsonData onSuccess:(OSResultSuccessBlock _Nullable)successBlock onFailure:(OSFailureBlock _Nullable)failureBlock;

#pragma mark Location
// - Request and track user's location
+ (void)promptLocation;
+ (void)setLocationShared:(BOOL)enable;
+ (BOOL)isLocationShared;

#pragma mark NotificationService Extension
// iOS 10 only
// Process from Notification Service Extension.
// Used for iOS Media Attachemtns and Action Buttons.
+ (UNMutableNotificationContent*)didReceiveNotificationExtensionRequest:(UNNotificationRequest* _Nonnull)request withMutableNotificationContent:(UNMutableNotificationContent* _Nullable)replacementContent;
+ (UNMutableNotificationContent*)serviceExtensionTimeWillExpireRequest:(UNNotificationRequest* _Nonnull)request withMutableNotificationContent:(UNMutableNotificationContent* _Nullable)replacementContent;

#pragma mark Tags
+ (void)sendTag:(NSString* _Nonnull)key value:(NSString* _Nonnull)value onSuccess:(OSResultSuccessBlock _Nullable)successBlock onFailure:(OSFailureBlock _Nullable)failureBlock;
+ (void)sendTag:(NSString* _Nonnull)key value:(NSString* _Nonnull)value;
+ (void)sendTags:(NSDictionary* _Nonnull)keyValuePair onSuccess:(OSResultSuccessBlock _Nullable)successBlock onFailure:(OSFailureBlock _Nullable)failureBlock;
+ (void)sendTags:(NSDictionary* _Nonnull)keyValuePair;
+ (void)sendTagsWithJsonString:(NSString* _Nonnull)jsonString;
+ (void)getTags:(OSResultSuccessBlock _Nullable)successBlock onFailure:(OSFailureBlock _Nullable)failureBlock;
+ (void)getTags:(OSResultSuccessBlock _Nullable)successBlock;
+ (void)deleteTag:(NSString* _Nonnull)key onSuccess:(OSResultSuccessBlock _Nullable)successBlock onFailure:(OSFailureBlock _Nullable)failureBlock;
+ (void)deleteTag:(NSString* _Nonnull)key;
+ (void)deleteTags:(NSArray* _Nonnull)keys onSuccess:(OSResultSuccessBlock _Nullable)successBlock onFailure:(OSFailureBlock _Nullable)failureBlock;
+ (void)deleteTags:(NSArray<NSString *> *_Nonnull)keys;
+ (void)deleteTagsWithJsonString:(NSString* _Nonnull)jsonString;

#pragma mark Permission, Subscription, and Email Observers
NS_ASSUME_NONNULL_BEGIN

+ (void)addPermissionObserver:(NSObject<OSPermissionObserver>*)observer;
+ (void)removePermissionObserver:(NSObject<OSPermissionObserver>*)observer;

+ (void)addSubscriptionObserver:(NSObject<OSSubscriptionObserver>*)observer;
+ (void)removeSubscriptionObserver:(NSObject<OSSubscriptionObserver>*)observer;

+ (void)addEmailSubscriptionObserver:(NSObject<OSEmailSubscriptionObserver>*)observer;
+ (void)removeEmailSubscriptionObserver:(NSObject<OSEmailSubscriptionObserver>*)observer;
NS_ASSUME_NONNULL_END

#pragma mark Email
// Typedefs defining completion blocks for email & simultaneous HTTP requests
typedef void (^OSEmailFailureBlock)(NSError *error);
typedef void (^OSEmailSuccessBlock)();

// Allows you to set the email for this user.
// Email Auth Token is a (recommended) optional parameter that should *NOT* be generated on the client.
// For security purposes, the emailAuthToken should be generated by your backend server.
// If you do not have a backend server for your application, use the version of thge setEmail: method without an emailAuthToken parameter.
+ (void)setEmail:(NSString * _Nonnull)email withEmailAuthHashToken:(NSString * _Nullable)hashToken;
+ (void)setEmail:(NSString * _Nonnull)email withEmailAuthHashToken:(NSString * _Nullable)hashToken withSuccess:(OSEmailSuccessBlock _Nullable)successBlock withFailure:(OSEmailFailureBlock _Nullable)failureBlock;

// Sets email without an authentication token
+ (void)setEmail:(NSString * _Nonnull)email;
+ (void)setEmail:(NSString * _Nonnull)email withSuccess:(OSEmailSuccessBlock _Nullable)successBlock withFailure:(OSEmailFailureBlock _Nullable)failureBlock;

// Logs the device out of the current email.
+ (void)logoutEmail;
+ (void)logoutEmailWithSuccess:(OSEmailSuccessBlock _Nullable)successBlock withFailure:(OSEmailFailureBlock _Nullable)failureBlock;


#pragma mark External User Id
// Typedefs defining completion blocks for updating the external user id
typedef void (^OSUpdateExternalUserIdFailureBlock)(NSError *error);
typedef void (^OSUpdateExternalUserIdSuccessBlock)(NSDictionary *results);

+ (void)setExternalUserId:(NSString * _Nonnull)externalId;
+ (void)setExternalUserId:(NSString * _Nonnull)externalId withSuccess:(OSUpdateExternalUserIdSuccessBlock _Nullable)successBlock withFailure:(OSUpdateExternalUserIdFailureBlock _Nullable)failureBlock;
+ (void)setExternalUserId:(NSString *)externalId withExternalIdAuthHashToken:(NSString *)hashToken withSuccess:(OSUpdateExternalUserIdSuccessBlock _Nullable)successBlock withFailure:(OSUpdateExternalUserIdFailureBlock _Nullable)failureBlock;
+ (void)removeExternalUserId;
+ (void)removeExternalUserId:(OSUpdateExternalUserIdSuccessBlock _Nullable)successBlock withFailure:(OSUpdateExternalUserIdFailureBlock _Nullable)failureBlock;

#pragma mark In-App Messaging
+ (BOOL)isInAppMessagingPaused;
+ (void)pauseInAppMessages:(BOOL)pause;
+ (void)addTrigger:(NSString * _Nonnull)key withValue:(id _Nonnull)value;
+ (void)addTriggers:(NSDictionary<NSString *, id> * _Nonnull)triggers;
+ (void)removeTriggerForKey:(NSString * _Nonnull)key;
+ (void)removeTriggersForKeys:(NSArray<NSString *> * _Nonnull)keys;
+ (NSDictionary<NSString *, id> * _Nonnull)getTriggers;
+ (id _Nullable)getTriggerValueForKey:(NSString * _Nonnull)key;

#pragma mark Outcomes
+ (void)sendOutcome:(NSString * _Nonnull)name;
+ (void)sendOutcome:(NSString * _Nonnull)name onSuccess:(OSSendOutcomeSuccess _Nullable)success;
+ (void)sendUniqueOutcome:(NSString * _Nonnull)name;
+ (void)sendUniqueOutcome:(NSString * _Nonnull)name onSuccess:(OSSendOutcomeSuccess _Nullable)success;
+ (void)sendOutcomeWithValue:(NSString * _Nonnull)name value:(NSNumber * _Nonnull)value;
+ (void)sendOutcomeWithValue:(NSString * _Nonnull)name value:(NSNumber * _Nonnull)value onSuccess:(OSSendOutcomeSuccess _Nullable)success;
@end

#pragma clang diagnostic pop
