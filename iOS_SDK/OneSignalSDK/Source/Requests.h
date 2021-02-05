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
#import "OSOutcomeEventParams.h"
#import "OSInAppMessageAction.h"
#import "OSFocusInfluenceParam.h"

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

@interface OSRequestUpdateDeviceToken : OneSignalRequest
+ (instancetype _Nonnull)withUserId:(NSString * _Nonnull)userId appId:(NSString * _Nonnull)appId deviceToken:(NSString * _Nullable)identifier notificationTypes:(NSNumber * _Nullable)notificationTypes withParentId:(NSString * _Nullable)parentId emailAuthToken:(NSString * _Nullable)emailAuthHash email:(NSString * _Nullable)email externalIdAuthToken:(NSString * _Nullable)externalIdAuthToken;

+ (instancetype _Nonnull)withUserId:(NSString * _Nonnull)userId appId:(NSString * _Nonnull)appId deviceToken:(NSString * _Nullable)identifier notificationTypes:(NSNumber * _Nullable)notificationTypes smsAuthToken:(NSString * _Nullable)smsAuthToken smsNumber:(NSString * _Nullable)smsNumber externalIdAuthToken:(NSString * _Nullable)externalIdAuthToken;
@end

@interface OSRequestRegisterUser : OneSignalRequest
+ (instancetype _Nonnull)withData:(NSDictionary * _Nonnull)registrationData userId:(NSString * _Nullable)userId;
@end

@interface OSRequestCreateDevice : OneSignalRequest
+ (instancetype _Nonnull)withAppId:(NSString * _Nonnull)appId withDeviceType:(NSNumber * _Nonnull)deviceType withEmail:(NSString * _Nullable)email withPlayerId:(NSString * _Nullable)playerId withEmailAuthHash:(NSString * _Nullable)emailAuthHash withExternalIdAuthToken:(NSString * _Nullable)externalIdAuthToken;

+ (instancetype _Nonnull)withAppId:(NSString * _Nonnull)appId withDeviceType:(NSNumber * _Nonnull)deviceType withSMSNumber:(NSString * _Nullable)smsNumber withSMSAuthHash:(NSString * _Nullable)smsAuthHash withExternalIdAuthToken:(NSString * _Nullable)externalIdAuthToken;
@end

@interface OSRequestLogoutEmail : OneSignalRequest
+ (instancetype _Nonnull)withAppId:(NSString * _Nonnull)appId emailPlayerId:(NSString * _Nonnull)emailPlayerId devicePlayerId:(NSString * _Nonnull)devicePlayerId emailAuthHash:(NSString * _Nullable)emailAuthHash;
@end

@interface OSRequestSendTagsToServer : OneSignalRequest
+ (instancetype _Nonnull)withUserId:(NSString * _Nonnull)userId appId:(NSString * _Nonnull)appId tags:(NSDictionary * _Nonnull)tags networkType:(NSNumber * _Nonnull)netType withEmailAuthHashToken:(NSString * _Nullable)emailAuthToken withExternalIdAuthHashToken:(NSString * _Nullable)externalIdAuthToken;
@end

@interface OSRequestSendLocation : OneSignalRequest
+ (instancetype _Nonnull)withUserId:(NSString * _Nonnull)userId appId:(NSString * _Nonnull)appId location:(os_last_location * _Nonnull)coordinate networkType:(NSNumber * _Nonnull)netType backgroundState:(BOOL)backgroundState emailAuthHashToken:(NSString * _Nullable)emailAuthHash externalIdAuthToken:(NSString * _Nullable)externalIdAuthToken;
@end

@interface OSRequestBadgeCount : OneSignalRequest
+ (instancetype _Nonnull)withUserId:(NSString * _Nonnull)userId
                              appId:(NSString * _Nonnull)appId
                         badgeCount:(NSNumber * _Nonnull)badgeCount
                     emailAuthToken:(NSString * _Nullable)emailAuthHash
                externalIdAuthToken:(NSString * _Nullable)externalIdAuthToken;
@end

