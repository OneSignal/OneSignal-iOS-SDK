/**
 * Modified MIT License
 *
 * Copyright 2021OneSignal
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

#import "OSNotification+OneSignal.h"
#import <OneSignalCore/OneSignalCore.h>
#import <UIKit/UIKit.h>

@interface OSNotification ()
- (void)initWithRawMessage:(NSDictionary*)message;
@end

@implementation OSDisplayableNotification

OSNotificationDisplayResponse _completion;
NSTimer *_timeoutTimer;
BOOL _wantsToDisplay = true;

+ (instancetype)parseWithApns:(nonnull NSDictionary*)message {
    if (!message)
        return nil;
    
    OSDisplayableNotification *osNotification = [OSDisplayableNotification new];
    
    [osNotification initWithRawMessage:message];
    [osNotification setTimeoutTimer];
    return osNotification;
}

- (void)setTimeoutTimer {
    _timeoutTimer = [NSTimer timerWithTimeInterval:CUSTOM_DISPLAY_TYPE_TIMEOUT target:self selector:@selector(timeoutTimerFired:) userInfo:self.notificationId repeats:false];
}

- (void)startTimeoutTimer {
    [[NSRunLoop currentRunLoop] addTimer:_timeoutTimer forMode:NSRunLoopCommonModes];
}

- (void)setCompletionBlock:(OSNotificationDisplayResponse)completion {
    _completion = completion;
}

- (void)display {
    if (!_completion) {
        [OneSignalLog onesignalLog:ONE_S_LL_ERROR message:@"OSNotificationWillDisplayEvent.notification.display cannot be called due to timing out or notification was already displayed."];
    }
    [self complete:self];
}

- (void)complete:(OSDisplayableNotification *)notification {
    [_timeoutTimer invalidate];
    /*
     If notification is null here then display was cancelled and we need to
     reset the badge count to the value prior to receipt of this notif
     */
    if (!notification) {
        NSInteger previousBadgeCount = [UIApplication sharedApplication].applicationIconBadgeNumber;
        [OneSignalUserDefaults.initShared saveIntegerForKey:ONESIGNAL_BADGE_KEY withValue:previousBadgeCount];
    }
    if (_completion) {
        _completion(notification);
        _completion = nil;
    }
}

- (BOOL)wantsToDisplay {
    return _wantsToDisplay;
}

- (void)setWantsToDisplay:(BOOL)display {
    _wantsToDisplay = display;
}

- (void)timeoutTimerFired:(NSTimer *)timer {
    [OneSignalLog onesignalLog:ONE_S_LL_WARN message:[NSString stringWithFormat:@"OSNotificationLifecycleListener:onWillDisplayNotification timed out. Display was not called within %f seconds. Continue with display notification: %d", CUSTOM_DISPLAY_TYPE_TIMEOUT, _wantsToDisplay]];
    if (_wantsToDisplay) {
        [self complete:self];
    } else {
        [self complete:nil];
    }
}

- (void)dealloc {
    if (_timeoutTimer && _completion) {
        [_timeoutTimer invalidate];
    }
}
@end
