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
#import "OneSignalReachability.h"
#import "OneSignalJailbreakDetection.h"
#import "OneSignalMobileProvision.h"
#import "OneSignalHelper.h"
#import "UNUserNotificationCenter+OneSignal.h"
#import "OneSignalSelectorHelpers.h"
#import "UIApplicationDelegate+OneSignal.h"
#import "NSString+OneSignal.h"
#import "OneSignalTrackFirebaseAnalytics.h"
#import "OneSignalNotificationServiceExtensionHandler.h"
#import "OSNotification+Internal.h"
#import "OSOutcomeEventsFactory.h"
#import "OSOutcomeEventsCache.h"
#import "OneSignalCommonDefines.h"
#import "OneSignalUserDefaults.h"
#import "OneSignalCacheCleaner.h"
#import "OSMigrationController.h"
#import "OSRemoteParamController.h"

#import "OneSignalNotificationSettings.h"
#import "OneSignalNotificationSettingsIOS10.h"
#import "OneSignalNotificationSettingsIOS9.h"

#import "OSObservable.h"
#import "OSPendingCallbacks.h"

#import "OneSignalExtensionBadgeHandler.h"

#import <stdlib.h>
#import <stdio.h>
#import <sys/types.h>
#import <sys/utsname.h>
#import <sys/sysctl.h>
#import <objc/runtime.h>
#import <UIKit/UIKit.h>


#import <UserNotifications/UserNotifications.h>

#import "OneSignalSetEmailParameters.h"
#import "OneSignalSetSMSParameters.h"
#import "OneSignalSetExternalIdParameters.h"
#import "OneSignalSetLanguageParameters.h"
#import "DelayedConsentInitializationParameters.h"
#import "OneSignalDialogController.h"

#import "OSInfluenceDataDefines.h"
#import "OSInfluenceDataRepository.h"
#import "OSTrackerFactory.h"
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

/* Used to determine if the app is able to present it's own customized Notification Settings view (iOS 12+) */
NSString* const kOSSettingsKeyProvidesAppNotificationSettings = @"kOSSettingsKeyProvidesAppNotificationSettings";

@implementation OSPermissionSubscriptionState
- (NSString*)description {
    static NSString* format = @"<OSPermissionSubscriptionState:\npermissionStatus: %@,\nsubscriptionStatus: %@\n>";
    return [NSString stringWithFormat:format, _permissionStatus, _subscriptionStatus];
}
- (NSDictionary*)toDictionary {
    return @{@"permissionStatus": [_permissionStatus toDictionary],
             @"subscriptionStatus": [_subscriptionStatus toDictionary],
             @"emailSubscriptionStatus" : [_emailSubscriptionStatus toDictionary]
             };
}
@end

@interface OneSignal (SessionStatusDelegate)
@end

@implementation OneSignal

NSString* const ONESIGNAL_VERSION = @"031002";
static NSString* mSDKType = @"native";
static BOOL coldStartFromTapOnNotification = NO;
static BOOL shouldDelaySubscriptionUpdate = false;

/*
    if setEmail: was called before the device was registered (push playerID = nil),
    then the call to setEmail: also gets delayed
    this property stores the parameters so that once registration is complete
    we can finish setEmail:
*/
static OneSignalSetEmailParameters *delayedEmailParameters;
static OneSignalSetSMSParameters *_delayedSMSParameters;
+ (OneSignalSetSMSParameters *)delayedSMSParameters {
    return _delayedSMSParameters;
}
static OneSignalSetExternalIdParameters *delayedExternalIdParameters;
static OneSignalSetLanguageParameters *delayedLanguageParameters;

static NSMutableArray* pendingSendTagCallbacks;
static OSResultSuccessBlock pendingGetTagsSuccessBlock;
static OSFailureBlock pendingGetTagsFailureBlock;

// Has attempted to register for push notifications with Apple since app was installed.
static BOOL registeredWithApple = NO;

// UIApplication-registerForRemoteNotifications has been called but a success or failure has not triggered yet.
static BOOL waitingForApnsResponse = false;

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

int mLastNotificationTypes = -1;
static int mSubscriptionStatus = -1;

BOOL disableBadgeClearing = NO;
BOOL requestedProvisionalAuthorization = false;
BOOL usesAutoPrompt = false;

static BOOL requiresUserIdAuth = false;
static BOOL providesAppNotificationSettings = false;

static BOOL performedOnSessionRequest = false;
static NSString *pendingExternalUserId;
static NSString *pendingExternalUserIdHashToken;

// iOS version implementation
static NSObject<OneSignalNotificationSettings> *_osNotificationSettings;
+ (NSObject<OneSignalNotificationSettings> *)osNotificationSettings {
    if (!_osNotificationSettings) {
        if ([OneSignalHelper isIOSVersionGreaterThanOrEqual:@"10.0"]) {
            _osNotificationSettings = [OneSignalNotificationSettingsIOS10 new];
        } else {
            _osNotificationSettings = [OneSignalNotificationSettingsIOS9 new];
        }
    }
    return _osNotificationSettings;
}

// static property def for currentPermissionState
static OSPermissionState* _currentPermissionState;
+ (OSPermissionState*)currentPermissionState {
    if (!_currentPermissionState) {
        _currentPermissionState = [OSPermissionState alloc];
        _currentPermissionState = [_currentPermissionState initAsTo];
        [self lastPermissionState]; // Trigger creation
        [_currentPermissionState.observable addObserver:[OSPermissionChangedInternalObserver alloc]];
    }
    return _currentPermissionState;
}

// static property def for previous OSSubscriptionState
static OSPermissionState* _lastPermissionState;
+ (OSPermissionState*)lastPermissionState {
    if (!_lastPermissionState)
        _lastPermissionState = [[OSPermissionState alloc] initAsFrom];
    return _lastPermissionState;
}
+ (void)setLastPermissionState:(OSPermissionState *)lastPermissionState {
    _lastPermissionState = lastPermissionState;
}

static OSEmailSubscriptionState* _currentEmailSubscriptionState;
+ (OSEmailSubscriptionState *)currentEmailSubscriptionState {
    if (!_currentEmailSubscriptionState) {
        _currentEmailSubscriptionState = [[OSEmailSubscriptionState alloc] init];

        [_currentEmailSubscriptionState.observable addObserver:[OSEmailSubscriptionChangedInternalObserver alloc]];
    }
    return _currentEmailSubscriptionState;
}

static OSEmailSubscriptionState *_lastEmailSubscriptionState;
+ (OSEmailSubscriptionState *)lastEmailSubscriptionState {
    if (!_lastEmailSubscriptionState) {
        _lastEmailSubscriptionState = [[OSEmailSubscriptionState alloc] init];
    }
    return _lastEmailSubscriptionState;
}

+ (void)setLastEmailSubscriptionState:(OSEmailSubscriptionState *)lastEmailSubscriptionState {
    _lastEmailSubscriptionState = lastEmailSubscriptionState;
}

static OSSMSSubscriptionState* _currentSMSSubscriptionState;
+ (OSSMSSubscriptionState *)currentSMSSubscriptionState {
    if (!_currentSMSSubscriptionState) {
        _currentSMSSubscriptionState = [[OSSMSSubscriptionState alloc] init];
        
        [_currentSMSSubscriptionState.observable addObserver:[OSSMSSubscriptionChangedInternalObserver alloc]];
    }
    return _currentSMSSubscriptionState;
}

static OSSMSSubscriptionState *_lastSMSSubscriptionState;
+ (OSSMSSubscriptionState *)lastSMSSubscriptionState {
    if (!_lastSMSSubscriptionState) {
        _lastSMSSubscriptionState = [[OSSMSSubscriptionState alloc] init];
    }
    return _lastSMSSubscriptionState;
}

+ (void)setLastSMSSubscriptionState:(OSSMSSubscriptionState *)lastSMSSubscriptionState {
    _lastSMSSubscriptionState = lastSMSSubscriptionState;
}

// static property def for current OSSubscriptionState
static OSSubscriptionState* _currentSubscriptionState;
+ (OSSubscriptionState*)currentSubscriptionState {
    if (!_currentSubscriptionState) {
        _currentSubscriptionState = [OSSubscriptionState alloc];
        _currentSubscriptionState = [_currentSubscriptionState initAsToWithPermision:self.currentPermissionState.accepted];
        mLastNotificationTypes = _currentPermissionState.notificationTypes;
        [self.currentPermissionState.observable addObserver:_currentSubscriptionState];
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
static ObserablePermissionStateChangesType* _permissionStateChangesObserver;
+ (ObserablePermissionStateChangesType*)permissionStateChangesObserver {
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

static ObservableEmailSubscriptionStateChangesType* _emailSubscriptionStateChangesObserver;
+ (ObservableEmailSubscriptionStateChangesType *)emailSubscriptionStateChangesObserver {
    if (!_emailSubscriptionStateChangesObserver)
        _emailSubscriptionStateChangesObserver = [[OSObservable alloc] initWithChangeSelector:@selector(onOSEmailSubscriptionChanged:)];
    return _emailSubscriptionStateChangesObserver;
}

static ObservableSMSSubscriptionStateChangesType* _smsSubscriptionStateChangesObserver;
+ (ObservableSMSSubscriptionStateChangesType *)smsSubscriptionStateChangesObserver {
    if (!_smsSubscriptionStateChangesObserver)
        _smsSubscriptionStateChangesObserver = [[OSObservable alloc] initWithChangeSelector:@selector(onOSSMSSubscriptionChanged:)];
    return _smsSubscriptionStateChangesObserver;
}

static OSPlayerTags *_playerTags;
+ (OSPlayerTags *)playerTags {
    if (!_playerTags) {
        _playerTags = [OSPlayerTags new];
    }
    return _playerTags;
}

+ (void)setMSubscriptionStatus:(NSNumber*)status {
    mSubscriptionStatus = [status intValue];
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

static OSOutcomeEventsCache *_outcomeEventsCache;
+ (OSOutcomeEventsCache *)outcomeEventsCache {
    if (!_outcomeEventsCache)
        _outcomeEventsCache = [[OSOutcomeEventsCache alloc] init];
    return _outcomeEventsCache;
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
// This is set to true even if register user fails
+ (void)registerUserFinished {
    _registerUserFinished = true;
}
// If successful then register user is also finished
+ (void)registerUserSuccessful {
    _registerUserSuccessful = true;
    [OneSignal registerUserFinished];
}

+ (NSString *)mEmailAuthToken {
    return self.currentEmailSubscriptionState.emailAuthCode;
}

+ (NSString *)mEmailUserId {
    return self.currentEmailSubscriptionState.emailUserId;
}

+ (void)setEmailUserId:(NSString *)emailUserId {
    self.currentEmailSubscriptionState.emailUserId = emailUserId;
}

+ (NSString *)mExternalIdAuthToken {
    return self.currentSubscriptionState.externalIdAuthCode;
}

+ (void)saveEmailAddress:(NSString *)email withAuthToken:(NSString *)emailAuthToken userId:(NSString *)emailPlayerId {
    self.currentEmailSubscriptionState.emailAddress = email;
    self.currentEmailSubscriptionState.emailAuthCode = emailAuthToken;
    self.currentEmailSubscriptionState.emailUserId = emailPlayerId;
    
    //call persistAsFrom in order to save the emailAuthToken & playerId to NSUserDefaults
    [self.currentEmailSubscriptionState persist];

    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"CurrentEmailSubscriptionState after saveEmailAddress: %@", self.currentEmailSubscriptionState.description]];
}


+ (NSString *)getSMSAuthToken {
    return self.currentSMSSubscriptionState.smsAuthCode;
}

+ (NSString *)getSMSUserId {
    return self.currentSMSSubscriptionState.smsUserId;
}

+ (void)saveSMSNumber:(NSString *)smsNumber withAuthToken:(NSString *)smsAuthToken userId:(NSString *)smsPlayerId {
    [self.currentSMSSubscriptionState setSMSNumber:smsNumber];
    self.currentSMSSubscriptionState.smsAuthCode = smsAuthToken;
    [self.currentSMSSubscriptionState setSMSUserId:smsPlayerId];

    //call persistAsFrom in order to save the smsNumber & playerId to NSUserDefaults
    [self.currentSMSSubscriptionState persist];

    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"CurrentSMSSubscriptionState after saveSMSNumber: %@", self.currentSMSSubscriptionState.description]];
}

+ (void)saveExternalIdAuthToken:(NSString *)hashToken {
    self.currentSubscriptionState.externalIdAuthCode = hashToken;
    // Call persistAsFrom in order to save the externalIdAuthCode to NSUserDefaults
    [self.currentSubscriptionState persist];
}

+ (void)setMSDKType:(NSString*)type {
    mSDKType = type;
}

+ (void)setWaitingForApnsResponse:(BOOL)value {
    waitingForApnsResponse = value;
}

// Used for testing purposes to decrease the amount of time the
// SDK will spend waiting for a response from APNS before it
// gives up and registers with OneSignal anyways
+ (void)setDelayIntervals:(NSTimeInterval)apnsMaxWait withRegistrationDelay:(NSTimeInterval)registrationDelay {
    reattemptRegistrationInterval = registrationDelay;
    maxApnsWait = apnsMaxWait;
}

+ (void)clearStatics {
    appId = nil;
    launchOptions = false;
    appSettings = nil;
    hasSetLaunchOptions = false;
    initDone = false;
    usesAutoPrompt = false;
    requestedProvisionalAuthorization = false;

    registeredWithApple = false;
    _osNotificationSettings = nil;
    waitingForApnsResponse = false;
    waitingForOneSReg = false;
    isOnSessionSuccessfulForCurrentState = false;
    mLastNotificationTypes = -1;
    
    _stateSynchronizer = nil;

    _lastPermissionState = nil;
    _currentPermissionState = nil;
    
    _currentEmailSubscriptionState = nil;
    _lastEmailSubscriptionState = nil;
    _lastSubscriptionState = nil;
    _currentSubscriptionState = nil;
    _currentSMSSubscriptionState = nil;
    _lastSMSSubscriptionState = nil;
    
    _permissionStateChangesObserver = nil;
    
    _downloadedParameters = false;
    _didCallDownloadParameters = false;
    
    maxApnsWait = APNS_TIMEOUT;
    reattemptRegistrationInterval = REGISTRATION_DELAY_SECONDS;

    sessionLaunchTime = [NSDate date];
    performedOnSessionRequest = false;
    pendingExternalUserId = nil;
    pendingExternalUserIdHashToken = nil;
    
    _trackerFactory = nil;
    _sessionManager = nil;
    _outcomeEventsCache = nil;
    _outcomeEventFactory = nil;
    _outcomeEventsController = nil;
    
    _registerUserFinished = false;
    _registerUserSuccessful = false;
    
    _delayedSMSParameters = nil;
}

// Set to false as soon as it's read.
+ (BOOL)coldStartFromTapOnNotification {
    BOOL val = coldStartFromTapOnNotification;
    coldStartFromTapOnNotification = NO;
    return val;
}

+ (BOOL)shouldDelaySubscriptionSettingsUpdate {
    return shouldDelaySubscriptionUpdate;
}

/*
 1/2 steps in OneSignal init, relying on setLaunchOptions (usage order does not matter)
 Sets the app id OneSignal should use in the application
 This is should be set from all OneSignal entry points
 */
+ (void)setAppId:(nonnull NSString*)newAppId {
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"setAppId(id) called with appId: %@!", newAppId]];

    if (!newAppId || newAppId.length == 0) {
        [OneSignal onesignal_Log:ONE_S_LL_WARN message:@"appId set, but please call setLaunchOptions(launchOptions) to complete OneSignal init!"];
        return;
    } else if (appId && ![newAppId isEqualToString:appId])  {
        // Pre-check on app id to make sure init of SDK is performed properly
        //     Usually when the app id is changed during runtime so that SDK is reinitialized properly
        initDone = false;
    }

    appId = newAppId;

    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"setAppId(id) finished, checking if launchOptions has been set before proceeding...!"];
    if (!hasSetLaunchOptions) {
        [OneSignal onesignal_Log:ONE_S_LL_WARN message:@"appId set, but please call setLaunchOptions(launchOptions) to complete OneSignal init!"];
        return;
    }

    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"setAppId(id) successful and launchOptions are set, initializing OneSignal..."];
    [self init];
}

