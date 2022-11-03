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

#import "OneSignal.h"
#import "OneSignalInternal.h"
#import "OneSignalTracker.h"
#import "OneSignalTrackIAP.h"
#import "OneSignalLocation.h"
#import "OneSignalJailbreakDetection.h"
#import "OneSignalMobileProvision.h"
#import "OneSignalHelper.h"
#import "UNUserNotificationCenter+OneSignal.h"
#import "OneSignalSelectorHelpers.h"
#import "UIApplicationDelegate+OneSignal.h"
#import "OSNotification+Internal.h"
#import "OneSignalCacheCleaner.h"
#import "OSMigrationController.h"
#import "OSRemoteParamController.h"

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

#import "OSUserState.h"
#import "OSLocationState.h"
#import "OSStateSynchronizer.h"
#import "OneSignalLifecycleObserver.h"
#import "OSPlayerTags.h"

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

@implementation OSPermissionSubscriptionState
- (NSString*)description {
    static NSString* format = @"<OSPermissionSubscriptionState:\npermissionStatus: %@,\nsubscriptionStatus: %@\n>";
    return [NSString stringWithFormat:format, _permissionStatus, _subscriptionStatus];
}
- (NSDictionary*)toDictionary {
    return @{@"permissionStatus": [_permissionStatus toDictionary],
             @"subscriptionStatus": [_subscriptionStatus toDictionary]
             };
}
@end

@interface OneSignal (SessionStatusDelegate)
@end

@implementation OneSignal

static NSString* mSDKType = @"native";

static BOOL shouldDelaySubscriptionUpdate = false;

static NSMutableArray* pendingSendTagCallbacks;
static OSResultSuccessBlock pendingGetTagsSuccessBlock;
static OSFailureBlock pendingGetTagsFailureBlock;

// Has attempted to register for push notifications with Apple since app was installed.
static BOOL registeredWithApple = NO;

// Under Capabilities is "Background Modes" > "Remote notifications" enabled.
static BOOL backgroundModesEnabled = false;

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
// Make sure launchOptions have been set
// We need this BOOL because launchOptions can be null so simply null checking
//  won't validate whether or not launchOptions have been set
static BOOL hasSetLaunchOptions = false;
// Ensure we only initlize the SDK once even if the public method is called more
// Called after successfully calling setAppId and setLaunchOptions
static BOOL initDone = false;

//used to ensure registration occurs even if APNS does not respond
static NSDate *initializationTime;
static NSTimeInterval maxApnsWait = APNS_TIMEOUT;
static NSTimeInterval reattemptRegistrationInterval = REGISTRATION_DELAY_SECONDS;

// Set when the app is launched
static NSDate *sessionLaunchTime;

static OneSignalTrackIAP* trackIAPPurchase;
NSString* emailToSet;
static LanguageContext* languageContext;

BOOL requestedProvisionalAuthorization = false;
BOOL usesAutoPrompt = false;

static BOOL requiresUserIdAuth = false;

static BOOL performedOnSessionRequest = false;

// static property def for current OSSubscriptionState
static OSSubscriptionState* _currentSubscriptionState;
+ (OSSubscriptionState*)currentSubscriptionState {
    if (!_currentSubscriptionState) {
        _currentSubscriptionState = [OSSubscriptionState alloc];
        _currentSubscriptionState = [_currentSubscriptionState initAsToWithPermision:OSNotificationsManager.currentPermissionState.accepted];
        // Why is it inited here?
        [OSNotificationsManager.currentPermissionState.observable addObserver:_currentSubscriptionState];
        [_currentSubscriptionState.observable addObserver:[OSSubscriptionChangedInternalObserver alloc]];
    }
    return _currentSubscriptionState;
}

static OSSubscriptionState* _lastSubscriptionState;
+ (OSSubscriptionState*)lastSubscriptionState {
    if (!_lastSubscriptionState) {
        _lastSubscriptionState = [OSSubscriptionState alloc];
        _lastSubscriptionState = [_lastSubscriptionState initAsFrom];
    }
    return _lastSubscriptionState;
}
+ (void)setLastSubscriptionState:(OSSubscriptionState*)lastSubscriptionState {
    _lastSubscriptionState = lastSubscriptionState;
}

static OSStateSynchronizer *_stateSynchronizer;
+ (OSStateSynchronizer*)stateSynchronizer {
    if (!_stateSynchronizer)
        _stateSynchronizer = [[OSStateSynchronizer alloc] initWithSubscriptionState:OneSignal.currentSubscriptionState withEmailSubscriptionState:OneSignal.currentEmailSubscriptionState
            withSMSSubscriptionState:OneSignal.currentSMSSubscriptionState];
    return _stateSynchronizer;
}

// static property def to add developer's OSPermissionStateChanges observers to.
static ObservablePermissionStateChangesType* _permissionStateChangesObserver;
+ (ObservablePermissionStateChangesType*)permissionStateChangesObserver {
    if (!_permissionStateChangesObserver)
        _permissionStateChangesObserver = [[OSObservable alloc] initWithChangeSelector:@selector(onOSPermissionChanged:)];
    return _permissionStateChangesObserver;
}

static ObservableSubscriptionStateChangesType* _subscriptionStateChangesObserver;
+ (ObservableSubscriptionStateChangesType*)subscriptionStateChangesObserver {
    if (!_subscriptionStateChangesObserver)
        _subscriptionStateChangesObserver = [[OSObservable alloc] initWithChangeSelector:@selector(onOSSubscriptionChanged:)];
    return _subscriptionStateChangesObserver;
}

static OSPlayerTags *_playerTags;
+ (OSPlayerTags *)playerTags {
    if (!_playerTags) {
        _playerTags = [OSPlayerTags new];
    }
    return _playerTags;
}

+ (OSDeviceState *)getDeviceState {
    return [[OSDeviceState alloc] initWithSubscriptionState:[OneSignal getPermissionSubscriptionState]];
}

