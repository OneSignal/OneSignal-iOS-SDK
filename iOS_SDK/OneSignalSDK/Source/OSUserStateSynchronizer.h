/**
Modified MIT License

Copyright 2021 OneSignal

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

1. The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

2. All copies of substantial portions of the Software may only be used in connection
with services provided by OneSignal.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
*/

#import "OneSignal.h"
#import "Requests.h"
#import "OneSignalLocation.h"

@interface OSUserStateSynchronizer : NSObject

- (OSRequestRegisterUser * _Nonnull)registerUserWithData:(NSDictionary * _Nonnull)registrationData
                                                  userId:(NSString * _Nullable)userId;

- (OSRequestUpdateExternalUserId * _Nonnull)setExternalUserId:(NSString *_Nonnull)externalId
                                  withExternalIdAuthHashToken:(NSString * _Nullable)hashToken
                                                   withUserId:(NSString * _Nonnull)userId
                                                    withAppId:(NSString * _Nonnull)appId;

- (OSRequestSendTagsToServer * _Nonnull)sendTagsWithUserId:(NSString * _Nonnull)userId
                                                     appId:(NSString * _Nonnull)appId
                                               sendingTags:(NSDictionary * _Nonnull)tags
                                               networkType:(NSNumber * _Nonnull)networkType
                                        emailAuthHashToken:(NSString * _Nullable)emailAuthHashToken
                                   externalIdAuthHashToken:(NSString * _Nullable)externalIdAuthHashToken;

- (OSRequestSendPurchases * _Nonnull)sendPurchases:(NSArray * _Nonnull)purchases
                                             appId:(NSString * _Nonnull)appId
                                            userId:(NSString * _Nonnull)userId
                               externalIdAuthToken:(NSString * _Nullable)externalIdAuthToken;

- (OSRequestBadgeCount * _Nonnull)sendBadgeCount:(NSNumber * _Nonnull)badgeCount
                                           appId:(NSString * _Nonnull)appId
                                          userId:(NSString * _Nonnull)userId
                              emailAuthHashToken:(NSString * _Nullable)emailAuthHashToken
                         externalIdAuthHashToken:(NSString * _Nullable)externalIdAuthHashToken;

- (OSRequestSendLocation * _Nonnull)sendLocation:(os_last_location * _Nonnull)lastLocation
                                           appId:(NSString * _Nonnull)appId
                                          userId:(NSString * _Nonnull)userId
                                     networkType:(NSNumber * _Nonnull)networkType
                                 backgroundState:(BOOL)background
                              emailAuthHashToken:(NSString * _Nullable)emailAuthHashToken
                         externalIdAuthHashToken:(NSString * _Nullable)externalIdAuthHashToken;

- (OSRequestOnFocus * _Nonnull)sendOnFocusTime:(NSNumber * _Nonnull)activeTime
                                        userId:(NSString * _Nonnull)userId
                                         appId:(NSString * _Nonnull)appId
                                       netType:(NSNumber * _Nonnull)netType
                                emailAuthToken:(NSString * _Nullable)emailAuthHash
                           externalIdAuthToken:(NSString * _Nullable)externalIdAuthToken
                                    deviceType:(NSNumber * _Nonnull)deviceType
                               influenceParams:(NSArray <OSFocusInfluenceParam *> * _Nullable)influenceParams;

@end
