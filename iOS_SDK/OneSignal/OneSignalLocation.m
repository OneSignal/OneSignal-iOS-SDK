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

#import "OneSignalLocation.h"

@implementation OneSignalLocation

static id locationManager;
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

+ (void) getLocation:(id)delegate prompt:(bool)prompt {
    if (hasDelayed)
        [OneSignalLocation internalGetLocation:delegate prompt:prompt];
    else {
        // Delay required for locationServicesEnabled and authorizationStatus return the correct values when CoreLocation is not staticly linked.
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, 2.0 * NSEC_PER_SEC);
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void) {
            hasDelayed = true;
            [OneSignalLocation internalGetLocation:delegate prompt:prompt];
        });
    }
}

+ (void) internalGetLocation:(id)delegate prompt:(bool)prompt {
    if (started)
        return;
    
    id clLocationManagerClass = NSClassFromString(@"CLLocationManager");
    
    // Check for location in plist
    if (![clLocationManagerClass performSelector:@selector(locationServicesEnabled)])
        return;
    
    if ([clLocationManagerClass performSelector:@selector(authorizationStatus)] == 0 && !prompt)
        return;
    
    locationManager = [[clLocationManagerClass alloc] init];
    [locationManager setValue:delegate forKey:@"delegate"];
    //locationManager.distanceFilter = kCLDistanceFilterNone;
    //locationManager.desiredAccuracy = kCLLocationAccuracyBest;
    
    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 8.0)
        [locationManager performSelector:@selector(requestWhenInUseAuthorization)];
    
    // iOS 6 and 7 prompts for location here.
    [locationManager performSelector:@selector(startUpdatingLocation)];
    
    started = true;
}

#pragma clang diagnostic pop
#pragma GCC diagnostic pop

@end
