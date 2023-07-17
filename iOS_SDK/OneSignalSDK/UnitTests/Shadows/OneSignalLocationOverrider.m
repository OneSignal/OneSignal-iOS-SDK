/**
 * Modified MIT License
 *
 * Copyright 2019 OneSignal
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

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

#import "TestHelperFunctions.h"
#import "OneSignalSelectorHelpers.h"
#import "OneSignalHelperOverrider.h"
#import "OneSignalLocationManager.h"
#import "OneSignalLocationOverrider.h"

@implementation OneSignalLocationOverrider

// BOOL to track whetehr the LocationServices prompt has been seen
bool startedMock;
// int representing the current permission status for LocationServices
int permissionStatusMock;
// BOOL to track whether or not location request was made (NSLocationAlwaysUsageDescription, NSLocationAlwaysAndWhenInUseUsageDescription)
bool calledRequestAlwaysAuthorization;
// BOOL to track whether or not location request was made (NSLocationWhenInUseUsageDescription)
bool calledRequestWhenInUseAuthorization;

// Location updates require a mocked manager and set of locations to be passed in
CLLocationManager* locationManager;
NSArray *locations;

+ (void)load {
    
    injectStaticSelector([OneSignalLocationOverrider class], @selector(overrideStarted), [OneSignalLocationManager class], @selector(started));
    injectStaticSelector([OneSignalLocationOverrider class], @selector(overrideAuthorizationStatus), [CLLocationManager class], @selector(authorizationStatus));
    
    injectSelector(
        [CLLocationManager class],
        @selector(requestAlwaysAuthorization),
        [OneSignalLocationOverrider class],
        @selector(overrideRequestAlwaysAuthorization)
    );
    injectSelector(
        [CLLocationManager class],
        @selector(requestWhenInUseAuthorization),
        [OneSignalLocationOverrider class],
        @selector(overrideRequestWhenInUseAuthorization)
    );
    injectSelector(
        [CLLocationManager class],
        @selector(startUpdatingLocation),
        [OneSignalLocationOverrider class],
        @selector(overrideStartUpdatingLocation)
   );
    
    // Never asked use for location service permission
    startedMock = false;
    // Set permission status for location services to 0 (not granted)
    permissionStatusMock = 0;
    // Never made a request for location based on info.plist params
    calledRequestAlwaysAuthorization = false;
    calledRequestWhenInUseAuthorization = false;
    
    // Create a mock location manager
    locationManager = [self createLocationManager];
    // Creater a mock array of locations
    id location = [self createLocation];
    locations = @[location];
}

+ (void)reset {
    // Reset request flags
    calledRequestAlwaysAuthorization = false;
    calledRequestWhenInUseAuthorization = false;
}

+ (bool)overrideStarted {
    return startedMock;
}

// Create a mocked location manager for use in overrider
+ (CLLocationManager*)createLocationManager {
    return [[CLLocationManager alloc] init];
}

// Create a mocked location for use in overrider
+ (CLLocation*)createLocation {
    return [[CLLocation alloc] initWithLatitude:3.0 longitude:4.0];
}

// Simulate granting location services
// The `locationManager` method is called after a user clicks the `Allow` button in the LocationServices alert because
// a location update is triggered
+ (void)grantLocationServices {
    
    // Reset started to false (never seen prompt before)
    startedMock = false;
    
    // Reset request flags
    calledRequestAlwaysAuthorization = false;
    calledRequestWhenInUseAuthorization = false;
    
    [OneSignalLocationManager internalGetLocation:true fallbackToSettings:false];
}

+ (int)overrideAuthorizationStatus {
    return permissionStatusMock;
}

- (void)overrideRequestAlwaysAuthorization {
    // Overriden to do nothing, causes a info.plist warning failing our tests
    calledRequestAlwaysAuthorization = true;
}

- (void)overrideRequestWhenInUseAuthorization {
    // Overriden to do nothing, causes a info.plist warning failing our tests
    calledRequestWhenInUseAuthorization = true;
}

- (void)overrideStartUpdatingLocation {
    // Check if the location request was made for info.plist params
    if (calledRequestAlwaysAuthorization || calledRequestWhenInUseAuthorization)
        [[OneSignalLocation sharedInstance] locationManager:locationManager didUpdateLocations:locations];
}

@end
