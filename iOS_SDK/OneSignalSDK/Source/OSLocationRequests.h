//
//  OSLocationRequests.h
//  OneSignal
//
//  Created by Elliot Mawby on 9/28/21.
//  Copyright © 2021 Hiptic. All rights reserved.
//
#import <OneSignalCore/OneSignalCore.h>
#import "OneSignalLocation.h"

@interface OSRequestSendLocation : OneSignalRequest
+ (instancetype _Nonnull)withUserId:(NSString * _Nonnull)userId appId:(NSString * _Nonnull)appId location:(os_last_location * _Nonnull)coordinate networkType:(NSNumber * _Nonnull)netType backgroundState:(BOOL)backgroundState emailAuthHashToken:(NSString * _Nullable)emailAuthHash externalIdAuthToken:(NSString * _Nullable)externalIdAuthToken;

+ (instancetype _Nonnull)withUserId:(NSString * _Nonnull)userId appId:(NSString * _Nonnull)appId location:(os_last_location * _Nonnull)coordinate networkType:(NSNumber * _Nonnull)netType backgroundState:(BOOL)backgroundState smsAuthHashToken:(NSString * _Nullable)smsAuthHash externalIdAuthToken:(NSString * _Nullable)externalIdAuthToken;
@end