@interface OSRequestOnFocus : OneSignalRequest
+ (instancetype _Nonnull)withUserId:(NSString * _Nonnull)userId
                              appId:(NSString * _Nonnull)appId
                         activeTime:(NSNumber * _Nonnull)activeTime
                            netType:(NSNumber * _Nonnull)netType
                     emailAuthToken:(NSString * _Nullable)emailAuthHash
                externalIdAuthToken:(NSString * _Nullable)externalIdAuthToken
                         deviceType:(NSNumber * _Nonnull)deviceType
                    influenceParams:(NSArray<OSFocusInfluenceParam *> * _Nonnull)influenceParams;
@end

@interface OSRequestInAppMessageViewed : OneSignalRequest
+ (instancetype _Nonnull)withAppId:(NSString * _Nonnull)appId withPlayerId:(NSString * _Nonnull)playerId withMessageId:(NSString * _Nonnull)messageId forVariantId:(NSString * _Nonnull)variantId;
@end

@interface OSRequestInAppMessagePageViewed : OneSignalRequest
+ (instancetype _Nonnull)withAppId:(NSString * _Nonnull)appId withPlayerId:(NSString * _Nonnull)playerId withMessageId:(NSString * _Nonnull)messageId withPageId:(NSString * _Nonnull)pageId forVariantId:(NSString * _Nonnull)variantId;
@end

@interface OSRequestInAppMessageClicked : OneSignalRequest
+ (instancetype _Nonnull)withAppId:(NSString * _Nonnull)appId
                      withPlayerId:(NSString * _Nonnull)playerId
                     withMessageId:(NSString * _Nonnull)messageId
                      forVariantId:(NSString * _Nonnull)variantId
                     withAction:(OSInAppMessageAction * _Nonnull)action;
@end

@interface OSRequestLoadInAppMessageContent : OneSignalRequest
+ (instancetype _Nonnull)withAppId:(NSString * _Nonnull)appId withMessageId:(NSString * _Nonnull)messageId withVariantId:(NSString * _Nonnull)variant;
@end

@interface OSRequestLoadInAppMessagePreviewContent : OneSignalRequest
+ (instancetype _Nonnull)withAppId:(NSString * _Nonnull)appId previewUUID:(NSString * _Nonnull)previewUUID;
@end

@interface OSRequestUpdateExternalUserId : OneSignalRequest
+ (instancetype _Nonnull)withUserId:(NSString * _Nullable)externalId withUserIdHashToken:(NSString * _Nullable)hashToken withOneSignalUserId:(NSString * _Nonnull)userId appId:(NSString * _Nonnull)appId;
@end

@interface OSRequestSendOutcomesV1ToServer : OneSignalRequest
+ (instancetype _Nonnull)directWithOutcome:(OSOutcomeEvent * _Nonnull)outcome
                                     appId:(NSString * _Nonnull)appId
                                deviceType:(NSNumber * _Nonnull)deviceType;

+ (instancetype _Nonnull)indirectWithOutcome:(OSOutcomeEvent * _Nonnull)outcome
                                       appId:(NSString * _Nonnull)appId
                                  deviceType:(NSNumber * _Nonnull)deviceType;

+ (instancetype _Nonnull)unattributedWithOutcome:(OSOutcomeEvent * _Nonnull)outcome
                                           appId:(NSString * _Nonnull)appId
                                      deviceType:(NSNumber * _Nonnull)deviceType;
@end

@interface OSRequestSendOutcomesV2ToServer : OneSignalRequest
+ (instancetype _Nonnull)measureOutcomeEvent:(OSOutcomeEventParams * _Nonnull)outcome
                                     appId:(NSString * _Nonnull)appId
                                deviceType:(NSNumber * _Nonnull)deviceType;

@end

@interface OSRequestReceiveReceipts : OneSignalRequest
+ (instancetype _Nonnull)withPlayerId:(NSString * _Nullable)playerId notificationId:(NSString * _Nonnull)notificationId appId:(NSString * _Nonnull)appId;
@end

#endif /* Requests_h */

