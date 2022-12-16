/**
 * Modified MIT License
 *
 * Copyright 2017 OneSignal
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

#import "OneSignalFramework.h"
#import "OneSignalInternal.h"
#import "OneSignalTracker.h"
#import "OneSignalTrackIAP.h"
#import "OneSignalLocation.h"
#import "OneSignalJailbreakDetection.h"
#import "OneSignalMobileProvision.h"
#import "OneSignalHelper.h"
// #import "UNUserNotificationCenter+OneSignal.h" // TODO: This is in Notifications
#import "OneSignalSelectorHelpers.h"
#import "UIApplicationDelegate+OneSignal.h"
#import "OSNotification+Internal.h"
#import "OSMigrationController.h"
#import "OSBackgroundTaskManagerImpl.h"
#import "OSFocusCallParams.h"

#import <OneSignalNotifications/OneSignalNotifications.h>

// TODO: ^ if no longer support ios 9 + 10 after user model, need to address all stuffs

#import <OneSignalOutcomes/OneSignalOutcomes.h>
#import "OneSignalExtension/OneSignalExtension.h"

#import "OSObservable.h"
#import "OSPendingCallbacks.h"

#import <stdlib.h>
#import <stdio.h>
#import <sys/types.h>
#import <sys/utsname.h>
#import <sys/sysctl.h>
#import <objc/runtime.h>
#import <UIKit/UIKit.h>

 //#import <OneSignalUser/OneSignalUser-Swift.h>
// #import <OneSignalUser/OneSignalUser.h>

#import <UserNotifications/UserNotifications.h>

#import "DelayedConsentInitializationParameters.h"
#import "OneSignalDialogController.h"

#import "OSMessagingController.h"
#import "OSInAppMessageAction.h"
#import "OSInAppMessageInternal.h"
#import "OneSignalInAppMessaging.h"

#import "OneSignalLifecycleObserver.h"

#import "LanguageProviderAppDefined.h"
#import "LanguageContext.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

/* Enable the default in-app launch urls*/
NSString* const kOSSettingsKeyInAppLaunchURL = @"kOSSettingsKeyInAppLaunchURL";

/* Omit no appId error logging, for use with wrapper SDKs. */
NSString* const kOSSettingsKeyInOmitNoAppIdLogging = @"kOSSettingsKeyInOmitNoAppIdLogging";

@interface OneSignal (SessionStatusDelegate)
@end

@implementation OneSignal

static NSString* mSDKType = @"native";

static NSMutableArray* pendingSendTagCallbacks;
static OSResultSuccessBlock pendingGetTagsSuccessBlock;
static OSFailureBlock pendingGetTagsFailureBlock;

static NSMutableArray* pendingLiveActivityUpdates;

// Has attempted to register for push notifications with Apple since app was installed.
static BOOL registeredWithApple = NO;

// Indicates if initialization of the SDK has been delayed until the user gives privacy consent
static BOOL delayedInitializationForPrivacyConsent = false;

// If initialization is delayed, this object holds params such as the app ID so that the init()
// method can be called the moment the user provides privacy consent.
DelayedConsentInitializationParameters *_delayedInitParameters;
+ (DelayedConsentInitializationParameters *)delayedInitParameters {
    return _delayedInitParameters;
}

static NSString* appId;
static NSDictionary* launchOptions;
static NSDictionary* appSettings;
// Ensure we only initlize the SDK once even if the public method is called more
// Called after successfully calling setAppId and setLaunchOptions
static BOOL initDone = false;

//used to ensure registration occurs even if APNS does not respond
static NSDate *initializationTime;
static NSTimeInterval maxApnsWait = APNS_TIMEOUT;
static NSTimeInterval reattemptRegistrationInterval = REGISTRATION_DELAY_SECONDS;

// Set when the app is launched
static NSDate *sessionLaunchTime;

NSString* emailToSet;
static LanguageContext* languageContext;

BOOL usesAutoPrompt = false;

static BOOL performedOnSessionRequest = false;


// static property def to add developer's OSPermissionStateChanges observers to.
static ObservablePermissionStateChangesType* _permissionStateChangesObserver;
+ (ObservablePermissionStateChangesType*)permissionStateChangesObserver {
    if (!_permissionStateChangesObserver)
        _permissionStateChangesObserver = [[OSObservable alloc] initWithChangeSelector:@selector(onOSPermissionChanged:)];
    return _permissionStateChangesObserver;
}

