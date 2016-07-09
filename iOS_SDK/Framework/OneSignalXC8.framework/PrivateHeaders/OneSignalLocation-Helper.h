//
//  OneSIgnalLocation-Helper.h
//  OneSignalSwift
//
//  Created by Joseph Kalash on 6/28/16.
//  Copyright © 2016 OneSignal. All rights reserved.
//

#ifndef OneSignalLocation_h
#define OneSignalLocation_h

#import <Foundation/Foundation.h>

@interface OneSignalLocationHelper : NSObject

+ (NSNumber *)getLocationAuthorizationStatus;
+ (BOOL)getLocationServicesEnabled;
+ (id)getLocationManager;


@end

#endif
