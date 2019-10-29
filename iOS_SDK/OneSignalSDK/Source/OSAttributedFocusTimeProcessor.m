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

const int ATTRIBUTED_MIN_SESSION_TIME = 1;
const int SESSION_TIME = 30;

@implementation OSAttributedFocusTimeProcessor

static UIBackgroundTaskIdentifier delayBackgroundTask;
static UIBackgroundTaskIdentifier attributedFocusBackgroundTask;

- (void)beginDelayBackgroungTask {
    NSLog(@"beginDelayBackgroungTask start");
    delayBackgroundTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
           [self endDelayBackgroungTask];
    }];
}

- (void)endDelayBackgroungTask {
    [[UIApplication sharedApplication] endBackgroundTask: delayBackgroundTask];
    delayBackgroundTask = UIBackgroundTaskInvalid;
    NSLog(@"endDelayBackgroungTask end");
}

- (void)beginBackgroundAttributedFocusTask {
    NSLog(@"beginBackgroundAttributedFocusTask start");
    attributedFocusBackgroundTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [self endBackgroundAttributedFocusTask];
    }];
}

- (void)endBackgroundAttributedFocusTask {
    [[UIApplication sharedApplication] endBackgroundTask: attributedFocusBackgroundTask];
    attributedFocusBackgroundTask = UIBackgroundTaskInvalid;
    NSLog(@"endBackgroundAttributedFocusTask end");
}

- (int)getMinSessionTime {
    return ATTRIBUTED_MIN_SESSION_TIME;
}

- (void)sendOnFocusCall:(OSFocusCallParams *)params {
    NSTimeInterval unsentActive = [super getUnsentActiveTime];
    NSTimeInterval totalTimeActive = unsentActive + [params timeElapsed];
    NSLog(@"sendOnFocusCall attributed %f", totalTimeActive);
    [super saveUnsentActiveTime:totalTimeActive];
    [self sendOnFocusCallWithParams:params totalTimeActive:totalTimeActive];
}

- (void)sendUnsentActiveTime:(OSFocusCallParams *)params {
    NSTimeInterval unsentActive = [super getUnsentActiveTime];
    NSLog(@"sendUnsentActiveTime attributed %f", unsentActive);
    [self sendOnFocusCallWithParams:params totalTimeActive:unsentActive];
}

- (void)sendOnFocusCallWithParams:(OSFocusCallParams *)params totalTimeActive:(NSTimeInterval)totalTimeActive {
    if (![params userId]) {
        NSLog(@"mUserId null");
        return;
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self beginDelayBackgroungTask];
        [super setOnFocusCallEnabled:YES];
        NSLog(@"sendDelayBackgroundTask start sleep");

        [NSThread sleepForTimeInterval: SESSION_TIME];
        
        NSLog(@"sendDelayBackgroundTask after sleep focus call enabled %@", [super onFocusCallEnabled] ? @"YES" : @"NO" );

        if ([super onFocusCallEnabled]) {
            NSLog(@"sendDelayBackgroundTask end sleep start sendBackgroundAttributedFocusPing");
            [self sendBackgroundAttributedFocusPing:params totalTimeActive:totalTimeActive];
        }
        NSLog(@"sendDelayBackgroundTask end");
        [self endDelayBackgroungTask];
    });
}

- (void)sendBackgroundAttributedFocusPing:(OSFocusCallParams *)params totalTimeActive:(NSTimeInterval)totalTimeActive {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self beginBackgroundAttributedFocusTask];
        NSLog(@"sendBackgroundAttributedFocusPing start");
        
        NSNumber *deviceType = [NSNumber numberWithInt:DEVICE_TYPE];
        NSMutableDictionary *requests = [NSMutableDictionary new];
    
        requests[@"push"] = [OSRequestOnFocus withUserId:[params userId] appId:[params appId] state:@"ping" type:@1 activeTime:@(totalTimeActive) netType:[params netType] emailAuthToken:nil deviceType:deviceType directSession:[params direct] notificationIds:[params notificationIds]];
        
        if ([params emailUserId])
            requests[@"email"] = [OSRequestOnFocus withUserId:[params emailUserId] appId:[params appId] state:@"ping" type:@1 activeTime:@(totalTimeActive) netType:[params netType] emailAuthToken:[params emailAuthToken] deviceType:deviceType directSession:[params direct] notificationIds:[params notificationIds]];

        [OneSignalClient.sharedClient executeSimultaneousRequests:requests withSuccess:^(NSDictionary *result) {
            [super saveUnsentActiveTime:0];
            NSLog(@"sendBackgroundAttributedFocusPing succed");
        } onFailure:nil];
        
        NSLog(@"sendBackgroundAttributedFocusPing end");
        [self endBackgroundAttributedFocusTask];
    });
}

@end
