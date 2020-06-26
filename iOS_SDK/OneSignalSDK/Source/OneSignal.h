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

/* The way a notification was displayed to the user */
typedef NS_ENUM(NSUInteger, OSNotificationDisplayType) {
    
    /* Notification is silent */
    OSNotificationDisplayTypeSilent,
    
    /* iOS native notification display */
    OSNotificationDisplayTypeNotification
};

@interface OSNotificationAction : NSObject

/* The type of the notification action */
@property(readonly)OSNotificationActionType type;

/* The ID associated with the button tapped. NULL when the actionType is NotificationTapped */
@property(readonly)NSString* actionID;

@end

/* Notification Payload Received Object */
@interface OSNotificationPayload : NSObject

/* Unique Message Identifier */
@property(readonly)NSString* notificationID;

/* Unique Template Identifier */
@property(readonly)NSString* templateID;

/* Name of Template */
@property(readonly)NSString* templateName;

/* True when the key content-available is set to 1 in the aps payload.
   content-available is used to wake your app when the payload is received.
   See Apple's documenation for more details.
  https://developer.apple.com/documentation/uikit/uiapplicationdelegate/1623013-application
*/
@property(readonly)BOOL contentAvailable;

/* True when the key mutable-content is set to 1 in the aps payload.
 mutable-content is used to wake your Notification Service Extension to modify a notification.
 See Apple's documenation for more details.
 https://developer.apple.com/documentation/usernotifications/unnotificationserviceextension
 */
@property(readonly)BOOL mutableContent;

/*
 Notification category key previously registered to display with.
 This overrides OneSignal's actionButtons.
 See Apple's documenation for more details.
 https://developer.apple.com/library/content/documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/SupportingNotificationsinYourApp.html#//apple_ref/doc/uid/TP40008194-CH4-SW26
*/
@property(readonly)NSString* category;

/* The badge assigned to the application icon */
@property(readonly)NSUInteger badge;
@property(readonly)NSInteger badgeIncrement;

/* The sound parameter passed to the notification
 By default set to UILocalNotificationDefaultSoundName */
@property(readonly)NSString* sound;

/* Main push content */
@property(readonly)NSString* title;
@property(readonly)NSString* subtitle;
@property(readonly)NSString* body;

/* Web address to launch within the app via a WKWebView */
@property(readonly)NSString* launchURL;

/* Additional key value properties set within the payload */
@property(readonly)NSDictionary* additionalData;

/* iOS 10+ : Attachments sent as part of the rich notification */
@property(readonly)NSDictionary* attachments;

/* Action buttons passed */
@property(readonly)NSArray *actionButtons;

/* Holds the original payload received
 Keep the raw value for users that would like to root the push */
@property(readonly)NSDictionary *rawPayload;

/* iOS 10+ : Groups notifications into threads */
@property(readonly)NSString *threadId;

/* Parses an APS push payload into a OSNotificationPayload object.
   Useful to call from your NotificationServiceExtension when the
      didReceiveNotificationRequest:withContentHandler: method fires. */
+ (instancetype)parseWithApns:(nonnull NSDictionary*)message;

@end

/* OneSignal OSNotification */
@interface OSNotification : NSObject

/* Notification Payload */
@property(readonly)OSNotificationPayload* payload;

/* Display method of the notification */
@property(readonly)OSNotificationDisplayType displayType;

/* Set to true when the user was able to see the notification and reacted to it
 Set to false when app is in focus and in-app alerts are disabled, or the remote notification is silent. */
@property(readonly, getter=wasShown)BOOL shown;

/* Set to true if the app was in focus when the notification  */
@property(readonly, getter=wasAppInFocus)BOOL isAppInFocus;

/* Set to true when the received notification is silent
 Silent means there is no alert, sound, or badge payload in the aps dictionary
 requires remote-notification within UIBackgroundModes array of the Info.plist */
@property(readonly, getter=isSilentNotification)BOOL silentNotification;

/* iOS 10+: Indicates whether or not the received notification has mutableContent : 1 assigned to its payload
 Used for UNNotificationServiceExtension to launch extension. */
@property(readonly, getter=hasMutableContent)BOOL mutableContent;

/* Convert object into an NSString that can be convertible into a custom Dictionary / JSON Object */
- (NSString*)stringify;

@end