static OSRemoteParamController* _remoteParamController;
+ (OSRemoteParamController *)getRemoteParamController {
    if (!_remoteParamController)
        _remoteParamController = [OSRemoteParamController new];
    return _remoteParamController;
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

static OSOutcomeEventsFactory *_outcomeEventFactory;
+ (OSOutcomeEventsFactory *)outcomeEventFactory {
    return _outcomeEventFactory;
}

static OneSignalOutcomeEventsController *_outcomeEventsController;
+ (OneSignalOutcomeEventsController *)getOutcomeEventsController {
    return _outcomeEventsController;
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

+ (OSPlayerTags *)getPlayerTags {
    return self.playerTags;
}

+ (NSString*)mUserId {
    return self.currentSubscriptionState.userId;
}

+ (void)setUserId:(NSString *)userId {
    self.currentSubscriptionState.userId = userId;
}
//TODO: Delete with um
// This is set to true even if register user fails
+ (void)registerUserFinished {
    _registerUserFinished = true;
}
//TODO: Delete with um
// If successful then register user is also finished
+ (void)registerUserSuccessful {
    _registerUserSuccessful = true;
    [OneSignal registerUserFinished];
}

+ (void)setMSDKType:(NSString*)type {
    mSDKType = type;
}
//TODO: Delete with um
// Used for testing purposes to decrease the amount of time the
// SDK will spend waiting for a response from APNS before it
// gives up and registers with OneSignal anyways
+ (void)setDelayIntervals:(NSTimeInterval)apnsMaxWait withRegistrationDelay:(NSTimeInterval)registrationDelay {
    reattemptRegistrationInterval = registrationDelay;
    maxApnsWait = apnsMaxWait;
}
//TODO: This is related to unit tests and will change with um tests
+ (void)clearStatics {
    appId = nil;
    launchOptions = false;
    appSettings = nil;
    hasSetLaunchOptions = false;
    initDone = false;
    usesAutoPrompt = false;
    requestedProvisionalAuthorization = false;
    
    [OSNotificationsManager clearStatics];
    registeredWithApple = false;
    waitingForOneSReg = false;
    isOnSessionSuccessfulForCurrentState = false;
    
    _stateSynchronizer = nil;
    
    _lastSubscriptionState = nil;
    _currentSubscriptionState = nil;
    
    _permissionStateChangesObserver = nil;
    
    _downloadedParameters = false;
    _didCallDownloadParameters = false;
    
    maxApnsWait = APNS_TIMEOUT;
    reattemptRegistrationInterval = REGISTRATION_DELAY_SECONDS;

    sessionLaunchTime = [NSDate date];
    performedOnSessionRequest = false;

    _outcomeEventFactory = nil;
    _outcomeEventsController = nil;
    
    _registerUserFinished = false;
    _registerUserSuccessful = false;
    
    
    [OSSessionManager resetSharedSessionManager];
}

//TODO: Delete with UM?
+ (BOOL)shouldDelaySubscriptionSettingsUpdate {
    return shouldDelaySubscriptionUpdate;
}

#pragma mark User Model 🔥

#pragma mark User Model - User Identity 🔥

+ (Class<OSUser>)User {
    return [OneSignalUserManagerImpl User];
}

+ (void)login:(NSString * _Nonnull)externalId {
    [OneSignalUserManagerImpl loginWithExternalId:externalId token:nil];
    // refine Swift name for Obj-C? But doesn't matter as much since this isn't public API
}

+ (void)login:(NSString * _Nonnull)externalId withToken:(NSString * _Nullable)token {
    [OneSignalUserManagerImpl loginWithExternalId:externalId token:token];
}

+ (void)logout {
    [OneSignalUserManagerImpl logout];
}

#pragma mark User Model - Notifications namespace 🔥
+ (Class<OSNotifications>)Notifications {
    return [OSNotificationsManager Notifications];
}

/*
 1/2 steps in OneSignal init, relying on setLaunchOptions (usage order does not matter)
 Sets the app id OneSignal should use in the application
 This is should be set from all OneSignal entry points
 */
+ (void)setAppId:(nonnull NSString*)newAppId {
    [OneSignal onesignalLog:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"setAppId(id) called with appId: %@!", newAppId]];

    if (!newAppId || newAppId.length == 0) {
        [OneSignal onesignalLog:ONE_S_LL_WARN message:@"appId set, but please call setLaunchOptions(launchOptions) to complete OneSignal init!"];
        return;
    } else if (appId && ![newAppId isEqualToString:appId])  {
        // Pre-check on app id to make sure init of SDK is performed properly
        //     Usually when the app id is changed during runtime so that SDK is reinitialized properly
        initDone = false;
    }

    appId = newAppId;

    [OneSignal onesignalLog:ONE_S_LL_VERBOSE message:@"setAppId(id) finished, checking if launchOptions has been set before proceeding...!"];
    if (!hasSetLaunchOptions) {
        [OneSignal onesignalLog:ONE_S_LL_WARN message:@"appId set, but please call setLaunchOptions(launchOptions) to complete OneSignal init!"];
        return;
    }

    [OneSignal onesignalLog:ONE_S_LL_VERBOSE message:@"setAppId(id) successful and launchOptions are set, initializing OneSignal..."];
    [self init];
}

/*
 1/2 steps in OneSignal init, relying on setAppId (usage order does not matter)
 Sets the iOS sepcific app settings
 Method must be called to successfully init OneSignal
 */
+ (void)initWithLaunchOptions:(nullable NSDictionary*)newLaunchOptions {
    [OneSignal onesignalLog:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"setLaunchOptions() called with launchOptions: %@!", launchOptions.description]];

    launchOptions = newLaunchOptions;
    hasSetLaunchOptions = true;

    [OneSignal onesignalLog:ONE_S_LL_VERBOSE message:@"setLaunchOptions(id) finished, checking if appId has been set before proceeding...!"];
    if (!appId || appId.length == 0) {
        // Read from .plist if not passed in with this method call
        appId = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"OneSignal_APPID"];
        if (!appId) {

            appId = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"GameThrive_APPID"];
            if (!appId) {

                let prevAppId = [OneSignalUserDefaults.initStandard getSavedStringForKey:OSUD_APP_ID defaultValue:nil];
                if (!prevAppId) {
                    [OneSignal onesignalLog:ONE_S_LL_INFO message:@"launchOptions set, now waiting for setAppId(appId) with a valid appId to complete OneSignal init!"];
                } else {
                    let logMessage = [NSString stringWithFormat:@"launchOptions set, initializing OneSignal with cached appId: '%@'.", prevAppId];
                    [OneSignal onesignalLog:ONE_S_LL_INFO message:logMessage];
                    [self setAppId:prevAppId];
                }
                return;
            }
        }
    }

    [OneSignal onesignalLog:ONE_S_LL_VERBOSE message:@"setLaunchOptions(launchOptions) successful and appId is set, initializing OneSignal..."];
    [self init];
}

+ (void)setLaunchURLsInApp:(BOOL)launchInApp {
    NSMutableDictionary *newSettings = [[NSMutableDictionary alloc] initWithDictionary:appSettings];
    newSettings[kOSSettingsKeyInAppLaunchURL] = launchInApp ? @true : @false;
    appSettings = newSettings;
    // This allows this method to have an effect after init is called
    [self enableInAppLaunchURL:launchInApp];
}
// TODO: um
+ (void)setProvidesNotificationSettingsView:(BOOL)providesView {
    if (providesView && [OSDeviceUtils isIOSVersionGreaterThanOrEqual:@"12.0"]) {
        [OSNotificationsManager setProvidesNotificationSettingsView: providesView];
    }
}

+ (void)setInAppMessageClickHandler:(OSInAppMessageClickBlock)block {
    [OneSignal onesignalLog:ONE_S_LL_VERBOSE message:@"In app message click handler set successfully"];
    [OSMessagingController.sharedInstance setInAppMessageClickHandler:block];
}

