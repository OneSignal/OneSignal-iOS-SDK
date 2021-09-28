//
//  OSFocusRequests.m
//  OneSignal
//
//  Created by Elliot Mawby on 9/28/21.
//  Copyright © 2021 Hiptic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OSFocusRequests.h"

@implementation OSRequestOnFocus

+ (instancetype)withUserId:(NSString *)userId
                     appId:(NSString *)appId
                activeTime:(NSNumber *)activeTime
                   netType:(NSNumber *)netType
                deviceType:(NSNumber *)deviceType
           influenceParams:(NSArray <OSFocusInfluenceParam *> *)influenceParams {
    let request = [OSRequestOnFocus new];

    let params = [NSMutableDictionary new];
    params[@"app_id"] = appId;
    params[@"state"] = @"ping";
    params[@"type"] = @1;
    params[@"active_time"] = activeTime;
    params[@"net_type"] = netType;
    params[@"device_type"] = deviceType;

    if (influenceParams) {
        for (OSFocusInfluenceParam *influenceParam in influenceParams) {
            params[influenceParam.influenceKey] = influenceParam.influenceIds;
            params[influenceParam.influenceDirectKey] = @(influenceParam.directInfluence);
        }
    }

    request.parameters = params;
    request.method = POST;
    request.path = [NSString stringWithFormat:@"players/%@/on_focus", userId];

    return request;
}
@end
