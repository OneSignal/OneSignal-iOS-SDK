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

#import <stdatomic.h>
#import "OneSignalFramework.h"
#import <OneSignalOSCore/OneSignalOSCore-Swift.h>
#import "OneSignalInternal.h"
#import "OneSignalTracker.h"
#import "OneSignalTrackIAP.h"
#import "OneSignalJailbreakDetection.h"
#import "OneSignalMobileProvision.h"
#import "OneSignalHelper.h"

// #import "UNUserNotificationCenter+OneSignal.h" // TODO: This is in Notifications
#import "OneSignalSelectorHelpers.h"
#import "UIApplicationDelegate+OneSignal.h"
#import "OSNotification+Internal.h"
#import "OSMigrationController.h"
#import "OSBackgroundTaskHandlerImpl.h"
#import "OSFocusCallParams.h"

#import <OneSignalNotifications/OneSignalNotifications.h>
#import <OneSignalLocation/OneSignalLocationManager.h>
#import <OneSignalInAppMessages/OneSignalInAppMessages.h>

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

#import "OneSignalLifecycleObserver.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@interface OneSignal (SessionStatusDelegate)
@end

@implementation OneSignal

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

static NSDictionary* launchOptions;
static NSDictionary* appSettings;
// Ensure we only initlize the SDK once even if the public method is called more
// Called after successfully calling setAppId and setLaunchOptions
static BOOL initDone = false;

// Used to track last time SDK was initialized, for whether or not to start a new session
static NSTimeInterval initializationTime;

//// Set when the app is launched
//static NSDate *sessionLaunchTime;

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

//TODO: This is related to unit tests and will change with um tests
+ (void)clearStatics {
    [OneSignalIdentifiers setCurrentAppId:nil];
    launchOptions = false;
    appSettings = nil;
    initDone = false;
    
    [OSNotificationsManager clearStatics];
    registeredWithApple = false;
        
    _downloadedParameters = false;
    _didCallDownloadParameters = false;
    
//    sessionLaunchTime = [NSDate date];

    [OSOutcomes clearStatics];
    
    [OSSessionManager resetSharedSessionManager];
}

#pragma mark Namespaces

+ (id<OSUser>)User {
    return [OneSignalUserManagerImpl.sharedInstance User];
}

+ (void)login:(NSString * _Nonnull)externalId {
    // return if no app_id / the user has not granted privacy permissions
    if ([OneSignalConfig shouldAwaitAppIdAndLogMissingPrivacyConsentForMethod:@"login"]) {
        return;
    }
    [OneSignalUserManagerImpl.sharedInstance loginWithExternalId:externalId token:nil];
    // refine Swift name for Obj-C? But doesn't matter as much since this isn't public API
}

+ (void)login:(NSString * _Nonnull)externalId withToken:(NSString * _Nullable)token {
    // TODO: Need to await download iOS params
    // return if no app_id / the user has not granted privacy permissions
    if ([OneSignalConfig shouldAwaitAppIdAndLogMissingPrivacyConsentForMethod:@"login"]) {
        return;
    }
    [OneSignalUserManagerImpl.sharedInstance loginWithExternalId:externalId token:token];
}

+ (void)logout {
    [OneSignalUserManagerImpl.sharedInstance logout];
}

#pragma mark: Namespaces

+ (Class<OSNotifications>)Notifications {
    return [OSNotificationsManager Notifications];
}

+ (Class<OSSession>)Session {
    return [OSOutcomes Session];
}

+ (Class<OSInAppMessages>)InAppMessages {
    let oneSignalInAppMessages = NSClassFromString(ONE_SIGNAL_IN_APP_MESSAGES_CLASS_NAME);
    if (oneSignalInAppMessages != nil && [oneSignalInAppMessages respondsToSelector:@selector(InAppMessages)]) {
        return [oneSignalInAppMessages performSelector:@selector(InAppMessages)];
    } else {
        [OneSignalLog onesignalLog:ONE_S_LL_ERROR message:@"OneSignalInAppMessages not found. In order to use OneSignal's In App Messaging features the OneSignalInAppMessages module must be added."];
        return [OSStubInAppMessages InAppMessages];
    }
}

