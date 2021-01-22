/**
 * Modified MIT License
 *
 * Copyright 2016 OneSignal
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

#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>

#import "OneSignalLocation.h"
#import "OneSignalHelper.h"
#import "OneSignal.h"
#import "OneSignalClient.h"
#import "Requests.h"
#import "OneSignalDialogController.h"
#import "OSStateSynchronizer.h"

@interface OneSignal ()
void onesignal_Log(ONE_S_LOG_LEVEL logLevel, NSString* message);
+ (NSString *)mEmailUserId;
+ (NSString*)mUserId;
+ (NSString *)mEmailAuthToken;
+ (NSString *)mExternalIdAuthToken;
+ (OSStateSynchronizer *)stateSynchronizer;
@end

@implementation OneSignalLocation

//Track time until next location fire event
const NSTimeInterval foregroundSendLocationWaitTime = 5 * 60.0;
NSTimer* requestLocationTimer = nil;
os_last_location *lastLocation;
bool initialLocationSent = false;
UIBackgroundTaskIdentifier fcTask;
const int alertSettingsTag = 199;

static id locationManager = nil;
static bool started = false;
static bool hasDelayed = false;
static bool fallbackToSettings = false;

// CoreLocation must be statically linked for geotagging to work on iOS 6 and possibly 7.
// plist NSLocationUsageDescription (iOS 6 & 7) and NSLocationWhenInUseUsageDescription (iOS 8+) keys also required.

// Suppressing undeclared selector warnings
// NSClassFromString and performSelector are used so OneSignal does not depend on CoreLocation to link the app.
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wundeclared-selector"
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"

NSMutableArray *_locationListeners;
+(NSMutableArray*)locationListeners {
    if (!_locationListeners)
        _locationListeners = [NSMutableArray new];
    return _locationListeners;
}

NSObject *_mutexObjectForLastLocation;
+(NSObject*)mutexObjectForLastLocation {
    if (!_mutexObjectForLastLocation)
        _mutexObjectForLastLocation = [NSObject alloc];
    return _mutexObjectForLastLocation;
}

static OneSignalLocation* singleInstance = nil;
+(OneSignalLocation*) sharedInstance {
    @synchronized( singleInstance ) {
        if( !singleInstance ) {
            singleInstance = [[OneSignalLocation alloc] init];
        }
    }
    
    return singleInstance;
}

+ (os_last_location*)lastLocation {
    return lastLocation;
}

+ (bool)started {
    return started;
}

+ (void)clearLastLocation {
    @synchronized(OneSignalLocation.mutexObjectForLastLocation) {
       lastLocation = nil;
    }
}

+ (void)getLocation:(bool)prompt fallbackToSettings:(BOOL)fallback withCompletionHandler:(void (^)(PromptActionResult result))completionHandler {
    if (completionHandler)
        [OneSignalLocation.locationListeners addObject:completionHandler];

    if (hasDelayed)
        [OneSignalLocation internalGetLocation:prompt fallbackToSettings:fallback];
    else {
        // Delay required for locationServicesEnabled and authorizationStatus return the correct values when CoreLocation is not statically linked.
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, 2.0 * NSEC_PER_SEC);
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void) {
            hasDelayed = true;
            [OneSignalLocation internalGetLocation:prompt fallbackToSettings:fallback];
        });
    }
    // Listen to app going to and from background
}

+ (void)onFocus:(BOOL)isActive {
    
    // return if the user has not granted privacy permissions
    if ([OneSignal requiresUserPrivacyConsent])
        return;
    
    if (!locationManager || ![self started])
        return;
    
    /**
     We have a state switch
     - If going to active: keep timer going
     - If going to background:
        1. Make sure that we can track background location
            -> continue timer to send location otherwise set location to nil
        Otherwise set timer to NULL
    **/
    
    NSTimeInterval remainingTimerTime = requestLocationTimer.fireDate.timeIntervalSinceNow;
    NSTimeInterval requiredWaitTime = foregroundSendLocationWaitTime;
    NSTimeInterval adjustedTime = remainingTimerTime > 0 ? remainingTimerTime : requiredWaitTime;

    if (isActive) {
        if(requestLocationTimer && initialLocationSent) {
            //Keep timer going with the remaining time
            [requestLocationTimer invalidate];
            requestLocationTimer = [NSTimer scheduledTimerWithTimeInterval:adjustedTime target:self selector:@selector(requestLocation) userInfo:nil repeats:NO];
        }
    } else {
        //Check if always granted
        if ((int)[NSClassFromString(@"CLLocationManager") performSelector:@selector(authorizationStatus)] == kCLAuthorizationStatusAuthorizedAlways) {
            [OneSignalLocation beginTask];
            [requestLocationTimer invalidate];
            [self requestLocation];
        } else {
            requestLocationTimer = NULL;
        }
    }
}

