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

// TODO: move these?

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

// TODO: Need to remove these too for user model

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

typedef void (^OSWebOpenURLResultBlock)(BOOL shouldOpen);

/*Block for generic results on success and errors on failure*/
typedef void (^OSResultSuccessBlock)(NSDictionary* result);
typedef void (^OSFailureBlock)(NSError* error);

@protocol OSInAppMessages <NSObject>

+ (void)addTrigger:(NSString * _Nonnull)key withValue:(id _Nonnull)value;
+ (void)addTriggers:(NSDictionary<NSString *, id> * _Nonnull)triggers;
+ (void)removeTriggerForKey:(NSString * _Nonnull)key;
+ (void)removeTriggersForKeys:(NSArray<NSString *> * _Nonnull)keys;
+ (void)clearTriggers;
// Allows Swift users to: OneSignal.InAppMessages.Paused = true
+ (BOOL)paused NS_REFINED_FOR_SWIFT;
+ (void)paused:(BOOL)pause NS_REFINED_FOR_SWIFT;

typedef void (^OSInAppMessageClickBlock)(OSInAppMessageAction * _Nonnull action);
+ (void)setInAppMessageClickHandler:(OSInAppMessageClickBlock _Nullable)block;
+ (void)setInAppMessageLifecycleHandler:(NSObject<OSInAppMessageLifecycleHandler> *_Nullable)delegate;

@end

// ======= OneSignal Class Interface =========
@interface OneSignal : NSObject

+ (NSString*)appId;
+ (NSString* _Nonnull)sdkVersionRaw;
+ (NSString* _Nonnull)sdkSemanticVersion;

// Only used for wrapping SDKs, such as Unity, Cordova, Xamarin, etc.
+ (void)setMSDKType:(NSString* _Nonnull)type;

#pragma mark User Model 🔥

#pragma mark User Model - User Identity 🔥
+ (id<OSUser>)User NS_REFINED_FOR_SWIFT;
+ (void)login:(NSString * _Nonnull)externalId;
+ (void)login:(NSString * _Nonnull)externalId withToken:(NSString * _Nullable)token
NS_SWIFT_NAME(login(externalId:token:));
+ (void)logout;

#pragma mark User Model - Notifications namespace 🔥
+ (Class<OSNotifications>)Notifications NS_REFINED_FOR_SWIFT;

#pragma mark Initialization
+ (void)initialize:(nonnull NSString*)newAppId withLaunchOptions:(nullable NSDictionary*)launchOptions;
+ (void)setLaunchURLsInApp:(BOOL)launchInApp;
+ (void)setProvidesNotificationSettingsView:(BOOL)providesView;

#pragma mark Logging
+ (void)setLogLevel:(ONE_S_LOG_LEVEL)logLevel visualLevel:(ONE_S_LOG_LEVEL)visualLogLevel; // TODO: UM split up into 2?

#pragma mark Privacy Consent
+ (void)setPrivacyConsent:(BOOL)granted;
// TODO: add getPrivacyConsent method
/**
 * Tells your application if privacy consent is still needed from the current device.
 * Consent should be provided prior to the invocation of `initialize` to ensure compliance.
 */
+ (BOOL)requiresPrivacyConsent;
+ (void)setRequiresPrivacyConsent:(BOOL)required;

#pragma mark Location
// - Request and track user's location
+ (void)promptLocation;
+ (void)setLocationShared:(BOOL)enable;
+ (BOOL)isLocationShared;

#pragma mark Permission, Subscription, and Email Observers

#pragma mark In-App Messaging

+ (Class<OSInAppMessages>)InAppMessages NS_REFINED_FOR_SWIFT;

#pragma mark Outcomes
+ (Class<OSSession>)Session NS_REFINED_FOR_SWIFT;

#pragma mark Extension
// iOS 10 only
// Process from Notification Service Extension.
// Used for iOS Media Attachemtns and Action Buttons.
+ (UNMutableNotificationContent*)didReceiveNotificationExtensionRequest:(UNNotificationRequest* _Nonnull)request withMutableNotificationContent:(UNMutableNotificationContent* _Nullable)replacementContent __deprecated_msg("Please use didReceiveNotificationExtensionRequest:withMutableNotificationContent:withContentHandler: instead.");
+ (UNMutableNotificationContent*)didReceiveNotificationExtensionRequest:(UNNotificationRequest* _Nonnull)request withMutableNotificationContent:(UNMutableNotificationContent* _Nullable)replacementContent withContentHandler:(void (^)(UNNotificationContent *_Nonnull))contentHandler;
+ (UNMutableNotificationContent*)serviceExtensionTimeWillExpireRequest:(UNNotificationRequest* _Nonnull)request withMutableNotificationContent:(UNMutableNotificationContent* _Nullable)replacementContent;
@end

#pragma clang diagnostic pop