/*
 1/2 steps in OneSignal init, relying on setAppId (usage order does not matter)
 Sets the iOS sepcific app settings
 Method must be called to successfully init OneSignal
 */
+ (void)initWithLaunchOptions:(nullable NSDictionary*)newLaunchOptions {
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"setLaunchOptions() called with launchOptions: %@!", launchOptions.description]];

    launchOptions = newLaunchOptions;
    hasSetLaunchOptions = true;

    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"setLaunchOptions(id) finished, checking if appId has been set before proceeding...!"];
    if (!appId || appId.length == 0) {
        // Read from .plist if not passed in with this method call
        appId = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"OneSignal_APPID"];
        if (!appId) {

            appId = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"GameThrive_APPID"];
            if (!appId) {

                let prevAppId = [OneSignalUserDefaults.initStandard getSavedStringForKey:OSUD_APP_ID defaultValue:nil];
                if (!prevAppId) {
                    [OneSignal onesignal_Log:ONE_S_LL_INFO message:@"launchOptions set, now waiting for setAppId(appId) with a valid appId to complete OneSignal init!"];
                } else {
                    let logMessage = [NSString stringWithFormat:@"launchOptions set, initializing OneSignal with cached appId: '%@'.", prevAppId];
                    [OneSignal onesignal_Log:ONE_S_LL_INFO message:logMessage];
                    [self setAppId:prevAppId];
                }
                return;
            }
        }
    }

    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"setLaunchOptions(launchOptions) successful and appId is set, initializing OneSignal..."];
    [self init];
}

+ (BOOL)shouldSuppressURL {
    // if the plist key does not exist default to false
    // the plist value specifies whether the user wants to open an url using default browser or OSWebView
    NSDictionary *bundleDict = [[NSBundle mainBundle] infoDictionary];
    BOOL shouldSuppress = [bundleDict[ONESIGNAL_SUPRESS_LAUNCH_URLS] boolValue];
    return shouldSuppress ?: false;
}

+ (void)setLaunchURLsInApp:(BOOL)launchInApp {
    NSMutableDictionary *newSettings = [[NSMutableDictionary alloc] initWithDictionary:appSettings];
    newSettings[kOSSettingsKeyInAppLaunchURL] = launchInApp ? @true : @false;
    appSettings = newSettings;
    // This allows this method to have an effect after init is called
    [self enableInAppLaunchURL:launchInApp];
}

+ (void)setProvidesNotificationSettingsView:(BOOL)providesView {
    NSMutableDictionary *newSettings = [[NSMutableDictionary alloc] initWithDictionary:appSettings];
    newSettings[kOSSettingsKeyProvidesAppNotificationSettings] = providesView ? @true : @false;
    appSettings = newSettings;
}

+ (void)setNotificationWillShowInForegroundHandler:(OSNotificationWillShowInForegroundBlock)block {
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"Notification will show in foreground handler set successfully"];
    [OneSignalHelper setNotificationWillShowInForegroundBlock:block];
}

+ (void)setNotificationOpenedHandler:(OSNotificationOpenedBlock)block {
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"Notification opened handler set successfully"];
    [OneSignalHelper setNotificationOpenedBlock:block];
}

+ (void)setInAppMessageClickHandler:(OSInAppMessageClickBlock)block {
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"In app message click handler set successfully"];
    [OSMessagingController.sharedInstance setInAppMessageClickHandler:block];
}

+ (void)setInAppMessageLifecycleHandler:(NSObject<OSInAppMessageLifecycleHandler> *_Nullable)delegate; {
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"In app message delegate set successfully"];
    [OSMessagingController.sharedInstance setInAppMessageDelegate:delegate];
}

/*
 Called after setAppId and setLaunchOptions, depending on which one is called last (order does not matter)
 */
+ (void)init {
    [[OSMigrationController new] migrate];
    if ([self requiresUserPrivacyConsent]) {
        [self onesignal_Log:ONE_S_LL_VERBOSE message:@"Delayed initialization of the OneSignal SDK until the user provides privacy consent using the consentGranted() method"];
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
    _outcomeEventFactory = [[OSOutcomeEventsFactory alloc] initWithCache:OneSignal.outcomeEventsCache];
    _outcomeEventsController = [[OneSignalOutcomeEventsController alloc] initWithSessionManager:OneSignal.sessionManager outcomeEventsFactory:_outcomeEventFactory];

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
        coldStartFromTapOnNotification = YES;

    [self clearBadgeCount:false];

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
        onesignal_Log(ONE_S_LL_WARN, @"OneSignal Example AppID detected, please update to your app's id found on OneSignal.com");
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
       onesignal_Log(ONE_S_LL_FATAL, @"OneSignal AppId format is invalid.\nExample: 'b2f7f966-d8cc-11e4-bed1-df8f05be55ba'\n");
       return false;
    }
    
    return true;
}

+ (void)initSettings:(NSDictionary*)settings {
    registeredWithApple = self.currentPermissionState.accepted;
    
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
    
    if (settings[kOSSettingsKeyProvidesAppNotificationSettings] && [settings[kOSSettingsKeyProvidesAppNotificationSettings] isKindOfClass:[NSNumber class]] && [OneSignalHelper isIOSVersionGreaterThanOrEqual:@"12.0"])
        providesAppNotificationSettings = [settings[kOSSettingsKeyProvidesAppNotificationSettings] boolValue];
    
    // Register with Apple's APNS server if we registed once before or if auto-prompt hasn't been disabled.
    if (usesAutoPrompt || (registeredWithApple && !self.currentPermissionState.ephemeral)) {
        [self registerForPushNotifications];
    } else {
        [self checkProvisionalAuthorizationStatus];
        [self registerForAPNsToken];
    }

    if (self.currentSubscriptionState.userId)
        [self registerUser];
    else {
        [self.osNotificationSettings getNotificationPermissionState:^(OSPermissionState *state) {
            if (state.answeredPrompt)
                [self registerUser];
            else
                [self registerUserAfterDelay];
        }];
    }
}

// Checks to see if we should register for APNS' new Provisional authorization
// (also known as Direct to History).
// This behavior is determined by the OneSignal Parameters request
+ (void)checkProvisionalAuthorizationStatus {
    if ([self shouldLogMissingPrivacyConsentErrorWithMethodName:nil])
        return;
    
    BOOL usesProvisional = [OneSignalUserDefaults.initStandard getSavedBoolForKey:OSUD_USES_PROVISIONAL_PUSH_AUTHORIZATION defaultValue:false];
    
    // if iOS parameters for this app have never downloaded, this method
    // should return
    if (!usesProvisional || requestedProvisionalAuthorization)
        return;
    
    requestedProvisionalAuthorization = true;
    
    [self.osNotificationSettings registerForProvisionalAuthorization:nil];
}

+ (void)registerForProvisionalAuthorization:(OSUserResponseBlock)block {
    if ([OneSignalHelper isIOSVersionGreaterThanOrEqual:@"12.0"])
        [self.osNotificationSettings registerForProvisionalAuthorization:block];
    else
        onesignal_Log(ONE_S_LL_WARN, @"registerForProvisionalAuthorization is only available in iOS 12+.");
}

+ (BOOL)shouldLogMissingPrivacyConsentErrorWithMethodName:(NSString *)methodName {
    if ([self requiresUserPrivacyConsent]) {
        if (methodName) {
            [self onesignal_Log:ONE_S_LL_WARN message:[NSString stringWithFormat:@"Your application has called %@ before the user granted privacy permission. Please call `consentGranted(bool)` in order to provide user privacy consent", methodName]];
        }
        return true;
    }
    
    return false;
}

+ (void)setRequiresUserPrivacyConsent:(BOOL)required {
    let remoteParamController = [self getRemoteParamController];

    // Already set by remote params
    if ([remoteParamController hasPrivacyConsentKey])
        return;

    if ([self requiresUserPrivacyConsent] && !required) {
        [OneSignal onesignal_Log:ONE_S_LL_ERROR message:@"Cannot change requiresUserPrivacyConsent() from TRUE to FALSE"];
        return;
    }

    [remoteParamController savePrivacyConsentRequired:required];
}

+ (BOOL)requiresUserPrivacyConsent {
    let remoteParamController = [self getRemoteParamController];
    let shouldRequireUserConsent = [remoteParamController isPrivacyConsentRequired];
    // if the plist key does not exist default to true
    // the plist value specifies whether GDPR privacy consent is required for this app
    // if required and consent has not been previously granted, return false
    let requiresConsent = [[[NSBundle mainBundle] objectForInfoDictionaryKey:ONESIGNAL_REQUIRE_PRIVACY_CONSENT] boolValue] ?: false;
    if (requiresConsent || shouldRequireUserConsent)
        return ![OneSignalUserDefaults.initStandard getSavedBoolForKey:GDPR_CONSENT_GRANTED defaultValue:false];
    
    return false;
}

+ (void)consentGranted:(BOOL)granted {
    [OneSignalUserDefaults.initStandard saveBoolForKey:GDPR_CONSENT_GRANTED withValue:granted];
    
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
                [OneSignal onesignal_Log:ONE_S_LL_WARN message:[NSString stringWithFormat:@"OneSignal has detected that your application delegate implements a deprecated method (%@). Please note that this method has been officially deprecated and the OneSignal SDK will no longer call it. You should use UNUserNotificationCenter instead", selectorName]];
    });
}