/*
 Indicates if the iOS params request has started
 Set to true when the method is called and set false if the request's failure callback is triggered
 */
static BOOL _didCallDownloadParameters = false;
+ (BOOL)didCallDownloadParameters {
    return _didCallDownloadParameters;
}

/*
 Indicates if the iOS params request is complete
 Set to true when the request's success callback is triggered
 */
static BOOL _downloadedParameters = false;
+ (BOOL)downloadedParameters {
    return _downloadedParameters;
}

static OneSignalReceiveReceiptsController* _receiveReceiptsController;
+ (OneSignalReceiveReceiptsController*)receiveReceiptsController {
    if (!_receiveReceiptsController)
        _receiveReceiptsController = [OneSignalReceiveReceiptsController new];
    
    return _receiveReceiptsController;
}

static AppEntryAction _appEntryState = APP_CLOSE;
+ (AppEntryAction)appEntryState {
    return _appEntryState;
}

+ (void)setAppEntryState:(AppEntryAction)appEntryState {
    _appEntryState = appEntryState;
}

+ (NSString*)appId {
    return appId;
}

+ (NSString*)sdkVersionRaw {
	return ONESIGNAL_VERSION;
}

+ (NSString*)sdkSemanticVersion {
	// examples:
	// ONESIGNAL_VERSION = @"020402" returns 2.4.2
	// ONESIGNAL_VERSION = @"001000" returns 0.10.0
	// so that's 6 digits, where the first two are the major version
	// the second two are the minor version and that last two, the patch.
	// c.f. http://semver.org/

	return [ONESIGNAL_VERSION one_getSemanticVersion];
}

+ (void)setMSDKType:(NSString*)type {
    mSDKType = type;
}

//TODO: This is related to unit tests and will change with um tests
+ (void)clearStatics {
    appId = nil;
    [OneSignalConfigManager setAppId:nil];
    launchOptions = false;
    appSettings = nil;
    initDone = false;
    usesAutoPrompt = false;
    
    [OSNotificationsManager clearStatics];
    registeredWithApple = false;
    
    _permissionStateChangesObserver = nil;
    
    _downloadedParameters = false;
    _didCallDownloadParameters = false;
    
    maxApnsWait = APNS_TIMEOUT;
    reattemptRegistrationInterval = REGISTRATION_DELAY_SECONDS;

    sessionLaunchTime = [NSDate date];
    performedOnSessionRequest = false;

    [OSOutcomes clearStatics];
    
    [OSSessionManager resetSharedSessionManager];
}

#pragma mark User Model 🔥

#pragma mark User Model - User Identity 🔥

+ (id<OSUser>)User {
    return [OneSignalUserManagerImpl.sharedInstance User];
}

+ (void)login:(NSString * _Nonnull)externalId {
    // return if no app_id / the user has not granted privacy permissions
    if ([OneSignalConfigManager shouldAwaitAppIdAndLogMissingPrivacyConsentForMethod:@"login"]) {
        return;
    }
    [OneSignalUserManagerImpl.sharedInstance loginWithExternalId:externalId token:nil];
    // refine Swift name for Obj-C? But doesn't matter as much since this isn't public API
}

+ (void)login:(NSString * _Nonnull)externalId withToken:(NSString * _Nullable)token {
    // TODO: Need to await download iOS params
    // return if no app_id / the user has not granted privacy permissions
    if ([OneSignalConfigManager shouldAwaitAppIdAndLogMissingPrivacyConsentForMethod:@"login"]) {
        return;
    }
    [OneSignalUserManagerImpl.sharedInstance loginWithExternalId:externalId token:token];
}

+ (void)logout {
    [OneSignalUserManagerImpl.sharedInstance logout];
}

#pragma mark User Model - Notifications namespace 🔥
+ (Class<OSNotifications>)Notifications {
    return [OSNotificationsManager Notifications];
}

+ (Class<OSSession>)Session {
    return [OSOutcomes Session];
}

+ (Class<OSInAppMessages>)InAppMessages {
    return [OneSignalInAppMessaging InAppMessages];
}