+ (void)beginTask {
    fcTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [OneSignalLocation endTask];
    }];
}

+ (void)endTask {
    [[UIApplication sharedApplication] endBackgroundTask: fcTask];
    fcTask = UIBackgroundTaskInvalid;
}

+ (void)sendAndClearLocationListener:(PromptActionResult)result {
    onesignal_Log(ONE_S_LL_DEBUG, [NSString stringWithFormat:@"OneSignalLocation sendAndClearLocationListener listeners: %@", OneSignalLocation.locationListeners]);
    for (int i = 0; i < OneSignalLocation.locationListeners.count; i++) {
        ((void (^)(PromptActionResult result))[OneSignalLocation.locationListeners objectAtIndex:i])(result);
    }
    // We only call the listeners once
    [OneSignalLocation.locationListeners removeAllObjects];
}

+ (void)sendCurrentAuthStatusToListeners {
    id clLocationManagerClass = NSClassFromString(@"CLLocationManager");
    CLAuthorizationStatus permissionStatus = (int)[clLocationManagerClass performSelector:@selector(authorizationStatus)];
    if (permissionStatus == kCLAuthorizationStatusNotDetermined)
        return;

    // If already given or denied the permission, listeners should have the response
    let denied = permissionStatus == kCLAuthorizationStatusRestricted || permissionStatus == kCLAuthorizationStatusDenied;
    [self sendAndClearLocationListener:denied ? PERMISSION_DENIED : PERMISSION_GRANTED];
}

