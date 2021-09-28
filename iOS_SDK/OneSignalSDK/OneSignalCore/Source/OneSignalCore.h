//
//  OneSignalCore.h
//  OneSignalCore
//
//  Created by Elliot Mawby on 9/27/21.
//  Copyright © 2021 Hiptic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OneSignalUserDefaults.h"
#import "OneSignalCommonDefines.h"
#import "OSNotification.h"
#import "OSNotification+Internal.h"
#import "OSNotificationClasses.h"
#import "OneSignalLog.h"
#import "NSURL+OneSignal.h"
#import "NSString+OneSignal.h"
#import "OneSignalRequest.h"
#import "OneSignalClient.h"
#import "OneSignalCoreHelper.h"

@interface OneSignalCore : NSObject

@end
// Defines let and var in Objective-c for shorter code
// __auto_type is compatible with Xcode 8+
#if defined(__cplusplus)
#define let auto const
#else
#define let const __auto_type
#endif

#if defined(__cplusplus)
#define var auto
#else
#define var __auto_type
#endif
