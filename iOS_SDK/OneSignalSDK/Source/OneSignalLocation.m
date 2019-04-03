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

#import "OneSignalLocation.h"
#import "OneSignalHelper.h"
#import "OneSignal.h"
#import "OneSignalClient.h"
#import "Requests.h"

@interface OneSignal ()
void onesignal_Log(ONE_S_LOG_LEVEL logLevel, NSString* message);
+ (NSString *)mEmailUserId;
+ (NSString*)mUserId;
+ (NSString *)mEmailAuthToken;
@end

@implementation OneSignalLocation

//Track time until next location fire event
const NSTimeInterval foregroundSendLocationWaitTime = 5 * 60.0;
const NSTimeInterval backgroundSendLocationWaitTime = 9.75 * 60.0;
NSTimer* sendLocationTimer = nil;
os_last_location *lastLocation;
bool initialLocationSent = false;
UIBackgroundTaskIdentifier fcTask;

static id locationManager = nil;
static bool started = false;
static bool hasDelayed = false;

// CoreLocation must be statically linked for geotagging to work on iOS 6 and possibly 7.
// plist NSLocationUsageDescription (iOS 6 & 7) and NSLocationWhenInUseUsageDescription (iOS 8+) keys also required.

// Suppressing undeclared selector warnings
// NSClassFromString and performSelector are used so OneSignal does not depend on CoreLocation to link the app.
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wundeclared-selector"
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"


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
+ (void)clearLastLocation {
    @synchronized(OneSignalLocation.mutexObjectForLastLocation) {
       lastLocation = nil;
    }
}

+ (void) getLocation:(bool)prompt {
    if (hasDelayed)
        [OneSignalLocation internalGetLocation:prompt];
    else {
        // Delay required for locationServicesEnabled and authorizationStatus return the correct values when CoreLocation is not statically linked.
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, 2.0 * NSEC_PER_SEC);
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void) {
            hasDelayed = true;
            [OneSignalLocation internalGetLocation:prompt];
        });
    }
    
    //Listen to app going to and from background
}

+ (void)onfocus:(BOOL)isActive {
    
    // return if the user has not granted privacy permissions
    if ([OneSignal requiresUserPrivacyConsent])
        return;
    
    if(!locationManager || !started) return;
    
    /**
     We have a state switch
     - If going to active: keep timer going
     - If going to background:
        1. Make sure that we can track background location
            -> continue timer to send location otherwise set location to nil
        Otherwise set timer to NULL
    **/
    
    
    NSTimeInterval remainingTimerTime = sendLocationTimer.fireDate.timeIntervalSinceNow;
    NSTimeInterval requiredWaitTime = isActive ? foregroundSendLocationWaitTime : backgroundSendLocationWaitTime ;
    NSTimeInterval adjustedTime = remainingTimerTime > 0 ? remainingTimerTime : requiredWaitTime;

    if(isActive) {
        if(sendLocationTimer && initialLocationSent) {
            //Keep timer going with the remaining time
            [sendLocationTimer invalidate];
            sendLocationTimer = [NSTimer scheduledTimerWithTimeInterval:adjustedTime target:self selector:@selector(sendLocation) userInfo:nil repeats:NO];
        }
    }
    else {
        
        //Check if always granted
        if( (int)[NSClassFromString(@"CLLocationManager") performSelector:@selector(authorizationStatus)] == 3) {
            [OneSignalLocation beginTask];
            [sendLocationTimer invalidate];
            sendLocationTimer = [NSTimer scheduledTimerWithTimeInterval:adjustedTime target:self selector:@selector(sendLocation) userInfo:nil repeats:NO];
            [[NSRunLoop mainRunLoop] addTimer:sendLocationTimer forMode:NSRunLoopCommonModes];
        }
        else sendLocationTimer = NULL;
    }
}

+ (void) beginTask {
    fcTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [OneSignalLocation endTask];
    }];
}

+ (void) endTask {
    [[UIApplication sharedApplication] endBackgroundTask: fcTask];
    fcTask = UIBackgroundTaskInvalid;
}



