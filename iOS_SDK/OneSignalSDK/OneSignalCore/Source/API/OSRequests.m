/**
 * Modified MIT License
 *
 * Copyright 2017 OneSignal
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
#import "OSRequests.h"
#import "OneSignalRequest.h"
#import "OneSignalCommonDefines.h"
#import "OSMacros.h"
#import "OneSignalCoreHelper.h"
#import "OneSignalLog.h"
#import <stdlib.h>
#import <stdio.h>
#import <sys/types.h>
#import <sys/utsname.h>
#import <sys/sysctl.h>

// SUBCLASSES - These subclasses each represent an individual request

/*
     NOTE: The OSRequestGetIosParams request will not return a Cache-Control header
     this means that, by default, NSURLSession would cache the result
     Since we do not want the parameters to be cached, we explicitly
     disable this behavior using disableLocalCaching
 */
@implementation OSRequestGetIosParams
+ (instancetype)withUserId:(NSString *)userId appId:(NSString *)appId {
    let request = [OSRequestGetIosParams new];
    
    if (userId) {
        request.parameters = @{@"player_id" : userId};
    }
    
    request.method = GET;
    request.path = [NSString stringWithFormat:@"apps/%@/ios_params.js", appId];
    request.disableLocalCaching = true;
    
    return request;
}
@end

@implementation OSRequestPostNotification
+ (instancetype)withAppId:(NSString *)appId withJson:(NSMutableDictionary *)json {
    let request = [OSRequestPostNotification new];
    if (!json[@"app_id"]) {
        json[@"app_id"] = appId;
    }
    
    request.parameters = json;
    request.method = POST;
    request.path = @"notifications";
    
    return request;
}
@end

@implementation OSRequestSubmitNotificationOpened
+ (instancetype)withUserId:(NSString *)userId appId:(NSString *)appId wasOpened:(BOOL)opened messageId:(NSString *)messageId withDeviceType:(nonnull NSNumber *)deviceType{
    let request = [OSRequestSubmitNotificationOpened new];
    
    request.parameters = @{@"player_id" : userId ?: [NSNull null], @"app_id" : appId ?: [NSNull null], @"opened" : @(opened), @"device_type": deviceType};
    request.method = PUT;
    request.path = [NSString stringWithFormat:@"notifications/%@", messageId];
    
    return request;
}
@end

@implementation OSRequestTrackV1
NSString * const OS_USAGE_DATA = @"OS-Usage-Data";
+ (instancetype)trackUsageData:(NSString *)osUsageData appId:(NSString *)appId {
    let request = [OSRequestTrackV1 new];
    let params = [NSMutableDictionary new];
    let headers = [NSMutableDictionary new];
    params[@"app_id"] = appId;
    headers[@"app_id"] = appId;
    headers[OS_USAGE_DATA] = osUsageData;
    request.method = POST;
    request.path = @"v1/track";
    request.parameters = params;
    request.additionalHeaders = headers;
    return request;
}
@end

@implementation OSRequestLiveActivityEnter
+ (instancetype)withSubscriptionId:(NSString * _Nonnull)subscriptionId
                     appId:(NSString * _Nonnull)appId
                activityId:(NSString * _Nonnull)activityId
                     token:(NSString * _Nonnull)token {
    let request = [OSRequestLiveActivityEnter new];
    let params = [NSMutableDictionary new];
    params[@"push_token"] = token;
    params[@"subscription_id"] = subscriptionId; // pre-5.X.X subscription_id = player_id = userId
    params[@"device_type"] = @0;
    request.parameters = params;
    request.method = POST;
    
    NSString *urlSafeActivityId = [activityId stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLUserAllowedCharacterSet]];
    
    request.path = [NSString stringWithFormat:@"apps/%@/live_activities/%@/token", appId, urlSafeActivityId];
    return request;
}
@end

@implementation OSRequestLiveActivityExit
+ (instancetype)withSubscriptionId:(NSString * _Nonnull)subscriptionId
                     appId:(NSString * _Nonnull)appId
                activityId:(NSString * _Nonnull)activityId {
    let request = [OSRequestLiveActivityExit new];
    request.method = DELETE;
    
    NSString *urlSafeActivityId = [activityId stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLUserAllowedCharacterSet]];
    
    request.path = [NSString stringWithFormat:@"apps/%@/live_activities/%@/token/%@", appId, urlSafeActivityId, subscriptionId];
    
    return request;
}
@end