+ (void)downloadIOSParamsWithAppId:(NSString *)appId {
    [self onesignal_Log:ONE_S_LL_DEBUG message:@"Downloading iOS parameters for this application"];
    _didCallDownloadParameters = true;
    [OneSignalClient.sharedClient executeRequest:[OSRequestGetIosParams withUserId:self.currentSubscriptionState.userId appId:appId] onSuccess:^(NSDictionary *result) {
        if (result[IOS_REQUIRES_EMAIL_AUTHENTICATION]) {
            self.currentEmailSubscriptionState.requiresEmailAuth = [result[IOS_REQUIRES_EMAIL_AUTHENTICATION] boolValue];
            
            // checks if a call to setEmail: was delayed due to missing 'requiresEmailAuth' parameter
            if (delayedEmailParameters && self.currentSubscriptionState.userId) {
                [self setEmail:delayedEmailParameters.email withEmailAuthHashToken:delayedEmailParameters.authToken withSuccess:delayedEmailParameters.successBlock withFailure:delayedEmailParameters.failureBlock];
                delayedEmailParameters = nil;
            }
        }
        
        if (result[IOS_REQUIRES_SMS_AUTHENTICATION]) {
            self.currentSMSSubscriptionState.requiresSMSAuth = [result[IOS_REQUIRES_SMS_AUTHENTICATION] boolValue];
            
            // checks if a call to setSMSNumber: was delayed due to missing 'requiresSMSAuth' parameter
            if (_delayedSMSParameters && self.currentSubscriptionState.userId) {
                [self setSMSNumber:_delayedSMSParameters.smsNumber withSMSAuthHashToken:_delayedSMSParameters.authToken withSuccess:_delayedSMSParameters.successBlock withFailure:_delayedSMSParameters.failureBlock];
                _delayedSMSParameters = nil;
            }
        }
        
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
            [_outcomeEventsCache saveOutcomesV2ServiceEnabled:(BOOL)result[OUTCOMES_PARAM][IOS_OUTCOMES_V2_SERVICE_ENABLE]];

        [OneSignal.trackerFactory saveInfluenceParams:result];
        [OneSignalTrackFirebaseAnalytics updateFromDownloadParams:result];
        
        _downloadedParameters = true;
        
        // Checks if a call to setExternalUserId: was delayed due to missing 'require_user_id_auth' parameter
        // If at this point we don't have user Id, then under register user the delayedExternalIdParameters will be used
        if (delayedExternalIdParameters && self.currentSubscriptionState.userId) {
            [self setExternalUserId:delayedExternalIdParameters.externalId withExternalIdAuthHashToken:delayedExternalIdParameters.authToken withSuccess:delayedExternalIdParameters.successBlock withFailure:delayedExternalIdParameters.failureBlock];
            delayedExternalIdParameters = nil;
        }
    } onFailure:^(NSError *error) {
        _didCallDownloadParameters = false;
    }];
}

//presents the settings page to control/customize push notification settings
+ (void)presentAppSettings {
    
    //only supported in 10+
    if ([OneSignalHelper isIOSVersionLessThan:@"10.0"])
        return;
    
    let url = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
    
    if (!url)
        return;
    
    if ([[UIApplication sharedApplication] canOpenURL:url]) {
        [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
    } else {
        [self onesignal_Log:ONE_S_LL_ERROR message:@"Unable to open settings for this application"];
    }
}

// iOS 12+ only
// A boolean indicating if the app provides its own custom Notifications Settings UI
// If this is set to TRUE via the kOSSettingsKeyProvidesAppNotificationSettings init
// parameter, the SDK will request authorization from the User Notification Center
+ (BOOL)providesAppNotificationSettings {
    return providesAppNotificationSettings;
}

// iOS 9+, only tries to register for an APNs token
+ (BOOL)registerForAPNsToken {
    
    if (waitingForApnsResponse)
        return true;
    
    id backgroundModes = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"UIBackgroundModes"];
    backgroundModesEnabled = (backgroundModes && [backgroundModes containsObject:@"remote-notification"]);
    
    // Only try to register for a pushToken if:
    //  - The user accepted notifications
    //  - "Background Modes" > "Remote Notifications" are enabled in Xcode
    if (![self.osNotificationSettings getNotificationPermissionState].accepted && !backgroundModesEnabled)
        return false;
    
    // Don't attempt to register again if there was a non-recoverable error.
    if (mSubscriptionStatus < -9)
        return false;
    
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"Firing registerForRemoteNotifications"];
    
    waitingForApnsResponse = true;
    [OneSignalHelper dispatch_async_on_main_queue:^{
        [[UIApplication sharedApplication] registerForRemoteNotifications];
    }];
    
    return true;
}

// if user has disabled push notifications & fallback == true,
// the SDK will prompt the user to open notification Settings for this app
+ (void)promptForPushNotificationsWithUserResponse:(OSUserResponseBlock)block fallbackToSettings:(BOOL)fallback {
    
    if (self.currentPermissionState.hasPrompted == true && self.osNotificationSettings.getNotificationTypes == 0 && fallback) {
        //show settings

        let localizedTitle = NSLocalizedString(@"Open Settings", @"A title saying that the user can open iOS Settings");
        let localizedSettingsActionTitle = NSLocalizedString(@"Open Settings", @"A button allowing the user to open the Settings app");
        let localizedCancelActionTitle = NSLocalizedString(@"Cancel", @"A button allowing the user to close the Settings prompt");
        
        //the developer can provide a custom message in Info.plist if they choose.
        var localizedMessage = (NSString *)[[NSBundle mainBundle] objectForInfoDictionaryKey:FALLBACK_TO_SETTINGS_MESSAGE];
        
        if (!localizedMessage)
            localizedMessage = NSLocalizedString(@"You currently have notifications turned off for this application. You can open Settings to re-enable them", @"A message explaining that users can open Settings to re-enable push notifications");
        
        
        [[OneSignalDialogController sharedInstance] presentDialogWithTitle:localizedTitle withMessage:localizedMessage withActions:@[localizedSettingsActionTitle] cancelTitle:localizedCancelActionTitle withActionCompletion:^(int tappedActionIndex) {
            if (block)
                block(false);
            //completion is called on the main thread
            if (tappedActionIndex > -1)
                [self presentAppSettings];
        }];
        
        return;
    }
    
    [self promptForPushNotificationsWithUserResponse:block];
}

+ (void)promptForPushNotificationsWithUserResponse:(OSUserResponseBlock)block {
    
    // return if the user has not granted privacy permissions
    if ([self shouldLogMissingPrivacyConsentErrorWithMethodName:@"promptForPushNotificationsWithUserResponse:"])
        return;
    
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"registerForPushNotifications Called:waitingForApnsResponse: %d", waitingForApnsResponse]];
    
    self.currentPermissionState.hasPrompted = true;
    
    [self.osNotificationSettings promptForNotifications:block];
}

// This registers for a push token and prompts the user for notifiations permisions
//    Will trigger didRegisterForRemoteNotificationsWithDeviceToken on the AppDelegate when APNs responses.
+ (void)registerForPushNotifications {
    
    // return if the user has not granted privacy permissions
    if ([self shouldLogMissingPrivacyConsentErrorWithMethodName:@"registerForPushNotifications:"])
        return;
    
    [self promptForPushNotificationsWithUserResponse:nil];
}


+ (OSPermissionSubscriptionState*)getPermissionSubscriptionState {
    OSPermissionSubscriptionState* status = [OSPermissionSubscriptionState alloc];
    
    status.subscriptionStatus = self.currentSubscriptionState;
    status.permissionStatus = self.currentPermissionState;
    status.emailSubscriptionStatus = self.currentEmailSubscriptionState;
    status.smsSubscriptionStatus = self.currentSMSSubscriptionState;

    return status;
}

// onOSPermissionChanged should only fire if something changed.
+ (void)addPermissionObserver:(NSObject<OSPermissionObserver>*)observer {
    [self.permissionStateChangesObserver addObserver:observer];
    
    if ([self.currentPermissionState compare:self.lastPermissionState])
        [OSPermissionChangedInternalObserver fireChangesObserver:self.currentPermissionState];
}
+ (void)removePermissionObserver:(NSObject<OSPermissionObserver>*)observer {
    [self.permissionStateChangesObserver removeObserver:observer];
}

// onOSSubscriptionChanged should only fire if something changed.
+ (void)addSubscriptionObserver:(NSObject<OSSubscriptionObserver>*)observer {
    [self.subscriptionStateChangesObserver addObserver:observer];
    
    if ([self.currentSubscriptionState compare:self.lastSubscriptionState])
        [OSSubscriptionChangedInternalObserver fireChangesObserver:self.currentSubscriptionState];
}

+ (void)removeSubscriptionObserver:(NSObject<OSSubscriptionObserver>*)observer {
    [self.subscriptionStateChangesObserver removeObserver:observer];
}

+ (void)addEmailSubscriptionObserver:(NSObject<OSEmailSubscriptionObserver>*)observer {
    [self.emailSubscriptionStateChangesObserver addObserver:observer];
    
    if ([self.currentEmailSubscriptionState compare:self.lastEmailSubscriptionState])
        [OSEmailSubscriptionChangedInternalObserver fireChangesObserver:self.currentEmailSubscriptionState];
}

+ (void)removeEmailSubscriptionObserver:(NSObject<OSEmailSubscriptionObserver>*)observer {
    [self.emailSubscriptionStateChangesObserver removeObserver:observer];
}

+ (void)addSMSSubscriptionObserver:(NSObject<OSSMSSubscriptionObserver>*)observer {
    [self.smsSubscriptionStateChangesObserver addObserver:observer];
    
    if ([self.currentSMSSubscriptionState compare:self.lastSMSSubscriptionState])
        [OSSMSSubscriptionChangedInternalObserver fireChangesObserver:self.currentSMSSubscriptionState];
}

+ (void)removeSMSSubscriptionObserver:(NSObject<OSSMSSubscriptionObserver>*)observer {
    [self.smsSubscriptionStateChangesObserver removeObserver:observer];
}

+ (void)sendTagsWithJsonString:(NSString*)jsonString {
    
    // return if the user has not granted privacy permissions
    if ([self shouldLogMissingPrivacyConsentErrorWithMethodName:@"sendTagsWithJsonString:"])
        return;
    
    NSError* jsonError;
    
    NSData* data = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary* keyValuePairs = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&jsonError];
    if (jsonError == nil) {
        [self sendTags:keyValuePairs];
    } else {
        onesignal_Log(ONE_S_LL_WARN,[NSString stringWithFormat: @"sendTags JSON Parse Error: %@", jsonError]);
        onesignal_Log(ONE_S_LL_WARN,[NSString stringWithFormat: @"sendTags JSON Parse Error, JSON: %@", jsonString]);
    }
}

+ (void)sendTags:(NSDictionary*)keyValuePair {
    
    // return if the user has not granted privacy permissions
    if ([self shouldLogMissingPrivacyConsentErrorWithMethodName:@"sendTags:"])
        return;
    
    [self sendTags:keyValuePair onSuccess:nil onFailure:nil];
}

+ (void)sendTags:(NSDictionary*)keyValuePair onSuccess:(OSResultSuccessBlock)successBlock onFailure:(OSFailureBlock)failureBlock {
    
    // return if the user has not granted privacy permissions
    if ([self shouldLogMissingPrivacyConsentErrorWithMethodName:@"sendTags:onSuccess:onFailure:"]) {
        if (failureBlock) {
            NSError *error = [NSError errorWithDomain:@"com.onesignal.tags" code:0 userInfo:@{@"error" : @"Your application has called sendTags:onSuccess:onFailure: before the user granted privacy permission. Please call `consentGranted(bool)` in order to provide user privacy consent"}];
            failureBlock(error);
        }
        return;
    }
        
   
    if (![NSJSONSerialization isValidJSONObject:keyValuePair]) {
        NSString *errorMessage = [NSString stringWithFormat:@"sendTags JSON Invalid: The following key/value pairs you attempted to send as tags are not valid JSON: %@", keyValuePair];
        onesignal_Log(ONE_S_LL_WARN, errorMessage);
        if (failureBlock) {
            NSError *error = [NSError errorWithDomain:@"com.onesignal.tags" code:0 userInfo:@{@"error" : errorMessage}];
            failureBlock(error);
        }
        return;
    }
    
    for (NSString *key in [keyValuePair allKeys]) {
        if ([keyValuePair[key] isKindOfClass:[NSDictionary class]]) {
            NSString *errorMessage = @"sendTags Tags JSON must not contain nested objects";
            onesignal_Log(ONE_S_LL_WARN, errorMessage);
            if (failureBlock) {
                NSError *error = [NSError errorWithDomain:@"com.onesignal.tags" code:0 userInfo:@{@"error" : errorMessage}];
                failureBlock(error);
            }
            return;
        }
    }
    
    if (!self.playerTags.tagsToSend) {
        [self.playerTags setTagsToSend: [keyValuePair mutableCopy]];
    } else {
        [self.playerTags addTagsToSend:keyValuePair];
    }
    
    if (successBlock || failureBlock) {
        if (!pendingSendTagCallbacks)
            pendingSendTagCallbacks = [[NSMutableArray alloc] init];
        OSPendingCallbacks *pendingCallbacks = [OSPendingCallbacks new];
        pendingCallbacks.successBlock = successBlock;
        pendingCallbacks.failureBlock = failureBlock;
        [pendingSendTagCallbacks addObject:pendingCallbacks];
    }
    
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(sendTagsToServer) object:nil];
    
    // Can't send tags yet as their isn't a player_id.
    //   tagsToSend will be sent with the POST create player call later in this case.
    if (self.currentSubscriptionState.userId)
       [OneSignalHelper performSelector:@selector(sendTagsToServer) onMainThreadOnObject:self withObject:nil afterDelay:5];
}