+ (Class<OSLocation>)Location {
    return [OneSignalLocation Location];
}

/*
 This is should be set from all OneSignal entry points.
 */
+ (void)initialize:(nonnull NSString*)newAppId withLaunchOptions:(nullable NSDictionary*)launchOptions {
    [self setAppId:newAppId];
    [self setLaunchOptions:launchOptions];
    [self init];
}

+ (NSString * _Nullable)getCachedAppId {
    let prevAppId = [OneSignalUserDefaults.initStandard getSavedStringForKey:OSUD_APP_ID defaultValue:nil];
    if (!prevAppId) {
        [OneSignalLog onesignalLog:ONE_S_LL_INFO message:@"Waiting for setAppId(appId) with a valid appId to complete OneSignal init!"];
    } else {
        let logMessage = [NSString stringWithFormat:@"Initializing OneSignal with cached appId: '%@'.", prevAppId];
        [OneSignalLog onesignalLog:ONE_S_LL_INFO message:logMessage];
    }
    return prevAppId;
}

/*
 1/2 steps in OneSignal init, relying on setLaunchOptions (usage order does not matter)
 Sets the app id OneSignal should use in the application
 */
// TODO: For release, note this change in migration guide:
// No longer reading appID from plist @"OneSignal_APPID" and @"GameThrive_APPID"
+ (void)setAppId:(nonnull NSString*)newAppId {
    [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"setAppId(id) called with appId: %@!", newAppId]];

    if (!newAppId || newAppId.length == 0) {
        NSString* cachedAppId = [self getCachedAppId];
        if (cachedAppId) {
            appId = cachedAppId;
            [OneSignalConfigManager setAppId:cachedAppId];
        } else {
            return;
        }
    } else if (appId && ![newAppId isEqualToString:appId])  {
        // Pre-check on app id to make sure init of SDK is performed properly
        //     Usually when the app id is changed during runtime so that SDK is reinitialized properly
        initDone = false;
    }
    appId = newAppId;
    [OneSignalConfigManager setAppId:newAppId];
    [self handleAppIdChange:appId];
}

+ (BOOL)isValidAppId:(NSString*)appId {
    if (!appId || ![[NSUUID alloc] initWithUUIDString:appId]) {
        [OneSignalLog onesignalLog:ONE_S_LL_FATAL message:@"OneSignal AppId format is invalid.\nExample: 'b2f7f966-d8cc-11e4-bed1-df8f05be55ba'\n"];
        return false;
    }
    return true;
}

/*
 1/2 steps in OneSignal init, relying on setAppId (usage order does not matter)
 Sets the iOS sepcific app settings
 Method must be called to successfully init OneSignal
 */
+ (void)setLaunchOptions:(nullable NSDictionary*)newLaunchOptions {
    [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"setLaunchOptions() called with launchOptions: %@!", launchOptions.description]];

    launchOptions = newLaunchOptions;
    
    // Cold start from tap on a remote notification
    //  NOTE: launchOptions may be nil if tapping on a notification's action button.
    NSDictionary* userInfo = [launchOptions objectForKey:UIApplicationLaunchOptionsRemoteNotificationKey];
    if (userInfo)
        [OSNotificationsManager setColdStartFromTapOnNotification:YES];
}

+ (void)setLaunchURLsInApp:(BOOL)launchInApp {
    NSMutableDictionary *newSettings = [[NSMutableDictionary alloc] initWithDictionary:appSettings];
    newSettings[kOSSettingsKeyInAppLaunchURL] = launchInApp ? @true : @false;
    appSettings = newSettings;
    // This allows this method to have an effect after init is called
    [self enableInAppLaunchURL:launchInApp];
}

+ (void)setProvidesNotificationSettingsView:(BOOL)providesView {
    if (providesView && [OSDeviceUtils isIOSVersionGreaterThanOrEqual:@"12.0"]) {
        [OSNotificationsManager setProvidesNotificationSettingsView: providesView];
    }
}

#pragma mark Initialization