/* OneSignal OSNotificationGenerationJob used in notificationWillShowInForegroundHandler. The display type for the notification can be changed before it is presented.*/
@interface OSNotificationGenerationJob : NSObject

/* Display method of the notification */
@property(nonatomic)OSNotificationDisplayType displayType;

/* Additional key value properties set within the payload */
@property(readonly)NSDictionary *additionalData;

/* The Notification ID */
@property(readonly)NSString *notificationId;

/* The message title */
@property(readonly)NSString *title;

/* The message body */
@property(readonly)NSString *body;

// Method controlling completion from the notificationWillShowInForegroundHandler
// If 'complete' is not called within 25 seconds of receiving the OSNotificationGenerationJob in notificationWillShowInForegroundHandler then 'complete' will be automatically fired.
- (void)complete;
@end


@interface OSNotificationOpenedResult : NSObject

@property(readonly)OSNotification* notification;
@property(readonly)OSNotificationAction *action;

/* Convert object into an NSString that can be convertible into a custom Dictionary / JSON Object */
- (NSString*)stringify;

@end;

@interface OSInAppMessageAction : NSObject

/* The action name attached to the IAM action */
@property (strong, nonatomic, nullable) NSString *clickName;

/* The URL (if any) that should be opened when the action occurs */
@property (strong, nonatomic, nullable) NSURL *clickUrl;

/* Whether or not the click action is first click on the IAM */
@property (nonatomic) BOOL firstClick;

/* Whether or not the click action dismisses the message */
@property (nonatomic) BOOL closesMessage;

@end

@protocol OSInAppMessageDelegate <NSObject>
@optional
- (void)handleMessageAction:(OSInAppMessageAction * _Nonnull)action NS_SWIFT_NAME(handleMessageAction(action:));
@end

typedef void (^OSNotificationDisplayTypeResponse)(OSNotificationDisplayType displayType);
/* OneSignal Session Types */
typedef NS_ENUM(NSUInteger, Session) {
    DIRECT,
    INDIRECT,
    UNATTRIBUTED,
    DISABLED
};

@interface OSOutcomeEvent : NSObject

// Session enum (DIRECT, INDIRECT, UNATTRIBUTED, or DISABLED) to determine code route and request params
@property (nonatomic) Session session;

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
    OSNotificationPermissionProvisional
};

// Permission Classes
@interface OSPermissionState : NSObject

@property (readonly, nonatomic) BOOL reachable;
@property (readonly, nonatomic) BOOL hasPrompted;
@property (readonly, nonatomic) BOOL providesAppNotificationSettings;
@property (readonly, nonatomic) OSNotificationPermission status;
- (NSDictionary*)toDictionary;

@end

@interface OSPermissionStateChanges : NSObject

@property (readonly) OSPermissionState* to;
@property (readonly) OSPermissionState* from;
- (NSDictionary*)toDictionary;

@end

@protocol OSPermissionObserver <NSObject>
- (void)onOSPermissionChanged:(OSPermissionStateChanges*)stateChanges;
@end


// Subscription Classes
@interface OSSubscriptionState : NSObject

@property (readonly, nonatomic) BOOL subscribed; // (yes only if userId, pushToken, and setSubscription exists / are true)
@property (readonly, nonatomic) BOOL userSubscriptionSetting; // returns setSubscription state.
@property (readonly, nonatomic) NSString* userId;    // AKA OneSignal PlayerId
@property (readonly, nonatomic) NSString* pushToken; // AKA Apple Device Token
- (NSDictionary*)toDictionary;

@end


@interface OSEmailSubscriptionState : NSObject
@property (readonly, nonatomic) NSString* emailUserId; // The new Email user ID
@property (readonly, nonatomic) NSString *emailAddress;
@property (readonly, nonatomic) BOOL subscribed;
- (NSDictionary*)toDictionary;
@end

@interface OSSubscriptionStateChanges : NSObject
@property (readonly) OSSubscriptionState* to;
@property (readonly) OSSubscriptionState* from;
- (NSDictionary*)toDictionary;
@end

@interface OSEmailSubscriptionStateChanges : NSObject
@property (readonly) OSEmailSubscriptionState* to;
@property (readonly) OSEmailSubscriptionState* from;
- (NSDictionary*)toDictionary;
@end

@protocol OSSubscriptionObserver <NSObject>
- (void)onOSSubscriptionChanged:(OSSubscriptionStateChanges*)stateChanges;
@end