+ (void)sendTagsOnBackground {
    if (!self.playerTags.tagsToSend || self.playerTags.tagsToSend.count <= 0 || !self.currentSubscriptionState.userId)
        return;
    
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(sendTagsToServer) object:nil];
    [OneSignalHelper dispatch_async_on_main_queue:^{
        [self sendTagsToServer];
    }];
}

// Called only with a delay to batch network calls.
+ (void)sendTagsToServer {
    
    // return if the user has not granted privacy permissions
    if ([self shouldLogMissingPrivacyConsentErrorWithMethodName:nil])
        return;
    
    if (!self.playerTags.tagsToSend)
        return;

    [self.playerTags saveTagsToUserDefaults];
    NSDictionary* nowSendingTags = self.playerTags.tagsToSend;
    [self.playerTags setTagsToSend: nil];
    
    NSArray* nowProcessingCallbacks = pendingSendTagCallbacks;
    pendingSendTagCallbacks = nil;
    [OneSignal.stateSynchronizer sendTagsWithAppId:self.appId sendingTags:nowSendingTags networkType:[OneSignalHelper getNetType] processingCallbacks:nowProcessingCallbacks];
}

+ (void)sendTag:(NSString*)key value:(NSString*)value {
    
    // return if the user has not granted privacy permissions
    if ([self shouldLogMissingPrivacyConsentErrorWithMethodName:@"sendTag:value:"])
        return;
    
    [self sendTag:key value:value onSuccess:nil onFailure:nil];
}

+ (void)sendTag:(NSString*)key value:(NSString*)value onSuccess:(OSResultSuccessBlock)successBlock onFailure:(OSFailureBlock)failureBlock {
    
    // return if the user has not granted privacy permissions
    if ([self shouldLogMissingPrivacyConsentErrorWithMethodName:@"sendTag:value:onSuccess:onFailure:"])
        return;
    
    [self sendTags:[NSDictionary dictionaryWithObjectsAndKeys: value, key, nil] onSuccess:successBlock onFailure:failureBlock];
}

+ (void)getTags:(OSResultSuccessBlock)successBlock onFailure:(OSFailureBlock)failureBlock {
    
    // return if the user has not granted privacy permissions
    if ([self shouldLogMissingPrivacyConsentErrorWithMethodName:@"getTags:onFailure:"])
        return;
    
    if (!self.currentSubscriptionState.userId) {
        pendingGetTagsSuccessBlock = successBlock;
        pendingGetTagsFailureBlock = failureBlock;
        return;
    }
    
    [OneSignalClient.sharedClient executeRequest:[OSRequestGetTags withUserId:self.currentSubscriptionState.userId appId:self.appId] onSuccess:^(NSDictionary *result) {
        [self.playerTags addTags:[result objectForKey:@"tags"]];
        successBlock([result objectForKey:@"tags"]);
    } onFailure:failureBlock];
    
}

+ (void)getTags:(OSResultSuccessBlock)successBlock {
    
    // return if the user has not granted privacy permissions
    if ([self shouldLogMissingPrivacyConsentErrorWithMethodName:@"getTags:"])
        return;
    
    [self getTags:successBlock onFailure:nil];
}


+ (void)deleteTag:(NSString*)key onSuccess:(OSResultSuccessBlock)successBlock onFailure:(OSFailureBlock)failureBlock {
    
    // return if the user has not granted privacy permissions
    if ([self shouldLogMissingPrivacyConsentErrorWithMethodName:@"deleteTag:onSuccess:onFailure:"])
        return;
    
    [self deleteTags:@[key] onSuccess:successBlock onFailure:failureBlock];
}

+ (void)deleteTag:(NSString*)key {
    
    // return if the user has not granted privacy permissions
    if ([self shouldLogMissingPrivacyConsentErrorWithMethodName:@"deleteTag:"])
        return;
    
    [self deleteTags:@[key] onSuccess:nil onFailure:nil];
}

+ (void)deleteTags:(NSArray*)keys {
    
    // return if the user has not granted privacy permissions
    if ([self shouldLogMissingPrivacyConsentErrorWithMethodName:@"deleteTags:"])
        return;
    
    [self deleteTags:keys onSuccess:nil onFailure:nil];
}

+ (void)deleteTagsWithJsonString:(NSString*)jsonString {
    
    // return if the user has not granted privacy permissions
    if ([self shouldLogMissingPrivacyConsentErrorWithMethodName:@"deleteTagsWithJsonString:"])
        return;
    
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

+ (void)deleteTags:(NSArray*)keys onSuccess:(OSResultSuccessBlock)successBlock onFailure:(OSFailureBlock)failureBlock {
    NSMutableDictionary* tags = [[NSMutableDictionary alloc] init];
    for (NSString* key in keys) {
        if (!self.playerTags.tagsToSend || !self.playerTags.tagsToSend[key]) {
            tags[key] = @"";
        }
    }
    [self.playerTags deleteTags:keys];
    [self sendTags:tags onSuccess:successBlock onFailure:failureBlock];
}


+ (void)postNotification:(NSDictionary*)jsonData {
    
    // return if the user has not granted privacy permissions
    if ([self shouldLogMissingPrivacyConsentErrorWithMethodName:@"postNotification:"])
        return;
    
    [self postNotification:jsonData onSuccess:nil onFailure:nil];
}

+ (void)postNotification:(NSDictionary*)jsonData onSuccess:(OSResultSuccessBlock)successBlock onFailure:(OSFailureBlock)failureBlock {
    
    // return if the user has not granted privacy permissions
    if ([self shouldLogMissingPrivacyConsentErrorWithMethodName:@"postNotification:onSuccess:onFailure:"])
        return;
    
    NSMutableDictionary *json = [jsonData mutableCopy];
    
    [OneSignal convertDatesToISO8061Strings:json]; //convert any dates to NSString's
    
    [OneSignalClient.sharedClient executeRequest:[OSRequestPostNotification withAppId:self.appId withJson:json] onSuccess:^(NSDictionary *result) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSData* jsonData = [NSJSONSerialization dataWithJSONObject:result options:0 error:nil];
            NSString* jsonResultsString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
            
            onesignal_Log(ONE_S_LL_DEBUG, [NSString stringWithFormat: @"HTTP create notification success %@", jsonResultsString]);
            if (successBlock)
                successBlock(result);
        });
    } onFailure:^(NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            onesignal_Log(ONE_S_LL_ERROR, @"Create notification failed");
            onesignal_Log(ONE_S_LL_INFO, [NSString stringWithFormat: @"%@", error]);
            if (failureBlock)
                failureBlock(error);
        });
    }];
}

+ (void)postNotificationWithJsonString:(NSString*)jsonString onSuccess:(OSResultSuccessBlock)successBlock onFailure:(OSFailureBlock)failureBlock {
    
    // return if the user has not granted privacy permissions
    if ([self shouldLogMissingPrivacyConsentErrorWithMethodName:@"postNotificationWithJsonString:onSuccess:onFailure:"])
        return;
    
    NSError* jsonError;
    
    NSData* data = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary* jsonData = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&jsonError];
    if (jsonError == nil && jsonData != nil)
        [self postNotification:jsonData onSuccess:successBlock onFailure:failureBlock];
    else {
        onesignal_Log(ONE_S_LL_WARN, [NSString stringWithFormat: @"postNotification JSON Parse Error: %@", jsonError]);
        onesignal_Log(ONE_S_LL_WARN, [NSString stringWithFormat: @"postNotification JSON Parse Error, JSON: %@", jsonString]);
    }
}

+ (void)convertDatesToISO8061Strings:(NSMutableDictionary *)dictionary {
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    NSLocale *enUSPOSIXLocale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    [dateFormatter setLocale:enUSPOSIXLocale];
    [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZZZZZ"];
    
    for (NSString *key in dictionary.allKeys) {
        id value = dictionary[key];
        
        if ([value isKindOfClass:[NSDate class]])
            dictionary[key] = [dateFormatter stringFromDate:(NSDate *)value];
    }
}

+ (NSString*)parseNSErrorAsJsonString:(NSError*)error {
    NSString* jsonResponse;
    
    if (error.userInfo && error.userInfo[@"returned"]) {
        @try {
            NSData* jsonData = [NSJSONSerialization dataWithJSONObject:error.userInfo[@"returned"] options:0 error:nil];
            jsonResponse = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        } @catch(NSException* e) {
            onesignal_Log(ONE_S_LL_ERROR, [NSString stringWithFormat:@"%@", e]);
            onesignal_Log(ONE_S_LL_ERROR, [NSString stringWithFormat:@"%@",  [NSThread callStackSymbols]]);
            jsonResponse = @"{\"error\": \"Unknown error parsing error response.\"}";
        }
    }
    else
        jsonResponse = @"{\"error\": \"HTTP no response error\"}";
    
    return jsonResponse;
}

+ (void)enableInAppLaunchURL:(BOOL)enable {
    [OneSignalUserDefaults.initStandard saveBoolForKey:OSUD_NOTIFICATION_OPEN_LAUNCH_URL withValue:enable];
}

+ (void)disablePush:(BOOL)disable {
    // return if the user has not granted privacy permissions
    if ([self shouldLogMissingPrivacyConsentErrorWithMethodName:@"disablePush:"])
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
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"startLocationSharedWithFlag called with status: %d", (int) enable]];

    let remoteController = [self getRemoteParamController];
    [remoteController saveLocationShared:enable];

    if (!enable) {
        [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"startLocationSharedWithFlag set false, clearing last location!"];
        [OneSignalLocation clearLastLocation];
    }
}

+ (void)promptLocation {
    [self promptLocationFallbackToSettings:false completionHandler:nil];
}

+ (void)promptLocationFallbackToSettings:(BOOL)fallback completionHandler:(void (^)(PromptActionResult result))completionHandler {
    // return if the user has not granted privacy permissions
    if ([self shouldLogMissingPrivacyConsentErrorWithMethodName:@"promptLocation"])
        return;
    
    [OneSignalLocation getLocation:true fallbackToSettings:fallback withCompletionHandler:completionHandler];
}

+ (BOOL)isLocationShared {
    return [[self getRemoteParamController] isLocationShared];
}

+ (void)handleDidFailRegisterForRemoteNotification:(NSError*)err {
    waitingForApnsResponse = false;
    
    if (err.code == 3000) {
        [OneSignal setSubscriptionErrorStatus:ERROR_PUSH_CAPABLILITY_DISABLED];
        [OneSignal onesignal_Log:ONE_S_LL_ERROR message:@"ERROR! 'Push Notifications' capability missing! Add the capability in Xcode under 'Target' -> '<MyAppName(MainTarget)>' -> 'Signing & Capabilities' then click the '+ Capability' button."];
    }
    else if (err.code == 3010) {
        [OneSignal setSubscriptionErrorStatus:ERROR_PUSH_SIMULATOR_NOT_SUPPORTED];
        [OneSignal onesignal_Log:ONE_S_LL_ERROR message:[NSString stringWithFormat:@"Error! iOS Simulator does not support push! Please test on a real iOS device. Error: %@", err]];
    }
    else {
        [OneSignal setSubscriptionErrorStatus:ERROR_PUSH_UNKNOWN_APNS_ERROR];
        [OneSignal onesignal_Log:ONE_S_LL_ERROR message:[NSString stringWithFormat:@"Error registering for Apple push notifications! Error: %@", err]];
    }
}

+ (void)updateDeviceToken:(NSString*)deviceToken {
    // return if the user has not granted privacy permissions
    if ([self shouldLogMissingPrivacyConsentErrorWithMethodName:@"updateDeviceToken:onSuccess:onFailure:"])
        return;
    
    onesignal_Log(ONE_S_LL_VERBOSE, @"updateDeviceToken:onSuccess:onFailure:");

    let isPushTokenDifferent = ![deviceToken isEqualToString:self.currentSubscriptionState.pushToken];
    self.currentSubscriptionState.pushToken = deviceToken;

    if ([self shouldRegisterNow])
        [self registerUser];
    else if (isPushTokenDifferent)
        [self playerPutForPushTokenAndNotificationTypes];
}

+ (void)playerPutForPushTokenAndNotificationTypes {
      onesignal_Log(ONE_S_LL_VERBOSE, @"Calling OneSignal PUT to updated pushToken and/or notificationTypes!");

      let request = [OSRequestUpdateDeviceToken
          withUserId:self.currentSubscriptionState.userId
          appId:self.appId
          deviceToken:self.currentSubscriptionState.pushToken
          notificationTypes:@([self getNotificationTypes])
          externalIdAuthToken:[self mExternalIdAuthToken]
      ];
      [OneSignalClient.sharedClient executeRequest:request onSuccess:nil onFailure:nil];
}

// Set to yes whenever a high priority registration fails ... need to make the next one a high priority to disregard the timer delay
bool immediateOnSessionRetry = NO;
+ (void)setImmediateOnSessionRetry:(BOOL)retry {
    immediateOnSessionRetry = retry;
}

+ (BOOL)isImmediatePlayerCreateOrOnSession {
    return !self.currentSubscriptionState.userId || immediateOnSessionRetry;
}

