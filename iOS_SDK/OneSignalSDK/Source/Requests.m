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

-(BOOL)missingAppId {
    return false; //this request doesn't have an app ID parameter
}
@end

@implementation OSRequestSendTagsToServer
+ (instancetype _Nonnull)withUserId:(NSString * _Nonnull)userId appId:(NSString * _Nonnull)appId tags:(NSDictionary * _Nonnull)tags networkType:(NSNumber * _Nonnull)netType withEmailAuthHashToken:(NSString * _Nullable)emailAuthToken {
    let request = [OSRequestSendTagsToServer new];
    
    let params = [NSMutableDictionary new];
    params[@"app_id"] = appId;
    params[@"tags"] = tags;
    params[@"net_type"] = netType;
    
    if (emailAuthToken && emailAuthToken.length > 0)
        params[@"email_auth_hash"] = emailAuthToken;
    
    request.parameters = params;
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
+ (instancetype _Nonnull)withUserId:(NSString * _Nonnull)userId appId:(NSString * _Nonnull)appId deviceToken:(NSString * _Nullable)identifier notificationTypes:(NSNumber * _Nullable)notificationTypes withParentId:(NSString * _Nullable)parentId emailAuthToken:(NSString * _Nullable)emailAuthHash email:(NSString * _Nullable)email {
    
    let request = [OSRequestUpdateDeviceToken new];
    
    let params = [NSMutableDictionary new];
    params[@"app_id"] = appId;
    params[@"email"] = email;
    
    if (notificationTypes)
        params[@"notification_types"] = notificationTypes;
    
    if (identifier)
        params[@"identifier"] = identifier;
    
    if (parentId)
        params[@"parent_player_id"] = parentId;
    
    if (emailAuthHash && emailAuthHash.length > 0)
        params[@"email_auth_hash"] = emailAuthHash;
    
    request.parameters = params;
    request.method = PUT;
    request.path = [NSString stringWithFormat:@"players/%@", userId];
    
    return request;
}
@end

@implementation OSRequestCreateDevice
+ (instancetype _Nonnull)withAppId:(NSString * _Nonnull)appId withDeviceType:(NSNumber * _Nonnull)deviceType withEmail:(NSString * _Nullable)email withPlayerId:(NSString * _Nullable)playerId withEmailAuthHash:(NSString * _Nullable)emailAuthHash {
    let request = [OSRequestCreateDevice new];
    
    request.parameters = @{
       @"app_id" : appId,
       @"device_type" : deviceType,
       @"identifier" : email ?: [NSNull null],
       @"email_auth_hash" : emailAuthHash ?: [NSNull null],
       @"device_player_id" : playerId ?: [NSNull null]
    };
    
    request.method = POST;
    request.path = @"players";
    
    return request;
}
@end

@implementation OSRequestLogoutEmail

+ (instancetype _Nonnull)withAppId:(NSString * _Nonnull)appId emailPlayerId:(NSString * _Nonnull)emailPlayerId devicePlayerId:(NSString * _Nonnull)devicePlayerId emailAuthHash:(NSString * _Nullable)emailAuthHash {
    let request = [OSRequestLogoutEmail new];
    
    request.parameters = @{
       @"parent_player_id" : emailPlayerId ?: [NSNull null],
       @"email_auth_hash" : emailAuthHash ?: [NSNull null],
       @"app_id" : appId
    };
    
    request.method = POST;
    request.path = [NSString stringWithFormat:@"players/%@/email_logout", devicePlayerId];
    
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
    request.path = [NSString stringWithFormat:@"players/%@/on_purchase", userId];
    
    return request;
}

+ (instancetype)withUserId:(NSString *)userId emailAuthToken:(NSString *)emailAuthToken appId:(NSString *)appId withPurchases:(NSArray *)purchases {
    let request = [OSRequestSendPurchases new];
    
    request.parameters = @{@"app_id" : appId, @"purchases" : purchases, @"email_auth_hash" : emailAuthToken ?: [NSNull null]};
    request.method = POST;
    request.path = [NSString stringWithFormat:@"players/%@/on_purchase", userId];
    
    return request;
}
@end

@implementation OSRequestSubmitNotificationOpened
+ (instancetype)withUserId:(NSString *)userId appId:(NSString *)appId wasOpened:(BOOL)opened messageId:(NSString *)messageId {
    let request = [OSRequestSubmitNotificationOpened new];
    
    request.parameters = @{@"player_id" : userId ?: [NSNull null], @"app_id" : appId ?: [NSNull null], @"opened" : @(opened)};
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
+ (instancetype _Nonnull)withUserId:(NSString * _Nonnull)userId appId:(NSString * _Nonnull)appId location:(os_last_location * _Nonnull)coordinate networkType:(NSNumber * _Nonnull)netType backgroundState:(BOOL)backgroundState emailAuthHashToken:(NSString * _Nullable)emailAuthHash {
    let request = [OSRequestSendLocation new];
    
    let params = [NSMutableDictionary new];
    params[@"app_id"] = appId;
    params[@"lat"] = @(coordinate->cords.latitude);
    params[@"long"] = @(coordinate->cords.longitude);
    params[@"loc_acc_vert"] = @(coordinate->verticalAccuracy);
    params[@"loc_acc"] = @(coordinate->horizontalAccuracy);
    params[@"net_type"] = netType;
    params[@"loc_bg"] = @(backgroundState);

    if (emailAuthHash && emailAuthHash.length > 0)
        params[@"email_auth_hash"] = emailAuthHash;
    
    request.parameters = params;
    request.method = PUT;
    request.path = [NSString stringWithFormat:@"players/%@", userId];
    
    return request;
}
@end

@implementation OSRequestOnFocus
+ (instancetype _Nonnull)withUserId:(NSString * _Nonnull)userId appId:(NSString * _Nonnull)appId badgeCount:(NSNumber * _Nonnull)badgeCount emailAuthToken:(NSString * _Nullable)emailAuthHash {
    let request = [OSRequestOnFocus new];
    
    let params = [NSMutableDictionary new];
    params[@"app_id"] = appId;
    params[@"badgeCount"] = badgeCount;
    
    if (emailAuthHash && emailAuthHash.length > 0)
        params[@"email_auth_hash"] = emailAuthHash;
    
    request.parameters = params;
    request.method = PUT;
    request.path = [NSString stringWithFormat:@"players/%@", userId];
    
    return request;
}

+ (instancetype _Nonnull)withUserId:(NSString * _Nonnull)userId appId:(NSString * _Nonnull)appId state:(NSString * _Nonnull)state type:(NSNumber * _Nonnull)type activeTime:(NSNumber * _Nonnull)activeTime netType:(NSNumber * _Nonnull)netType emailAuthToken:(NSString * _Nullable)emailAuthHash {
    let request = [OSRequestOnFocus new];
    
    
    let params = [NSMutableDictionary new];
    params[@"app_id"] = appId;
    params[@"state"] = state;
    params[@"type"] = type;
    params[@"active_time"] = activeTime;
    params[@"net_type"] = netType;
    
    if (emailAuthHash && emailAuthHash.length > 0)
        params[@"email_auth_hash"] = emailAuthHash;
    
    request.parameters = params;
    request.method = POST;
    request.path = [NSString stringWithFormat:@"players/%@/on_focus", userId];
    
    return request;
}
@end