+ (BOOL)shouldStartNewSession {
    // return if the user has not granted privacy permissions
    if ([OSPrivacyConsentController shouldLogMissingPrivacyConsentErrorWithMethodName:nil])
        return false;
    
    // TODO: There used to be many additional checks here but for now, let's omit. Consider adding them or variants later.
    
    // The SDK hasn't finished initializing yet, init() will start the new session
    if (!initDone) {
        [OneSignalLog onesignalLog:ONE_S_LL_DEBUG message:[NSString stringWithFormat:@"shouldStartNewSession:initDone: %d", initDone]];
        return false;
    }
    
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    NSTimeInterval lastTimeClosed = [OneSignalUserDefaults.initStandard getSavedDoubleForKey:OSUD_APP_LAST_CLOSED_TIME defaultValue:0];

    if (lastTimeClosed == 0) {
        [OneSignalLog onesignalLog:ONE_S_LL_DEBUG message:@"shouldStartNewSession:lastTimeClosed: default."];
        return true;
    }

    // Make sure last time we closed app was more than 30 secs ago
    const int minTimeThreshold = 30;
    NSTimeInterval delta = now - lastTimeClosed;
    [OneSignalLog onesignalLog:ONE_S_LL_DEBUG message:[NSString stringWithFormat:@"shouldStartNewSession:timeSincelastClosed: %f", delta]];

    return delta >= minTimeThreshold;
}

+ (void)startNewSession:(BOOL)fromInit {
    // If not called from init, need to check if we should start a new session
    if (!fromInit && ![self shouldStartNewSession]) {
        return;
    }
    
    [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:@"startNewSession"];
    
    // Run on the main queue as it is possible for this to be called from multiple queues.
    // Also some of the code in the method is not thread safe such as _outcomeEventsController.
    [OneSignalHelper dispatch_async_on_main_queue:^{
        [self startNewSessionInternal];
    }];
}

+ (void)startNewSessionInternal {
    [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:@"startNewSessionInternal"];
    
    // return if the user has not granted privacy permissions
    if ([OSPrivacyConsentController shouldLogMissingPrivacyConsentErrorWithMethodName:nil])
        return;

    [OSOutcomes.sharedController clearOutcomes];

    [[OSSessionManager sharedSessionManager] restartSessionIfNeeded:_appEntryState];
    
    [OneSignalTrackFirebaseAnalytics trackInfluenceOpenEvent];
    
    // Clear last location after attaching data to user state or not
    [OneSignalLocation clearLastLocation];
    [OSNotificationsManager sendNotificationTypesUpdateToDelegate];

    sessionLaunchTime = [NSDate date];

    [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:@"Calling OneSignal `create/on_session`"];

    // TODO: Figure out if Create User also sets session_count automatically on backend
    [OneSignalUserManagerImpl.sharedInstance startNewSession];
    
    // This is almost always going to be nil the first time.
    // The OSMessagingController is an OSPushSubscriptionObserver so that we pull IAMs once we have the sub id
    NSString *subscriptionId = OneSignalUserManagerImpl.sharedInstance.pushSubscription.subscriptionId;
    if (subscriptionId) {
        [OSMessagingController.sharedInstance getInAppMessagesFromServer:subscriptionId];
    }
    
    // The below means there are NO IAMs until on_session returns
    // because they can be ended, paused, or deleted from the server, or your segment has changed and you're no longer eligible
    
    // ^ Do the "on_session" call, send session_count++
    // on success:
    //    [OneSignalLocation sendLocation];
    //    [self executePendingLiveActivityUpdates];
    //    [self receivedInAppMessageJson:results[@"push"][@"in_app_messages"]];  // go to controller
    
    // on failure:
    //    [OSMessagingController.sharedInstance updateInAppMessagesFromCache]; // go to controller
}

+ (void)initInAppLaunchURLSettings:(NSDictionary*)settings {
    // TODO: Make booleans on the class instead of as keys in a dictionary
    let standardUserDefaults = OneSignalUserDefaults.initStandard;
    // Check if disabled in-app launch url if passed a NO
    if (settings[kOSSettingsKeyInAppLaunchURL] && [settings[kOSSettingsKeyInAppLaunchURL] isKindOfClass:[NSNumber class]])
        
        [self enableInAppLaunchURL:[settings[kOSSettingsKeyInAppLaunchURL] boolValue]];
    
    else if (![standardUserDefaults keyExists:OSUD_NOTIFICATION_OPEN_LAUNCH_URL]) {
        // Only need to default to true if the app doesn't already have this setting saved in NSUserDefaults
        
        [self enableInAppLaunchURL:true];
    }
}

