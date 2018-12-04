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
#import "OneSignalRequest.h"
#import "OneSignalLocation.h"

#ifndef OneSignalRequests_h
#define OneSignalRequests_h

NS_ASSUME_NONNULL_BEGIN

@interface OSRequestGetTags : OneSignalRequest
+ (instancetype)withUserId:(NSString *)userId appId:(NSString *)appId;
@end

@interface OSRequestGetIosParams : OneSignalRequest
+ (instancetype)withUserId:(NSString *)userId appId:(NSString *)appId;
@end

@interface OSRequestPostNotification : OneSignalRequest
+ (instancetype)withAppId:(NSString *)appId withJson:(NSMutableDictionary *)json;
@end

@interface OSRequestUpdateNotificationTypes : OneSignalRequest
+ (instancetype)withUserId:(NSString *)userId appId:(NSString *)appId notificationTypes:(NSNumber *)notificationTypes;
@end

@interface OSRequestSendPurchases : OneSignalRequest
+ (instancetype)withUserId:(NSString *)userId appId:(NSString *)appId withPurchases:(NSArray *)purchases;
+ (instancetype)withUserId:(NSString *)userId emailAuthToken:(NSString *)emailAuthToken appId:(NSString *)appId withPurchases:(NSArray *)purchases;
@end

@interface OSRequestSubmitNotificationOpened : OneSignalRequest
+ (instancetype)withUserId:(NSString *)userId appId:(NSString *)appId wasOpened:(BOOL)opened messageId:(NSString *)messageId;
@end

@interface OSRequestSyncHashedEmail : OneSignalRequest
+ (instancetype)withUserId:(NSString *)userId appId:(NSString *)appId email:(NSString *)email networkType:(NSNumber *)netType;
@end

NS_ASSUME_NONNULL_END

@interface OSRequestUpdateDeviceToken : OneSignalRequest
+ (instancetype _Nonnull)withUserId:(NSString * _Nonnull)userId appId:(NSString * _Nonnull)appId deviceToken:(NSString * _Nullable)identifier notificationTypes:(NSNumber * _Nullable)notificationTypes withParentId:(NSString * _Nullable)parentId emailAuthToken:(NSString * _Nullable)emailAuthHash email:(NSString * _Nullable)email;
@end

@interface OSRequestRegisterUser : OneSignalRequest
+ (instancetype _Nonnull)withData:(NSDictionary * _Nonnull)registrationData userId:(NSString * _Nullable)userId;
@end

@interface OSRequestCreateDevice : OneSignalRequest
+ (instancetype _Nonnull)withAppId:(NSString * _Nonnull)appId withDeviceType:(NSNumber * _Nonnull)deviceType withEmail:(NSString * _Nullable)email withPlayerId:(NSString * _Nullable)playerId withEmailAuthHash:(NSString * _Nullable)emailAuthHash;
@end

@interface OSRequestLogoutEmail : OneSignalRequest
+ (instancetype _Nonnull)withAppId:(NSString * _Nonnull)appId emailPlayerId:(NSString * _Nonnull)emailPlayerId devicePlayerId:(NSString * _Nonnull)devicePlayerId emailAuthHash:(NSString * _Nullable)emailAuthHash;
@end

@interface OSRequestSendTagsToServer : OneSignalRequest
+ (instancetype _Nonnull)withUserId:(NSString * _Nonnull)userId appId:(NSString * _Nonnull)appId tags:(NSDictionary * _Nonnull)tags networkType:(NSNumber * _Nonnull)netType withEmailAuthHashToken:(NSString * _Nullable)emailAuthToken;
@end

@interface OSRequestSendLocation : OneSignalRequest
+ (instancetype _Nonnull)withUserId:(NSString * _Nonnull)userId appId:(NSString * _Nonnull)appId location:(os_last_location * _Nonnull)coordinate networkType:(NSNumber * _Nonnull)netType backgroundState:(BOOL)backgroundState emailAuthHashToken:(NSString * _Nullable)emailAuthHash;
@end

@interface OSRequestOnFocus : OneSignalRequest
+ (instancetype _Nonnull)withUserId:(NSString * _Nonnull)userId appId:(NSString * _Nonnull)appId badgeCount:(NSNumber * _Nonnull)badgeCount emailAuthToken:(NSString * _Nullable)emailAuthHash;
+ (instancetype _Nonnull)withUserId:(NSString * _Nonnull)userId appId:(NSString * _Nonnull)appId state:(NSString * _Nonnull)state type:(NSNumber * _Nonnull)type activeTime:(NSNumber * _Nonnull)activeTime netType:(NSNumber * _Nonnull)netType emailAuthToken:(NSString * _Nullable)emailAuthHash;
@end

@interface OSRequestUpdateExternalUserId : OneSignalRequest
+ (instancetype _Nonnull)withUserId:(NSString * _Nullable)externalId withOneSignalUserId:(NSString * _Nonnull)userId appId:(NSString * _Nonnull)appId;
@end

#endif /* Requests_h */

