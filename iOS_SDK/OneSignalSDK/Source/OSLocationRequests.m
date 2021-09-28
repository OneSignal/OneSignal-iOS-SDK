//
//  OSLocationRequests.m
//  OneSignal
//
//  Created by Elliot Mawby on 9/28/21.
//  Copyright © 2021 Hiptic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OSLocationRequests.h"

@implementation OSRequestSendLocation
+ (instancetype _Nonnull)withUserId:(NSString * _Nonnull)userId appId:(NSString * _Nonnull)appId location:(os_last_location * _Nonnull)coordinate networkType:(NSNumber * _Nonnull)netType backgroundState:(BOOL)backgroundState emailAuthHashToken:(NSString * _Nullable)emailAuthHash externalIdAuthToken:(NSString * _Nullable)externalIdAuthToken {
    return [self withUserId:userId appId:appId location:coordinate networkType:netType backgroundState:backgroundState authHashToken:emailAuthHash authHashTokenKey:@"email_auth_hash" externalIdAuthToken:externalIdAuthToken];
}

+ (instancetype)withUserId:(NSString *)userId appId:(NSString *)appId location:(os_last_location *)coordinate networkType:(NSNumber *)netType backgroundState:(BOOL)backgroundState smsAuthHashToken:(NSString *)smsAuthHash externalIdAuthToken:(NSString *)externalIdAuthToken {
    return [self withUserId:userId appId:appId location:coordinate networkType:netType backgroundState:backgroundState authHashToken:smsAuthHash authHashTokenKey:@"sms_auth_hash" externalIdAuthToken:externalIdAuthToken];
}

+ (instancetype)withUserId:(NSString *)userId appId:(NSString *)appId location:(os_last_location *)coordinate networkType:(NSNumber *)netType backgroundState:(BOOL)backgroundState authHashToken:(NSString *)authHashToken authHashTokenKey:(NSString *)authHashKey externalIdAuthToken:(NSString *)externalIdAuthToken {
    let request = [OSRequestSendLocation new];

    let params = [NSMutableDictionary new];
    params[@"app_id"] = appId;
    params[@"lat"] = @(coordinate->cords.latitude);
    params[@"long"] = @(coordinate->cords.longitude);
    params[@"loc_acc_vert"] = @(coordinate->verticalAccuracy);
    params[@"loc_acc"] = @(coordinate->horizontalAccuracy);
    params[@"net_type"] = netType;
    params[@"loc_bg"] = @(backgroundState);

    if (authHashToken && authHashToken.length > 0 && authHashKey)
        params[authHashKey] = authHashToken;

    if (externalIdAuthToken && externalIdAuthToken.length > 0)
        params[@"external_user_id_auth_hash"] = externalIdAuthToken;

    request.parameters = params;
    request.method = PUT;
    request.path = [NSString stringWithFormat:@"players/%@", userId];

    return request;
}
@end