+ (void)startInAppMessages {
    [OneSignalInAppMessaging start];
}

+ (void)startOutcomes {
    [OSOutcomes start];
    [OSOutcomes.sharedController cleanUniqueOutcomeNotifications]; // TODO: should this actually be in new session instead of init
}

+ (void)startLocation {
    [OneSignalLocation start];
}

+ (void)startTrackFirebaseAnalytics {
    if ([OneSignalTrackFirebaseAnalytics libraryExists]) {
        [OneSignalTrackFirebaseAnalytics init];
    }
}

+ (void)startTrackIAP {
    if ([OneSignalTrackIAP canTrack])
        [OneSignalTrackIAP sharedInstance]; // start observing purchases
}

+ (void)startLifecycleObserver {
    [OneSignalLifecycleObserver registerLifecycleObserver];
}

+ (void)startUserManager {
    [OneSignalUserManagerImpl.sharedInstance start];
    [OSNotificationsManager sendPushTokenToDelegate];
}

+ (void)delayInitializationForPrivacyConsent {
    [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:@"Delayed initialization of the OneSignal SDK until the user provides privacy consent using the consentGranted() method"];
    delayedInitializationForPrivacyConsent = true;
    _delayedInitParameters = [[DelayedConsentInitializationParameters alloc] initWithLaunchOptions:launchOptions withAppId:appId];
    // Init was not successful, set appId back to nil
    appId = nil;
    [OneSignalConfigManager setAppId:nil];
}

/*
 Called after setAppId and setLaunchOptions, depending on which one is called last (order does not matter)
 */
+ (void)init {
    [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:@"setLaunchOptions(launchOptions) successful and appId is set, initializing OneSignal..."];
    
    // TODO: We moved this check to the top of this method, we should test this.
    if (initDone) {
        return;
    }
    
    [[OSMigrationController new] migrate];
    
    OSBackgroundTaskManager.delegate = [OSBackgroundTaskManagerImpl new];

    [self registerForAPNsToken];
    
    // Wrapper SDK's call init twice and pass null as the appId on the first call
    //  the app ID is required to download parameters, so do not download params until the appID is provided
    if (!_didCallDownloadParameters && appId && appId != (id)[NSNull null])
        [self downloadIOSParamsWithAppId:appId];
    
    // using classes as delegates is not best practice. We should consider using a shared instance of a class instead
    [OSSessionManager sharedSessionManager].delegate = (id<SessionStatusDelegate>)self;
        
    if ([self requiresPrivacyConsent]) {
        [self delayInitializationForPrivacyConsent];
        return;
    }
    
    // Now really initializing the SDK!

    // TODO: Language move to user?
    languageContext = [LanguageContext new];
    
    [self initInAppLaunchURLSettings:appSettings];
    
    // Invalid app ids reaching here will cause failure
    if (![self isValidAppId:appId])
        return;

    // TODO: Consider the implications of `registerUserInternal` previously running on the main_queue
    // Some of its calls have been moved into `init` here below
    /*
     // Run on the main queue as it is possible for this to be called from multiple queues.
     // Also some of the code in the method is not thread safe such as _outcomeEventsController.
     [OneSignalHelper dispatch_async_on_main_queue:^{
         [self registerUserInternal];
     }];
     */
    
    [OSNotificationsManager clearBadgeCount:false];
    [self startOutcomes];
    [self startLocation];
    [self startTrackIAP];
    [self startTrackFirebaseAnalytics];
    [self startLifecycleObserver];
    //TODO: Should these be started in Dependency order? e.g. IAM depends on User Manager shared instance
    [self startUserManager]; // By here, app_id exists, and consent is granted.
    [self startInAppMessages];
    [self startNewSession:YES];
    initDone = true;
}

+ (NSString *)appGroupKey {
    return [OneSignalUserDefaults appGroupName];
}

