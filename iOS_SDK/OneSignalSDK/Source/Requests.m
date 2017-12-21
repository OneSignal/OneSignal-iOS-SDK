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
#import "Requests.h"
#import "OneSignalRequest.h"
#import "OneSignalHelper.h"
#import <stdlib.h>
#import <stdio.h>
#import <sys/types.h>
#import <sys/utsname.h>
#import <sys/sysctl.h>

// SUBCLASSES - These subclasses each represent an individual request
@implementation OSRequestGetTags
+ (instancetype)withUserId:(NSString *)userId appId:(NSString *)appId {
    let request = [OSRequestGetTags new];
    
    request.parameters = @{@"app_id" : appId};
    request.method = GET;
    request.path = [NSString stringWithFormat:@"players/%@", userId];
    
    return request;
}
@end

@implementation OSRequestGetIosParams
+ (instancetype)withUserId:(NSString *)userId appId:(NSString *)appId {
    let request = [OSRequestGetIosParams new];
    
    if (userId) {
        request.parameters = @{@"player_id" : userId};
    }
    
    request.method = GET;
    request.path = [NSString stringWithFormat:@"apps/%@/ios_params.js", appId];
    
    return request;
}
@end

@implementation OSRequestSendTagsToServer
+ (instancetype)withUserId:(NSString *)userId appId:(NSString *)appId tags:(NSDictionary *)tags networkType:(NSNumber *)netType {
    let request = [OSRequestSendTagsToServer new];
    
    request.parameters = @{@"app_id" : appId, @"tags" : tags, @"net_type" : netType};
    request.method = PUT;
    request.path = [NSString stringWithFormat:@"players/%@", userId];
    
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

@implementation OSRequestUpdateDeviceToken
+ (instancetype)withUserId:(NSString *)userId appId:(NSString *)appId deviceToken:(NSString *)identifier notificationTypes:(NSNumber *)notificationTypes {
    let request = [OSRequestUpdateDeviceToken new];
    
    request.parameters = @{
                           @"app_id" : appId,
                           @"identifier" : identifier,
                           @"notification_types" : notificationTypes
                           };
    
    request.method = PUT;
    request.path = [NSString stringWithFormat:@"players/%@", userId];
    
    return request;
}
@end


@implementation OSRequestUpdateNotificationTypes
+ (instancetype)withUserId:(NSString *)userId appId:(NSString *)appId notificationTypes:(NSNumber *)notificationTypes {
    let request = [OSRequestUpdateNotificationTypes new];
    
    request.parameters = @{@"app_id" : appId, @"notification_types" : notificationTypes};
    request.method = PUT;
    request.path = [NSString stringWithFormat:@"players/%@", userId];
    
    return request;
}
@end

@implementation OSRequestSendPurchases
+ (instancetype)withUserId:(NSString *)userId appId:(NSString *)appId withPurchases:(NSArray *)purchases {
    let request = [OSRequestSendPurchases new];
    
    request.parameters = @{@"app_id" : appId, @"purchases" : purchases};
    request.method = POST;
    request.path = [NSString stringWithFormat:@"players/%@/on_purchase", purchases];
    
    return request;
}
@end

@implementation OSRequestSubmitNotificationOpened
+ (instancetype)withUserId:(NSString *)userId appId:(NSString *)appId wasOpened:(BOOL)opened messageId:(NSString *)messageId {
    let request = [OSRequestSubmitNotificationOpened new];
    
    request.parameters = @{@"player_id" : userId, @"app_id" : appId, @"opened" : @(opened)};
    request.method = PUT;
    request.path = [NSString stringWithFormat:@"notifications/%@", messageId];
    
    return request;
}
@end

@implementation OSRequestRegisterUser
+ (instancetype _Nonnull)withData:(NSDictionary * _Nonnull)registrationData userId:(NSString * _Nullable)userId {
    
    let request = [OSRequestRegisterUser new];
    
    request.parameters = registrationData;
    request.method = POST;
    request.path = userId ? [NSString stringWithFormat:@"players/%@/on_session", userId] : @"players";
    
    return request;
}
@end

@implementation OSRequestSyncHashedEmail
+ (instancetype)withUserId:(NSString *)userId appId:(NSString *)appId email:(NSString *)email networkType:(NSNumber *)netType {
    let request = [OSRequestSyncHashedEmail new];
    
    let lowerCase = [email lowercaseString];
    let md5Hash = [OneSignalHelper hashUsingMD5:lowerCase];
    let sha1Hash = [OneSignalHelper hashUsingSha1:lowerCase];
    
    [OneSignal onesignal_Log:ONE_S_LL_DEBUG message:[NSString stringWithFormat:@"%@ - MD5: %@, SHA1:%@", lowerCase, md5Hash, sha1Hash]];
    
    request.parameters = @{@"app_id" : appId, @"em_m" : md5Hash, @"em_s" : sha1Hash, @"net_type" : netType};
    request.method = PUT;
    request.path = [NSString stringWithFormat:@"players/%@", userId];
    
    return request;
}
@end

@implementation OSRequestSendLocation
+ (instancetype)withUserId:(NSString *)userId appId:(NSString *)appId location:(os_last_location *)coordinate networkType:(NSNumber *)netType backgroundState:(BOOL)backgroundState {
    let request = [OSRequestSendLocation new];
    
    request.parameters = @{@"app_id" : appId, @"lat" : @(coordinate->cords.latitude), @"long" : @(coordinate->cords.longitude), @"loc_acc_vert" : @(coordinate->verticalAccuracy), @"loc_acc" : @(coordinate->horizontalAccuracy), @"net_type" : netType, @"loc_bg" : @(backgroundState)};
    request.method = PUT;
    request.path = [NSString stringWithFormat:@"players/%@", userId];
    
    return request;
}
@end

@implementation OSRequestOnFocus
+ (instancetype)withUserId:(NSString *)userId appId:(NSString *)appId badgeCount:(NSNumber *)badgeCount {
    let request = [OSRequestOnFocus new];
    
    request.parameters = @{@"app_id" : appId, @"badge_count" : badgeCount};
    request.method = PUT;
    request.path = [NSString stringWithFormat:@"players/%@", userId];
    
    return request;
}

+ (instancetype)withUserId:(NSString *)userId appId:(NSString *)appId state:(NSString *)state type:(NSNumber *)type activeTime:(NSNumber *)activeTime netType:(NSNumber *)netType {
    let request = [OSRequestOnFocus new];
    
    request.parameters = @{@"app_id" : appId, @"state" : state, @"type" : type, @"active_time" : activeTime, @"net_type" : netType};
    request.method = POST;
    request.path = [NSString stringWithFormat:@"players/%@/on_focus", userId];
    
    return request;
}
@end
