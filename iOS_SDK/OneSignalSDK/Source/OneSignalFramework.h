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
#import "OneSignalInAppMessaging.h"
#import "OneSignalLocation.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wstrict-prototypes"
#pragma clang diagnostic ignored "-Wnullability-completeness"

typedef void (^OSWebOpenURLResultBlock)(BOOL shouldOpen);

/*Block for generic results on success and errors on failure*/
typedef void (^OSResultSuccessBlock)(NSDictionary* result);
typedef void (^OSFailureBlock)(NSError* error);

// ======= OneSignal Class Interface =========
@interface OneSignal : NSObject

+ (NSString*)appId;
+ (NSString* _Nonnull)sdkVersionRaw;
+ (NSString* _Nonnull)sdkSemanticVersion;

// Only used for wrapping SDKs, such as Unity, Cordova, Xamarin, etc.
+ (void)setMSDKType:(NSString* _Nonnull)type;

#pragma mark User
+ (id<OSUser>)User NS_REFINED_FOR_SWIFT;
+ (void)login:(NSString * _Nonnull)externalId;
+ (void)login:(NSString * _Nonnull)externalId withToken:(NSString * _Nullable)token
NS_SWIFT_NAME(login(externalId:token:));
+ (void)logout;

#pragma mark Notifications
+ (Class<OSNotifications>)Notifications NS_REFINED_FOR_SWIFT;

#pragma mark Initialization
+ (void)setLaunchOptions:(nullable NSDictionary*)newLaunchOptions; // meant for use by wrappers
+ (void)initialize:(nonnull NSString*)newAppId withLaunchOptions:(nullable NSDictionary*)launchOptions;
+ (void)setLaunchURLsInApp:(BOOL)launchInApp;
+ (void)setProvidesNotificationSettingsView:(BOOL)providesView;

#pragma mark Live Activity
+ (void)enterLiveActivity:(NSString * _Nonnull)activityId withToken:(NSString * _Nonnull)token;
+ (void)enterLiveActivity:(NSString * _Nonnull)activityId withToken:(NSString * _Nonnull)token withSuccess:(OSResultSuccessBlock _Nullable)successBlock withFailure:(OSFailureBlock _Nullable)failureBlock;

+ (void)exitLiveActivity:(NSString * _Nonnull)activityId;
+ (void)exitLiveActivity:(NSString * _Nonnull)activityId withSuccess:(OSResultSuccessBlock _Nullable)successBlock withFailure:(OSFailureBlock _Nullable)failureBlock;

#pragma mark Logging
+ (Class<OSDebug>)Debug NS_REFINED_FOR_SWIFT;

#pragma mark Privacy Consent
+ (void)setPrivacyConsent:(BOOL)granted NS_REFINED_FOR_SWIFT;
+ (BOOL)getPrivacyConsent NS_REFINED_FOR_SWIFT;
/**
 * Tells your application if privacy consent is still needed from the current device.
 * Consent should be provided prior to the invocation of `initialize` to ensure compliance.
 */
+ (BOOL)requiresPrivacyConsent NS_REFINED_FOR_SWIFT;
+ (void)setRequiresPrivacyConsent:(BOOL)required NS_REFINED_FOR_SWIFT;

#pragma mark In-App Messaging
+ (Class<OSInAppMessages>)InAppMessages NS_REFINED_FOR_SWIFT;

#pragma mark Location
+ (Class<OSLocation>)Location NS_REFINED_FOR_SWIFT;

#pragma mark Session
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
