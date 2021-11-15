/**
 * Modified MIT License
 *
 * Copyright 2021 OneSignal
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * 1. The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * 2. All copies of substantial portions of the Software may only be used in connection
 * with services provided by OneSignal.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

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
