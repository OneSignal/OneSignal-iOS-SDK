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
#import "OSUserState.h"
#import "OneSignalClient.h"
#import "OneSignalLocation.h"
#import "OSFocusCallParams.h"

#ifndef OSStateSynchronizer_h
#define OSStateSynchronizer_h

@interface OSStateSynchronizer : NSObject

- (instancetype _Nonnull)initWithSubscriptionState:(OSSubscriptionState * _Nonnull)subscriptionState
                        withEmailSubscriptionState:(OSEmailSubscriptionState * _Nonnull)emailSubscriptionState;

- (void)registerUserWithState:(OSUserState * _Nonnull)registrationState
                  withSuccess:(OSMultipleSuccessBlock _Nullable)successBlock
                    onFailure:(OSMultipleFailureBlock _Nullable)failureBlock;

- (void)setExternalUserId:(NSString * _Nonnull)externalId
withExternalIdAuthHashToken:(NSString * _Nullable)hashToken
                withAppId:(NSString * _Nonnull)appId withSuccess:(OSUpdateExternalUserIdSuccessBlock _Nullable)successBlock
              withFailure:(OSUpdateExternalUserIdFailureBlock _Nullable)failureBlock;

- (void)sendTagsWithAppId:(NSString * _Nonnull)appId
               sendingTags:(NSDictionary * _Nonnull)tag
               networkType:(NSNumber * _Nonnull)networkType
      processingCallbacks:(NSArray * _Nullable)nowProcessingCallbacks;

- (void)sendPurchases:(NSArray * _Nonnull)purchases appId:(NSString * _Nonnull)appId;

- (void)sendBadgeCount:(NSNumber * _Nonnull)badgeCount appId:(NSString * _Nonnull)appId;

- (void)sendLocation:(os_last_location * _Nonnull)lastLocation
               appId:(NSString * _Nonnull)appId
         networkType:(NSNumber * _Nonnull)networkType
     backgroundState:(BOOL)background;

- (void)sendOnFocusTime:(NSNumber * _Nonnull)totalTimeActive
                 params:(OSFocusCallParams * _Nonnull)params
            withSuccess:(OSMultipleSuccessBlock _Nullable)successBlock
              onFailure:(OSMultipleFailureBlock _Nullable)failureBlock;

@end

#endif /* OSStateSynchronizer_h */
