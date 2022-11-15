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
@implementation OSRequestGetTags
+ (instancetype)withUserId:(NSString *)userId appId:(NSString *)appId {
    let request = [OSRequestGetTags new];
    
    request.parameters = @{@"app_id" : appId};
    request.method = GET;
    request.path = [NSString stringWithFormat:@"players/%@", userId];
    request.disableLocalCaching = true;
    
    return request;
}
@end

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

-(BOOL)missingAppId {
    return false; //this request doesn't have an app ID parameter
}
@end

@implementation OSRequestSendTagsToServer
+ (instancetype _Nonnull)withUserId:(NSString * _Nonnull)userId appId:(NSString * _Nonnull)appId tags:(NSDictionary * _Nonnull)tags networkType:(NSNumber * _Nonnull)netType withEmailAuthHashToken:(NSString * _Nullable)emailAuthToken withExternalIdAuthHashToken:(NSString * _Nullable)externalIdAuthToken {
    return [self withUserId:userId appId:appId tags:tags networkType:netType withAuthHashToken:emailAuthToken withAuthTokenKey:@"email_auth_hash" withExternalIdAuthHashToken:externalIdAuthToken];
}

+ (instancetype)withUserId:(NSString *)userId appId:(NSString *)appId tags:(NSDictionary *)tags networkType:(NSNumber *)netType withSMSAuthHashToken:(NSString *)smsAuthToken withExternalIdAuthHashToken:(NSString *)externalIdAuthToken {
    return [self withUserId:userId appId:appId tags:tags networkType:netType withAuthHashToken:smsAuthToken withAuthTokenKey:@"sms_auth_hash" withExternalIdAuthHashToken:externalIdAuthToken];
}