// True if we asked Apple for an APNS token the AppDelegate callback has not fired yet
static BOOL waitingForOneSReg = false;
// Esnure we call on_session only once while the app is infocus.
static BOOL isOnSessionSuccessfulForCurrentState = false;
+ (void)setIsOnSessionSuccessfulForCurrentState:(BOOL)value {
    isOnSessionSuccessfulForCurrentState = value;
}

static BOOL _registerUserFinished = false;
+ (BOOL)isRegisterUserFinished {
    return _registerUserFinished || isOnSessionSuccessfulForCurrentState;
}

static BOOL _registerUserSuccessful = false;
+ (BOOL)isRegisterUserSuccessful {
    return _registerUserSuccessful || isOnSessionSuccessfulForCurrentState;
}

static BOOL _trackedColdRestart = false;
+ (BOOL)shouldRegisterNow {
    // return if the user has not granted privacy permissions
    if ([self shouldLogMissingPrivacyConsentErrorWithMethodName:nil])
        return false;
    
    // Don't make a 2nd on_session if have in inflight one
    onesignal_Log(ONE_S_LL_VERBOSE, [NSString stringWithFormat:@"shouldRegisterNow:waitingForOneSReg: %d", waitingForOneSReg]);
    if (waitingForOneSReg)
        return false;

    onesignal_Log(ONE_S_LL_VERBOSE, [NSString stringWithFormat:@"shouldRegisterNow:isImmediatePlayerCreateOrOnSession: %d", [self isImmediatePlayerCreateOrOnSession]]);
    if ([self isImmediatePlayerCreateOrOnSession])
        return true;

    onesignal_Log(ONE_S_LL_VERBOSE, [NSString stringWithFormat:@"shouldRegisterNow:isOnSessionSuccessfulForCurrentState: %d", isOnSessionSuccessfulForCurrentState]);
    if (isOnSessionSuccessfulForCurrentState)
        return false;
    
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    NSTimeInterval lastTimeClosed = [OneSignalUserDefaults.initStandard getSavedDoubleForKey:OSUD_APP_LAST_CLOSED_TIME defaultValue:0];

    if (lastTimeClosed == 0) {
        onesignal_Log(ONE_S_LL_DEBUG, @"shouldRegisterNow: lastTimeClosed: default.");
        return true;
    }

    onesignal_Log(ONE_S_LL_DEBUG, [NSString stringWithFormat:@"shouldRegisterNow: lastTimeClosed: %f", lastTimeClosed]);

    // Make sure last time we closed app was more than 30 secs ago
    const int minTimeThreshold = 30;
    NSTimeInterval delta = now - lastTimeClosed;
    
    // Tracking cold starts within 30 seconds of last close.
    // Depending on the results of our tracking we will change this case
    // from a tracking request to return true
    if (delta < minTimeThreshold && appId && !_registerUserFinished && !_trackedColdRestart) {
        [OneSignal trackColdRestart];
    }
    return delta >= minTimeThreshold;
}

+ (void)trackColdRestart {
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"trackColdRestart"];
    // Set to true even if it doesn't pass the sample check
    _trackedColdRestart = true;
    // Sample /track calls to avoid hitting our endpoint too hard
    int randomSample = arc4random_uniform(100);
    if (randomSample == 99) {
        NSString *osUsageData = [NSString stringWithFormat:@"kind=sdk, version=%@, source=iOS_SDK, name=cold_restart, lockScreenApp=false", ONESIGNAL_VERSION];
        [[OneSignalClient sharedClient] executeRequest:[OSRequestTrackV1 trackUsageData:osUsageData appId:appId] onSuccess:^(NSDictionary *result) {
            [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"trackColdRestart: successfully tracked cold restart"];
        } onFailure:^(NSError *error) {
            [OneSignal onesignal_Log:ONE_S_LL_ERROR message:[NSString stringWithFormat:@"trackColdRestart: Failed to track cold restart: %@", error.localizedDescription]];
        }];
    }
}

+ (void)registerUserAfterDelay {
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"registerUserAfterDelay"];
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(registerUser) object:nil];
    [OneSignalHelper performSelector:@selector(registerUser) onMainThreadOnObject:self withObject:nil afterDelay:reattemptRegistrationInterval];
}

+ (void)registerUser {
    // return if the user has not granted privacy permissions
    if ([self shouldLogMissingPrivacyConsentErrorWithMethodName:nil])
        return;

    if ([self shouldRegisterUserAfterDelay]) {
        [self registerUserAfterDelay];
        return;
    }

    [self registerUserNow];
}

+(void)registerUserNow {
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"registerUserNow"];
    
    // Run on the main queue as it is possible for this to be called from multiple queues.
    // Also some of the code in the method is not thread safe such as _outcomeEventsController.
    [OneSignalHelper dispatch_async_on_main_queue:^{
        [self registerUserInternal];
    }];
}

// We should delay registration if we are waiting on APNS
// But if APNS hasn't responded within 30 seconds (maxApnsWait),
// we should continue and register the user.
+ (BOOL)shouldRegisterUserAfterDelay {
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"registerUser:waitingForApnsResponse: %d", waitingForApnsResponse]];
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"registerUser:initializationTime: %@", initializationTime]];
    
    // If there isn't an initializationTime yet then the SDK hasn't finished initializing so we should delay
    if (!initializationTime)
        return true;
    
    if (!waitingForApnsResponse)
        return false;
    
    return [[NSDate date] timeIntervalSinceDate:initializationTime] < maxApnsWait;
}

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
    
    let deviceModel = [OneSignalHelper getDeviceVariant];
    if (deviceModel)
        userState.deviceModel = deviceModel;
    
    let infoDictionary = [[NSBundle mainBundle] infoDictionary];
    NSString *version = infoDictionary[@"CFBundleShortVersionString"];
    if (version)
        userState.gameVersion = version;
    
    if ([OneSignalJailbreakDetection isJailbroken])
        userState.isRooted = YES;
    
    userState.netType = [OneSignalHelper getNetType];
    
    if (!self.currentSubscriptionState.userId) {
        userState.sdkType = mSDKType;
        userState.iOSBundle = [[NSBundle mainBundle] bundleIdentifier];
    }

    userState.language = [languageContext language];
    
    let notificationTypes = [self getNotificationTypes];
    mLastNotificationTypes = notificationTypes;
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
        [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"Attaching device location to 'on_session' request payload"];
        let locationState = [OSLocationState new];
        locationState.latitude = [NSNumber numberWithDouble:[OneSignalLocation lastLocation]->cords.latitude];
        locationState.longitude = [NSNumber numberWithDouble:[OneSignalLocation lastLocation]->cords.longitude];
        locationState.verticalAccuracy = [NSNumber numberWithDouble:[OneSignalLocation lastLocation]->verticalAccuracy];
        locationState.accuracy = [NSNumber numberWithDouble:[OneSignalLocation lastLocation]->horizontalAccuracy];
        userState.locationState = locationState;
    } else
        [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"Not sending location with 'on_session' request payload, setLocationShared is false or lastLocation is null"];
    
    return userState;
}