+ (void)setInAppMessageLifecycleHandler:(NSObject<OSInAppMessageLifecycleHandler> *_Nullable)delegate; {
    [OneSignal onesignalLog:ONE_S_LL_VERBOSE message:@"In app message delegate set successfully"];
    [OSMessagingController.sharedInstance setInAppMessageDelegate:delegate];
}

/*
 Called after setAppId and setLaunchOptions, depending on which one is called last (order does not matter)
 */
+ (void)init {
    [[OSMigrationController new] migrate];
    // using classes as delegates is not best practice. We should consider using a shared instance of a class instead
    [OSSessionManager sharedSessionManager].delegate = (id<SessionStatusDelegate>)self;
    if ([self requiresPrivacyConsent]) {
        [OneSignal onesignalLog:ONE_S_LL_VERBOSE message:@"Delayed initialization of the OneSignal SDK until the user provides privacy consent using the consentGranted() method"];
        delayedInitializationForPrivacyConsent = true;
        _delayedInitParameters = [[DelayedConsentInitializationParameters alloc] initWithLaunchOptions:launchOptions withAppId:appId];
        // Init was not successful, set appId back to nil
        appId = nil;
        return;
    }
    
    languageContext = [LanguageContext new];

    [OneSignalCacheCleaner cleanCachedUserData];
    [OneSignal checkIfApplicationImplementsDeprecatedMethods];

    let success = [self handleAppIdChange:appId];
    if (!success)
        return;

    // Wrapper SDK's call init twice and pass null as the appId on the first call
    //  the app ID is required to download parameters, so do not download params until the appID is provided
    if (!_didCallDownloadParameters && appId && appId != (id)[NSNull null])
        [self downloadIOSParamsWithAppId:appId];

    [self initSettings:appSettings];

    if (initDone)
        return;

    initializationTime = [NSDate date];

    // Outcomes init
    _outcomeEventFactory = [[OSOutcomeEventsFactory alloc] initWithCache:[OSOutcomeEventsCache sharedOutcomeEventsCache]];
    _outcomeEventsController = [[OneSignalOutcomeEventsController alloc] initWithSessionManager:[OSSessionManager sharedSessionManager] outcomeEventsFactory:_outcomeEventFactory];

    if (appId && [self isLocationShared])
       [OneSignalLocation getLocation:false fallbackToSettings:false withCompletionHandler:nil];

    /*
     * No need to call the handleNotificationOpened:userInfo as it will be called from one of the following selectors
     *  - application:didReceiveRemoteNotification:fetchCompletionHandler
     *  - userNotificationCenter:didReceiveNotificationResponse:withCompletionHandler (iOS10)
     */

    // Cold start from tap on a remote notification
    //  NOTE: launchOptions may be nil if tapping on a notification's action button.
    NSDictionary* userInfo = [launchOptions objectForKey:UIApplicationLaunchOptionsRemoteNotificationKey];
    if (userInfo)
        [OSNotificationsManager setColdStartFromTapOnNotification:YES];

    [OSNotificationsManager clearBadgeCount:false];

    if (!trackIAPPurchase && [OneSignalTrackIAP canTrack])
        trackIAPPurchase = [OneSignalTrackIAP new];

    if ([OneSignalTrackFirebaseAnalytics libraryExists])
        [OneSignalTrackFirebaseAnalytics init];

    [OneSignalLifecycleObserver registerLifecycleObserver];

    initDone = true;
}

+ (NSString *)appGroupKey {
    return [OneSignalUserDefaults appGroupName];
}

