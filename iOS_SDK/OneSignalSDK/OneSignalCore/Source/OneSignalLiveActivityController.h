//
//  OneSignalLiveActivityController.h
//  OneSignal
//
//  Created by Henry Boswell on 1/11/23.
//  Copyright © 2023 Hiptic. All rights reserved.
//

#ifndef OneSignalLiveActivityController_h
#define OneSignalLiveActivityController_h

#import <OneSignalUser/OneSignalUser-Swift.h>


@interface OneSignalLiveActivityController: NSObject<OSPushSubscriptionObserver>

+ (void)enterLiveActivity:(NSString * _Nonnull)activityId appId:(NSString *)appId withToken:(NSString * _Nonnull)token withSuccess:(OSResultSuccessBlock _Nullable)successBlock withFailure:(OSFailureBlock _Nullable)failureBlock;
+ (void)exitLiveActivity:(NSString * _Nonnull)activityId appId:(NSString *)appId withSuccess:(OSResultSuccessBlock _Nullable)successBlock withFailure:(OSFailureBlock _Nullable)failureBlock;


@end

#endif /* OneSignalLiveActivityController_h */