+ (void)internalGetLocation:(bool)prompt fallbackToSettings:(BOOL)fallback {
    fallbackToSettings = fallback;
    id clLocationManagerClass = NSClassFromString(@"CLLocationManager");
    
    // On the application init we are always calling this method
    // If location permissions was not asked "started" will never be true
    if ([self started]) {
        // We evaluate the following cases after permissions were asked (denied or given)
        CLAuthorizationStatus permissionStatus = (int)[clLocationManagerClass performSelector:@selector(authorizationStatus)];
        BOOL showSettings = prompt && fallback && permissionStatus == kCLAuthorizationStatusDenied;
        [OneSignal onesignalLog:ONE_S_LL_DEBUG message:[NSString stringWithFormat:@"internalGetLocation called showSettings: %@", showSettings ? @"YES" : @"NO"]];
        // Fallback to settings alert view when the following condition are true:
        //   - On a prompt flow
        //   - Fallback to settings is enabled
        //   - Permission were denied
        if (showSettings)
            [self showLocationSettingsAlertController];
        else
            [self sendCurrentAuthStatusToListeners];
        return;
    }
    
    // Check for location in plist
    if (![clLocationManagerClass performSelector:@selector(locationServicesEnabled)]) {
        onesignal_Log(ONE_S_LL_DEBUG, @"CLLocationManager locationServices Disabled.");
        [self sendAndClearLocationListener:ERROR];
        return;
    }
    
    CLAuthorizationStatus permissionStatus = (int)[clLocationManagerClass performSelector:@selector(authorizationStatus)];
    // return if permission not determined and should not prompt
    if (permissionStatus == kCLAuthorizationStatusNotDetermined && !prompt) {
        onesignal_Log(ONE_S_LL_DEBUG, @"internalGetLocation kCLAuthorizationStatusNotDetermined.");
        return;
    }
    
    [self sendCurrentAuthStatusToListeners];
    locationManager = [[clLocationManagerClass alloc] init];
    [locationManager setValue:[self sharedInstance] forKey:@"delegate"];

        
    //Check info plist for request descriptions
    //LocationAlways > LocationWhenInUse > No entry (Log error)
    //Location Always requires: Location Background Mode + NSLocationAlwaysUsageDescription
    NSArray* backgroundModes = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"UIBackgroundModes"];
    NSString* alwaysDescription = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"NSLocationAlwaysUsageDescription"] ?: [[NSBundle mainBundle] objectForInfoDictionaryKey:@"NSLocationAlwaysAndWhenInUseUsageDescription"];
    // use background location updates if always permission granted or prompt allowed
    BOOL backgroundLocationEnable = backgroundModes && [backgroundModes containsObject:@"location"] && alwaysDescription;
    BOOL permissionEnable = permissionStatus == kCLAuthorizationStatusAuthorizedAlways || prompt;
    
    [OneSignal onesignalLog:ONE_S_LL_DEBUG message:[NSString stringWithFormat:@"internalGetLocation called backgroundLocationEnable: %@ permissionEnable: %@", backgroundLocationEnable ? @"YES" : @"NO", permissionEnable ? @"YES" : @"NO"]];
    
    if (backgroundLocationEnable && permissionEnable) {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [locationManager performSelector:NSSelectorFromString(@"requestAlwaysAuthorization")];
        #pragma clang diagnostic pop
        if ([OneSignalHelper isIOSVersionGreaterThanOrEqual:@"9.0"])
            [locationManager setValue:@YES forKey:@"allowsBackgroundLocationUpdates"];
    }

    else if ([[NSBundle mainBundle] objectForInfoDictionaryKey:@"NSLocationWhenInUseUsageDescription"]) {
        if (permissionStatus == kCLAuthorizationStatusNotDetermined)
            [locationManager performSelector:@selector(requestWhenInUseAuthorization)];
    }

    else {
        onesignal_Log(ONE_S_LL_ERROR, @"Include a privacy NSLocationAlwaysUsageDescription or NSLocationWhenInUseUsageDescription in your info.plist to request location permissions.");
        [self sendAndClearLocationListener:LOCATION_PERMISSIONS_MISSING_INFO_PLIST];
    }
        
    // This method is used for getting the location manager to obtain an initial location fix
    // and will notify your delegate by calling its locationManager:didUpdateLocations: method
    [locationManager performSelector:@selector(startUpdatingLocation)];
    
    started = true;
}

+ (void)showLocationSettingsAlertController {
    onesignal_Log(ONE_S_LL_DEBUG, @"CLLocationManager permissionStatus kCLAuthorizationStatusDenied fallaback to settings");
    [[OneSignalDialogController sharedInstance] presentDialogWithTitle:@"Location Not Available" withMessage:@"You have previously denied sharing your device location. Please go to settings to enable." withActions:@[@"Open Settings"] cancelTitle:@"Cancel" withActionCompletion:^(int tappedActionIndex) {
        if (tappedActionIndex > -1) {
            onesignal_Log(ONE_S_LL_DEBUG, @"CLLocationManage open settings option click");
            #pragma clang diagnostic push
            #pragma clang diagnostic ignored "-Wdeprecated"
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]];
            #pragma clang diagnostic pop
        }
        [OneSignalLocation sendAndClearLocationListener:false];
        return;
    }];
}

