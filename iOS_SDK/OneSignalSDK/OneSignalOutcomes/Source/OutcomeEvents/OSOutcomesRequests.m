/*
 Modified MIT License

 Copyright 2021 OneSignal

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 1. The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.

 2. All copies of substantial portions of the Software may only be used in connection
 with services provided by OneSignal.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
 */

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
