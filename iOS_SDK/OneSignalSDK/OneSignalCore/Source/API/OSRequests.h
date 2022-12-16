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
#import <OneSignalCore/OneSignalRequest.h>

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
+ (instancetype)withUserId:(NSString *)userId externalIdAuthToken:(NSString * _Nullable)externalIdAuthToken appId:(NSString *)appId withPurchases:(NSArray *)purchases;
+ (instancetype)withUserId:(NSString *)userId emailAuthToken:(NSString *)emailAuthToken appId:(NSString *)appId withPurchases:(NSArray *)purchases;
@end

@interface OSRequestSubmitNotificationOpened : OneSignalRequest
+ (instancetype)withUserId:(NSString *)userId appId:(NSString *)appId wasOpened:(BOOL)opened messageId:(NSString *)messageId withDeviceType:(NSNumber *)deviceType;
@end

@interface OSRequestSyncHashedEmail : OneSignalRequest
+ (instancetype)withUserId:(NSString *)userId appId:(NSString *)appId email:(NSString *)email networkType:(NSNumber *)netType;
@end

NS_ASSUME_NONNULL_END

@interface OSRequestRegisterUser : OneSignalRequest
+ (instancetype _Nonnull)withData:(NSDictionary * _Nonnull)registrationData userId:(NSString * _Nullable)userId;
@end

@interface OSRequestCreateDevice : OneSignalRequest
+ (instancetype _Nonnull)withAppId:(NSString * _Nonnull)appId withDeviceType:(NSNumber * _Nonnull)deviceType withEmail:(NSString * _Nullable)email withPlayerId:(NSString * _Nullable)playerId withEmailAuthHash:(NSString * _Nullable)emailAuthHash withExternalUserId:(NSString * _Nullable)externalUserId withExternalIdAuthToken:(NSString * _Nullable)externalIdAuthToken;

+ (instancetype _Nonnull)withAppId:(NSString * _Nonnull)appId withDeviceType:(NSNumber * _Nonnull)deviceType withSMSNumber:(NSString * _Nullable)smsNumber withPlayerId:(NSString * _Nullable)playerId withSMSAuthHash:(NSString * _Nullable)smsAuthHash withExternalUserId:(NSString * _Nullable)externalUserId withExternalIdAuthToken:(NSString * _Nullable)externalIdAuthToken;
@end

@interface OSRequestLogoutEmail : OneSignalRequest
+ (instancetype _Nonnull)withAppId:(NSString * _Nonnull)appId emailPlayerId:(NSString * _Nonnull)emailPlayerId devicePlayerId:(NSString * _Nonnull)devicePlayerId emailAuthHash:(NSString * _Nullable)emailAuthHash;
@end

@interface OSRequestLogoutSMS : OneSignalRequest
+ (instancetype _Nonnull)withAppId:(NSString * _Nonnull)appId smsPlayerId:(NSString * _Nonnull)smsPlayerId smsAuthHash:(NSString * _Nullable)smsAuthHash devicePlayerId:(NSString * _Nonnull)devicePlayerId;
@end

@interface OSRequestSendTagsToServer : OneSignalRequest
+ (instancetype _Nonnull)withUserId:(NSString * _Nonnull)userId appId:(NSString * _Nonnull)appId tags:(NSDictionary * _Nonnull)tags networkType:(NSNumber * _Nonnull)netType withEmailAuthHashToken:(NSString * _Nullable)emailAuthToken withExternalIdAuthHashToken:(NSString * _Nullable)externalIdAuthToken;

+ (instancetype _Nonnull)withUserId:(NSString * _Nonnull)userId appId:(NSString * _Nonnull)appId tags:(NSDictionary * _Nonnull)tags networkType:(NSNumber * _Nonnull)netType withSMSAuthHashToken:(NSString * _Nullable)smsAuthToken withExternalIdAuthHashToken:(NSString * _Nullable)externalIdAuthToken;
@end

@interface OSRequestUpdateLanguage : OneSignalRequest
+ (instancetype _Nonnull)withUserId:(NSString * _Nonnull)userId
                              appId:(NSString * _Nonnull)appId
                           language:(NSString * _Nonnull)language
                     emailAuthToken:(NSString * _Nullable)emailAuthHash
                externalIdAuthToken:(NSString * _Nullable)externalIdAuthToken;

+ (instancetype _Nonnull)withUserId:(NSString * _Nonnull)userId
                              appId:(NSString * _Nonnull)appId
                           language:(NSString * _Nonnull)language
                       smsAuthToken:(NSString * _Nullable)smsAuthToken
                externalIdAuthToken:(NSString * _Nullable)externalIdAuthToken;
@end

@interface OSRequestUpdateExternalUserId : OneSignalRequest
+ (instancetype _Nonnull)withUserId:(NSString * _Nullable)externalId withUserIdHashToken:(NSString * _Nullable)hashToken withOneSignalUserId:(NSString * _Nonnull)userId appId:(NSString * _Nonnull)appId;

+ (instancetype _Nonnull)withUserId:(NSString * _Nullable)externalId withUserIdHashToken:(NSString * _Nullable)hashToken withOneSignalUserId:(NSString * _Nonnull)userId  withEmailHashToken:(NSString * _Nullable)emailHashToken appId:(NSString * _Nonnull)appId;

+ (instancetype _Nonnull)withUserId:(NSString * _Nullable)externalId withUserIdHashToken:(NSString * _Nullable)hashToken withOneSignalUserId:(NSString * _Nonnull)userId withSMSHashToken:(NSString * _Nullable)smsHashToken appId:(NSString * _Nonnull)appId;
@end


@interface OSRequestTrackV1 : OneSignalRequest
+ (instancetype _Nonnull)trackUsageData:(NSString * _Nonnull)osUsageData
                                     appId:(NSString * _Nonnull)appId;
@end
#endif /* Requests_h */

