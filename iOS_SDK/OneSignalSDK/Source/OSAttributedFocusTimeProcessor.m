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
#import "Requests.h"
#import "OneSignalClient.h"
#import "OSAttributedFocusTimeProcessor.h"

@implementation OSAttributedFocusTimeProcessor

static let ATTRIBUTED_MIN_SESSION_TIME_SEC = 1;
static let DELAY_TIME = 30;

UIBackgroundTaskIdentifier delayBackgroundTask;
NSTimer* restCallTimer = nil;

- (instancetype) init {
    self = [super init];
    delayBackgroundTask = UIBackgroundTaskInvalid;
    return self;
}

- (void)beginDelayBackgroungTask {
    delayBackgroundTask = [UIApplication.sharedApplication beginBackgroundTaskWithExpirationHandler:^{
        [self endDelayBackgroungTask];
    }];
}

- (void)endDelayBackgroungTask {
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE
                     message:[NSString stringWithFormat:@"OSAttributedFocusTimeProcessor:endDelayBackgroungTask:%d", delayBackgroundTask]];
    [UIApplication.sharedApplication endBackgroundTask:delayBackgroundTask];
    delayBackgroundTask = UIBackgroundTaskInvalid;
}

- (int)getMinSessionTime {
    return ATTRIBUTED_MIN_SESSION_TIME_SEC;
}

- (void)sendOnFocusCall:(OSFocusCallParams *)params {
    let unsentActive = [super getUnsentActiveTime];
    let totalTimeActive = unsentActive + params.timeElapsed;
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE
                     message:[NSString stringWithFormat:@"sendOnFocusCall attributed with totalTimeActive %f", totalTimeActive]];
    
    [super saveUnsentActiveTime:totalTimeActive];
    [self sendOnFocusCallWithParams:params totalTimeActive:totalTimeActive];
}

- (void)sendUnsentActiveTime:(OSFocusCallParams *)params {
    let unsentActive = [super getUnsentActiveTime];
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE
                     message:[NSString stringWithFormat:@"sendUnsentActiveTime attributed with unsentActive %f", unsentActive]];
    
    [self sendOnFocusCallWithParams:params totalTimeActive:unsentActive];
}

- (void)sendOnFocusCallWithParams:(OSFocusCallParams *)params totalTimeActive:(NSTimeInterval)totalTimeActive {
    if (!params.userId)
        return;
    
    [self beginDelayBackgroungTask];
    restCallTimer = [NSTimer
        scheduledTimerWithTimeInterval:DELAY_TIME
                               target:self
                             selector:@selector(sendBackgroundAttributedFocusPing:)
                             userInfo:@{@"params": params, @"time": @(totalTimeActive)}
                              repeats:false
    ];
}

- (void)sendBackgroundAttributedFocusPing:(NSTimer*)timer {
    let userInfo = (NSDictionary<NSString*, id>*)timer.userInfo;
    let params = (OSFocusCallParams*)userInfo[@"params"];
    let totalTimeActive = (NSNumber*)userInfo[@"time"];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"beginBackgroundAttributedFocusTask start"];
        
        let requests = [NSMutableDictionary new];
    
        requests[@"push"] = [OSRequestOnFocus withUserId:params.userId appId:params.appId activeTime:totalTimeActive netType:params.netType emailAuthToken:nil deviceType:@(DEVICE_TYPE_PUSH) directSession:params.direct notificationIds:params.notificationIds];
        
        // For email we omit additionalFieldsToAddToOnFocusPayload as we don't want to add
        //   outcome fields which would double report the session time
        if (params.emailUserId)
            requests[@"email"] = [OSRequestOnFocus withUserId:params.emailUserId appId:params.appId activeTime:totalTimeActive netType:params.netType emailAuthToken:params.emailAuthToken deviceType:@(DEVICE_TYPE_EMAIL)];

        [OneSignalClient.sharedClient executeSimultaneousRequests:requests withSuccess:^(NSDictionary *result) {
            [super saveUnsentActiveTime:0];
            [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"sendBackgroundAttributedFocusPing attributed succeed, saveUnsentActiveTime with 0"];
        } onFailure:nil];
        
        [self endDelayBackgroungTask];
    });
}

- (void)cancelDelayedJob {
    if (!restCallTimer)
        return;
    
    [restCallTimer invalidate];
    restCallTimer = nil;
    [self endDelayBackgroungTask];
}

@end