+ (BOOL)handleAppIdChange:(NSString*)appId {
    // TODO: Maybe in the future we can make a file with add app ids and validate that way?
    if ([@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba" isEqualToString:appId] ||
        [@"5eb5a37e-b458-11e3-ac11-000c2940e62c" isEqualToString:appId]) {
        [OneSignal onesignalLog:ONE_S_LL_WARN message:@"OneSignal Example AppID detected, please update to your app's id found on OneSignal.com"];
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
    }
    
    // Always save appId and player_id as it will not be present on shared if:
    //   - Updating from an older SDK
    //   - Updating to an app that didn't have App Groups setup before
    [OneSignalUserDefaults.initShared saveStringForKey:OSUD_APP_ID withValue:appId];
    [OneSignalUserDefaults.initShared saveStringForKey:OSUD_PLAYER_ID_TO withValue:self.currentSubscriptionState.userId];
    
    // Invalid app ids reaching here will cause failure
    if (!appId || ![[NSUUID alloc] initWithUUIDString:appId]) {
        [OneSignal onesignalLog:ONE_S_LL_FATAL message:@"OneSignal AppId format is invalid.\nExample: 'b2f7f966-d8cc-11e4-bed1-df8f05be55ba'\n"];
       return false;
    }
    
    return true;
}

+ (void)initSettings:(NSDictionary*)settings {
    registeredWithApple = OSNotificationsManager.currentPermissionState.accepted;
    
    let standardUserDefaults = OneSignalUserDefaults.initStandard;
    // Check if disabled in-app launch url if passed a NO
    if (settings[kOSSettingsKeyInAppLaunchURL] && [settings[kOSSettingsKeyInAppLaunchURL] isKindOfClass:[NSNumber class]])
        [self enableInAppLaunchURL:[settings[kOSSettingsKeyInAppLaunchURL] boolValue]];
    else if (![standardUserDefaults keyExists:OSUD_NOTIFICATION_OPEN_LAUNCH_URL]) {
        // Only need to default to true if the app doesn't already have this setting saved in NSUserDefaults
        [self enableInAppLaunchURL:true];
    }
    
    // Always NO, can be cleaned up in a future commit
    usesAutoPrompt = NO;
    
    // Register with Apple's APNS server if we registed once before or if auto-prompt hasn't been disabled.
    if (usesAutoPrompt || (registeredWithApple && !OSNotificationsManager.currentPermissionState.ephemeral)) {
        [self registerForPushNotifications];
    } else {
        [self checkProvisionalAuthorizationStatus];
        [OSNotificationsManager registerForAPNsToken];
    }

    if (self.currentSubscriptionState.userId)
        [self registerUser];
    else {
        [OSNotificationsManager.osNotificationSettings getNotificationPermissionState:^(OSPermissionStateInternal *state) {
            if (state.answeredPrompt)
                [self registerUser];
            else
                [self registerUserAfterDelay];
        }];
    }
}
//TODO: move to notifications
// Checks to see if we should register for APNS' new Provisional authorization
// (also known as Direct to History).
// This behavior is determined by the OneSignal Parameters request
+ (void)checkProvisionalAuthorizationStatus {
    if ([OSPrivacyConsentController shouldLogMissingPrivacyConsentErrorWithMethodName:nil])
        return;
    
    BOOL usesProvisional = [OneSignalUserDefaults.initStandard getSavedBoolForKey:OSUD_USES_PROVISIONAL_PUSH_AUTHORIZATION defaultValue:false];
    
    // if iOS parameters for this app have never downloaded, this method
    // should return
    if (!usesProvisional || requestedProvisionalAuthorization)
        return;
    
    requestedProvisionalAuthorization = true;
    
    [OSNotificationsManager.osNotificationSettings registerForProvisionalAuthorization:nil];
}
//TODO: move to core?
+ (void)setRequiresPrivacyConsent:(BOOL)required {
    let remoteParamController = [self getRemoteParamController];

    // Already set by remote params
    if ([remoteParamController hasPrivacyConsentKey])
        return;

    if ([self requiresPrivacyConsent] && !required) {
        [OneSignal onesignalLog:ONE_S_LL_ERROR message:@"Cannot change requiresUserPrivacyConsent() from TRUE to FALSE"];
        return;
    }

    [remoteParamController savePrivacyConsentRequired:required];
}

+ (BOOL)requiresPrivacyConsent {
    return [OSPrivacyConsentController requiresUserPrivacyConsent];
}

+ (void)setPrivacyConsent:(BOOL)granted {
    [OSPrivacyConsentController consentGranted:granted];
    
    if (!granted || !delayedInitializationForPrivacyConsent || _delayedInitParameters == nil)
        return;
    // Try to init again using delayed params (order does not matter)
    [self setAppId:_delayedInitParameters.appId];
    [self initWithLaunchOptions:_delayedInitParameters.launchOptions];

    delayedInitializationForPrivacyConsent = false;
    _delayedInitParameters = nil;
}

// the iOS SDK used to call these selectors as a convenience but has stopped due to concerns about private API usage
// the SDK will now print warnings when a developer's app implements these selectors
+ (void)checkIfApplicationImplementsDeprecatedMethods {
    dispatch_async(dispatch_get_main_queue(), ^{
        for (NSString *selectorName in DEPRECATED_SELECTORS)
            if ([[[UIApplication sharedApplication] delegate] respondsToSelector:NSSelectorFromString(selectorName)])
                [OneSignal onesignalLog:ONE_S_LL_WARN message:[NSString stringWithFormat:@"OneSignal has detected that your application delegate implements a deprecated method (%@). Please note that this method has been officially deprecated and the OneSignal SDK will no longer call it. You should use UNUserNotificationCenter instead", selectorName]];
    });
}
//TODO: move to core?
+ (void)downloadIOSParamsWithAppId:(NSString *)appId {
    [OneSignal onesignalLog:ONE_S_LL_DEBUG message:@"Downloading iOS parameters for this application"];
    _didCallDownloadParameters = true;
    [OneSignalClient.sharedClient executeRequest:[OSRequestGetIosParams withUserId:self.currentSubscriptionState.userId appId:appId] onSuccess:^(NSDictionary *result) {
        
        if (result[IOS_REQUIRES_USER_ID_AUTHENTICATION])
            requiresUserIdAuth = [result[IOS_REQUIRES_USER_ID_AUTHENTICATION] boolValue];

        if (!usesAutoPrompt && result[IOS_USES_PROVISIONAL_AUTHORIZATION] != (id)[NSNull null]) {
            [OneSignalUserDefaults.initStandard saveBoolForKey:OSUD_USES_PROVISIONAL_PUSH_AUTHORIZATION withValue:[result[IOS_USES_PROVISIONAL_AUTHORIZATION] boolValue]];
            
            [self checkProvisionalAuthorizationStatus];
        }

        if (result[IOS_RECEIVE_RECEIPTS_ENABLE] != (id)[NSNull null])
            [OneSignalUserDefaults.initShared saveBoolForKey:OSUD_RECEIVE_RECEIPTS_ENABLED withValue:[result[IOS_RECEIVE_RECEIPTS_ENABLE] boolValue]];

        //TODO: move all remote param logic to new OSRemoteParamController
        [[self getRemoteParamController] saveRemoteParams:result];

        if (result[OUTCOMES_PARAM] && result[OUTCOMES_PARAM][IOS_OUTCOMES_V2_SERVICE_ENABLE])
            [[OSOutcomeEventsCache sharedOutcomeEventsCache] saveOutcomesV2ServiceEnabled:[result[OUTCOMES_PARAM][IOS_OUTCOMES_V2_SERVICE_ENABLE] boolValue]];

        [[OSTrackerFactory sharedTrackerFactory] saveInfluenceParams:result];
        [OneSignalTrackFirebaseAnalytics updateFromDownloadParams:result];
        
        _downloadedParameters = true;

    } onFailure:^(NSError *error) {
        _didCallDownloadParameters = false;
    }];
}
//TODO: delete with um?
// This registers for a push token and prompts the user for notifiations permisions
//    Will trigger didRegisterForRemoteNotificationsWithDeviceToken on the AppDelegate when APNs responses.
+ (void)registerForPushNotifications {
    
    // return if the user has not granted privacy permissions
    if ([OSPrivacyConsentController shouldLogMissingPrivacyConsentErrorWithMethodName:@"registerForPushNotifications:"])
        return;
    
    [OSNotificationsManager requestPermission:nil];
}
//TODO: delete with um
+ (OSPermissionSubscriptionState*)getPermissionSubscriptionState {
    OSPermissionSubscriptionState* status = [OSPermissionSubscriptionState alloc];
    
    status.subscriptionStatus = self.currentSubscriptionState;
    status.permissionStatus = OSNotificationsManager.currentPermissionState;

    return status;
}

// onOSSubscriptionChanged should only fire if something changed.
// TODO: UM rename to addPushSubscriptionObserver, and connect functionality
+ (void)addSubscriptionObserver:(NSObject<OSPushSubscriptionObserver>*)observer {
    [self.subscriptionStateChangesObserver addObserver:observer];
    
    if ([self.currentSubscriptionState compare:self.lastSubscriptionState])
        [OSSubscriptionChangedInternalObserver fireChangesObserver:self.currentSubscriptionState];
}
//TODO: Move to UM
+ (void)removeSubscriptionObserver:(NSObject<OSPushSubscriptionObserver>*)observer {
    [self.subscriptionStateChangesObserver removeObserver:observer];
}

+ (void)enableInAppLaunchURL:(BOOL)enable {
    [OneSignalUserDefaults.initStandard saveBoolForKey:OSUD_NOTIFICATION_OPEN_LAUNCH_URL withValue:enable];
}

//TODO: Delete/move with um
+ (void)disablePush:(BOOL)disable {
    // return if the user has not granted privacy permissions
    if ([OSPrivacyConsentController shouldLogMissingPrivacyConsentErrorWithMethodName:@"disablePush:"])
        return;

    NSString* value = nil;
    if (disable)
        value = @"no";
    
    [OneSignalUserDefaults.initStandard saveObjectForKey:OSUD_USER_SUBSCRIPTION_TO withValue:value];
    
    shouldDelaySubscriptionUpdate = true;
    
    self.currentSubscriptionState.isPushDisabled = disable;
    
    if (appId)
        [OneSignal sendNotificationTypesUpdate];
}

+ (void)setLocationShared:(BOOL)enable {
    let remoteController = [self getRemoteParamController];
    
    // Already set by remote params
    if ([remoteController hasLocationKey])
        return;

    [self startLocationSharedWithFlag:enable];
}

+ (void)startLocationSharedWithFlag:(BOOL)enable {
    [OneSignal onesignalLog:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"startLocationSharedWithFlag called with status: %d", (int) enable]];

    let remoteController = [self getRemoteParamController];
    [remoteController saveLocationShared:enable];

    if (!enable) {
        [OneSignal onesignalLog:ONE_S_LL_VERBOSE message:@"startLocationSharedWithFlag set false, clearing last location!"];
        [OneSignalLocation clearLastLocation];
    }
}

