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

@interface OSRequestGetIosParams : OneSignalRequest
+ (instancetype)withUserId:(NSString *)userId appId:(NSString *)appId;
@end

@interface OSRequestPostNotification : OneSignalRequest
+ (instancetype)withAppId:(NSString *)appId withJson:(NSMutableDictionary *)json;
@end

@interface OSRequestSubmitNotificationOpened : OneSignalRequest
+ (instancetype)withUserId:(NSString *)userId appId:(NSString *)appId wasOpened:(BOOL)opened messageId:(NSString *)messageId withDeviceType:(NSNumber *)deviceType;
@end

NS_ASSUME_NONNULL_END

@interface OSRequestTrackV1 : OneSignalRequest
+ (instancetype _Nonnull)trackUsageData:(NSString * _Nonnull)osUsageData
                                     appId:(NSString * _Nonnull)appId;
@end

@interface OSRequestLiveActivityEnter: OneSignalRequest
+ (instancetype _Nonnull)withSubscriptionId:(NSString * _Nonnull)subscriptionId
                              appId:(NSString * _Nonnull)appId
                         activityId:(NSString * _Nonnull)activityId
                              token:(NSString * _Nonnull)token;
@end

@interface OSRequestLiveActivityExit: OneSignalRequest
+ (instancetype _Nonnull)withSubscriptionId:(NSString * _Nonnull)subscriptionId
                              appId:(NSString * _Nonnull)appId
                         activityId:(NSString * _Nonnull)activityId;
@end
#endif /* Requests_h */

