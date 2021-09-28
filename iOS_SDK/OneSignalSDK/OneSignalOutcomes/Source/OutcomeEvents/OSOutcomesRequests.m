//
//  OSOutcomesRequests.m
//  OneSignal
//
//  Created by Elliot Mawby on 9/28/21.
//  Copyright © 2021 Hiptic. All rights reserved.
//

#import "OSOutcomesRequests.h"


@implementation OSRequestSendOutcomesV1ToServer
NSString * const APP_ID = @"app_id";
NSString * const DEVICE = @"device_type";
NSString * const OUTCOME_ID = @"id";
NSString * const WEIGHT = @"weight";
NSString * const IS_DIRECT = @"direct";
NSString * const NOTIFICATION_IDS = @"notification_ids";

+ (instancetype _Nonnull)directWithOutcome:(OSOutcomeEvent * _Nonnull)outcome
                                     appId:(NSString * _Nonnull)appId
                                deviceType:(NSNumber * _Nonnull)deviceType {
    let request = [OSRequestSendOutcomesV1ToServer new];

    let params = [NSMutableDictionary new];
    params[APP_ID] = appId;
    params[DEVICE] = deviceType;
    params[IS_DIRECT] = @YES;
    params[OUTCOME_ID] = outcome.name;

    if (outcome.notificationIds && [outcome.notificationIds count] > 0)
        params[NOTIFICATION_IDS] = outcome.notificationIds;

    if ([outcome.weight doubleValue] > 0)
        params[WEIGHT] = outcome.weight;

    request.parameters = params;
    request.method = POST;
    request.path = @"outcomes/measure";

    return request;
}

+ (instancetype _Nonnull)indirectWithOutcome:(OSOutcomeEvent * _Nonnull)outcome
                                       appId:(NSString * _Nonnull)appId
                                  deviceType:(NSNumber * _Nonnull)deviceType {
    let request = [OSRequestSendOutcomesV1ToServer new];

    let params = [NSMutableDictionary new];
    params[APP_ID] = appId;
    params[DEVICE] = deviceType;
    params[IS_DIRECT] = @NO;
    params[OUTCOME_ID] = outcome.name;

    if (outcome.notificationIds && [outcome.notificationIds count] > 0)
        params[NOTIFICATION_IDS] = outcome.notificationIds;

    if ([outcome.weight doubleValue] > 0)
        params[WEIGHT] = outcome.weight;

    request.parameters = params;
    request.method = POST;
    request.path = @"outcomes/measure";

    return request;
}

+ (instancetype _Nonnull)unattributedWithOutcome:(OSOutcomeEvent * _Nonnull)outcome
                                           appId:(NSString * _Nonnull)appId
                                      deviceType:(NSNumber * _Nonnull)deviceType {
    let request = [OSRequestSendOutcomesV1ToServer new];

    let params = [NSMutableDictionary new];
    params[APP_ID] = appId;
    params[DEVICE] = deviceType;

    params[OUTCOME_ID] = outcome.name;

    if ([outcome.weight doubleValue] > 0)
        params[WEIGHT] = outcome.weight;

    request.parameters = params;
    request.method = POST;
    request.path = @"outcomes/measure";

    return request;
}

@end

@implementation OSRequestSendOutcomesV2ToServer
NSString * const OUTCOME_SOURCE = @"source";

+ (instancetype)measureOutcomeEvent:(OSOutcomeEventParams *)outcome appId:(NSString *)appId deviceType:(NSNumber *)deviceType {
    let request = [OSRequestSendOutcomesV2ToServer new];
    
    let params = [NSMutableDictionary new];
    params[APP_ID] = appId;
    params[DEVICE] = deviceType;
    [params addEntriesFromDictionary:[outcome toDictionaryObject]];
    
    request.parameters = params;
    request.method = POST;
    request.path = @"outcomes/measure_sources";

    return request;
}
@end