@protocol OSEmailSubscriptionObserver <NSObject>
- (void)onOSEmailSubscriptionChanged:(OSEmailSubscriptionStateChanges*)stateChanges;
@end



// Permission+Subscription Classes
@interface OSPermissionSubscriptionState : NSObject

@property (readonly) OSPermissionState* permissionStatus;
@property (readonly) OSSubscriptionState* subscriptionStatus;
@property (readonly) OSEmailSubscriptionState *emailSubscriptionStatus;
- (NSDictionary*)toDictionary;

@end


typedef void (^OSWebOpenURLResultBlock)(BOOL shouldOpen);

/*Block for generic results on success and errors on failure*/
typedef void (^OSResultSuccessBlock)(NSDictionary* result);
typedef void (^OSFailureBlock)(NSError* error);

/*Block for handling the reception of a remote notification */
typedef void (^OSNotificationWillShowInForegroundBlock)(OSNotificationGenerationJob* notification);

/*Block for handling a user reaction to a notification*/
typedef void (^OSNotificationOpenedBlock)(OSNotificationOpenedResult * result);

/*Block for handling user click on an in app message*/
typedef void (^OSInAppMessageClickBlock)(OSInAppMessageAction* action);

/*Block for handling outcome event being sent successfully*/
typedef void (^OSSendOutcomeSuccess)(OSOutcomeEvent* outcome);


/*Dictionary of keys to pass alongside the init settings*/
    
/*Let OneSignal directly prompt for push notifications on init*/
extern NSString * const kOSSettingsKeyAutoPrompt;

/*Enable In-App display of Launch URLs*/
extern NSString * const kOSSettingsKeyInAppLaunchURL;

/* iOS 12 +
 Used to determine if the app is able to present it's
 own customized Notification Settings view
*/
extern NSString * const kOSSettingsKeyProvidesAppNotificationSettings;

// ======= OneSignal Class Interface =========
@interface OneSignal : NSObject

extern NSString* const ONESIGNAL_VERSION;

typedef NS_ENUM(NSUInteger, ONE_S_LOG_LEVEL) {
    ONE_S_LL_NONE, ONE_S_LL_FATAL, ONE_S_LL_ERROR, ONE_S_LL_WARN, ONE_S_LL_INFO, ONE_S_LL_DEBUG, ONE_S_LL_VERBOSE
};


/*
 Initialize OneSignal.
 Sends push token to OneSignal so you can later send notifications.
 */

// - Initialization
+ (void)setAppId:(NSString* _Nonnull)newAppId;
+ (void)setLaunchOptions:(NSDictionary* _Nullable)launchOptions;
+ (void)setAppSettings:(NSDictionary* _Nonnull)settings;

// - Privacy
+ (void)consentGranted:(BOOL)granted;
+ (BOOL)requiresUserPrivacyConsent; // tells your application if privacy consent is still needed from the current user
+ (void)setRequiresUserPrivacyConsent:(BOOL)required; //used by wrapper SDK's to require user privacy consent

@property (class) OSNotificationDisplayType notificationDisplayType;

+ (NSString*)appId;
+ (NSString*)sdk_version_raw;
+ (NSString*)sdk_semantic_version;

// Only use if you set kOSSettingsKeyAutoPrompt to false
+ (void)promptForPushNotificationsWithUserResponse:(void(^)(BOOL accepted))completionHandler;
+ (void)promptForPushNotificationsWithUserResponse:(void (^)(BOOL accepted))completionHandler fallbackToSettings:(BOOL)fallback;

+ (void)registerForProvisionalAuthorization:(void(^)(BOOL accepted))completionHandler;

// - Blocks
+ (void)setNotificationWillShowInForegroundHandler:(OSNotificationWillShowInForegroundBlock _Nonnull)block;
+ (void)setNotificationOpenedHandler:(OSNotificationOpenedBlock _Nonnull)block;
+ (void)setInAppMessageClickHandler:(OSInAppMessageClickBlock _Nonnull)block;

// - Logging
+ (void)setLogLevel:(ONE_S_LOG_LEVEL)logLevel visualLevel:(ONE_S_LOG_LEVEL)visualLogLevel;
+ (void)onesignal_Log:(ONE_S_LOG_LEVEL)logLevel message:(NSString* _Nonnull)message;