+ (void)promptLocation {
    [self promptLocationFallbackToSettings:false completionHandler:nil];
}

+ (void)promptLocationFallbackToSettings:(BOOL)fallback completionHandler:(void (^)(PromptActionResult result))completionHandler {
    // return if the user has not granted privacy permissions
    if ([OSPrivacyConsentController shouldLogMissingPrivacyConsentErrorWithMethodName:@"promptLocation"])
        return;
    
    [OneSignalLocation getLocation:true fallbackToSettings:fallback withCompletionHandler:completionHandler];
}

+ (BOOL)isLocationShared {
    return [[self getRemoteParamController] isLocationShared];
}

// TODO: Move this to User Module to update push sub with the apns push token
+ (void)updateDeviceToken:(NSString*)deviceToken {
    // return if the user has not granted privacy permissions
    if ([OSPrivacyConsentController shouldLogMissingPrivacyConsentErrorWithMethodName:@"updateDeviceToken:onSuccess:onFailure:"])
        return;
    
    [OneSignal onesignalLog:ONE_S_LL_VERBOSE message:@"updateDeviceToken:onSuccess:onFailure:"];

    let isPushTokenDifferent = ![deviceToken isEqualToString:self.currentSubscriptionState.pushToken];
    self.currentSubscriptionState.pushToken = deviceToken;

    if ([self shouldRegisterNow])
        [self registerUser];
    else if (isPushTokenDifferent)
        [self playerPutForPushTokenAndNotificationTypes];
}

// TODO: Move this to User Module to update push sub
+ (void)playerPutForPushTokenAndNotificationTypes {
    [OneSignal onesignalLog:ONE_S_LL_VERBOSE message:@"Calling OneSignal PUT to updated pushToken and/or notificationTypes!"];

      let request = [OSRequestUpdateDeviceToken
          withUserId:self.currentSubscriptionState.userId
          appId:self.appId
          deviceToken:self.currentSubscriptionState.pushToken
          notificationTypes:@([self getNotificationTypes])
          externalIdAuthToken:[self mExternalIdAuthToken]
      ];
      [OneSignalClient.sharedClient executeRequest:request onSuccess:nil onFailure:nil];
}

// TODO: delete with um?
// Set to yes whenever a high priority registration fails ... need to make the next one a high priority to disregard the timer delay
bool immediateOnSessionRetry = NO;
+ (void)setImmediateOnSessionRetry:(BOOL)retry {
    immediateOnSessionRetry = retry;
}

// TODO: delete with um?
+ (BOOL)isImmediatePlayerCreateOrOnSession {
    return !self.currentSubscriptionState.userId || immediateOnSessionRetry;
}

// TODO: delete with um?
// True if we asked Apple for an APNS token the AppDelegate callback has not fired yet
static BOOL waitingForOneSReg = false;
// Esnure we call on_session only once while the app is infocus.
// TODO: delete with um?
static BOOL isOnSessionSuccessfulForCurrentState = false;
+ (void)setIsOnSessionSuccessfulForCurrentState:(BOOL)value {
    isOnSessionSuccessfulForCurrentState = value;
}

// TODO: delete with um?
static BOOL _registerUserFinished = false;
+ (BOOL)isRegisterUserFinished {
    return _registerUserFinished || isOnSessionSuccessfulForCurrentState;
}

// TODO: delete with um?
static BOOL _registerUserSuccessful = false;
+ (BOOL)isRegisterUserSuccessful {
    return _registerUserSuccessful || isOnSessionSuccessfulForCurrentState;
}

// TODO: delete with um?
+ (BOOL)shouldRegisterNow {
    // return if the user has not granted privacy permissions
    if ([OSPrivacyConsentController shouldLogMissingPrivacyConsentErrorWithMethodName:nil])
        return false;
    
    // Don't make a 2nd on_session if have in inflight one
    [OneSignal onesignalLog:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"shouldRegisterNow:waitingForOneSReg: %d", waitingForOneSReg]];
    if (waitingForOneSReg)
        return false;

    [OneSignal onesignalLog:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"shouldRegisterNow:isImmediatePlayerCreateOrOnSession: %d", [self isImmediatePlayerCreateOrOnSession]]];
    if ([self isImmediatePlayerCreateOrOnSession])
        return true;

    [OneSignal onesignalLog:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"shouldRegisterNow:isOnSessionSuccessfulForCurrentState: %d", isOnSessionSuccessfulForCurrentState]];
    if (isOnSessionSuccessfulForCurrentState)
        return false;
    
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    NSTimeInterval lastTimeClosed = [OneSignalUserDefaults.initStandard getSavedDoubleForKey:OSUD_APP_LAST_CLOSED_TIME defaultValue:0];

    if (lastTimeClosed == 0) {
        [OneSignal onesignalLog:ONE_S_LL_DEBUG message:@"shouldRegisterNow: lastTimeClosed: default."];
        return true;
    }

    [OneSignal onesignalLog:ONE_S_LL_DEBUG message:[NSString stringWithFormat:@"shouldRegisterNow: lastTimeClosed: %f", lastTimeClosed]];

    // Make sure last time we closed app was more than 30 secs ago
    const int minTimeThreshold = 30;
    NSTimeInterval delta = now - lastTimeClosed;
    
    return delta >= minTimeThreshold;
}

// TODO: delete with um?
+ (void)registerUserAfterDelay {
    [OneSignal onesignalLog:ONE_S_LL_VERBOSE message:@"registerUserAfterDelay"];
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(registerUser) object:nil];
    [OneSignalHelper performSelector:@selector(registerUser) onMainThreadOnObject:self withObject:nil afterDelay:reattemptRegistrationInterval];
}

// TODO: delete with um?
+ (void)registerUser {
    // return if the user has not granted privacy permissions
    if ([OSPrivacyConsentController shouldLogMissingPrivacyConsentErrorWithMethodName:nil])
        return;

    if ([self shouldRegisterUserAfterDelay]) {
        [self registerUserAfterDelay];
        return;
    }

    [self registerUserNow];
}

// TODO: delete with um?
+(void)registerUserNow {
    [OneSignal onesignalLog:ONE_S_LL_VERBOSE message:@"registerUserNow"];
    
    // Run on the main queue as it is possible for this to be called from multiple queues.
    // Also some of the code in the method is not thread safe such as _outcomeEventsController.
    [OneSignalHelper dispatch_async_on_main_queue:^{
        [self registerUserInternal];
    }];
}

