//
//  OneSignalLog.m
//  OneSignalCore
//
//  Created by Elliot Mawby on 9/27/21.
//  Copyright © 2021 Hiptic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OneSignalLog.h"

@implementation OneSignalLog

static ONE_S_LOG_LEVEL _nsLogLevel = ONE_S_LL_WARN;
static ONE_S_LOG_LEVEL _visualLogLevel = ONE_S_LL_NONE;

+ (void)setLogLevel:(ONE_S_LOG_LEVEL)nsLogLevel visualLevel:(ONE_S_LOG_LEVEL)visualLogLevel {
    _nsLogLevel = nsLogLevel; _visualLogLevel = visualLogLevel;
}

+ (void) onesignal_Log:(ONE_S_LOG_LEVEL)logLevel message:(NSString*) message {
    onesignal_Log(logLevel, message);
}

+ (void)onesignalLog:(ONE_S_LOG_LEVEL)logLevel message:(NSString* _Nonnull)message {
    onesignal_Log(logLevel, message);
}

void onesignal_Log(ONE_S_LOG_LEVEL logLevel, NSString* message) {
    NSString* levelString;
    switch (logLevel) {
        case ONE_S_LL_FATAL:
            levelString = @"FATAL: ";
            break;
        case ONE_S_LL_ERROR:
            levelString = @"ERROR: ";
            break;
        case ONE_S_LL_WARN:
            levelString = @"WARNING: ";
            break;
        case ONE_S_LL_INFO:
            levelString = @"INFO: ";
            break;
        case ONE_S_LL_DEBUG:
            levelString = @"DEBUG: ";
            break;
        case ONE_S_LL_VERBOSE:
            levelString = @"VERBOSE: ";
            break;
            
        default:
            break;
    }

    if (logLevel <= _nsLogLevel)
        NSLog(@"%@", [levelString stringByAppendingString:message]);
    
    // ECM TODO: Do we want to support visual level?
}

@end

