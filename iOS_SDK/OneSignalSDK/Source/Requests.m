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
#import "OSOutcomeEvent.h"
#import "OneSignalRequest.h"
#import "OneSignalHelper.h"
#import "OneSignalCommonDefines.h"
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
    
    if (email)
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

@implementation OSRequestBadgeCount

+ (instancetype _Nonnull)withUserId:(NSString * _Nonnull)userId
                              appId:(NSString * _Nonnull)appId
                         badgeCount:(NSNumber * _Nonnull)badgeCount
                     emailAuthToken:(NSString * _Nullable)emailAuthHash {
    let request = [OSRequestBadgeCount new];
    
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

@end

@implementation OSRequestOnFocus

NSString * const IS_DIRECT = @"direct";
NSString * const NOTIFICATION_IDS = @"notification_ids";

+ (instancetype)withUserId:(NSString *)userId
                     appId:(NSString *)appId
                activeTime:(NSNumber *)activeTime
                   netType:(NSNumber *)netType
            emailAuthToken:(NSString *)emailAuthHash
                deviceType:(NSNumber * _Nonnull)deviceType {
    let request = [OSRequestOnFocus new];

    let params = [NSMutableDictionary new];
    params[@"app_id"] = appId;
    params[@"state"] = @"ping";
    params[@"type"] = @1;
    params[@"active_time"] = activeTime;
    params[@"net_type"] = netType;
    params[@"device_type"] = deviceType;

    if (emailAuthHash && emailAuthHash.length > 0)
        params[@"email_auth_hash"] = emailAuthHash;

    request.parameters = params;
    request.method = POST;
    request.path = [NSString stringWithFormat:@"players/%@/on_focus", userId];

    return request;
}

+ (instancetype)withUserId:(NSString *)userId
                     appId:(NSString *)appId
                activeTime:(NSNumber *)activeTime
                   netType:(NSNumber *)netType
            emailAuthToken:(NSString *)emailAuthHash
                deviceType:(NSNumber * _Nonnull)deviceType
             directSession:(BOOL)directSession
            notificationIds:(NSArray *)notificationIds {

    let request = [OSRequestOnFocus new];

    let params = [NSMutableDictionary new];
    params[@"app_id"] = appId;
    params[@"state"] = @"ping";
    params[@"type"] = @1;
    params[@"active_time"] = activeTime;
    params[@"net_type"] = netType;
    params[@"device_type"] = deviceType;
    params[IS_DIRECT] = @(directSession);
    params[NOTIFICATION_IDS] = notificationIds;

    if (emailAuthHash && emailAuthHash.length > 0)
        params[@"email_auth_hash"] = emailAuthHash;
    
    request.parameters = params;
    request.method = POST;
    request.path = [NSString stringWithFormat:@"players/%@/on_focus", userId];
    
    return request;
}

@end

@implementation OSRequestInAppMessageViewed
+ (instancetype _Nonnull)withAppId:(NSString * _Nonnull)appId
                      withPlayerId:(NSString * _Nonnull)playerId
                     withMessageId:(NSString * _Nonnull)messageId
                      forVariantId:(NSString *)variantId {
    let request = [OSRequestInAppMessageViewed new];

    request.parameters = @{
       @"device_type": @0,
       @"player_id": playerId,
       @"app_id": appId,
       @"variant_id": variantId
    };

    request.method = POST;
    request.path = [NSString stringWithFormat:@"in_app_messages/%@/impression", messageId];

    return request;
}
@end

@implementation OSRequestInAppMessageClicked
+ (instancetype _Nonnull)withAppId:(NSString * _Nonnull)appId
                      withPlayerId:(NSString * _Nonnull)playerId
                     withMessageId:(NSString * _Nonnull)messageId
                      forVariantId:(NSString * _Nonnull)variantId
                     withAction:(OSInAppMessageAction * _Nonnull)action {
    let request = [OSRequestInAppMessageClicked new];

    request.parameters = @{
       @"app_id": appId,
       @"device_type": @0,
       @"player_id": playerId,
       @"click_id": action.clickId ?: @"",
       @"variant_id": variantId,
       @"first_click": @(action.firstClick)
    };

    request.method = POST;
    request.path = [NSString stringWithFormat:@"in_app_messages/%@/click", messageId];

    return request;
}
@end

@implementation OSRequestLoadInAppMessageContent
+ (instancetype _Nonnull)withAppId:(NSString * _Nonnull)appId
                     withMessageId:(NSString * _Nonnull)messageId
                     withVariantId:(NSString * _Nonnull)variantId {
    let request = [OSRequestLoadInAppMessageContent new];

    request.method = GET;
    request.parameters = @{@"app_id": appId};
    request.path = [NSString stringWithFormat:@"in_app_messages/%@/variants/%@/html", messageId, variantId];

    return request;
}
@end

@implementation OSRequestLoadInAppMessagePreviewContent

+ (instancetype)withAppId:(NSString *)appId previewUUID:(NSString *)previewUUID {
    let request = [OSRequestLoadInAppMessagePreviewContent new];

    request.method = GET;
    request.parameters = @{
      @"preview_id": previewUUID,
      @"app_id": appId
    };

    request.path = @"in_app_messages/device_preview";

    return request;
}
@end

@implementation OSRequestUpdateExternalUserId
+ (instancetype _Nonnull)withUserId:(NSString * _Nullable)externalId withOneSignalUserId:(NSString *)userId appId:(NSString *)appId {
    NSString *msg = [NSString stringWithFormat:@"App ID: %@, external ID: %@", appId, externalId];
    [OneSignal onesignal_Log:ONE_S_LL_DEBUG message:msg];

    let request = [OSRequestUpdateExternalUserId new];
    request.parameters = @{@"app_id" : appId, @"external_user_id" : externalId ?: @""};
    request.method = PUT;
    request.path = [NSString stringWithFormat:@"players/%@", userId];

    return request;
}
@end

@implementation OSRequestReceiveReceipts

+ (instancetype _Nonnull)withPlayerId:(NSString *)playerId notificationId:(NSString *)notificationId appId:(NSString *)appId {
    let request = [OSRequestReceiveReceipts new];
    
    request.parameters = @{@"app_id": appId, @"player_id": playerId ?: [NSNull null]};
    request.method = PUT;
    request.path = [NSString stringWithFormat:@"notifications/%@/report_received", notificationId];

    return request;
}

@end

@implementation OSRequestSendOutcomesToServer
NSString * const APP_ID = @"app_id";
NSString * const DEVICE = @"device_type";
NSString * const OUTCOME_ID = @"id";
NSString * const WEIGHT = @"weight";

+ (instancetype _Nonnull)directWithOutcome:(OSOutcomeEvent * _Nonnull)outcome
                                     appId:(NSString * _Nonnull)appId
                                deviceType:(NSNumber * _Nonnull)deviceType {
    let request = [OSRequestSendOutcomesToServer new];

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
    let request = [OSRequestSendOutcomesToServer new];

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
    let request = [OSRequestSendOutcomesToServer new];

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