// - Tagging
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
+ (void)deleteTags:(NSArray* _Nonnull)keys;
+ (void)deleteTagsWithJsonString:(NSString* _Nonnull)jsonString;

+ (OSPermissionSubscriptionState* _Nonnull)getPermissionSubscriptionState;

+ (void)addPermissionObserver:(NSObject<OSPermissionObserver>* _Nonnull)observer;
+ (void)removePermissionObserver:(NSObject<OSPermissionObserver>* _Nonnull)observer;

+ (void)addSubscriptionObserver:(NSObject<OSSubscriptionObserver>* _Nonnull)observer;
+ (void)removeSubscriptionObserver:(NSObject<OSSubscriptionObserver>* _Nonnull)observer;

+ (void)addEmailSubscriptionObserver:(NSObject<OSEmailSubscriptionObserver>* _Nonnull)observer;
+ (void)removeEmailSubscriptionObserver:(NSObject<OSEmailSubscriptionObserver>* _Nonnull)observer;

+ (void)setSubscription:(BOOL)enable;
+ (BOOL)isInAppMessagingPaused;
+ (void)pauseInAppMessages:(BOOL)pause;

// - Posting Notification
+ (void)postNotification:(NSDictionary* _Nonnull)jsonData;
+ (void)postNotification:(NSDictionary* _Nonnull)jsonData onSuccess:(OSResultSuccessBlock _Nullable)successBlock onFailure:(OSFailureBlock _Nullable)failureBlock;
+ (void)postNotificationWithJsonString:(NSString* _Nonnull)jsonData onSuccess:(OSResultSuccessBlock _Nullable)successBlock onFailure:(OSFailureBlock _Nullable)failureBlock;
+ (NSString* _Nonnull)parseNSErrorAsJsonString:(NSError* _Nonnull)error;

// - Request and track user's location
+ (void)promptLocation;
+ (void)setLocationShared:(BOOL)enable;
+ (BOOL)isLocationShared;


// Only used for wrapping SDKs, such as Unity, Cordova, Xamarin, etc.
+ (void)setMSDKType:(NSString* _Nonnull)type;

// iOS 10 only
// Process from Notification Service Extension.
// Used for iOS Media Attachemtns and Action Buttons.
+ (UNMutableNotificationContent*)didReceiveNotificationExtensionRequest:(UNNotificationRequest* _Nonnull)request withMutableNotificationContent:(UNMutableNotificationContent* _Nullable)replacementContent;
+ (UNMutableNotificationContent*)serviceExtensionTimeWillExpireRequest:(UNNotificationRequest* _Nonnull)request withMutableNotificationContent:(UNMutableNotificationContent* _Nullable)replacementContent;

// Email methods

// Typedefs defining completion blocks for email & simultaneous HTTP requests
typedef void (^OSEmailFailureBlock)(NSError* error);
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


// External user id
+ (void)setExternalUserId:(NSString * _Nonnull)externalId;
+ (void)removeExternalUserId;

// In-App Messaging triggers
+ (void)addTrigger:(NSString * _Nonnull)key withValue:(id _Nonnull)value;
+ (void)addTriggers:(NSDictionary<NSString *, id> * _Nonnull)triggers;
+ (void)removeTriggerForKey:(NSString * _Nonnull)key;
+ (void)removeTriggersForKeys:(NSArray<NSString *> * _Nonnull)keys;
+ (NSDictionary<NSString *, id> * _Nonnull)getTriggers;
+ (id _Nullable)getTriggerValueForKey:(NSString * _Nonnull)key;

// Outcome Events
+ (void)sendOutcome:(NSString * _Nonnull)name;
+ (void)sendOutcome:(NSString * _Nonnull)name onSuccess:(OSSendOutcomeSuccess _Nullable)success;
+ (void)sendUniqueOutcome:(NSString * _Nonnull)name;
+ (void)sendUniqueOutcome:(NSString * _Nonnull)name onSuccess:(OSSendOutcomeSuccess _Nullable)success;
+ (void)sendOutcomeWithValue:(NSString * _Nonnull)name value:(NSNumber * _Nonnull)value;
+ (void)sendOutcomeWithValue:(NSString * _Nonnull)name value:(NSNumber * _Nonnull)value onSuccess:(OSSendOutcomeSuccess _Nullable)success;
@end

#pragma clang diagnostic pop