+ (void) internalGetLocation:(bool)prompt {
    if (started)
        return;
    
    id clLocationManagerClass = NSClassFromString(@"CLLocationManager");
    
    // Check for location in plist
    if (![clLocationManagerClass performSelector:@selector(locationServicesEnabled)])
        return;
    int permissionStatus = [clLocationManagerClass performSelector:@selector(authorizationStatus)];
    // return if permission not determined and should not prompt
    if (permissionStatus == 0 && !prompt)
        return;
    
    locationManager = [[clLocationManagerClass alloc] init];
    [locationManager setValue:[self sharedInstance] forKey:@"delegate"];
    
    float deviceOSVersion = [[[UIDevice currentDevice] systemVersion] floatValue];
    if (deviceOSVersion >= 8.0) {
        
        //Check info plist for request descriptions
        //LocationAlways > LocationWhenInUse > No entry (Log error)
        //Location Always requires: Location Background Mode + NSLocationAlwaysUsageDescription
        NSArray* backgroundModes = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"UIBackgroundModes"];
        NSString* alwaysDescription = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"NSLocationAlwaysUsageDescription"] ?: [[NSBundle mainBundle] objectForInfoDictionaryKey:@"NSLocationAlwaysAndWhenInUseUsageDescription"];
        // use background location updates if always permission granted or prompt allowed
        if(backgroundModes && [backgroundModes containsObject:@"location"] && alwaysDescription && (permissionStatus == 3 || prompt)) {
            [locationManager performSelector:@selector(requestAlwaysAuthorization)];
            if (deviceOSVersion >= 9.0) {
                [locationManager setValue:@YES forKey:@"allowsBackgroundLocationUpdates"];
            }
        }
        
        else if([[NSBundle mainBundle] objectForInfoDictionaryKey:@"NSLocationWhenInUseUsageDescription"]) {
            if (permissionStatus == 0) [locationManager performSelector:@selector(requestWhenInUseAuthorization)];
        }
        
        else onesignal_Log(ONE_S_LL_ERROR, @"Include a privacy NSLocationAlwaysUsageDescription or NSLocationWhenInUseUsageDescription in your info.plist to request location permissions.");
    }
    
    // iOS 6 and 7 prompts for location here.
    [locationManager performSelector:@selector(startUpdatingLocation)];
    
    
    
    started = true;
}

#pragma mark CLLocationManagerDelegate

- (void)locationManager:(id)manager didUpdateLocations:(NSArray *)locations {
    
    // return if the user has not granted privacy permissions
    if ([OneSignal requiresUserPrivacyConsent])
        return;
    
    [manager performSelector:@selector(stopUpdatingLocation)];
    
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
    
    if(!sendLocationTimer)
        [OneSignalLocation resetSendTimer];
    
    if(!initialLocationSent)
        [OneSignalLocation sendLocation];

}

-(void)locationManager:(id)manager didFailWithError:(NSError *)error {
    [OneSignal onesignal_Log:ONE_S_LL_ERROR message:[NSString stringWithFormat:@"CLLocationManager did fail with error: %@", error]];
}

+ (void)resetSendTimer {
    NSTimeInterval requiredWaitTime = [UIApplication sharedApplication].applicationState == UIApplicationStateActive ? foregroundSendLocationWaitTime : backgroundSendLocationWaitTime ;
    sendLocationTimer = [NSTimer scheduledTimerWithTimeInterval:requiredWaitTime target:self selector:@selector(sendLocation) userInfo:nil repeats:NO];
}

+ (void)sendLocation {
    
    // return if the user has not granted privacy permissions
    if ([OneSignal requiresUserPrivacyConsent])
        return;
    
    @synchronized(OneSignalLocation.mutexObjectForLastLocation) {
        if (!lastLocation || ![OneSignal mUserId]) return;
        
        //Fired from timer and not initial location fetched
        if (initialLocationSent)
            [OneSignalLocation resetSendTimer];
        
        initialLocationSent = YES;
        
        NSMutableDictionary *requests = [NSMutableDictionary new];
        
        if ([OneSignal mEmailUserId])
            requests[@"email"] = [OSRequestSendLocation withUserId:[OneSignal mEmailUserId] appId:[OneSignal app_id] location:lastLocation networkType:[OneSignalHelper getNetType] backgroundState:([UIApplication sharedApplication].applicationState != UIApplicationStateActive) emailAuthHashToken:[OneSignal mEmailAuthToken]];
        
        requests[@"push"] = [OSRequestSendLocation withUserId:[OneSignal mUserId] appId:[OneSignal app_id] location:lastLocation networkType:[OneSignalHelper getNetType] backgroundState:([UIApplication sharedApplication].applicationState != UIApplicationStateActive) emailAuthHashToken:nil];
        
        [OneSignalClient.sharedClient executeSimultaneousRequests:requests withSuccess:nil onFailure:nil];
    }
    
}


#pragma clang diagnostic pop
#pragma GCC diagnostic pop

@end