+ (void)handleAppIdChange:(NSString*)appId {
    // TODO: Maybe in the future we can make a file with add app ids and validate that way?
    if ([@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba" isEqualToString:appId] ||
        [@"5eb5a37e-b458-11e3-ac11-000c2940e62c" isEqualToString:appId]) {
        [OneSignalLog onesignalLog:ONE_S_LL_WARN message:@"OneSignal Example AppID detected, please update to your app's id found on OneSignal.com"];
    }

    let standardUserDefaults = OneSignalUserDefaults.initStandard;
    let prevAppId = [standardUserDefaults getSavedStringForKey:OSUD_APP_ID defaultValue:nil];

    // Handle changes to the app id, this might happen on a developer's device when testing
    // Will also run the first time OneSignal is initialized
    if (appId && ![appId isEqualToString:prevAppId]) {
        initDone = false;
        _downloadedParameters = false;
        _didCallDownloadParameters = false;

        let sharedUserDefaults = OneSignalUserDefaults.initShared;
        
        [standardUserDefaults saveStringForKey:OSUD_APP_ID withValue:appId];
        
        // Remove player_id from both standard and shared NSUserDefaults
        [standardUserDefaults removeValueForKey:OSUD_PLAYER_ID_TO];
        [sharedUserDefaults removeValueForKey:OSUD_PLAYER_ID_TO];
        // TODO: Clear all cached data, is it sufficient to call logout
        [self logout];
    }
    
    // Always save appId and player_id as it will not be present on shared if:
    //   - Updating from an older SDK
    //   - Updating to an app that didn't have App Groups setup before
    [OneSignalUserDefaults.initShared saveStringForKey:OSUD_APP_ID withValue:appId];
}

+ (void)registerForAPNsToken {
    registeredWithApple = OSNotificationsManager.currentPermissionState.accepted;
    
    // Register with Apple's APNS server if we registed once before or if auto-prompt hasn't been disabled.
    if (registeredWithApple && !OSNotificationsManager.currentPermissionState.ephemeral) {
        [OSNotificationsManager requestPermission:nil];
    } else {
        [OSNotificationsManager checkProvisionalAuthorizationStatus];
        [OSNotificationsManager registerForAPNsToken];
    }
}

+ (void)setRequiresPrivacyConsent:(BOOL)required {
    [OSPrivacyConsentController setRequiresPrivacyConsent:required];
}

+ (BOOL)requiresPrivacyConsent {
    return [OSPrivacyConsentController requiresUserPrivacyConsent];
}

+ (void)setPrivacyConsent:(BOOL)granted {
    [OSPrivacyConsentController consentGranted:granted];
    
    if (!granted || !delayedInitializationForPrivacyConsent || _delayedInitParameters == nil)
        return;
    // Try to init again using delayed params
    [self initialize:_delayedInitParameters.appId withLaunchOptions:_delayedInitParameters.launchOptions];
    delayedInitializationForPrivacyConsent = false;
    _delayedInitParameters = nil;
}

+ (BOOL)getPrivacyConsent {
    return [OSPrivacyConsentController getPrivacyConsent];
}

+ (void)downloadIOSParamsWithAppId:(NSString *)appId {
    [OneSignalLog onesignalLog:ONE_S_LL_DEBUG message:@"Downloading iOS parameters for this application"];
    _didCallDownloadParameters = true;
    // This will be nil unless we have a cached user
    NSString *userId = OneSignalUserManagerImpl.sharedInstance.User.pushSubscription.subscriptionId;
    [OneSignalClient.sharedClient executeRequest:[OSRequestGetIosParams withUserId:userId appId:appId] onSuccess:^(NSDictionary *result) {

        if (result[IOS_REQUIRES_USER_ID_AUTHENTICATION]) {
            OneSignalUserManagerImpl.sharedInstance.requiresUserAuth = [result[IOS_REQUIRES_USER_ID_AUTHENTICATION] boolValue];
        }

        if (!usesAutoPrompt && result[IOS_USES_PROVISIONAL_AUTHORIZATION] != (id)[NSNull null]) {
            [OneSignalUserDefaults.initStandard saveBoolForKey:OSUD_USES_PROVISIONAL_PUSH_AUTHORIZATION withValue:[result[IOS_USES_PROVISIONAL_AUTHORIZATION] boolValue]];

            [OSNotificationsManager checkProvisionalAuthorizationStatus];
        }

        if (result[IOS_RECEIVE_RECEIPTS_ENABLE] != (id)[NSNull null])
            [OneSignalUserDefaults.initShared saveBoolForKey:OSUD_RECEIVE_RECEIPTS_ENABLED withValue:[result[IOS_RECEIVE_RECEIPTS_ENABLE] boolValue]];

        [[OSRemoteParamController sharedController] saveRemoteParams:result];
        if ([[OSRemoteParamController sharedController] hasLocationKey]) {
            BOOL shared = [result[IOS_LOCATION_SHARED] boolValue];
            [OneSignalLocation startLocationSharedWithFlag:shared];
        }
        
        if ([[OSRemoteParamController sharedController] hasPrivacyConsentKey]) {
            BOOL required = [result[IOS_REQUIRES_USER_PRIVACY_CONSENT] boolValue];
            [[OSRemoteParamController sharedController] savePrivacyConsentRequired:required];
            [OSPrivacyConsentController setRequiresPrivacyConsent:required];
        }

        if (result[OUTCOMES_PARAM] && result[OUTCOMES_PARAM][IOS_OUTCOMES_V2_SERVICE_ENABLE])
            [[OSOutcomeEventsCache sharedOutcomeEventsCache] saveOutcomesV2ServiceEnabled:[result[OUTCOMES_PARAM][IOS_OUTCOMES_V2_SERVICE_ENABLE] boolValue]];

        [[OSTrackerFactory sharedTrackerFactory] saveInfluenceParams:result];
        [OneSignalTrackFirebaseAnalytics updateFromDownloadParams:result];

        _downloadedParameters = true;

    } onFailure:^(NSError *error) {
        _didCallDownloadParameters = false;
    }];
}

+ (void)enableInAppLaunchURL:(BOOL)enable {
    [OneSignalUserDefaults.initStandard saveBoolForKey:OSUD_NOTIFICATION_OPEN_LAUNCH_URL withValue:enable];
}

//TODO: consolidate in one place. Where???
+ (void)launchWebURL:(NSString*)openUrl {
    
    NSString* toOpenUrl = [OneSignalCoreHelper trimURLSpacing:openUrl];
    
    if (toOpenUrl && [OneSignalCoreHelper verifyURL:toOpenUrl]) {
        NSURL *url = [NSURL URLWithString:toOpenUrl];
        // Give the app resume animation time to finish when tapping on a notification from the notification center.
        // Isn't a requirement but improves visual flow.
        [OneSignalHelper performSelector:@selector(displayWebView:) withObject:url afterDelay:0.5];
    }
    
}

// Called from the app's Notification Service Extension
+ (UNMutableNotificationContent*)didReceiveNotificationExtensionRequest:(UNNotificationRequest*)request withMutableNotificationContent:(UNMutableNotificationContent*)replacementContent {
    return [OneSignalNotificationServiceExtensionHandler
            didReceiveNotificationExtensionRequest:request
            withMutableNotificationContent:replacementContent];
}

// Called from the app's Notification Service Extension. Calls contentHandler() to display the notification
+ (UNMutableNotificationContent*)didReceiveNotificationExtensionRequest:(UNNotificationRequest*)request                              withMutableNotificationContent:(UNMutableNotificationContent*)replacementContent
                withContentHandler:(void (^)(UNNotificationContent * _Nonnull))contentHandler {
    return [OneSignalNotificationServiceExtensionHandler
            didReceiveNotificationExtensionRequest:request
            withMutableNotificationContent:replacementContent
            withContentHandler:contentHandler];
}

// Called from the app's Notification Service Extension
+ (UNMutableNotificationContent*)serviceExtensionTimeWillExpireRequest:(UNNotificationRequest*)request withMutableNotificationContent:(UNMutableNotificationContent*)replacementContent {
    return [OneSignalNotificationServiceExtensionHandler
            serviceExtensionTimeWillExpireRequest:request
            withMutableNotificationContent:replacementContent];
}

//TODO: move to sessions/onfocus
+ (NSDate *)sessionLaunchTime {
    return sessionLaunchTime;
}

/*
 Start of outcome module
 */

+ (void)sendClickActionOutcomes:(NSArray<OSInAppMessageOutcome *> *)outcomes {
    if (![OSOutcomes sharedController]) {
        [OneSignalLog onesignalLog:ONE_S_LL_ERROR message:@"Make sure OneSignal init is called first"];
        return;
    }

    [OSOutcomes.sharedController sendClickActionOutcomes:outcomes appId:appId deviceType:[NSNumber numberWithInt:DEVICE_TYPE_PUSH]];
}

// Returns if we can send this, meaning we have a subscription_id and onesignal_id
+ (BOOL)sendSessionEndOutcomes:(NSNumber*)totalTimeActive params:(OSFocusCallParams *)params {
    if (![OSOutcomes sharedController]) {
        [OneSignalLog onesignalLog:ONE_S_LL_ERROR message:@"Make sure OneSignal init is called first"];
        return false;
    }
    
    NSString* onesignalId = OneSignalUserManagerImpl.sharedInstance.onesignalId;
    NSString* pushSubscriptionId = OneSignalUserManagerImpl.sharedInstance.pushSubscription.subscriptionId;
    
    if (!onesignalId || !pushSubscriptionId) {
        return false;
    }
    
    [OSOutcomes.sharedController sendSessionEndOutcomes:totalTimeActive
                                                         appId:appId
                                            pushSubscriptionId:pushSubscriptionId
                                                   onesignalId:onesignalId
                                               influenceParams:params.influenceParams];
    return true;
}

#pragma mark Logging
+ (Class<OSDebug>)Debug {
    return [OneSignalLog Debug];
}

@end

@implementation OneSignal (SessionStatusDelegate)

+ (void)onSessionEnding:(NSArray<OSInfluence *> *)lastInfluences {
    if ([OSOutcomes sharedController])
        [OSOutcomes.sharedController clearOutcomes];

    [OneSignalTracker onSessionEnded:lastInfluences];
}

@end
/*
 End of outcome module
 */

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
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wincomplete-implementation"
@implementation UIApplication (OneSignal)
+ (void)load {
    
    if ([self shouldDisableBasedOnProcessArguments]) {
        [OneSignalLog onesignalLog:ONE_S_LL_WARN message:@"OneSignal method swizzling is disabled. Make sure the feature is enabled for production."];
        return;
    }
    [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:@"UIApplication(OneSignal) LOADED!"];
    
    // Prevent Xcode storyboard rendering process from crashing with custom IBDesignable Views or from hostless unit tests or share-extension.
    // https://github.com/OneSignal/OneSignal-iOS-SDK/issues/160
    // https://github.com/OneSignal/OneSignal-iOS-SDK/issues/935
    // https://github.com/OneSignal/OneSignal-iOS-SDK/issues/1073
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    NSString *processName = [processInfo processName];
    NSString *infoPath = [[processInfo arguments] objectAtIndex:0];

    if ([processName isEqualToString:@"IBDesignablesAgentCocoaTouch"] || [processName isEqualToString:@"IBDesignablesAgent-iOS"] || [processName isEqualToString:@"xctest"] || ([infoPath rangeOfString: @".appex"].location != NSNotFound))
        return;

    // Double loading of class detection.
    BOOL existing = injectSelector(
        self,
        @selector(oneSignalLoadedTagSelector:),
        [OneSignalAppDelegate class],
        @selector(oneSignalLoadedTagSelector:)
    );
    if (existing) {
        [OneSignalLog onesignalLog:ONE_S_LL_WARN message:@"Already swizzled UIApplication.setDelegate. Make sure the OneSignal library wasn't loaded into the runtime twice!"];
        return;
    }

    [OSNotificationsManager start];

    [[OSMigrationController new] migrate];
    sessionLaunchTime = [NSDate date];
    
    [OSDialogInstanceManager setSharedInstance:[OneSignalDialogController new]];
}

/*
    In order for the badge count to be consistent even in situations where the developer manually sets the badge number,
    We swizzle the 'setApplicationIconBadgeNumber()' to intercept these calls so we always know the latest count
*/
- (void)onesignalSetApplicationIconBadgeNumber:(NSInteger)badge {
    [OneSignalExtensionBadgeHandler updateCachedBadgeValue:badge];
    
    [self onesignalSetApplicationIconBadgeNumber:badge];
}

+(BOOL) shouldDisableBasedOnProcessArguments {
    if ([NSProcessInfo.processInfo.arguments containsObject:@"DISABLE_ONESIGNAL_SWIZZLING"]) {
        return YES;
    }
    return NO;
}
@end

#pragma clang diagnostic pop
#pragma clang diagnostic pop
#pragma clang diagnostic pop