// We should delay registration if we are waiting on APNS
// But if APNS hasn't responded within 30 seconds (maxApnsWait),
// we should continue and register the user.
// TODO: delete with um?
+ (BOOL)shouldRegisterUserAfterDelay {
    [OneSignal onesignalLog:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"registerUser:waitingForApnsResponse: %d", OSNotificationsManager.waitingForApnsResponse]];
    [OneSignal onesignalLog:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"registerUser:initializationTime: %@", initializationTime]];
    
    // If there isn't an initializationTime yet then the SDK hasn't finished initializing so we should delay
    if (!initializationTime)
        return true;
    
    if (!OSNotificationsManager.waitingForApnsResponse)
        return false;
    
    return [[NSDate date] timeIntervalSinceDate:initializationTime] < maxApnsWait;
}

// TODO: move to um properties
+ (OSUserState *)createUserState {
    let userState = [OSUserState new];
    userState.appId = appId;
    userState.deviceOs = [[UIDevice currentDevice] systemVersion];
    userState.timezone = [NSNumber numberWithInt:(int)[[NSTimeZone localTimeZone] secondsFromGMT]];
    userState.timezoneId = [[NSTimeZone localTimeZone] name];
    userState.sdk = ONESIGNAL_VERSION;

    // should be set to true even before the API request is finished
    performedOnSessionRequest = true;

    if (pendingExternalUserId && ![self.existingPushExternalUserId isEqualToString:pendingExternalUserId])
        userState.externalUserId = pendingExternalUserId;

    if (pendingExternalUserIdHashToken)
        userState.externalUserIdHash = pendingExternalUserIdHashToken;
    else if ([self mEmailAuthToken])
        userState.externalUserIdHash = [self mExternalIdAuthToken];
    
    let deviceModel = [OSDeviceUtils getDeviceVariant];
    if (deviceModel)
        userState.deviceModel = deviceModel;
    
    let infoDictionary = [[NSBundle mainBundle] infoDictionary];
    NSString *version = infoDictionary[@"CFBundleShortVersionString"];
    if (version)
        userState.gameVersion = version;
    
    if ([OneSignalJailbreakDetection isJailbroken])
        userState.isRooted = YES;
    
    userState.netType = [OSNetworkingUtils getNetType];
    
    if (!self.currentSubscriptionState.userId) {
        userState.sdkType = mSDKType;
        userState.iOSBundle = [[NSBundle mainBundle] bundleIdentifier];
    }

    userState.language = [languageContext language];
    
    let notificationTypes = [self getNotificationTypes];
    userState.notificationTypes = [NSNumber numberWithInt:notificationTypes];
    
    let CTTelephonyNetworkInfoClass = NSClassFromString(@"CTTelephonyNetworkInfo");
    if (CTTelephonyNetworkInfoClass) {
        id instance = [[CTTelephonyNetworkInfoClass alloc] init];
        let carrierName = (NSString *)[[instance valueForKey:@"subscriberCellularProvider"] valueForKey:@"carrierName"];
        
        if (carrierName)
            userState.carrier = carrierName;
    }
    
    let releaseMode = [OneSignalMobileProvision releaseMode];
    if (releaseMode == UIApplicationReleaseDev || releaseMode == UIApplicationReleaseAdHoc || releaseMode == UIApplicationReleaseWildcard)
        userState.testType = [NSNumber numberWithInt:(int)releaseMode];
    
    if (self.playerTags.tagsToSend)
        userState.tags = self.playerTags.tagsToSend;
    
    if ([self isLocationShared] && [OneSignalLocation lastLocation]) {
        [OneSignal onesignalLog:ONE_S_LL_VERBOSE message:@"Attaching device location to 'on_session' request payload"];
        let locationState = [OSLocationState new];
        locationState.latitude = [NSNumber numberWithDouble:[OneSignalLocation lastLocation]->cords.latitude];
        locationState.longitude = [NSNumber numberWithDouble:[OneSignalLocation lastLocation]->cords.longitude];
        locationState.verticalAccuracy = [NSNumber numberWithDouble:[OneSignalLocation lastLocation]->verticalAccuracy];
        locationState.accuracy = [NSNumber numberWithDouble:[OneSignalLocation lastLocation]->horizontalAccuracy];
        userState.locationState = locationState;
    } else
        [OneSignal onesignalLog:ONE_S_LL_VERBOSE message:@"Not sending location with 'on_session' request payload, setLocationShared is false or lastLocation is null"];
    
    return userState;
}

// TODO: delete with um?
+ (void)registerUserInternal {
    [OneSignal onesignalLog:ONE_S_LL_VERBOSE message:@"registerUserInternal"];
    _registerUserFinished = false;
    _registerUserSuccessful = false;

    // return if the user has not granted privacy permissions
    if ([OSPrivacyConsentController shouldLogMissingPrivacyConsentErrorWithMethodName:nil])
        return;
    
    // Make sure we only call create or on_session once per open of the app.
    if (![self shouldRegisterNow])
        return;

    [_outcomeEventsController clearOutcomes];
    [[OSSessionManager sharedSessionManager] restartSessionIfNeeded:_appEntryState];

    [OneSignalTrackFirebaseAnalytics trackInfluenceOpenEvent];
    
    waitingForOneSReg = true;
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(registerUser) object:nil];
    
    NSArray* nowProcessingCallbacks;
    let userState = [self createUserState];
    if (userState.tags) {
        [self.playerTags addTags:userState.tags];
        [self.playerTags saveTagsToUserDefaults];
        [self.playerTags setTagsToSend: nil];
        
        nowProcessingCallbacks = pendingSendTagCallbacks;
        pendingSendTagCallbacks = nil;
    }

    // Clear last location after attaching data to user state or not
    [OneSignalLocation clearLastLocation];
    sessionLaunchTime = [NSDate date];
    
    [OneSignal onesignalLog:ONE_S_LL_VERBOSE message:@"Calling OneSignal create/on_session"];
    [self.stateSynchronizer registerUserWithState:userState withSuccess:^(NSDictionary<NSString *, NSDictionary *> *results) {
        immediateOnSessionRetry = NO;
        waitingForOneSReg = false;
        isOnSessionSuccessfulForCurrentState = true;
        pendingExternalUserId = nil;
        pendingExternalUserIdHashToken = nil;
        
        //update push player id
        if (results.count > 0 && results[@"push"][@"id"]) {
            
            if (nowProcessingCallbacks) {
                for (OSPendingCallbacks *callbackSet in nowProcessingCallbacks) {
                    if (callbackSet.successBlock)
                        callbackSet.successBlock(userState.tags);
                }
            }
            
            if (self.playerTags.tagsToSend) {
                [self performSelector:@selector(sendTagsToServer) withObject:nil afterDelay:5];
            }
                
            // Try to send location
            [OneSignalLocation sendLocation];
            
            if (emailToSet) {
                [OneSignal setEmail:emailToSet];
                emailToSet = nil;
            }

            [self sendNotificationTypesUpdate];
            
            if (pendingGetTagsSuccessBlock) {
                [OneSignal getTags:pendingGetTagsSuccessBlock onFailure:pendingGetTagsFailureBlock];
                pendingGetTagsSuccessBlock = nil;
                pendingGetTagsFailureBlock = nil;
            }
            
        }
        
        if (results[@"push"][@"in_app_messages"]) {
            [self receivedInAppMessageJson:results[@"push"][@"in_app_messages"]];
        }
    } onFailure:^(NSDictionary<NSString *, NSError *> *errors) {
        waitingForOneSReg = false;
        
        // If the failed registration is priority, force the next one to be a high priority
        immediateOnSessionRetry = YES;
        
        let error = (NSError *)(errors[@"push"] ?: errors[@"email"]);
        
        if (nowProcessingCallbacks) {
            for (OSPendingCallbacks *callbackSet in nowProcessingCallbacks) {
                if (callbackSet.failureBlock)
                    callbackSet.failureBlock(error);
            }
        }
        [OSMessagingController.sharedInstance updateInAppMessagesFromCache];
    }];
}