+ (void)registerUserInternal {
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"registerUserInternal"];
    _registerUserFinished = false;
    _registerUserSuccessful = false;

    // return if the user has not granted privacy permissions
    if ([self shouldLogMissingPrivacyConsentErrorWithMethodName:nil])
        return;
    
    // Make sure we only call create or on_session once per open of the app.
    if (![self shouldRegisterNow])
        return;

    [_outcomeEventsController clearOutcomes];
    [_sessionManager restartSessionIfNeeded:_appEntryState];

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
    
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"Calling OneSignal create/on_session"];
    [self.stateSynchronizer registerUserWithState:userState withSuccess:^(NSDictionary<NSString *, NSDictionary *> *results) {
        immediateOnSessionRetry = NO;
        waitingForOneSReg = false;
        isOnSessionSuccessfulForCurrentState = true;
        pendingExternalUserId = nil;
        pendingExternalUserIdHashToken = nil;
        
        //update push player id
        if (results.count > 0 && results[@"push"][@"id"]) {
            if (delayedEmailParameters) {
                // Call to setEmail: was delayed because the push player_id did not exist yet
                [self setEmail:delayedEmailParameters.email withEmailAuthHashToken:delayedEmailParameters.authToken withSuccess:delayedEmailParameters.successBlock withFailure:delayedEmailParameters.failureBlock];
                delayedEmailParameters = nil;
            }
            
            if (delayedExternalIdParameters) {
                // Call to setExternalUserId: was delayed because the push player_id did not exist yet
                [self setExternalUserId:delayedExternalIdParameters.externalId withExternalIdAuthHashToken:delayedExternalIdParameters.authToken withSuccess:delayedExternalIdParameters.successBlock withFailure:delayedExternalIdParameters.failureBlock];
                delayedExternalIdParameters = nil;
            }
            
            if (_delayedSMSParameters) {
                // Call to setSMSNumber: was delayed because the push player_id did not exist yet
                [self setSMSNumber:_delayedSMSParameters.smsNumber withSMSAuthHashToken:_delayedSMSParameters.authToken withSuccess:_delayedSMSParameters.successBlock withFailure:_delayedSMSParameters.failureBlock];
                _delayedSMSParameters = nil;
            }
            
            if (delayedLanguageParameters) {
                // Call to setLanguage: was delayed because the push player_id did not exist yet
                [self setLanguage:delayedLanguageParameters.language withSuccess:delayedLanguageParameters.successBlock withFailure:delayedLanguageParameters.failureBlock];
                delayedLanguageParameters = nil;
            }
            
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

+ (NSString*)getUsableDeviceToken {
    if (mSubscriptionStatus < -1)
        return NULL;
    
    return self.currentPermissionState.accepted ? self.currentSubscriptionState.pushToken : NULL;
}

// Updates the server with the new user's notification setting or subscription status changes
+ (BOOL)sendNotificationTypesUpdate {
    
    // return if the user has not granted privacy permissions
    if ([self shouldLogMissingPrivacyConsentErrorWithMethodName:nil])
        return false;
    
    // User changed notification settings for the app.
    if ([self getNotificationTypes] != -1 && self.currentSubscriptionState.userId && mLastNotificationTypes != [self getNotificationTypes]) {
        if (!self.currentSubscriptionState.pushToken) {
            if ([self registerForAPNsToken])
                return true;
        }
        
        mLastNotificationTypes = [self getNotificationTypes];
        
        //delays observer update until the OneSignal server is notified
        shouldDelaySubscriptionUpdate = true;
        
        [OneSignalClient.sharedClient executeRequest:[OSRequestUpdateNotificationTypes withUserId:self.currentSubscriptionState.userId appId:self.appId notificationTypes:@([self getNotificationTypes])] onSuccess:^(NSDictionary *result) {
            
            shouldDelaySubscriptionUpdate = false;
            
            if (self.currentSubscriptionState.delayedObserverUpdate)
                [self.currentSubscriptionState setAccepted:[self getNotificationTypes] > 0];

        } onFailure:nil];

        return true;
    }
    
    return false;
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
    if ([self shouldLogMissingPrivacyConsentErrorWithMethodName:nil])
        return;
    
    [OneSignal.stateSynchronizer sendPurchases:purchases appId:self.appId];
}

static NSString *_lastAppActiveMessageId;
+ (void)setLastAppActiveMessageId:(NSString*)value { _lastAppActiveMessageId = value; }

static NSString *_lastnonActiveMessageId;
+ (void)setLastnonActiveMessageId:(NSString*)value { _lastnonActiveMessageId = value; }

// Entry point for the following:
//  - 1. (iOS all) - Opening notifications
//  - 2. Notification received
//    - 2A. iOS 9  - Notification received while app is in focus.
//    - 2B. iOS 10 - Notification received/displayed while app is in focus.
// isActive is not always true for when the application is on foreground, we need differentiation
// between foreground and isActive
+ (void)notificationReceived:(NSDictionary*)messageDict wasOpened:(BOOL)opened {
    if ([OneSignal shouldLogMissingPrivacyConsentErrorWithMethodName:nil])
        return;
    
    if (!appId)
        return;
    
    // This method should not continue to be executed for non-OS push notifications
    if (![OneSignalHelper isOneSignalPayload:messageDict])
        return;
    
    onesignal_Log(ONE_S_LL_VERBOSE, [NSString stringWithFormat:@"notificationReceived called! opened: %@", opened ? @"YES" : @"NO"]);
    
    NSDictionary* customDict = [messageDict objectForKey:@"os_data"] ?: [messageDict objectForKey:@"custom"];
    
    // Should be called first, other methods relay on this global state below.
    [OneSignalHelper lastMessageReceived:messageDict];
    
    BOOL isPreview = [[OSNotification parseWithApns:messageDict] additionalData][ONESIGNAL_IAM_PREVIEW] != nil;

    if (opened) {
        // Prevent duplicate calls
        let newId = [self checkForProcessedDups:customDict lastMessageId:_lastnonActiveMessageId];
        if ([@"dup" isEqualToString:newId]) {
            [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"Duplicate notif received. Not calling opened handler."];
            return;
        }
        if (newId)
            _lastnonActiveMessageId = newId;
        //app was in background / not running and opened due to a tap on a notification or an action check what type
        OSNotificationActionType type = OSNotificationActionTypeOpened;

        if (messageDict[@"custom"][@"a"][@"actionSelected"] || messageDict[@"actionSelected"])
            type = OSNotificationActionTypeActionTaken;

        // Call Action Block
        [OneSignal handleNotificationOpened:messageDict actionType:type];
    } else if (isPreview && [OneSignalHelper isIOSVersionGreaterThanOrEqual:@"10.0"]) {
        let notification = [OSNotification parseWithApns:messageDict];
        [OneSignalHelper handleIAMPreview:notification];
    }
}

+ (NSString*)checkForProcessedDups:(NSDictionary*)customDict lastMessageId:(NSString*)lastMessageId {
    if (customDict && customDict[@"i"]) {
        NSString* currentNotificationId = customDict[@"i"];
        if ([currentNotificationId isEqualToString:lastMessageId])
            return @"dup";
        return customDict[@"i"];
    }
    return nil;
}

+ (void)handleWillPresentNotificationInForegroundWithPayload:(NSDictionary *)payload withCompletion:(OSNotificationDisplayResponse)completion {
    // check to make sure the app is in focus and it's a OneSignal notification
    if (![OneSignalHelper isOneSignalPayload:payload]
        || UIApplication.sharedApplication.applicationState == UIApplicationStateBackground) {
        completion([OSNotification new]);
        return;
    }
    //Only call the willShowInForegroundHandler for notifications not preview IAMs

    OSNotification *osNotification = [OSNotification parseWithApns:payload];
    if ([osNotification additionalData][ONESIGNAL_IAM_PREVIEW]) {
        completion(nil);
        return;
    }
    [OneSignalHelper handleWillShowInForegroundHandlerForNotification:osNotification  completion:completion];
}

+ (void)handleNotificationOpened:(NSDictionary*)messageDict
                      actionType:(OSNotificationActionType)actionType {
    
    // return if the user has not granted privacy permissions
    if ([self shouldLogMissingPrivacyConsentErrorWithMethodName:@"handleNotificationOpened:actionType:"])
        return;

    OSNotification *notification = [OSNotification parseWithApns:messageDict];
    if ([OneSignalHelper handleIAMPreview:notification])
        return;

    NSDictionary* customDict = [messageDict objectForKey:@"custom"] ?: [messageDict objectForKey:@"os_data"];
    // Notify backend that user opened the notification
    NSString* messageId = [customDict objectForKey:@"i"];
    [OneSignal submitNotificationOpened:messageId];
    
    let isActive = [UIApplication sharedApplication].applicationState == UIApplicationStateActive;
    
    onesignal_Log(ONE_S_LL_VERBOSE, [NSString stringWithFormat:@"handleNotificationOpened called! isActive: %@ notificationId: %@",
                                     isActive ? @"YES" : @"NO", messageId]);

    if (![OneSignal shouldSuppressURL]) {
        // Try to fetch the open url to launch
        [OneSignal launchWebURL:notification.launchURL];
    }
        
    [self clearBadgeCount:true];
    
    NSString* actionID = NULL;
    if (actionType == OSNotificationActionTypeActionTaken) {
        actionID = messageDict[@"custom"][@"a"][@"actionSelected"];
        if(!actionID)
            actionID = messageDict[@"actionSelected"];
    }
    
    // Call Action Block
    [OneSignalHelper lastMessageReceived:messageDict];
    if (!isActive) {
        OneSignal.appEntryState = NOTIFICATION_CLICK;
        [OneSignal.sessionManager onDirectInfluenceFromNotificationOpen:_appEntryState withNotificationId:messageId];
    }

    [OneSignalHelper handleNotificationAction:actionType actionID:actionID];
}

+ (void)launchWebURL:(NSString*)openUrl {
    
    NSString* toOpenUrl = [OneSignalHelper trimURLSpacing:openUrl];
    
    if (toOpenUrl && [OneSignalHelper verifyURL:toOpenUrl]) {
        NSURL *url = [NSURL URLWithString:toOpenUrl];
        // Give the app resume animation time to finish when tapping on a notification from the notification center.
        // Isn't a requirement but improves visual flow.
        [OneSignalHelper performSelector:@selector(displayWebView:) withObject:url afterDelay:0.5];
    }
    
}

+ (void)submitNotificationOpened:(NSString*)messageId {
    
    // return if the user has not granted privacy permissions
    if ([self shouldLogMissingPrivacyConsentErrorWithMethodName:nil])
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
    
+ (BOOL)clearBadgeCount:(BOOL)fromNotifOpened {
    
    NSNumber *disableBadgeNumber = [[NSBundle mainBundle] objectForInfoDictionaryKey:ONESIGNAL_DISABLE_BADGE_CLEARING];
    
    if (disableBadgeNumber)
        disableBadgeClearing = [disableBadgeNumber boolValue];
    else
        disableBadgeClearing = NO;
    
    if (disableBadgeClearing)
        return false;
    
    bool wasBadgeSet = [UIApplication sharedApplication].applicationIconBadgeNumber > 0;
    
    if (fromNotifOpened || wasBadgeSet) {
        [OneSignalHelper runOnMainThread:^{
            [[UIApplication sharedApplication] setApplicationIconBadgeNumber:0];
        }];
    }

    return wasBadgeSet;
}

+ (int)getNotificationTypes {
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message: [NSString stringWithFormat:@"getNotificationTypes:mSubscriptionStatus: %d", mSubscriptionStatus]];
    
    if (mSubscriptionStatus < -9)
        return mSubscriptionStatus;
    
    if (waitingForApnsResponse && !self.currentSubscriptionState.pushToken)
        return ERROR_PUSH_DELEGATE_NEVER_FIRED;
    
    OSPermissionState* permissionStatus = [self.osNotificationSettings getNotificationPermissionState];
    
    //only return the error statuses if not provisional
    if (!permissionStatus.provisional && !permissionStatus.hasPrompted)
        return ERROR_PUSH_NEVER_PROMPTED;
    
    if (!permissionStatus.provisional && !permissionStatus.answeredPrompt)
        return ERROR_PUSH_PROMPT_NEVER_ANSWERED;
    
    if (self.currentSubscriptionState.isPushDisabled)
        return -2;

    return permissionStatus.notificationTypes;
}

+ (void)setSubscriptionErrorStatus:(int)errorType {
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message: [NSString stringWithFormat:@"setSubscriptionErrorStatus: %d", errorType]];
    
    mSubscriptionStatus = errorType;
    if (self.currentSubscriptionState.userId)
        [self sendNotificationTypesUpdate];
    else
        [self registerUser];
}

//    User just responed to the iOS native notification permission prompt.
//    Also extra calls to registerUserNotificationSettings will fire this without prompting again.
+ (void)updateNotificationTypes:(int)notificationTypes {
    
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"updateNotificationTypes called: %d", notificationTypes]];
    
    if ([OneSignalHelper isIOSVersionLessThan:@"10.0"])
        [OneSignalUserDefaults.initStandard saveBoolForKey:OSUD_WAS_NOTIFICATION_PROMPT_ANSWERED_TO withValue:true];
    
    BOOL startedRegister = [self registerForAPNsToken];
    
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"startedRegister: %d", startedRegister]];
    
    [self.osNotificationSettings onNotificationPromptResponse:notificationTypes];
    
    if (mSubscriptionStatus == -2)
        return;
    
    if (!startedRegister && [self shouldRegisterNow])
        [self registerUser];
    else
        [self sendNotificationTypesUpdate];
}

+ (void)didRegisterForRemoteNotifications:(UIApplication *)app
                              deviceToken:(NSData *)inDeviceToken {
    if ([OneSignal shouldLogMissingPrivacyConsentErrorWithMethodName:nil])
        return;

    let parsedDeviceToken = [NSString hexStringFromData:inDeviceToken];

    [OneSignal onesignal_Log:ONE_S_LL_INFO message: [NSString stringWithFormat:@"Device Registered with Apple: %@", parsedDeviceToken]];

    if (!parsedDeviceToken) {
        [OneSignal onesignal_Log:ONE_S_LL_ERROR message:@"Unable to convert APNS device token to a string"];
        return;
    }

    waitingForApnsResponse = false;

    if (!appId)
        return;
    
    [OneSignal updateDeviceToken:parsedDeviceToken];
}
    
+ (BOOL)receiveRemoteNotification:(UIApplication*)application UserInfo:(NSDictionary*)userInfo completionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
    var startedBackgroundJob = false;
    
    NSDictionary* richData = nil;
    // TODO: Look into why the userInfo payload would be different here for displaying vs opening....
    // Check for buttons or attachments pre-2.4.0 version
    if ((userInfo[@"os_data"][@"buttons"] && [userInfo[@"os_data"][@"buttons"] isKindOfClass:[NSDictionary class]]) || userInfo[@"at"] || userInfo[@"o"])
        richData = userInfo;

    // Generate local notification for action button and/or attachments.
    if (richData) {
        let osNotification = [OSNotification parseWithApns:userInfo];
        
        if ([OneSignalHelper isIOSVersionGreaterThanOrEqual:@"10.0"]) {
            startedBackgroundJob = true;
            [OneSignalHelper addNotificationRequest:osNotification completionHandler:completionHandler];
        } else {
            let notification = [OneSignalHelper prepareUILocalNotification:osNotification];
            [[UIApplication sharedApplication] scheduleLocalNotification:notification];
        }
    }
    // Method was called due to a tap on a notification - Fire open notification
    else if (application.applicationState == UIApplicationStateActive) {
        [OneSignalHelper lastMessageReceived:userInfo];

        if ([OneSignalHelper isDisplayableNotification:userInfo]) {
             [OneSignal notificationReceived:userInfo wasOpened:YES];
        }
        return startedBackgroundJob;
    }
    // content-available notification received in the background
    else {
        [OneSignalHelper lastMessageReceived:userInfo];
    }
    
    return startedBackgroundJob;
}

