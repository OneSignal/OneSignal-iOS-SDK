//
//  OSStubLocation.m
//  OneSignalCore
//
//  Created by Elliot Mawby on 6/21/23.
//  Copyright © 2023 Hiptic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OneSignalLog.h"
#import "OSLocation.h"

@implementation OSStubLocation

+ (Class<OSLocation>)Location {
    return self;
}

+ (BOOL)isShared {
    [OneSignalLog onesignalLog:ONE_S_LL_ERROR message:@"OneSignalLocation not found. In order to use OneSignal's location features the OneSignalLocation module must be added."];
    return false;
}

+ (void)requestPermission {
    [OneSignalLog onesignalLog:ONE_S_LL_ERROR message:@"OneSignalLocation not found. In order to use OneSignal's location features the OneSignalLocation module must be added."];
}

+ (void)setShared:(BOOL)enable {
    [OneSignalLog onesignalLog:ONE_S_LL_ERROR message:@"OneSignalLocation not found. In order to use OneSignal's location features the OneSignalLocation module must be added."];
}

@end
