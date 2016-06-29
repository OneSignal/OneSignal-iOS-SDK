//
//  OneSIgnalLocation-Helper.m
//  OneSignalSwift
//
//  Created by Joseph Kalash on 6/28/16.
//  Copyright © 2016 Joseph Kalash. All rights reserved.
//

#import "OneSignalLocation-Helper.h"
#import <CoreLocation/CoreLocation.h>

@implementation OneSignalLocationHelper

// Suppressing undeclared selector warnings
// NSClassFromString and performSelector are used so OneSignal does not depend on CoreLocation to link the app.
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wundeclared-selector"
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"

+(NSNumber*)getLocationAuthorizationStatus {
    id clLocationManagerClass = NSClassFromString(@"CLLocationManager");
    return [NSNumber numberWithInt:(int)[clLocationManagerClass performSelector:@selector(authorizationStatus)]];
}
+(BOOL)getLocationServicesEnabled {
        id clLocationManagerClass = NSClassFromString(@"CLLocationManager");
    return [clLocationManagerClass performSelector:@selector(locationServicesEnabled)];
}

+(id)getLocationManager {
    return [[NSClassFromString(@"CLLocationManager") alloc] init];
}

#pragma clang diagnostic pop
#pragma GCC diagnostic pop

@end