// TODO: new IAM server call
+ (void)receivedInAppMessageJson:(NSArray<NSDictionary *> *)messagesJson {
    let messages = [NSMutableArray new];

    if (messagesJson) {
        for (NSDictionary *messageJson in messagesJson) {
            let message = [OSInAppMessageInternal instanceWithJson:messageJson];
            if (message) {
                [messages addObject:message];
            }
        }

        [OSMessagingController.sharedInstance updateInAppMessagesFromOnSession:messages];
        return;
    }

    // Default is using cached IAMs in the messaging controller
    [OSMessagingController.sharedInstance updateInAppMessagesFromCache];
}

// In-App Messaging Public Methods
+ (void)pauseInAppMessages:(BOOL)pause {
    [OSMessagingController.sharedInstance setInAppMessagingPaused:pause];
}

+ (BOOL)isInAppMessagingPaused {
    return [OSMessagingController.sharedInstance isInAppMessagingPaused];
}

+ (void)sendPurchases:(NSArray*)purchases {
    // return if the user has not granted privacy permissions
    if ([OSPrivacyConsentController shouldLogMissingPrivacyConsentErrorWithMethodName:nil])
        return;
    
    [OneSignal.stateSynchronizer sendPurchases:purchases appId:self.appId];
}

//TODO: consolidate in one place. Where???
+ (void)launchWebURL:(NSString*)openUrl {
    
    NSString* toOpenUrl = [OneSignalHelper trimURLSpacing:openUrl];
    
    if (toOpenUrl && [OneSignalHelper verifyURL:toOpenUrl]) {
        NSURL *url = [NSURL URLWithString:toOpenUrl];
        // Give the app resume animation time to finish when tapping on a notification from the notification center.
        // Isn't a requirement but improves visual flow.
        [OneSignalHelper performSelector:@selector(displayWebView:) withObject:url afterDelay:0.5];
    }
    
}
//TODO: move to um or notifications
+ (void)submitNotificationOpened:(NSString*)messageId {
    
    // return if the user has not granted privacy permissions
    if ([OSPrivacyConsentController shouldLogMissingPrivacyConsentErrorWithMethodName:nil])
        return;
    
    let standardUserDefaults = OneSignalUserDefaults.initStandard;
    //(DUPLICATE Fix): Make sure we do not upload a notification opened twice for the same messageId
    //Keep track of the Id for the last message sent
    NSString* lastMessageId = [standardUserDefaults getSavedStringForKey:OSUD_LAST_MESSAGE_OPENED defaultValue:nil];
    //Only submit request if messageId not nil and: (lastMessage is nil or not equal to current one)
    if(messageId && (!lastMessageId || ![lastMessageId isEqualToString:messageId])) {
        [OneSignalClient.sharedClient executeRequest:[OSRequestSubmitNotificationOpened withUserId:self.currentSubscriptionState.userId
                                                                                             appId:self.appId
                                                                                         wasOpened:YES
                                                                                         messageId:messageId
                                                                                    withDeviceType:[NSNumber numberWithInt:DEVICE_TYPE_PUSH]]
                                           onSuccess:nil
                                           onFailure:nil];
        [standardUserDefaults saveStringForKey:OSUD_LAST_MESSAGE_OPENED withValue:messageId];
    }
}