+ (instancetype)withUserId:(NSString *)userId appId:(NSString *)appId tags:(NSDictionary *)tags networkType:(NSNumber *)netType withAuthHashToken:(NSString *)authToken withAuthTokenKey:(NSString *)authTokenKey withExternalIdAuthHashToken:(NSString *)externalIdAuthToken {
    let request = [OSRequestSendTagsToServer new];
    
    let params = [NSMutableDictionary new];
    params[@"app_id"] = appId;
    params[@"tags"] = tags;
    params[@"net_type"] = netType;
    
    if (authToken && authToken.length > 0)
        params[authTokenKey] = authToken;
    
    if (externalIdAuthToken && externalIdAuthToken.length > 0)
        params[@"external_user_id_auth_hash"] = externalIdAuthToken;
    
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
+ (instancetype _Nonnull)withUserId:(NSString * _Nonnull)userId appId:(NSString * _Nonnull)appId deviceToken:(NSString * _Nullable)identifier notificationTypes:(NSNumber * _Nullable)notificationTypes externalIdAuthToken:(NSString * _Nullable)externalIdAuthToken {
    
    let request = [OSRequestUpdateDeviceToken new];
    
    let params = [NSMutableDictionary new];
    params[@"app_id"] = appId;
   
    if (notificationTypes)
        params[@"notification_types"] = notificationTypes;
    
    if (identifier)
        params[@"identifier"] = identifier;
    
    if (externalIdAuthToken && externalIdAuthToken.length > 0)
        params[@"external_user_id_auth_hash"] = externalIdAuthToken;
    
    request.parameters = params;
    request.method = PUT;
    request.path = [NSString stringWithFormat:@"players/%@", userId];
    
    return request;
}

+ (instancetype)withUserId:(NSString *)userId appId:(NSString *)appId deviceToken:(NSString *)identifier withParentId:(NSString *)parentId emailAuthToken:(NSString *)emailAuthHash email:(NSString *)email externalIdAuthToken:(NSString *)externalIdAuthToken {
    let request = [OSRequestUpdateDeviceToken new];
    
    let params = [NSMutableDictionary new];
    params[@"app_id"] = appId;
    
    if (email)
        params[@"email"] = email;
    
    if (identifier)
        params[@"identifier"] = identifier;
    
    if (parentId)
        params[@"parent_player_id"] = parentId;
    
    if (emailAuthHash && emailAuthHash.length > 0)
        params[@"email_auth_hash"] = emailAuthHash;
    
    if (externalIdAuthToken && externalIdAuthToken.length > 0)
        params[@"external_user_id_auth_hash"] = externalIdAuthToken;
    
    request.parameters = params;
    request.method = PUT;
    request.path = [NSString stringWithFormat:@"players/%@", userId];
    
    return request;
}

+ (instancetype)withUserId:(NSString *)userId appId:(NSString *)appId deviceToken:(NSString *)identifier smsAuthToken:(NSString *)smsAuthToken externalIdAuthToken:(NSString *)externalIdAuthToken {
    let request = [OSRequestUpdateDeviceToken new];
    
    let params = [NSMutableDictionary new];
    params[@"app_id"] = appId;

    if (identifier)
        params[@"identifier"] = identifier;
    
    if (smsAuthToken && smsAuthToken.length > 0)
        params[SMS_NUMBER_AUTH_HASH_KEY] = smsAuthToken;
    
    if (externalIdAuthToken && externalIdAuthToken.length > 0)
        params[@"external_user_id_auth_hash"] = externalIdAuthToken;
    
    request.parameters = params;
    request.method = PUT;
    request.path = [NSString stringWithFormat:@"players/%@", userId];
    
    return request;
}
@end

@implementation OSRequestCreateDevice
+ (instancetype _Nonnull)withAppId:(NSString * _Nonnull)appId withDeviceType:(NSNumber * _Nonnull)deviceType withEmail:(NSString * _Nullable)email withPlayerId:(NSString * _Nullable)playerId withEmailAuthHash:(NSString * _Nullable)emailAuthHash withExternalUserId: (NSString * _Nullable)externalUserId withExternalIdAuthToken:(NSString * _Nullable)externalIdAuthToken {
    let request = [OSRequestCreateDevice new];
    
    let params = [[NSMutableDictionary alloc] initWithDictionary:@{
        @"app_id" : appId,
        @"device_type" : deviceType,
        @"identifier" : email ?: [NSNull null],
        @"email_auth_hash" : emailAuthHash ?: [NSNull null],
        @"external_user_id_auth_hash" : externalIdAuthToken ?: [NSNull null],
        @"device_player_id" : playerId ?: [NSNull null]
     }];
    
    if (externalUserId) {
        params[@"external_user_id"] = externalUserId;
    }
    request.parameters = params;
    request.method = POST;
    request.path = @"players";
    
    return request;
}

+ (instancetype)withAppId:(NSString *)appId withDeviceType:(NSNumber *)deviceType withSMSNumber:(NSString *)smsNumber withPlayerId:(NSString *)playerId withSMSAuthHash:(NSString *)smsAuthHash withExternalUserId: (NSString * _Nullable)externalUserId withExternalIdAuthToken:(NSString *)externalIdAuthToken {
    let request = [OSRequestCreateDevice new];
    
    let params = [[NSMutableDictionary alloc] initWithDictionary:@{
           @"app_id" : appId,
           @"device_type" : deviceType,
           @"identifier" : smsNumber ?: [NSNull null],
           SMS_NUMBER_AUTH_HASH_KEY : smsAuthHash ?: [NSNull null],
           @"external_user_id_auth_hash" : externalIdAuthToken ?: [NSNull null],
           @"device_player_id" : playerId ?: [NSNull null]
        }];
    
    if (externalUserId) {
        params[@"external_user_id"] = externalUserId;
    }
    
    request.parameters = params;
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
+ (instancetype)withUserId:(NSString *)userId externalIdAuthToken:(NSString * _Nullable)externalIdAuthToken appId:(NSString *)appId withPurchases:(NSArray *)purchases {
    let request = [OSRequestSendPurchases new];
    
    request.parameters = @{@"app_id" : appId,
                           @"purchases" : purchases,
                           @"external_user_id_auth_hash" : externalIdAuthToken ?: [NSNull null]
    };
    request.method = POST;
    request.path = [NSString stringWithFormat:@"players/%@/on_purchase", userId];
    
    return request;
}

+ (instancetype)withUserId:(NSString *)userId emailAuthToken:(NSString *)emailAuthToken appId:(NSString *)appId withPurchases:(NSArray *)purchases {
    let request = [OSRequestSendPurchases new];
    
    request.parameters = @{
        @"app_id" : appId,
        @"purchases" : purchases,
        @"email_auth_hash" : emailAuthToken ?: [NSNull null]
    };
    request.method = POST;
    request.path = [NSString stringWithFormat:@"players/%@/on_purchase", userId];
    
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
    let md5Hash = [OneSignalCoreHelper hashUsingMD5:lowerCase];
    let sha1Hash = [OneSignalCoreHelper hashUsingSha1:lowerCase];
    
    [OneSignalLog onesignalLog:ONE_S_LL_DEBUG message:[NSString stringWithFormat:@"%@ - MD5: %@, SHA1:%@", lowerCase, md5Hash, sha1Hash]];
    
    request.parameters = @{@"app_id" : appId, @"em_m" : md5Hash, @"em_s" : sha1Hash, @"net_type" : netType};
    request.method = PUT;
    request.path = [NSString stringWithFormat:@"players/%@", userId];
    
    return request;
}
@end

@implementation OSRequestUpdateLanguage

+ (instancetype _Nonnull)withUserId:(NSString * _Nonnull)userId
                              appId:(NSString * _Nonnull)appId
                           language:(NSString * _Nonnull)language
                     emailAuthToken:(NSString * _Nullable)emailAuthHash
                externalIdAuthToken:(NSString * _Nullable)externalIdAuthToken {
    return [self withUserId:userId appId:appId language:language authToken:emailAuthHash authTokenKey:@"email_auth_hash" externalIdAuthToken:externalIdAuthToken];
}

+ (instancetype)withUserId:(NSString *)userId
                     appId:(NSString *)appId
                  language:(NSString *)language
              smsAuthToken:(NSString *)smsAuthToken
       externalIdAuthToken:(NSString *)externalIdAuthToken {
    return [self withUserId:userId appId:appId language:language authToken:smsAuthToken authTokenKey:@"sms_auth_hash" externalIdAuthToken:externalIdAuthToken];
}

+ (instancetype)withUserId:(NSString *)userId
                     appId:(NSString *)appId
                language:(NSString *)language
                 authToken:(NSString *)authToken
              authTokenKey:(NSString *)authTokenKey
       externalIdAuthToken:(NSString *)externalIdAuthToken {
    let request = [OSRequestUpdateLanguage new];
    
    NSLog(@"Attempting Update to Language");
    
    let params = [NSMutableDictionary new];
    params[@"app_id"] = appId;
    params[@"language"] = language;
    
    if (authToken && authToken.length > 0 && authTokenKey)
        params[authTokenKey] = authToken;
    
    if (externalIdAuthToken && externalIdAuthToken.length > 0)
        params[@"external_user_id_auth_hash"] = externalIdAuthToken;
    
    request.parameters = params;
    request.method = PUT;
    request.path = [NSString stringWithFormat:@"players/%@", userId];
    
    return request;
}

@end

@implementation OSRequestBadgeCount

+ (instancetype _Nonnull)withUserId:(NSString * _Nonnull)userId
                              appId:(NSString * _Nonnull)appId
                         badgeCount:(NSNumber * _Nonnull)badgeCount
                     emailAuthToken:(NSString * _Nullable)emailAuthHash
                externalIdAuthToken:(NSString * _Nullable)externalIdAuthToken {
    return [self withUserId:userId appId:appId badgeCount:badgeCount authToken:emailAuthHash authTokenKey:@"email_auth_hash" externalIdAuthToken:externalIdAuthToken];
}

+ (instancetype)withUserId:(NSString *)userId
                     appId:(NSString *)appId
                badgeCount:(NSNumber *)badgeCount
              smsAuthToken:(NSString *)smsAuthToken
       externalIdAuthToken:(NSString *)externalIdAuthToken {
    return [self withUserId:userId appId:appId badgeCount:badgeCount authToken:smsAuthToken authTokenKey:@"sms_auth_hash" externalIdAuthToken:externalIdAuthToken];
}

+ (instancetype)withUserId:(NSString *)userId
                     appId:(NSString *)appId
                badgeCount:(NSNumber *)badgeCount
                 authToken:(NSString *)authToken
              authTokenKey:(NSString *)authTokenKey
       externalIdAuthToken:(NSString *)externalIdAuthToken {
    let request = [OSRequestBadgeCount new];
    
    let params = [NSMutableDictionary new];
    params[@"app_id"] = appId;
    params[@"badgeCount"] = badgeCount;
    
    if (authToken && authToken.length > 0 && authTokenKey)
        params[authTokenKey] = authToken;
    
    if (externalIdAuthToken && externalIdAuthToken.length > 0)
        params[@"external_user_id_auth_hash"] = externalIdAuthToken;
    
    request.parameters = params;
    request.method = PUT;
    request.path = [NSString stringWithFormat:@"players/%@", userId];
    
    return request;
}

@end

@implementation OSRequestUpdateExternalUserId
+ (instancetype _Nonnull)withUserId:(NSString * _Nullable)externalId withUserIdHashToken:(NSString * _Nullable)hashToken withOneSignalUserId:(NSString *)userId appId:(NSString *)appId {
    return [self withUserId:externalId withUserIdHashToken:hashToken withOneSignalUserId:userId withChannelHashToken:nil withHashTokenKey:nil appId:appId];
}

+ (instancetype)withUserId:(NSString *)externalId withUserIdHashToken:(NSString *)hashToken withOneSignalUserId:(NSString *)userId withEmailHashToken:(NSString *)emailHashToken appId:(NSString *)appId {
    return [self withUserId:externalId withUserIdHashToken:hashToken withOneSignalUserId:userId withChannelHashToken:emailHashToken withHashTokenKey:@"email_auth_hash" appId:appId];
}

+ (instancetype)withUserId:(NSString *)externalId withUserIdHashToken:(NSString *)hashToken withOneSignalUserId:(NSString *)userId withSMSHashToken:(NSString *)smsHashToken appId:(NSString *)appId {
    return [self withUserId:externalId withUserIdHashToken:hashToken withOneSignalUserId:userId withChannelHashToken:smsHashToken withHashTokenKey:@"sms_auth_hash" appId:appId];
}

+ (instancetype)withUserId:(NSString *)externalId withUserIdHashToken:(NSString *)hashToken withOneSignalUserId:(NSString *)userId  withChannelHashToken:(NSString *)channelHashToken withHashTokenKey:(NSString *)hashTokenKey appId:(NSString *)appId {
    NSString *msg = [NSString stringWithFormat:@"App ID: %@, external ID: %@", appId, externalId];
    [OneSignalLog onesignalLog:ONE_S_LL_DEBUG message:msg];

    let request = [OSRequestUpdateExternalUserId new];
    NSMutableDictionary *parametres = [NSMutableDictionary new];
    [parametres setObject:appId forKey:@"app_id"];
    [parametres setObject:externalId ?: @"" forKey:@"external_user_id"];
    if (hashToken && [hashToken length] > 0)
        [parametres setObject:hashToken forKey:@"external_user_id_auth_hash"];
    if (channelHashToken && hashTokenKey)
        [parametres setObject:channelHashToken forKey:hashTokenKey];
    request.parameters = parametres;
    request.method = PUT;
    request.path = [NSString stringWithFormat:@"players/%@", userId];

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
+ (instancetype)withUserId:(NSString * _Nonnull)userId
                     appId:(NSString * _Nonnull)appId
                activityId:(NSString * _Nonnull)activityId
                     token:(NSString * _Nullable)token {
    let request = [OSRequestLiveActivityEnter new];
    let params = [NSMutableDictionary new];
    params[@"push_token"] = token;
    params[@"subscription_id"] = userId; // pre-5.X.X subscription_id = player_id = userId
    request.parameters = params;
    request.method = POST;
    request.path = [NSString stringWithFormat:@"apps/%@/live_activities/%@/token", appId, activityId];
    return request;
}
@end

@implementation OSRequestLiveActivityExit
+ (instancetype)withUserId:(NSString * _Nonnull)userId
                     appId:(NSString * _Nonnull)appId
                activityId:(NSString * _Nonnull)activityId {
    let request = [OSRequestLiveActivityExit new];
    request.method = DELETE;
    request.path = [NSString stringWithFormat:@"apps/%@/live_activities/%@/token/%@", appId, activityId, userId];
    return request;
}
@end
