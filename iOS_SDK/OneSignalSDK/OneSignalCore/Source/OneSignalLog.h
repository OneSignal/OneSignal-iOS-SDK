//
//  OneSignalLog.h
//  OneSignalCore
//
//  Created by Elliot Mawby on 9/27/21.
//  Copyright © 2021 Hiptic. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface OneSignalLog : NSObject
#pragma mark Logging
typedef NS_ENUM(NSUInteger, ONE_S_LOG_LEVEL) {
    ONE_S_LL_NONE,
    ONE_S_LL_FATAL,
    ONE_S_LL_ERROR,
    ONE_S_LL_WARN,
    ONE_S_LL_INFO,
    ONE_S_LL_DEBUG,
    ONE_S_LL_VERBOSE
};

+ (void)setLogLevel:(ONE_S_LOG_LEVEL)logLevel visualLevel:(ONE_S_LOG_LEVEL)visualLogLevel;
+ (void)onesignalLog:(ONE_S_LOG_LEVEL)logLevel message:(NSString* _Nonnull)message;

@end
