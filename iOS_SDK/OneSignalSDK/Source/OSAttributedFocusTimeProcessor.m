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
#import "OneSignalFramework.h"
#import "OSAttributedFocusTimeProcessor.h"

@interface OneSignal ()
+ (void)sendSessionEndOutcomes:(NSNumber*)totalTimeActive params:(OSFocusCallParams *)params onSuccess:(OSResultSuccessBlock _Nonnull)successBlock onFailure:(OSFailureBlock _Nonnull)failureBlock;
@end

@implementation OSAttributedFocusTimeProcessor {
    NSTimer* restCallTimer;
}

static let ATTRIBUTED_MIN_SESSION_TIME_SEC = 1;
static let DELAY_TIME = 30;

- (instancetype)init {
    self = [super init];
    [OSBackgroundTaskManager setTaskInvalid:ATTRIBUTED_FOCUS_TASK];
    return self;
}

- (int)getMinSessionTime {
    return ATTRIBUTED_MIN_SESSION_TIME_SEC;
}

- (NSString*)unsentActiveTimeUserDefaultsKey {
    return OSUD_UNSENT_ACTIVE_TIME_ATTRIBUTED;
}

- (void)sendOnFocusCall:(OSFocusCallParams *)params {
    let unsentActive = [super getUnsentActiveTime];
    let totalTimeActive = unsentActive + params.timeElapsed;
    [OneSignalLog onesignalLog:ONE_S_LL_DEBUG
                     message:[NSString stringWithFormat:@"sendOnFocusCall attributed with totalTimeActive %f", totalTimeActive]];
    
    [super saveUnsentActiveTime:totalTimeActive];
    [self sendOnFocusCallWithParams:params totalTimeActive:totalTimeActive];
}

- (void)sendUnsentActiveTime:(OSFocusCallParams *)params {
    let unsentActive = [super getUnsentActiveTime];
    [OneSignalLog onesignalLog:ONE_S_LL_DEBUG
                     message:[NSString stringWithFormat:@"sendUnsentActiveTime attributed with unsentActive %f", unsentActive]];
    
    [self sendOnFocusCallWithParams:params totalTimeActive:unsentActive];
}

- (void)sendOnFocusCallWithParams:(OSFocusCallParams *)params totalTimeActive:(NSTimeInterval)totalTimeActive {
    // Don't send influenced session with time < 1 seconds
    if (totalTimeActive < 1) {
        [OneSignalLog onesignalLog:ONE_S_LL_DEBUG message:[NSString stringWithFormat:@"sendSessionEndOutcomes not sending active time %f", totalTimeActive]];
        return;
    }
    
    [OSBackgroundTaskManager beginBackgroundTask:ATTRIBUTED_FOCUS_TASK];

    if (params.onSessionEnded) {
        [self sendBackgroundAttributedFocusPingWithParams:params withTotalTimeActive:@(totalTimeActive)];
        return;
    }
    
    restCallTimer = [NSTimer
        scheduledTimerWithTimeInterval:DELAY_TIME
                               target:self
                             selector:@selector(sendBackgroundAttributedFocusPingWithNSTimer:)
                             userInfo:@{@"params": params, @"time": @(totalTimeActive)}
                              repeats:false];
}

- (void)sendBackgroundAttributedFocusPingWithNSTimer:(NSTimer*)timer {
    let userInfo = (NSDictionary<NSString*, id>*)timer.userInfo;
    let params = (OSFocusCallParams*)userInfo[@"params"];
    let totalTimeActive = (NSNumber*)userInfo[@"time"];
    [self sendBackgroundAttributedFocusPingWithParams:params withTotalTimeActive:totalTimeActive];
}

- (void)sendBackgroundAttributedFocusPingWithParams:(OSFocusCallParams *)params withTotalTimeActive:(NSNumber*)totalTimeActive {
    
    [OneSignalLog onesignalLog:ONE_S_LL_DEBUG message:@"OSAttributedFocusTimeProcessor:sendBackgroundAttributedFocusPingWithParams start"];
    // TODO: Can we get wait for onSuccess to call [super saveUnsentActiveTime:0]
    // Need on failure an success to end background task
    if ([OneSignal sendSessionEndOutcomes:totalTimeActive params:params]) {
        [super saveUnsentActiveTime:0];
    }

    [OSBackgroundTaskManager endBackgroundTask:ATTRIBUTED_FOCUS_TASK];
}

- (void)cancelDelayedJob {
    if (!restCallTimer)
        return;
    
    [restCallTimer invalidate];
    restCallTimer = nil;
    [OSBackgroundTaskManager endBackgroundTask:ATTRIBUTED_FOCUS_TASK];
}

@end