+ (void)requestLocation {
    onesignal_Log(ONE_S_LL_DEBUG, @"OneSignalLocation Requesting Updated Location");
    id clLocationManagerClass = NSClassFromString(@"CLLocationManager");
    if ([UIApplication sharedApplication].applicationState == UIApplicationStateBackground
        && [clLocationManagerClass performSelector:@selector(significantLocationChangeMonitoringAvailable)]) {
        [locationManager performSelector:@selector(startMonitoringSignificantLocationChanges)];
    } else {
        [locationManager performSelector:@selector(requestLocation)];
    }
}

#pragma mark CLLocationManagerDelegate

- (void)locationManager:(id)manager didUpdateLocations:(NSArray *)locations {
    // return if the user has not granted privacy permissions or location shared is false
    if (([OneSignal requiresUserPrivacyConsent] || ![OneSignal isLocationShared]) && !fallbackToSettings) {
        onesignal_Log(ONE_S_LL_DEBUG, @"CLLocationManagerDelegate clear Location listener due to permissions denied or location shared not available");
        [OneSignalLocation sendAndClearLocationListener:PERMISSION_DENIED];
        return;
    }
    [manager performSelector:@selector(stopUpdatingLocation)];
    if ([UIApplication sharedApplication].applicationState != UIApplicationStateBackground) {
        [manager performSelector:@selector(stopMonitoringSignificantLocationChanges)];
        if (!requestLocationTimer)
            [OneSignalLocation resetSendTimer];
    }
    
    id location = locations.lastObject;
    
    SEL cord_selector = NSSelectorFromString(@"coordinate");
    os_location_coordinate cords;
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[[location class] instanceMethodSignatureForSelector:cord_selector]];
    
    [invocation setTarget:locations.lastObject];
    [invocation setSelector:cord_selector];
    [invocation invoke];
    [invocation getReturnValue:&cords];
    
    @synchronized(OneSignalLocation.mutexObjectForLastLocation) {
        if (!lastLocation)
            lastLocation = (os_last_location*)malloc(sizeof(os_last_location));
        
        lastLocation->verticalAccuracy = [[location valueForKey:@"verticalAccuracy"] doubleValue];
        lastLocation->horizontalAccuracy = [[location valueForKey:@"horizontalAccuracy"] doubleValue];
        lastLocation->cords = cords;
    }
    
    
    
    [OneSignalLocation sendLocation];
    
    [OneSignalLocation sendAndClearLocationListener:PERMISSION_GRANTED];
}

- (void)locationManager:(id)manager didFailWithError:(NSError *)error {
    [OneSignal onesignal_Log:ONE_S_LL_ERROR message:[NSString stringWithFormat:@"CLLocationManager did fail with error: %@", error]];
    [OneSignalLocation sendAndClearLocationListener:ERROR];
}

+ (void)resetSendTimer {
    [requestLocationTimer invalidate];
    NSTimeInterval requiredWaitTime = foregroundSendLocationWaitTime;
    requestLocationTimer = [NSTimer scheduledTimerWithTimeInterval:requiredWaitTime target:self selector:@selector(requestLocation) userInfo:nil repeats:NO];
}

+ (void)sendLocation {
    // return if the user has not granted privacy permissions
    if ([OneSignal requiresUserPrivacyConsent])
        return;
    
    @synchronized(OneSignalLocation.mutexObjectForLastLocation) {
        if (!lastLocation || ![OneSignal mUserId])
            return;
        
        //Fired from timer and not initial location fetched
        if (initialLocationSent && [UIApplication sharedApplication].applicationState != UIApplicationStateBackground)
            [OneSignalLocation resetSendTimer];
        
        initialLocationSent = YES;
        
        [OneSignal.stateSynchronizer sendLocation:lastLocation appId:[OneSignal appId] networkType:[OneSignalHelper getNetType] backgroundState:([UIApplication sharedApplication].applicationState != UIApplicationStateActive)];
    }
    
}


#pragma clang diagnostic pop
#pragma GCC diagnostic pop

@end