+ (Class<OSLiveActivities>)LiveActivities {
    let oneSignalLiveActivities = NSClassFromString(ONE_SIGNAL_LIVE_ACTIVITIES_CLASS_NAME);
    if (oneSignalLiveActivities != nil && [oneSignalLiveActivities respondsToSelector:@selector(liveActivities)]) {
        return [oneSignalLiveActivities performSelector:@selector(liveActivities)];
    } else {
        [OneSignalLog onesignalLog:ONE_S_LL_ERROR message:@"oneSignalLiveActivities not found. In order to use OneSignal's LiveActivities features the OneSignalLiveActivities module must be added."];
        return [OSStubLiveActivities liveActivities];
    }
}

+ (Class<OSLocation>)Location {
    let oneSignalLocationManager = NSClassFromString(ONE_SIGNAL_LOCATION_CLASS_NAME);
    if (oneSignalLocationManager != nil && [oneSignalLocationManager respondsToSelector:@selector(Location)]) {
        return [oneSignalLocationManager performSelector:@selector(Location)];
    } else {
        return [OSStubLocation Location];
    }
}

+ (Class<OSDebug>)Debug {
    return [OneSignalLog Debug];
}

#pragma mark Initialization

/*
 This should be set from all OneSignal entry points.
 Note: wrappers may call this method with a null appId.
 */
+ (void)initialize:(nonnull NSString*)newAppId withLaunchOptions:(nullable NSDictionary*)launchOptions {
    [self setAppId:newAppId];
    [self setLaunchOptions:launchOptions];
    [self init];
}

/*
 1/2 steps in OneSignal init, relying on setLaunchOptions (usage order does not matter)
 Sets the app id OneSignal should use in the application
 */
// TODO: For release, note this change in migration guide:
// No longer reading appID from plist @"OneSignal_APPID" and @"GameThrive_APPID"
+ (void)setAppId:(nullable NSString*)newAppId {
    [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"setAppId called with appId: %@!", newAppId]];

    if (!newAppId || newAppId.length == 0) {
        NSString* cachedAppId = OneSignalIdentifiers.storedAppId;
        if (cachedAppId) {
            [OneSignalLog onesignalLog:ONE_S_LL_INFO message:[NSString stringWithFormat:@"Initializing OneSignal with cached appId: '%@'.", cachedAppId]];
            [OneSignalIdentifiers setCurrentAppId:cachedAppId];
        } else {
            [OneSignalLog onesignalLog:ONE_S_LL_INFO message:@"Waiting for setAppId(appId) with a valid appId to complete OneSignal init!"];
            return;
        }
    } else if (OneSignalIdentifiers.currentAppId && ![newAppId isEqualToString:OneSignalIdentifiers.currentAppId])  {
        // Pre-check on app id to make sure init of SDK is performed properly
        //     Usually when the app id is changed during runtime so that SDK is reinitialized properly
        initDone = false;
        [OneSignalIdentifiers setCurrentAppId:newAppId];
    } else {
        [OneSignalIdentifiers setCurrentAppId:newAppId];
    }

    [self handleAppIdChange:OneSignalIdentifiers.currentAppId];
}

+ (BOOL)isValidAppId:(NSString*)appId {
    if (!appId || ![[NSUUID alloc] initWithUUIDString:appId]) {
        if (!OneSignalWrapper.sdkType) {
            // Fatal log if not a wrapper SDK, wrappers will call init with null App Id
            [OneSignalLog onesignalLog:ONE_S_LL_FATAL message:[NSString stringWithFormat:@"OneSignal AppId: %@ - AppId is null or format is invalid, stopping initialization.\nExample usage: 'b2f7f966-d8cc-11e4-bed1-df8f05be55ba'\n", appId]];
        }
        return false;
    }
    return true;
}

/*
 1/2 steps in OneSignal init, relying on setAppId (usage order does not matter)
 Sets the iOS sepcific app settings
 Method must be called to successfully init OneSignal
 Note: While this is called via `initialize`, it is also called directly from wrapper SDKs.
 */
