/**
 * Modified MIT License
 *
 * Copyright 2019 OneSignal
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
#import <UIKit/UIKit.h>
#import <OneSignalCore/OneSignalCore.h>
#import "OSUnattributedFocusTimeProcessor.h"
#import "OSStateSynchronizer.h"

@interface OneSignal ()
+ (OSStateSynchronizer *)stateSynchronizer;
@end

@implementation OSUnattributedFocusTimeProcessor {
    UIBackgroundTaskIdentifier focusBackgroundTask;
}

static let UNATTRIBUTED_MIN_SESSION_TIME_SEC = 60;

- (instancetype)init {
    self = [super init];
    focusBackgroundTask = UIBackgroundTaskInvalid;
    return self;
}

- (void)beginBackgroundFocusTask {
    focusBackgroundTask = [UIApplication.sharedApplication beginBackgroundTaskWithExpirationHandler:^{
        [self endBackgroundFocusTask];
    }];
}

- (void)endBackgroundFocusTask {
    [OneSignal onesignal_Log:ONE_S_LL_DEBUG
                     message:[NSString stringWithFormat:@"OSUnattributedFocusTimeProcessor:endDelayBackgroundTask:%lu", (unsigned long)focusBackgroundTask]];
    [UIApplication.sharedApplication endBackgroundTask: focusBackgroundTask];
    focusBackgroundTask = UIBackgroundTaskInvalid;
    [OneSignal onesignal_Log:ONE_S_LL_DEBUG message:@"endBackgroundFocusTask called"];
}

- (int)getMinSessionTime {
    return UNATTRIBUTED_MIN_SESSION_TIME_SEC;
}

- (NSString*)unsentActiveTimeUserDefaultsKey {
    return OSUD_UNSENT_ACTIVE_TIME;
}

- (void)sendOnFocusCall:(OSFocusCallParams *)params {
    let unsentActive = [super getUnsentActiveTime];
    let totalTimeActive = unsentActive + params.timeElapsed;
    
    [OneSignal onesignal_Log:ONE_S_LL_DEBUG message:[NSString stringWithFormat:@"sendOnFocusCall unattributed with totalTimeActive %f", totalTimeActive]];
    
    if (![super hasMinSyncTime:totalTimeActive]) {
        [OneSignal onesignal_Log:ONE_S_LL_DEBUG message:[NSString stringWithFormat:@"unattributed influence saveUnsentActiveTime %f", totalTimeActive]];
        [super saveUnsentActiveTime:totalTimeActive];
        return;
    }

    [self sendOnFocusCallWithParams:params totalTimeActive:totalTimeActive];
}

- (void)sendUnsentActiveTime:(OSFocusCallParams *)params {
    let unsentActive = [super getUnsentActiveTime];
    [OneSignal onesignal_Log:ONE_S_LL_DEBUG message:[NSString stringWithFormat:@"sendUnsentActiveTime unattributed with unsentActive %f", unsentActive]];
    
    [self sendOnFocusCallWithParams:params totalTimeActive:unsentActive];
}

- (void)sendOnFocusCallWithParams:(OSFocusCallParams *)params totalTimeActive:(NSTimeInterval)totalTimeActive {
    if (!params.userId)
        return;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self beginBackgroundFocusTask];
        [OneSignal onesignal_Log:ONE_S_LL_DEBUG message:@"beginBackgroundFocusTask start"];
       
        [OneSignal.stateSynchronizer sendOnFocusTime:@(totalTimeActive) params:params withSuccess:^(NSDictionary *result) {
            [super saveUnsentActiveTime:0];
            [OneSignal onesignal_Log:ONE_S_LL_DEBUG message:@"sendOnFocusCallWithParams unattributed succeed, saveUnsentActiveTime with 0"];
            [self endBackgroundFocusTask];
        } onFailure:^(NSDictionary<NSString *, NSError *> *errors) {
            [OneSignal onesignal_Log:ONE_S_LL_DEBUG message:@"sendOnFocusCallWithParams unattributed failed, will retry on next open"];
            [self endBackgroundFocusTask];
        }];
    });
}

- (void)cancelDelayedJob {
    // No job to cancel, network call is made right away.
}


@end

