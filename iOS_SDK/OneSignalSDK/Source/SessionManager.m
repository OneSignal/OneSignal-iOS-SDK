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
#import "SessionManager.h"
#import "OneSignalCommonDefines.h"
#import "NotificationData.h"
#import "LastNotification.h"
#import "OneSignal.h"

const int TWENTY_FOUR_HOURS_SECONDS = 24 * 60 * 60;
const int HALF_MINUTE_SECONDS = 30;

@interface SessionManager ()
@property (nonatomic, readwrite) SessionState session;
@end

@implementation SessionManager

- (id) init {
    _session = NONE;
    return self;
}

- (void)restartSession {
    _session = NONE;
    [self onSessionStarted];
}

- (void)onSessionStarted {
    if (_session != NONE) {
        return;
    }

    LastNotification *lastNotification = [NotificationData getLastNotification];
    NSString *notificationId = lastNotification.notificationId;
    double notificationTime = lastNotification.arrivalTime;
    BOOL wasOnBackground = lastNotification.wasOnBackground;
    
    if (notificationId == nil || [notificationId length] == 0) {
        [self onSessionNotInfluenced];
    } else {
        NSTimeInterval currentTime = [[NSDate date] timeIntervalSince1970];
        long difference = currentTime - notificationTime;
        [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"Last notification time difference: %ld", difference]];

        if (wasOnBackground && difference < HALF_MINUTE_SECONDS) {
            [self onSessionFromNotification];
        } else if (difference < TWENTY_FOUR_HOURS_SECONDS) {
            [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"Influenced sesssion"];
            _session = INDIRECT;
        } else {
            [self onSessionNotInfluenced];
        }
    }
}

- (void)onSessionNotInfluenced {
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"Not influenced sesssion"];
    _session = UNATTRIBUTED;
}

- (void)onSessionFromNotification {
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"Direct sesssion"];
    _session = DIRECT;
}
@end