+ (void)setLaunchOptions:(nullable NSDictionary*)newLaunchOptions {
    [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"setLaunchOptions() called with launchOptions: %@!", launchOptions.description]];

    // Don't continue if the newLaunchOptions are nil
    if (!newLaunchOptions) {
        return;
    }

    launchOptions = newLaunchOptions;
    
    // Cold start from tap on a remote notification
    //  NOTE: launchOptions may be nil if tapping on a notification's action button.
    NSDictionary* userInfo = [launchOptions objectForKey:UIApplicationLaunchOptionsRemoteNotificationKey];
    if (userInfo)
        [OSNotificationsManager setColdStartFromTapOnNotification:YES];
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

    // Make sure last time we closed app was more than 30 secs ago
    const int minTimeThreshold = 30;
    NSTimeInterval timeSinceLastClosed = now - lastTimeClosed;
    NSTimeInterval timeSinceInitialization = now - initializationTime;

    [OneSignalLog onesignalLog:ONE_S_LL_DEBUG message:[NSString stringWithFormat:@"shouldStartNewSession:timeSinceLastClosed: %f", timeSinceLastClosed]];
    [OneSignalLog onesignalLog:ONE_S_LL_DEBUG message:[NSString stringWithFormat:@"shouldStartNewSession:timeSinceInitialization: %f", timeSinceInitialization]];

    return MIN(timeSinceLastClosed, timeSinceInitialization) >= minTimeThreshold;
}

+ (void)startNewSession:(BOOL)fromInit {
    // If not called from init, need to check if we should start a new session
    if (!fromInit && ![self shouldStartNewSession]) {
        return;
    }
    
    [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:@"OneSignal.startNewSession"];
    
    // Run on the main queue as it is possible for this to be called from multiple queues.
    // Also some of the code in the method is not thread safe such as _outcomeEventsController.
    [OneSignalHelper dispatch_async_on_main_queue:^{
        [self startNewSessionInternal];
    }];
}

+ (void)startNewSessionInternal {
    [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:@"OneSignal.startNewSessionInternal"];

    // return if the user has not granted privacy permissions, or device-protected storage
    // isn't readable yet (iOS prewarm before first unlock — the observer recovery will
    // re-fire `[OneSignal startNewSession:YES]` once storage becomes available).
    if ([OneSignalConfig shouldAwaitAppIdAndLogMissingPrivacyConsentForMethod:nil])
        return;

    [OSOutcomes.sharedController clearOutcomes];

    [[OSSessionManager sharedSessionManager] restartSessionIfNeeded];
    
    [OneSignalTrackFirebaseAnalytics trackInfluenceOpenEvent];
    
    // Clear last location after attaching data to user state or not
    let oneSignalLocation = NSClassFromString(ONE_SIGNAL_LOCATION_CLASS_NAME);
    if (oneSignalLocation != nil && [oneSignalLocation respondsToSelector:@selector(clearLastLocation)]) {
        [oneSignalLocation performSelector:@selector(clearLastLocation)];
    }
    
    [OSNotificationsManager sendNotificationTypesUpdateToDelegate];

    // TODO: Figure out if Create User also sets session_count automatically on backend
    [OneSignalUserManagerImpl.sharedInstance startNewSession];
    
    // This is almost always going to be nil the first time.
    // The OSMessagingController is an OSPushSubscriptionObserver so that we pull IAMs once we have the sub id
    NSString *subscriptionId = OneSignalUserManagerImpl.sharedInstance.pushSubscriptionId;
    if (subscriptionId) {
        let oneSignalInAppMessages = NSClassFromString(ONE_SIGNAL_IN_APP_MESSAGES_CLASS_NAME);
        if (oneSignalInAppMessages != nil && [oneSignalInAppMessages respondsToSelector:@selector(getInAppMessagesFromServer:)]) {
            [oneSignalInAppMessages performSelector:@selector(getInAppMessagesFromServer:) withObject:subscriptionId];
        }
    }
    
    // The below means there are NO IAMs until on_session returns
    // because they can be ended, paused, or deleted from the server, or your segment has changed and you're no longer eligible
    
    // ^ Do the "on_session" call, send session_count++
    // on success:
    //    [OneSignalLocation sendLocation];
    //    [self executePendingLiveActivityUpdates];
    //    [self receivedInAppMessageJson:results[@"push"][@"in_app_messages"]];  // go to controller
}

