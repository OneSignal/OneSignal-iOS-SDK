//
//  Requests.h
//  OneSignal
//
//  Created by Brad Hesse on 12/19/17.
//  Copyright © 2017 Hiptic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OneSignalRequest.h"
#import "OneSignalLocation.h"

#ifndef OneSignalRequests_h
#define OneSignalRequests_h

NS_ASSUME_NONNULL_BEGIN

@interface OSRequestRegisterDevice : OneSignalRequest
+ (instancetype)withAppId:(NSString *)appId withDeviceType:(NSNumber *)deviceType withAdId:(NSString *)adId withSDKVersion:(NSString *)sdkVersion withIdentifier:(NSString *)identifier;
@end

@interface OSRequestGetTags : OneSignalRequest
+ (instancetype)withUserId:(NSString *)userId appId:(NSString *)appId;
@end

@interface OSRequestGetIosParams : OneSignalRequest
+ (instancetype)withUserId:(NSString *)userId appId:(NSString *)appId;
@end

@interface OSRequestSendTagsToServer : OneSignalRequest
+ (instancetype)withUserId:(NSString *)userId appId:(NSString *)appId tags:(NSDictionary *)tags networkType:(NSNumber *)netType;
@end

@interface OSRequestPostNotification : OneSignalRequest
+ (instancetype)withAppId:(NSString *)appId withJson:(NSMutableDictionary *)json;
@end

@interface OSRequestUpdateDeviceToken : OneSignalRequest
+ (instancetype)withUserId:(NSString *)userId appId:(NSString *)appId deviceToken:(NSString *)identifier notificationTypes:(NSNumber *)notificationTypes;
@end

@interface OSRequestUpdateNotificationTypes : OneSignalRequest
+ (instancetype)withUserId:(NSString *)userId appId:(NSString *)appId notificationTypes:(NSNumber *)notificationTypes;
@end

@interface OSRequestSendPurchases : OneSignalRequest
+ (instancetype)withUserId:(NSString *)userId appId:(NSString *)appId withPurchases:(NSArray *)purchases;
@end

@interface OSRequestSubmitNotificationOpened : OneSignalRequest
+ (instancetype)withUserId:(NSString *)userId appId:(NSString *)appId wasOpened:(BOOL)opened messageId:(NSString *)messageId;
@end

@interface OSRequestSyncHashedEmail : OneSignalRequest
+ (instancetype)withUserId:(NSString *)userId appId:(NSString *)appId email:(NSString *)email networkType:(NSNumber *)netType;
@end

@interface OSRequestSendLocation : OneSignalRequest
+ (instancetype)withUserId:(NSString *)userId appId:(NSString *)appId location:(os_last_location *)coordinate networkType:(NSNumber *)netType backgroundState:(BOOL)backgroundState;
@end

@interface OSRequestOnFocus : OneSignalRequest
+ (instancetype)withUserId:(NSString *)userId appId:(NSString *)appId badgeCount:(NSNumber *)badgeCount;
+ (instancetype)withUserId:(NSString *)userId appId:(NSString *)appId state:(NSString *)state type:(NSNumber *)type activeTime:(NSNumber *)activeTime netType:(NSNumber *)netType;
@end

NS_ASSUME_NONNULL_END

@interface OSRequestRegisterUser : OneSignalRequest
+ (instancetype _Nonnull)withData:(NSDictionary * _Nonnull)registrationData userId:(NSString * _Nullable)userId;
@end

#endif /* Requests_h */