//TODO: move to um?
+ (void)setSubscriptionErrorStatus:(int)errorType {
    [OneSignal onesignalLog:ONE_S_LL_VERBOSE message: [NSString stringWithFormat:@"setSubscriptionErrorStatus: %d", errorType]];
    
    mSubscriptionStatus = errorType;
    if (self.currentSubscriptionState.userId)
        [self sendNotificationTypesUpdate];
    else
        [self registerUser];
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

+ (void)addTrigger:(NSString *)key withValue:(id)value {

    // return if the user has not granted privacy permissions
    if ([OSPrivacyConsentController shouldLogMissingPrivacyConsentErrorWithMethodName:@"addTrigger:withValue:"])
        return;

    if (!key) {
        [OneSignal onesignalLog:ONE_S_LL_ERROR message:@"Attempted to set a trigger with a nil key."];
        return;
    }

    [OSMessagingController.sharedInstance addTriggers:@{key : value}];
}

+ (void)addTriggers:(NSDictionary<NSString *, id> *)triggers {
    // return if the user has not granted privacy permissions
    if ([OSPrivacyConsentController shouldLogMissingPrivacyConsentErrorWithMethodName:@"addTriggers:"])
        return;

    [OSMessagingController.sharedInstance addTriggers:triggers];
}

+ (void)removeTriggerForKey:(NSString *)key {
    // return if the user has not granted privacy permissions
    if ([OSPrivacyConsentController shouldLogMissingPrivacyConsentErrorWithMethodName:@"removeTriggerForKey:"])
        return;

    if (!key) {
        [OneSignal onesignalLog:ONE_S_LL_ERROR message:@"Attempted to remove a trigger with a nil key."];
        return;
    }

    [OSMessagingController.sharedInstance removeTriggersForKeys:@[key]];
}

+ (void)removeTriggersForKeys:(NSArray<NSString *> *)keys {
    // return if the user has not granted privacy permissions
    if ([OSPrivacyConsentController shouldLogMissingPrivacyConsentErrorWithMethodName:@"removeTriggerForKey:"])
        return;

    [OSMessagingController.sharedInstance removeTriggersForKeys:keys];
}

+ (NSDictionary<NSString *, id> *)getTriggers {
    // return if the user has not granted privacy permissions
    if ([OSPrivacyConsentController shouldLogMissingPrivacyConsentErrorWithMethodName:@"getTriggers"])
        return @{};

    return [OSMessagingController.sharedInstance getTriggers];
}

+ (id)getTriggerValueForKey:(NSString *)key {
    // return if the user has not granted privacy permissions
    if ([OSPrivacyConsentController shouldLogMissingPrivacyConsentErrorWithMethodName:@"getTriggerValueForKey:"])
        return nil;

    return [OSMessagingController.sharedInstance getTriggerValueForKey:key];
}

/*
 Start of outcome module
 */

+ (void)sendClickActionOutcomes:(NSArray<OSInAppMessageOutcome *> *)outcomes {
    if (!_outcomeEventsController) {
        [OneSignal onesignalLog:ONE_S_LL_ERROR message:@"Make sure OneSignal init is called first"];
        return;
    }

    [_outcomeEventsController sendClickActionOutcomes:outcomes appId:appId deviceType:[NSNumber numberWithInt:DEVICE_TYPE_PUSH]];
}

+ (void)sendOutcome:(NSString * _Nonnull)name {
    [self sendOutcome:name onSuccess:nil];
}

+ (void)sendOutcome:(NSString * _Nonnull)name onSuccess:(OSSendOutcomeSuccess _Nullable)success {
    // return if the user has not granted privacy permissions
    if ([OSPrivacyConsentController shouldLogMissingPrivacyConsentErrorWithMethodName:@"sendOutcome:onSuccess:"])
        return;

    if (!_outcomeEventsController) {
        [OneSignal onesignalLog:ONE_S_LL_ERROR message:@"Make sure OneSignal init is called first"];
        return;
    }

    if (![self isValidOutcomeEntry:name])
        return;

    [_outcomeEventsController sendOutcomeEvent:name appId:appId deviceType:[NSNumber numberWithInt:DEVICE_TYPE_PUSH] successBlock:success];
}

+ (void)sendUniqueOutcome:(NSString * _Nonnull)name {
    [self sendUniqueOutcome:name onSuccess:nil];
}

+ (void)sendUniqueOutcome:(NSString * _Nonnull)name onSuccess:(OSSendOutcomeSuccess _Nullable)success {
    // return if the user has not granted privacy permissions
    if ([OSPrivacyConsentController shouldLogMissingPrivacyConsentErrorWithMethodName:@"sendUniqueOutcome:onSuccess:"])
        return;

    if (!_outcomeEventsController) {
        [OneSignal onesignalLog:ONE_S_LL_ERROR message:@"Make sure OneSignal init is called first"];
        return;
    }

    if (![self isValidOutcomeEntry:name])
        return;

    [_outcomeEventsController sendUniqueOutcomeEvent:name appId:appId deviceType:[NSNumber numberWithInt:DEVICE_TYPE_PUSH] successBlock:success];
}

+ (void)sendOutcomeWithValue:(NSString * _Nonnull)name value:(NSNumber * _Nonnull)value {
    [self sendOutcomeWithValue:name value:value onSuccess:nil];
}

+ (void)sendOutcomeWithValue:(NSString * _Nonnull)name value:(NSNumber * _Nonnull)value onSuccess:(OSSendOutcomeSuccess _Nullable)success {
    // return if the user has not granted privacy permissions
    if ([OSPrivacyConsentController shouldLogMissingPrivacyConsentErrorWithMethodName:@"sendOutcomeWithValue:value:onSuccess:"])
        return;

    if (!_outcomeEventsController) {
        [OneSignal onesignalLog:ONE_S_LL_ERROR message:@"Make sure OneSignal init is called first"];
        return;
    }

    if (![self isValidOutcomeEntry:name])
        return;

    if (![self isValidOutcomeValue:value])
        return;

    [_outcomeEventsController sendOutcomeEventWithValue:name value:value appId:appId deviceType:[NSNumber numberWithInt:DEVICE_TYPE_PUSH] successBlock:success];
}

+ (BOOL)isValidOutcomeEntry:(NSString * _Nonnull)name {
    if (!name || [name length] == 0) {
        [OneSignal onesignalLog:ONE_S_LL_ERROR message:@"Outcome name must not be null or empty"];
        return false;
    }

    return true;
}

+ (BOOL)isValidOutcomeValue:(NSNumber *)value {
    if (!value || value.intValue <= 0) {
        [OneSignal onesignalLog:ONE_S_LL_ERROR message:@"Outcome value must not be null or 0"];
        return false;
    }

    return true;
}

static ONE_S_LOG_LEVEL _visualLogLevel = ONE_S_LL_NONE;

#pragma mark Logging
//TODO: delete with um
+ (void)setLogLevel:(ONE_S_LOG_LEVEL)logLevel visualLevel:(ONE_S_LOG_LEVEL)visualLogLevel {
    [OneSignalLog setLogLevel:logLevel];
    _visualLogLevel = visualLogLevel;
}
//TODO: delete with um
+ (void)onesignalLog:(ONE_S_LOG_LEVEL)logLevel message:(NSString* _Nonnull)message {
    [OneSignalLog onesignalLog:logLevel message:message];
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
    if (logLevel <= _visualLogLevel) {
        [[OSDialogInstanceManager sharedInstance] presentDialogWithTitle:levelString withMessage:message withActions:nil cancelTitle:NSLocalizedString(@"Close", @"Close button") withActionCompletion:nil];
    }
}

@end

@implementation OneSignal (SessionStatusDelegate)

+ (void)onSessionEnding:(NSArray<OSInfluence *> *)lastInfluences {
    if (_outcomeEventsController)
        [_outcomeEventsController clearOutcomes];

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
        [OneSignal onesignalLog:ONE_S_LL_WARN message:@"OneSignal method swizzling is disabled. Make sure the feature is enabled for production."];
        return;
    }
    [OneSignal onesignalLog:ONE_S_LL_VERBOSE message:@"UIApplication(OneSignal) LOADED!"];
    
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
        [OneSignal onesignalLog:ONE_S_LL_WARN message:@"Already swizzled UIApplication.setDelegate. Make sure the OneSignal library wasn't loaded into the runtime twice!"];
        return;
    }

    // Swizzle - UIApplication delegate
    //TODO: do the equivalent in the notificaitons module
    injectSelector(
        [UIApplication class],
        @selector(setDelegate:),
        [OneSignalAppDelegate class],
        @selector(setOneSignalDelegate:)
   );
    //TODO: This swizzling is done from notifications module
    injectSelector(
        [UIApplication class],
        @selector(setApplicationIconBadgeNumber:),
        [OneSignalAppDelegate class],
        @selector(onesignalSetApplicationIconBadgeNumber:)
    );
    //TODO: Do this in the notifications module
    [self setupUNUserNotificationCenterDelegate];
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

+(void)setupUNUserNotificationCenterDelegate {
    // Swizzle - UNUserNotificationCenter delegate - iOS 10+
    if (!NSClassFromString(@"UNUserNotificationCenter"))
        return;

    //[OneSignalUNUserNotificationCenter setup]; TODO: do this is notifications
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