+ (void)startInAppMessages {
    let oneSignalInAppMessages = NSClassFromString(ONE_SIGNAL_IN_APP_MESSAGES_CLASS_NAME);
    if (oneSignalInAppMessages != nil && [oneSignalInAppMessages respondsToSelector:@selector(start)]) {
        [oneSignalInAppMessages performSelector:@selector(start)];
    }
}

+ (void)startOutcomes {
    [OSOutcomes start];
    [OSOutcomes.sharedController cleanUniqueOutcomeNotifications]; // TODO: should this actually be in new session instead of init
}

+ (void)startLocation {
    let oneSignalLocation = NSClassFromString(ONE_SIGNAL_LOCATION_CLASS_NAME);
    if (oneSignalLocation != nil && [oneSignalLocation respondsToSelector:@selector(start)]) {
        [oneSignalLocation performSelector:@selector(start)];
    }
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

+ (void)startLiveActivitiesManager {
    let oneSignalLiveActivities = NSClassFromString(ONE_SIGNAL_LIVE_ACTIVITIES_CLASS_NAME);
    if (oneSignalLiveActivities != nil && [oneSignalLiveActivities respondsToSelector:@selector(start)]) {
        [oneSignalLiveActivities performSelector:@selector(start)];
    } else {
        [OneSignalLog onesignalLog:ONE_S_LL_ERROR message:@"oneSignalLiveActivities not found. In order to use OneSignal's LiveActivities features the OneSignalLiveActivities module must be added."];
    }
}

+ (void)delayInitializationForPrivacyConsent {
    [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:@"Delayed initialization of the OneSignal SDK until the user provides privacy consent using the setPrivacyConsent() method"];
    delayedInitializationForPrivacyConsent = true;
    _delayedInitParameters = [[DelayedConsentInitializationParameters alloc] initWithLaunchOptions:launchOptions withAppId:OneSignalIdentifiers.currentAppId];
    // Init was not successful, set appId back to nil
    [OneSignalIdentifiers setCurrentAppId:nil];
}

/*
 Called after setAppId and setLaunchOptions, depending on which one is called last (order does not matter)
 */
+ (void)init {
    [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"launchOptions is set and appId of %@ is set, initializing OneSignal...", OneSignalIdentifiers.currentAppId]];

    // Wire the protected-data check so OneSignalConfig's readiness predicate defers SDK
    // operations during iOS prewarm (before first unlock) when shared UserDefaults reads
    // are unreliable. UIApplication isn't available to OneSignalOSCore (which OneSignalConfig
    // lives in), so the main app injects the check here at initialize time.
    //
    // The flag is a one-way latch: it starts NO, flips to YES once our storage is readable,
    // and stays YES for the lifetime of the process. The SDK's shared App Group UserDefaults
    // use `NSFileProtectionCompleteUntilFirstUserAuthentication` — readable from first unlock
    // onward, and stays readable across every subsequent lock/unlock cycle.
    //
    // We seed via a UD probe of the push-subscription model store. Primary path tests our
    // actual storage class (`…UntilFirstUserAuthentication`) directly, with
    // `UIApplication.isProtectedDataAvailable` only as a tiebreaker for the ambiguous
    // no-positive-signal case (so pre-PR SDK upgraders — who never wrote `keyDidStart` —
    // don't get misclassified as "fresh install" during prewarm and orphaned by Path 3).
    //   * UD readable → pushModels has entries → flag = YES
    //   * UD locked (genuine prewarm) + `keyDidStart` set → flag = NO (returning user; defer)
    //   * No positive signal + main thread → tiebreaker on `isProtectedDataAvailable`:
    //       - YES → flag = YES (likely fresh install on a normal launch)
    //       - NO  → flag = NO  (could be pre-PR upgrader prewarm OR fresh install in a
    //                          locked-after-first-unlock spawn; defer to observer to be safe)
    //   * No positive signal + off-main thread → flag = YES (can't safely read UIApplication;
    //     accept the rare pre-PR-upgrader-off-main-init risk in exchange for not bricking
    //     the common case)
    // `keyDidStart` is written at the end of a successful `start()` and cleared on app-id
    // change; it's the explicit "SDK previously initialized on this device" sentinel.
    // We deliberately do NOT observe `UIApplicationProtectedDataWillBecomeUnavailable` —
    // it tracks `NSFileProtectionComplete` (the stricter class) which flips back to NO ~10s
    // after every device lock, and using it would silently gate APIs in locked-after-first-
    // unlock contexts where our `…UntilFirstUserAuthentication` storage is still readable.
    static _Atomic(BOOL) gProtectedDataAvailable = NO;
    // Whether `+init`'s synchronous `start()` / `startNewSession:YES` calls were gated out
    // and need to be re-driven from the observer. Set inside the dispatch_once below;
    // cleared atomically on the first observer fire. Without this guard, every
    // device lock-then-unlock cycle while the app is alive would post
    // `UIApplicationProtectedDataDidBecomeAvailable` (it tracks `NSFileProtectionComplete`,
    // which transitions on every lock), re-run `startNewSession:YES`, and bypass the
    // 30s threshold — spuriously incrementing `session_count` and firing duplicate
    // `fetchUser` requests.
    static _Atomic(BOOL) gObserverShouldRecover = NO;
    static dispatch_once_t protectedDataOnce;
    dispatch_once(&protectedDataOnce, ^{
        [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationProtectedDataDidBecomeAvailable
                            object:nil
                             queue:nil
                        usingBlock:^(NSNotification * _Nonnull note) {
            atomic_store(&gProtectedDataAvailable, YES);
            // Only run the recovery if the seed put us in the deferred state. Otherwise
            // `+init`'s synchronous calls already ran and re-driving them on routine
            // lock/unlock cycles would duplicate work.
            BOOL expected = YES;
            if (!atomic_compare_exchange_strong(&gObserverShouldRecover, &expected, NO)) {
                return;
            }
            // Drive `start()` again — it was gated by the predicate while protected data was
            // unavailable. The re-call now sees the gate clear, refreshes the model stores
            // from shared UserDefaults, and takes the normal Path 1 cache load.
            [OneSignalUserManagerImpl.sharedInstance start];
            // Replay any APNs token cached in `_pushToken` before the delegate was set.
            // `start()` only assigns `OSNotificationsManager.delegate`; it does not pull the
            // existing token. Mirrors `+startUserManager`'s pairing.
            [OSNotificationsManager sendPushTokenToDelegate];
            // Start the modules `+init` deferred during prewarm — their singletons eagerly
            // read UserDefaults at init, so initializing them now (with storage readable)
            // gives them the real on-disk state instead of empty caches that would overwrite
            // it on first save.
            [OneSignal startLiveActivitiesManager];
            [OneSignal startInAppMessages];
            // Complete the deferred `+init` new-session call. We use `:YES` (force) because
            // the 30s threshold would otherwise no-op this recovery when unlock happens
            // within 30s of init.
            [OneSignal startNewSession:YES];
        }];

        OneSignalConfig.isProtectedDataAvailableProvider = ^BOOL {
            return atomic_load(&gProtectedDataAvailable);
        };

        // Seed the cached flag — see the block comment above for the case table.
        // UserDefaults reads are thread-safe so this works from any thread; the
        // `UIApplication` tiebreaker is only consulted on the main thread.
        NSDictionary *pushModels = [OneSignalUserDefaults.initShared getSavedCodeableDataForKey:OS_PUSH_SUBSCRIPTION_MODEL_STORE_KEY defaultValue:@{}];
        BOOL hasPriorSession = [OSResilientStorage stringForKey:OSResilientStorage.keyDidStart] != nil;
        BOOL storageReadable;
        if (pushModels.count > 0) {
            storageReadable = YES;
        } else if (hasPriorSession) {
            storageReadable = NO;
        } else if ([NSThread isMainThread]) {
            storageReadable = UIApplication.sharedApplication.isProtectedDataAvailable;
        } else {
            storageReadable = YES;
        }
        atomic_store(&gProtectedDataAvailable, storageReadable);
        atomic_store(&gObserverShouldRecover, !storageReadable);
    });

    // TODO: We moved this check to the top of this method, we should test this.
    if (initDone) {
        return;
    }
    
    [[OSMigrationController new] migrate];
    
    OSBackgroundTaskManager.taskHandler = [OSBackgroundTaskHandlerImpl new];

    [self registerForAPNsToken];
    
    // Wrapper SDK's call init twice and pass null as the appId on the first call
    //  the app ID is required to download parameters, so do not download params until the appID is provided
    if (!_didCallDownloadParameters && OneSignalIdentifiers.currentAppId && OneSignalIdentifiers.currentAppId != (id)[NSNull null])
        [self downloadIOSParamsWithAppId:OneSignalIdentifiers.currentAppId];
    
    // using classes as delegates is not best practice. We should consider using a shared instance of a class instead
    [OSSessionManager sharedSessionManager].delegate = (id<SessionStatusDelegate>)self;
        
    if ([OSPrivacyConsentController requiresUserPrivacyConsent]) {
        [self delayInitializationForPrivacyConsent];
        return;
    }
    
    // Now really initializing the SDK!
    
    // Invalid app ids reaching here will cause failure
    if (![self isValidAppId:OneSignalIdentifiers.currentAppId])
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
    
    [OSNotificationsManager clearBadgeCount:false fromClearAll:false];
    [self startOutcomes];
    [self startLocation];
    [self startTrackIAP];
    [self startTrackFirebaseAnalytics];
    [self startLifecycleObserver];
    //TODO: Should these be started in Dependency order? e.g. IAM depends on User Manager shared instance
    [self startUserManager]; // By here, app_id exists, and consent is granted.
    // `OneSignalLiveActivitiesManagerImpl` and `OSMessagingController` both eagerly read
    // shared/standard UserDefaults at their first-access init (LA's `RequestCache.init`
    // reads the pending token-update queue; IAM's `OSMessagingController.init` reads
    // seen/clicked/impressioned sets). During prewarm-before-first-unlock those reads
    // return empty and subsequent saves overwrite the prior on-disk state. Gate both here
    // and re-drive from the protected-data observer (above) once storage is readable.
    if (![OneSignalConfig shouldAwaitAppIdAndLogMissingPrivacyConsentForMethod:nil]) {
        [self startLiveActivitiesManager];
        [self startInAppMessages];
    }
    [self startNewSession:YES];
    
    initializationTime = [[NSDate date] timeIntervalSince1970];
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
    NSString *prevAppId = OneSignalIdentifiers.storedAppId;

    // Handle changes to the app id, this might happen on a developer's device when testing.
    // Only treat as a change when a non-nil prevAppId was previously stored AND it differs —
    // a nil prevAppId means either a true first install OR a degenerate read (which the
    // OSResilientStorage fallback inside storedAppId now mostly prevents). Treating nil as
    // "changed" would fire the destructive subscription_id clear on first install.
    if (appId && prevAppId && ![appId isEqualToString:prevAppId]) {
        initDone = false;
        _downloadedParameters = false;
        _didCallDownloadParameters = false;

        let sharedUserDefaults = OneSignalUserDefaults.initShared;

        // Remove player_id from both standard and shared NSUserDefaults
        [standardUserDefaults removeValueForKey:OSUD_PUSH_SUBSCRIPTION_ID];
        [sharedUserDefaults removeValueForKey:OSUD_PUSH_SUBSCRIPTION_ID];
        [standardUserDefaults removeValueForKey:OSUD_LEGACY_PLAYER_ID];
        [sharedUserDefaults removeValueForKey:OSUD_LEGACY_PLAYER_ID];
        // Symmetric with the OSResilientStorage clear below. The NSE's `isReceiveReceiptsEnabled`
        // short-circuits on UD = YES before consulting the mirror, so leaving stale UD here
        // would mask the mirror clear until the new app's `downloadIOSParams` lands.
        [sharedUserDefaults removeValueForKey:OSUD_RECEIVE_RECEIPTS_ENABLED];
        // Drop the archived push subscription model dict — `pushSubscriptionModelStore` is the
        // only model store NOT registered for `OS_ON_USER_WILL_CHANGE` (its push-sub is
        // device-tied), so `clearAllModelsFromStores` below doesn't clear it. Without this
        // removal, the next launch reloads the OLD app's server-issued `subscriptionId` via
        // NSCoding and the new `_user` operates with a stale id until `downloadIOSParams`
        // re-issues one.
        [sharedUserDefaults removeValueForKey:OS_PUSH_SUBSCRIPTION_MODEL_STORE_KEY];

        // Drop cached identifiers — a real app-id change invalidates them.
        [OSResilientStorage setStrings:@{
            OSResilientStorage.keySubscriptionId: @"",
            OSResilientStorage.keyReceiveReceiptsEnabled: @"",
            OSResilientStorage.keyDidStart: @""
        }];

        // Clear all cached data, does not start User Module nor call logout.
        [OneSignalUserManagerImpl.sharedInstance clearAllModelsFromStores];
    }

    [OneSignalUserDefaults.initShared saveStringForKey:OSUD_APP_ID withValue:appId];
    [OSResilientStorage setString:appId forKey:OSResilientStorage.keyAppId];
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

+ (void)setConsentRequired:(BOOL)required {
    [OSPrivacyConsentController setRequiresPrivacyConsent:required];
}

+ (void)setConsentGiven:(BOOL)granted {
    [OSPrivacyConsentController consentGranted:granted];
    
    if (!granted || !delayedInitializationForPrivacyConsent || _delayedInitParameters == nil)
        return;
    // Try to init again using delayed params
    [self initialize:_delayedInitParameters.appId withLaunchOptions:_delayedInitParameters.launchOptions];
    delayedInitializationForPrivacyConsent = false;
    _delayedInitParameters = nil;
}

+ (void)downloadIOSParamsWithAppId:(NSString *)appId {
    [OneSignalLog onesignalLog:ONE_S_LL_DEBUG message:@"Downloading iOS parameters for this application"];
    _didCallDownloadParameters = true;
    // This will be nil unless we have a cached user
    // TODO: Commented out. This will init the User Manager too early, and userId is not needed anyway.
    // NSString *userId = OneSignalUserManagerImpl.sharedInstance.pushSubscriptionId;
    NSString *userId = nil;

    [OneSignalCoreImpl.sharedClient executeRequest:[OSRequestGetIosParams withUserId:userId appId:appId] onSuccess:^(NSDictionary *result) {

        if (result[IOS_REQUIRES_USER_ID_AUTHENTICATION]) {
            OneSignalUserManagerImpl.sharedInstance.requiresUserAuth = [result[IOS_REQUIRES_USER_ID_AUTHENTICATION] boolValue];
        }

        if (result[IOS_USES_PROVISIONAL_AUTHORIZATION] != (id)[NSNull null]) {
            [OneSignalUserDefaults.initStandard saveBoolForKey:OSUD_USES_PROVISIONAL_PUSH_AUTHORIZATION withValue:[result[IOS_USES_PROVISIONAL_AUTHORIZATION] boolValue]];

            [OSNotificationsManager checkProvisionalAuthorizationStatus];
        }

        if (result[IOS_RECEIVE_RECEIPTS_ENABLE] != (id)[NSNull null]) {
            BOOL enabled = [result[IOS_RECEIVE_RECEIPTS_ENABLE] boolValue];
            [OneSignalUserDefaults.initShared saveBoolForKey:OSUD_RECEIVE_RECEIPTS_ENABLED withValue:enabled];
            // Mirror to the unencrypted cache so the NSE can read this flag while the
            // device is booted-but-locked (UserDefaults reads return nil in that state).
            [OSResilientStorage setString:enabled ? @"1" : @"0" forKey:OSResilientStorage.keyReceiveReceiptsEnabled];
        }

        [[OSRemoteParamController sharedController] saveRemoteParams:result];
        if ([[OSRemoteParamController sharedController] hasLocationKey]) {
            BOOL shared = [result[IOS_LOCATION_SHARED] boolValue];
            let oneSignalLocation = NSClassFromString(ONE_SIGNAL_LOCATION_CLASS_NAME);
            if (oneSignalLocation != nil && [oneSignalLocation respondsToSelector:@selector(startLocationSharedWithFlag:)]) {
                [OneSignalCoreHelper callSelector:@selector(startLocationSharedWithFlag:) onObject:oneSignalLocation withArg:shared];
            }
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

    } onFailure:^(OneSignalClientError *error) {
        _didCallDownloadParameters = false;
    }];
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
//
////TODO: move to sessions/onfocus
//+ (NSDate *)sessionLaunchTime {
//    return sessionLaunchTime;
//}

/*
 Start of outcome module
 */

+ (void)sendSessionEndOutcomes:(NSNumber*)totalTimeActive params:(OSFocusCallParams *)params onSuccess:(OSResultSuccessBlock _Nonnull)successBlock onFailure:(OSFailureBlock _Nonnull)failureBlock {
    if (![OSOutcomes sharedController]) {
        [OneSignalLog onesignalLog:ONE_S_LL_ERROR message:@"Make sure OneSignal init is called first"];
        if (failureBlock) {
            failureBlock([NSError errorWithDomain:@"onesignal" code:0 userInfo:@{@"error" : @"Missing outcomes controller."}]);
        }
        return;
    }
    
    NSString* onesignalId = OneSignalUserManagerImpl.sharedInstance.onesignalId;
    NSString* pushSubscriptionId = OneSignalUserManagerImpl.sharedInstance.pushSubscriptionId;
    
    if (!onesignalId || !pushSubscriptionId) {
        if (failureBlock) {
            failureBlock([NSError errorWithDomain:@"onesignal" code:0 userInfo:@{@"error" : @"Missing onesignalId or pushSubscriptionId."}]);
        }
        return;
        
    }
    
    [OSOutcomes.sharedController sendSessionEndOutcomes:totalTimeActive
                                                  appId:OneSignalIdentifiers.currentAppId
                                     pushSubscriptionId:pushSubscriptionId
                                            onesignalId:onesignalId
                                        influenceParams:params.influenceParams
                                              onSuccess:successBlock
                                              onFailure:failureBlock];
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
    [OSDialogInstanceManager setSharedOSDialogInstance:[OneSignalDialogController sharedInstance]];
    [OSNotificationsManager registerLifecycleObserver];
    
    if ([OSNotificationsManager isSwizzlingDisabled]) {
        [OneSignalLog onesignalLog:ONE_S_LL_WARN message:@"OneSignal method swizzling is disabled via Info.plist. Developers must manually forward notification delegate methods to OneSignal."];
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

    [OSNotificationsManager startSwizzling];

    [[OSMigrationController new] migrate];
//    sessionLaunchTime = [NSDate date];
    // TODO: sessionLaunchTime used to always be set in load
}

/*
    In order for the badge count to be consistent even in situations where the developer manually sets the badge number,
    We swizzle the 'setApplicationIconBadgeNumber()' to intercept these calls so we always know the latest count
*/
- (void)onesignalSetApplicationIconBadgeNumber:(NSInteger)badge {
    [OneSignalBadgeHelpers updateCachedBadgeValue:badge usePreviousBadgeCount:false];
    [self onesignalSetApplicationIconBadgeNumber:badge];
}

@end

#pragma clang diagnostic pop
#pragma clang diagnostic pop
#pragma clang diagnostic pop
