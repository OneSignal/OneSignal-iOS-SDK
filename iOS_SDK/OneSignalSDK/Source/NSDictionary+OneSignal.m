//
//  NSDictionary+OneSignal.m
//  OneSignal
//
//  Created by Brad Hesse on 9/26/18.
//  Copyright © 2018 Hiptic. All rights reserved.
//

#import "NSDictionary+OneSignal.h"

@implementation NSDictionary (OneSignal)

// Prevent the OSNotification blocks from firing if we receive a Non-OneSignal remote push
- (BOOL)isOneSignalPayload {
    return self[@"custom"][@"i"] || self[@"os_data"][@"i"];
}

@end