// iOS 9 - Entry point when OneSignal action button notification is displayed or opened.
+ (void)processLocalActionBasedNotification:(UILocalNotification*) notification identifier:(NSString*)identifier {
    if ([OneSignal shouldLogMissingPrivacyConsentErrorWithMethodName:nil])
        return;
    
    if (!notification.userInfo)
        return;

    let userInfo = [OneSignalHelper formatApsPayloadIntoStandard:notification.userInfo identifier:identifier];
    
    if (!userInfo)
        return;
    
    let isActive = [[UIApplication sharedApplication] applicationState] == UIApplicationStateActive;

    [OneSignal notificationReceived:userInfo wasOpened:YES];
    
    // Notification Tapped or notification Action Tapped
    if (!isActive)
        [self handleNotificationOpened:userInfo
                            actionType:OSNotificationActionTypeActionTaken];
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

#pragma mark Email

+ (void)callFailureBlockOnMainThread:(OSFailureBlock)failureBlock withError:(NSError *)error {
    if (failureBlock) {
        dispatch_async(dispatch_get_main_queue(), ^{
            failureBlock(error);
        });
    }
}

+ (void)callSuccessBlockOnMainThread:(OSEmailSuccessBlock)successBlock {
    if (successBlock) {
        dispatch_async(dispatch_get_main_queue(), ^{
            successBlock();
        });
    }
}

+ (void)setEmail:(NSString * _Nonnull)email {

    // return if the user has not granted privacy permissions
    if ([self shouldLogMissingPrivacyConsentErrorWithMethodName:@"setEmail:"])
        return;

    [self setEmail:email withSuccess:nil withFailure:nil];
}

+ (void)setEmail:(NSString * _Nonnull)email withSuccess:(OSEmailSuccessBlock _Nullable)successBlock withFailure:(OSEmailFailureBlock _Nullable)failureBlock {

    // return if the user has not granted privacy permissions
    if ([self shouldLogMissingPrivacyConsentErrorWithMethodName:@"setEmail:withSuccess:withFailure:"])
        return;

    [self setEmail:email withEmailAuthHashToken:nil withSuccess:successBlock withFailure:failureBlock];
}

+ (void)setEmail:(NSString * _Nonnull)email withEmailAuthHashToken:(NSString * _Nullable)hashToken {

    // return if the user has not granted privacy permissions
    if ([self shouldLogMissingPrivacyConsentErrorWithMethodName:@"setEmail:withEmailAuthHashToken:"])
        return;

    [self setEmail:email withEmailAuthHashToken:hashToken withSuccess:nil withFailure:nil];
}

+ (void)setEmail:(NSString * _Nonnull)email withEmailAuthHashToken:(NSString * _Nullable)hashToken withSuccess:(OSEmailSuccessBlock _Nullable)successBlock withFailure:(OSEmailFailureBlock _Nullable)failureBlock {

    // Return if the user has not granted privacy permissions
    if ([self shouldLogMissingPrivacyConsentErrorWithMethodName:@"setEmail:withEmailAuthHashToken:withSuccess:withFailure:"])
        return;
    
    // Some clients/wrappers may send NSNull instead of nil as the auth token
    NSString *emailAuthToken = hashToken;
    if (hashToken == (id)[NSNull null])
        emailAuthToken = nil;
    
    // Checks to ensure it is a valid email
    if (![OneSignalHelper isValidEmail:email]) {
        [self onesignal_Log:ONE_S_LL_WARN message:[NSString stringWithFormat:@"Invalid email (%@) passed to setEmail", email]];
        if (failureBlock)
            failureBlock([NSError errorWithDomain:@"com.onesignal" code:0 userInfo:@{@"error" : @"Email is invalid"}]);
        return;
    }
    
    // Checks to make sure that if email_auth is required, the user has passed in a hash token
    if (self.currentEmailSubscriptionState.requiresEmailAuth && (!emailAuthToken || emailAuthToken.length == 0)) {
        if (failureBlock)
            failureBlock([NSError errorWithDomain:@"com.onesignal.email" code:0 userInfo:@{@"error" : @"Email authentication (auth token) is set to REQUIRED for this application. Please provide an auth token from your backend server or change the setting in the OneSignal dashboard."}]);
        return;
    }
    
    // If both the email address & hash token are the same, there's no need to make a network call here.
    if ([self.currentEmailSubscriptionState.emailAddress isEqualToString:email] && ([self.currentEmailSubscriptionState.emailAuthCode isEqualToString:emailAuthToken] || (self.currentEmailSubscriptionState.emailAuthCode == nil && emailAuthToken == nil))) {
        [self onesignal_Log:ONE_S_LL_VERBOSE message:@"Email already exists, there is no need to call setEmail again"];
        if (successBlock)
            successBlock();
        return;
    }
    
    // If the iOS params (with the require_email_auth setting) has not been downloaded yet, we should delay the request
    //  however, if this method was called with an email auth code passed in, then there is no need to check this setting
    //  and we do not need to delay the request
    if (!self.currentSubscriptionState.userId || (_downloadedParameters == false && emailAuthToken != nil)) {
        [self onesignal_Log:ONE_S_LL_VERBOSE message:@"iOS Parameters for this application has not yet been downloaded. Delaying call to setEmail: until the parameters have been downloaded."];
        delayedEmailParameters = [OneSignalSetEmailParameters withEmail:email withAuthToken:emailAuthToken withSuccess:successBlock withFailure:failureBlock];
        return;
    }
    
    // If the user already has a onesignal email player_id, then we should call update the device token
    //  otherwise, we should call Create Device
    // Since developers may be making UI changes when this call finishes, we will call callbacks on the main thread.
    if (self.currentEmailSubscriptionState.emailUserId) {
        [OneSignalClient.sharedClient executeRequest:[OSRequestUpdateDeviceToken withUserId:self.currentEmailSubscriptionState.emailUserId appId:self.appId deviceToken:email withParentId:nil emailAuthToken:emailAuthToken email:nil externalIdAuthToken:[self mExternalIdAuthToken]] onSuccess:^(NSDictionary *result) {
            [self callSuccessBlockOnMainThread:successBlock];
        } onFailure:^(NSError *error) {
            [self callFailureBlockOnMainThread:failureBlock withError:error];
        }];
    } else {
        [OneSignalClient.sharedClient executeRequest:[OSRequestCreateDevice withAppId:self.appId withDeviceType:[NSNumber numberWithInt:DEVICE_TYPE_EMAIL] withEmail:email withPlayerId:self.currentSubscriptionState.userId withEmailAuthHash:emailAuthToken withExternalUserId:[self existingPushExternalUserId] withExternalIdAuthToken:[self mExternalIdAuthToken]] onSuccess:^(NSDictionary *result) {
            
            let emailPlayerId = (NSString*)result[@"id"];
            
            if (emailPlayerId) {
                [OneSignal saveEmailAddress:email withAuthToken:emailAuthToken userId:emailPlayerId];
                [OneSignalClient.sharedClient executeRequest:[OSRequestUpdateDeviceToken withUserId:self.currentSubscriptionState.userId appId:self.appId deviceToken:nil withParentId:self.currentEmailSubscriptionState.emailUserId emailAuthToken:hashToken email:email externalIdAuthToken:[self mExternalIdAuthToken] ] onSuccess:^(NSDictionary *result) {
                    [self callSuccessBlockOnMainThread:successBlock];
                } onFailure:^(NSError *error) {
                    [self callFailureBlockOnMainThread:failureBlock withError:error];
                }];
            } else {
                [self onesignal_Log:ONE_S_LL_ERROR message:@"Missing OneSignal Email Player ID"];
            }
        } onFailure:^(NSError *error) {
            [self callFailureBlockOnMainThread:failureBlock withError:error];
        }];
    }
}

+ (void)logoutEmail {
    
    // return if the user has not granted privacy permissions
    if ([self shouldLogMissingPrivacyConsentErrorWithMethodName:@"logoutEmail"])
        return;
    
    [self logoutEmailWithSuccess:nil withFailure:nil];
}

+ (void)logoutEmailWithSuccess:(OSEmailSuccessBlock _Nullable)successBlock withFailure:(OSEmailFailureBlock _Nullable)failureBlock {
    
    // return if the user has not granted privacy permissions
    if ([self shouldLogMissingPrivacyConsentErrorWithMethodName:@"logoutEmailWithSuccess:withFailure:"])
        return;
    
    if (!self.currentEmailSubscriptionState.emailUserId) {
        [OneSignal onesignal_Log:ONE_S_LL_ERROR message:@"Email Player ID does not exist, cannot logout"];
        
        if (failureBlock)
            failureBlock([NSError errorWithDomain:@"com.onesignal" code:0 userInfo:@{@"error" : @"Attempted to log out of the user's email with OneSignal. The user does not currently have an email player ID and is not logged in, so it is not possible to log out of the email for this device"}]);
        return;
    }

    [OneSignalClient.sharedClient executeRequest:[OSRequestLogoutEmail withAppId:self.appId emailPlayerId:self.currentEmailSubscriptionState.emailUserId devicePlayerId:self.currentSubscriptionState.userId emailAuthHash:self.currentEmailSubscriptionState.emailAuthCode] onSuccess:^(NSDictionary *result) {
        
        [OneSignalUserDefaults.initStandard removeValueForKey:OSUD_EMAIL_PLAYER_ID];
        [OneSignal saveEmailAddress:nil withAuthToken:nil userId:nil];
        
        [self callSuccessBlockOnMainThread:successBlock];
    } onFailure:^(NSError *error) {
        [self callFailureBlockOnMainThread:failureBlock withError:error];
    }];
}

+ (void)emailChangedWithNewEmailPlayerId:(NSString * _Nullable)emailPlayerId {
    //make sure that the email player ID has changed otherwise there's no point in this request
    if ([self.currentEmailSubscriptionState.emailUserId isEqualToString:emailPlayerId])
        return;
    
    self.currentEmailSubscriptionState.emailUserId = emailPlayerId;
    
    [self.currentEmailSubscriptionState persist];

    let request = [OSRequestUpdateDeviceToken withUserId:self.currentSubscriptionState.userId
                                                   appId:self.appId
                                                   deviceToken:nil
                                                   withParentId:emailPlayerId
                                                   emailAuthToken:self.currentEmailSubscriptionState.emailAuthCode
                                                   email:self.currentEmailSubscriptionState.emailAddress
                                     externalIdAuthToken:[self mExternalIdAuthToken]];
    
    [OneSignalClient.sharedClient executeRequest:request onSuccess:nil onFailure:^(NSError *error) {
        [self onesignal_Log:ONE_S_LL_ERROR message:[NSString stringWithFormat:@"Encountered an error updating this user's email player record: %@", error.description]];
    }];
}

#pragma mark SMS

+ (void)setSMSNumber:(NSString *)smsNumber {
    // return if the user has not granted privacy permissions
    if ([self shouldLogMissingPrivacyConsentErrorWithMethodName:@"setSMSNumber:"])
        return;

    [self setSMSNumber:smsNumber withSMSAuthHashToken:nil withSuccess:nil withFailure:nil];
}

+ (void)setSMSNumber:(NSString *)smsNumber withSuccess:(OSSMSSuccessBlock)successBlock withFailure:(OSSMSFailureBlock)failureBlock {
    // return if the user has not granted privacy permissions
    if ([self shouldLogMissingPrivacyConsentErrorWithMethodName:@"setSMSNumber:withSuccess:withFailure:"])
        return;

    [self setSMSNumber:smsNumber withSMSAuthHashToken:nil withSuccess:successBlock withFailure:failureBlock];
}

+ (void)setSMSNumber:(NSString *)smsNumber withSMSAuthHashToken:(NSString *)hashToken {
    // return if the user has not granted privacy permissions
    if ([self shouldLogMissingPrivacyConsentErrorWithMethodName:@"setSMSNumber:withSMSAuthHashToken:"])
        return;

    [self setSMSNumber:smsNumber withSMSAuthHashToken:hashToken withSuccess:nil withFailure:nil];
}

+ (void)setSMSNumber:(NSString *)smsNumber withSMSAuthHashToken:(NSString *)hashToken withSuccess:(OSSMSSuccessBlock)successBlock withFailure:(OSSMSFailureBlock)failureBlock {
    // return if the user has not granted privacy permissions
    if ([self shouldLogMissingPrivacyConsentErrorWithMethodName:@"setSMSNumber:withSMSAuthHashToken:withSuccess:withFailure:"])
        return;
    
    // Some clients/wrappers may send NSNull instead of nil as the auth token
    NSString *smsAuthToken = hashToken;
    if (hashToken == (id)[NSNull null])
        smsAuthToken = nil;
    
    // Checks to ensure it is a valid smsNumber
    if (!smsNumber || [smsNumber length] == 0) {
        [self onesignal_Log:ONE_S_LL_WARN message:[NSString stringWithFormat:@"Invalid sms number (%@) passed to setSMSNumber", smsNumber]];
        if (failureBlock)
            failureBlock([NSError errorWithDomain:@"com.onesignal.sms" code:0 userInfo:@{@"error" : @"SMS number is invalid"}]);
        return;
    }
    
    // Checks to make sure that if sms_auth is required, the user has passed in a hash token
    if (self.currentSMSSubscriptionState.requiresSMSAuth && (!hashToken || hashToken.length == 0)) {
        if (failureBlock)
            failureBlock([NSError errorWithDomain:@"com.onesignal.sms" code:0 userInfo:@{@"error" : @"SMS authentication (auth token) is set to REQUIRED for this application. Please provide an auth token from your backend server or change the setting in the OneSignal dashboard."}]);
        return;
    }

    // If both the sms number & hash token are the same, there's no need to make a network call here.
    if ([self.currentSMSSubscriptionState.smsNumber isEqualToString:smsNumber] && ([self.currentSMSSubscriptionState.smsAuthCode isEqualToString:hashToken] || (self.currentSMSSubscriptionState.smsAuthCode == nil && hashToken == nil))) {
        [self onesignal_Log:ONE_S_LL_VERBOSE message:@"SMS number already exists, there is no need to call setSMSNumber again"];
        if (successBlock) {
            let response = [NSMutableDictionary new];
            [response setValue:smsNumber forKey:SMS_NUMBER_KEY];
            successBlock(response);
        }
        return;
    }
    
    // If the iOS params (with the require_sms_auth setting) has not been downloaded yet, we should delay the request
    // however, if this method was called with an sms auth code passed in, then there is no need to check this setting
    // and we do not need to delay the request
    if (!self.currentSubscriptionState.userId || (_downloadedParameters == false && hashToken == nil)) {
        [self onesignal_Log:ONE_S_LL_VERBOSE message:@"iOS Parameters for this application has not yet been downloaded. Delaying call to setSMSNumber: until the parameters have been downloaded."];
        _delayedSMSParameters = [OneSignalSetSMSParameters withSMSNumber:smsNumber withAuthToken:hashToken withSuccess:successBlock withFailure:failureBlock];
        return;
    }
    
    [self.stateSynchronizer setSMSNumber:smsNumber withSMSAuthHashToken:hashToken withAppId:self.appId withSuccess:successBlock withFailure:failureBlock];
}

+ (void)logoutSMSNumber {
    // return if the user has not granted privacy permissions
    if ([self shouldLogMissingPrivacyConsentErrorWithMethodName:@"logoutSMSNumber"])
        return;
    
    [self logoutSMSNumberWithSuccess:nil withFailure:nil];
}

+ (void)logoutSMSNumberWithSuccess:(OSSMSSuccessBlock)successBlock withFailure:(OSSMSFailureBlock)failureBlock {
    // return if the user has not granted privacy permissions
    if ([self shouldLogMissingPrivacyConsentErrorWithMethodName:@"logoutSMSNumberWithSuccess:withFailure:"])
        return;
    
    if (!self.currentSMSSubscriptionState.smsUserId) {
        [OneSignal onesignal_Log:ONE_S_LL_ERROR message:@"SMS Player ID does not exist, cannot logout"];
        
        if (failureBlock)
            failureBlock([NSError errorWithDomain:@"com.onesignal.sms" code:0 userInfo:@{@"error" : @"Attempted to log out of the user's sms number with OneSignal. The user does not currently have an sms player ID and is not logged in, so it is not possible to log out of the sms number for this device"}]);
        return;
    }
    
    [self.stateSynchronizer logoutSMSWithAppId:self.appId withSuccess:successBlock withFailure:failureBlock];
}

+ (NSDate *)sessionLaunchTime {
    return sessionLaunchTime;
}

+ (void)addTrigger:(NSString *)key withValue:(id)value {

    // return if the user has not granted privacy permissions
    if ([self shouldLogMissingPrivacyConsentErrorWithMethodName:@"addTrigger:withValue:"])
        return;

    if (!key) {
        [self onesignal_Log:ONE_S_LL_ERROR message:@"Attempted to set a trigger with a nil key."];
        return;
    }

    [OSMessagingController.sharedInstance addTriggers:@{key : value}];
}

+ (void)addTriggers:(NSDictionary<NSString *, id> *)triggers {
    // return if the user has not granted privacy permissions
    if ([self shouldLogMissingPrivacyConsentErrorWithMethodName:@"addTriggers:"])
        return;

    [OSMessagingController.sharedInstance addTriggers:triggers];
}

+ (void)removeTriggerForKey:(NSString *)key {
    // return if the user has not granted privacy permissions
    if ([self shouldLogMissingPrivacyConsentErrorWithMethodName:@"removeTriggerForKey:"])
        return;

    if (!key) {
        [self onesignal_Log:ONE_S_LL_ERROR message:@"Attempted to remove a trigger with a nil key."];
        return;
    }

    [OSMessagingController.sharedInstance removeTriggersForKeys:@[key]];
}

+ (void)removeTriggersForKeys:(NSArray<NSString *> *)keys {
    // return if the user has not granted privacy permissions
    if ([self shouldLogMissingPrivacyConsentErrorWithMethodName:@"removeTriggerForKey:"])
        return;

    [OSMessagingController.sharedInstance removeTriggersForKeys:keys];
}

+ (NSDictionary<NSString *, id> *)getTriggers {
    // return if the user has not granted privacy permissions
    if ([self shouldLogMissingPrivacyConsentErrorWithMethodName:@"getTriggers"])
        return @{};

    return [OSMessagingController.sharedInstance getTriggers];
}

+ (id)getTriggerValueForKey:(NSString *)key {
    // return if the user has not granted privacy permissions
    if ([self shouldLogMissingPrivacyConsentErrorWithMethodName:@"getTriggerValueForKey:"])
        return nil;

    return [OSMessagingController.sharedInstance getTriggerValueForKey:key];
}

+ (void)setLanguage:(NSString * _Nonnull)language {
    // return if the user has not granted privacy permissions
    if ([self shouldLogMissingPrivacyConsentErrorWithMethodName:@"setLanguage"])
        return;
    
    let languageProviderAppDefined = [LanguageProviderAppDefined new];
    [languageProviderAppDefined setLanguage:language];
    [languageContext setStrategy:languageProviderAppDefined];
    
    //Can't send Language if there exists no language
    if (language)
        [self setLanguageOnServer:language WithSuccess:nil withFailure:nil];
}

+ (void)setLanguage:(NSString * _Nonnull)language withSuccess:(OSUpdateLanguageSuccessBlock _Nullable)successBlock withFailure:(OSUpdateLanguageFailureBlock _Nullable)failureBlock {
    // return if the user has not granted privacy permissions
    if ([self shouldLogMissingPrivacyConsentErrorWithMethodName:@"setLanguage"])
        return;
    
    //Can't send Language if there exists not LanguageContext or language
    if (languageContext.language)
        [self setLanguageOnServer:language WithSuccess:successBlock withFailure:failureBlock];
}

+ (void)setLanguageOnServer:(NSString * _Nonnull)language WithSuccess:(OSUpdateLanguageSuccessBlock)successBlock withFailure:(OSUpdateLanguageFailureBlock)failureBlock {
    
    if ([language isEqualToString:@""]) {
        failureBlock([NSError errorWithDomain:@"com.onesignal.language" code:0 userInfo:@{@"error" : @"Empty Language Code"}]);
        return;
    }
    
    if (!self.currentSubscriptionState.userId || _downloadedParameters == false) {
        [self onesignal_Log:ONE_S_LL_VERBOSE message:@"iOS Parameters for this application has not yet been downloaded. Delaying call to setLanguage: until the parameters have been downloaded."];
        delayedLanguageParameters = [OneSignalSetLanguageParameters language:language withSuccess:successBlock withFailure:failureBlock];
        return;
    }
    
    [OneSignal.stateSynchronizer updateLanguage:language appId:appId withSuccess:^(NSDictionary *results) {
        if (successBlock)
            successBlock(results);
    } withFailure:^(NSError *error) {
        if (failureBlock)
            failureBlock([NSError errorWithDomain:@"com.onesignal.language" code:0 userInfo:@{@"error" : @"Network Error"}]);
    }];
}

+ (void)setExternalUserId:(NSString * _Nonnull)externalId {

    // return if the user has not granted privacy permissions
    if ([self shouldLogMissingPrivacyConsentErrorWithMethodName:@"setExternalUserId:"])
        return;
    
    [self setExternalUserId:externalId withSuccess:nil withFailure:nil];
}

+ (void)setExternalUserId:(NSString * _Nonnull)externalId withSuccess:(OSUpdateExternalUserIdSuccessBlock _Nullable)successBlock withFailure:(OSUpdateExternalUserIdFailureBlock _Nullable)failureBlock {
    // return if the user has not granted privacy permissions
    if ([self shouldLogMissingPrivacyConsentErrorWithMethodName:@"setExternalUserId:withSuccess:withFailure:"])
        return;

    [self setExternalUserId:externalId withExternalIdAuthHashToken:nil withSuccess:successBlock withFailure:failureBlock];
}

+ (void)setExternalUserId:(NSString *)externalId withExternalIdAuthHashToken:(NSString *)hashToken withSuccess:(OSUpdateExternalUserIdSuccessBlock _Nullable)successBlock withFailure:(OSUpdateExternalUserIdFailureBlock _Nullable)failureBlock {
    // return if the user has not granted privacy permissions
    if ([self shouldLogMissingPrivacyConsentErrorWithMethodName:@"setExternalUserId:withExternalIdAuthHashToken:withSuccess:withFailure:"])
        return;

    // Can't set the external id if init is not done or the app id or user id has not ben set yet
    if (!_downloadedParameters || !self.currentSubscriptionState.userId) {
        // will be sent as part of the registration/on_session request
        pendingExternalUserId = externalId;
        pendingExternalUserIdHashToken = hashToken;
        delayedExternalIdParameters = [OneSignalSetExternalIdParameters withExternalId:externalId withAuthToken:hashToken withSuccess:successBlock withFailure:failureBlock];
        return;
    } else if (!appId) {
        [OneSignal onesignal_Log:ONE_S_LL_WARN message:@"Attempted to set external user id, but app_id is not set"];
        if (failureBlock)
            failureBlock([NSError errorWithDomain:@"com.onesignal" code:0 userInfo:@{@"error" : [NSString stringWithFormat:@"%@ is not set", appId == nil ? @"app_id" : @"user_id"]}]);
        return;
    } else if (externalId.length > 0 && requiresUserIdAuth && (!hashToken || hashToken.length == 0)) {
        [OneSignal onesignal_Log:ONE_S_LL_ERROR message:@"External Id authentication (auth token) is set to REQUIRED for this application. Please provide an auth token from your backend server or change the setting in the OneSignal dashboard."];
        if (failureBlock)
            failureBlock([NSError errorWithDomain:@"com.onesignal.externalUserId" code:0 userInfo:@{@"error" : @"External User Id authentication (auth token) is set to REQUIRED for this application. Please provide an auth token from your backend server or change the setting in the OneSignal dashboard."}]);
        return;
    }
    
    // Remove external id case
    if (externalId.length == 0) {
        hashToken = self.currentSubscriptionState.externalIdAuthCode;
    }

    [[self stateSynchronizer] setExternalUserId:externalId withExternalIdAuthHashToken:hashToken withAppId:appId withSuccess:successBlock withFailure:failureBlock];
}

+ (void)removeExternalUserId {
    // return if the user has not granted privacy permissions
    if ([self shouldLogMissingPrivacyConsentErrorWithMethodName:@"removeExternalUserId"])
        return;

    [self setExternalUserId:@""];
}

+ (void)removeExternalUserId:(OSUpdateExternalUserIdSuccessBlock _Nullable)successBlock withFailure:(OSUpdateExternalUserIdFailureBlock _Nullable)failureBlock {
    // return if the user has not granted privacy permissions
    if ([self shouldLogMissingPrivacyConsentErrorWithMethodName:@"removeExternalUserId:"])
        return;

    [self setExternalUserId:@"" withSuccess:successBlock withFailure:failureBlock];
}

+ (NSString*)existingPushExternalUserId {
    return [OneSignalUserDefaults.initStandard getSavedStringForKey:OSUD_EXTERNAL_USER_ID defaultValue:@""];
}

+ (NSString*)existingEmailExternalUserId {
    return [OneSignalUserDefaults.initStandard getSavedStringForKey:OSUD_EMAIL_EXTERNAL_USER_ID defaultValue:@""];
}

+ (BOOL)shouldUpdateExternalUserId:(NSString*)externalId withRequests:(NSDictionary*)requests {
    // If we are not making a request to email user, no need to validate that external user id
    bool updateExternalUserId = ![self.existingPushExternalUserId isEqualToString:externalId]
                                && !requests[@"email"];

    bool updateEmailExternalUserId = (requests[@"email"]
                                      && ![self.existingEmailExternalUserId isEqualToString:externalId]);

    return updateExternalUserId || updateEmailExternalUserId;
}

/*
 Start of outcome module
 */

+ (void)sendClickActionOutcomes:(NSArray<OSInAppMessageOutcome *> *)outcomes {
    if (!_outcomeEventsController) {
        [self onesignal_Log:ONE_S_LL_ERROR message:@"Make sure OneSignal init is called first"];
        return;
    }

    [_outcomeEventsController sendClickActionOutcomes:outcomes appId:appId deviceType:[NSNumber numberWithInt:DEVICE_TYPE_PUSH]];
}

+ (void)sendOutcome:(NSString * _Nonnull)name {
    [self sendOutcome:name onSuccess:nil];
}

+ (void)sendOutcome:(NSString * _Nonnull)name onSuccess:(OSSendOutcomeSuccess _Nullable)success {
    // return if the user has not granted privacy permissions
    if ([self shouldLogMissingPrivacyConsentErrorWithMethodName:@"sendOutcome:onSuccess:"])
        return;

    if (!_outcomeEventsController) {
        [self onesignal_Log:ONE_S_LL_ERROR message:@"Make sure OneSignal init is called first"];
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
    if ([self shouldLogMissingPrivacyConsentErrorWithMethodName:@"sendUniqueOutcome:onSuccess:"])
        return;

    if (!_outcomeEventsController) {
        [self onesignal_Log:ONE_S_LL_ERROR message:@"Make sure OneSignal init is called first"];
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
    if ([self shouldLogMissingPrivacyConsentErrorWithMethodName:@"sendOutcomeWithValue:value:onSuccess:"])
        return;

    if (!_outcomeEventsController) {
        [self onesignal_Log:ONE_S_LL_ERROR message:@"Make sure OneSignal init is called first"];
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
        [self onesignal_Log:ONE_S_LL_ERROR message:@"Outcome name must not be null or empty"];
        return false;
    }

    return true;
}

+ (BOOL)isValidOutcomeValue:(NSNumber *)value {
    if (!value || value.intValue <= 0) {
        [self onesignal_Log:ONE_S_LL_ERROR message:@"Outcome value must not be null or 0"];
        return false;
    }

    return true;
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
        [OneSignal onesignal_Log:ONE_S_LL_WARN message:@"OneSignal method swizzling is disabled. Make sure the feature is enabled for production."];
        return;
    }
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"UIApplication(OneSignal) LOADED!"];
    
    // Prevent Xcode storyboard rendering process from crashing with custom IBDesignable Views or from hostless unit tests.
    // https://github.com/OneSignal/OneSignal-iOS-SDK/issues/160
    // https://github.com/OneSignal/OneSignal-iOS-SDK/issues/935
    NSString *processName = [[NSProcessInfo processInfo] processName];
    if ([processName isEqualToString:@"IBDesignablesAgentCocoaTouch"] || [processName isEqualToString:@"IBDesignablesAgent-iOS"] || [processName isEqualToString:@"xctest"])
        return;

    // Double loading of class detection.
    BOOL existing = injectSelector([OneSignalAppDelegate class], @selector(oneSignalLoadedTagSelector:), self, @selector(oneSignalLoadedTagSelector:));
    if (existing) {
        [OneSignal onesignal_Log:ONE_S_LL_WARN message:@"Already swizzled UIApplication.setDelegate. Make sure the OneSignal library wasn't loaded into the runtime twice!"];
        return;
    }

    // Swizzle - UIApplication delegate
    injectToProperClass(@selector(setOneSignalDelegate:), @selector(setDelegate:), @[], [OneSignalAppDelegate class], [UIApplication class]);
    
    injectToProperClass(@selector(onesignalSetApplicationIconBadgeNumber:), @selector(setApplicationIconBadgeNumber:), @[], [OneSignalAppDelegate class], [UIApplication class]);
    
    [self setupUNUserNotificationCenterDelegate];
    [[OSMigrationController new] migrate];
    sessionLaunchTime = [NSDate date];
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

    [OneSignalUNUserNotificationCenter setup];
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
