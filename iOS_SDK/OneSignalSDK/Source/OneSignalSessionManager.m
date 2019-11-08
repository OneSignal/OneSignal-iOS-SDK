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

#import <Foundation/Foundation.h>
#import "OneSignalSessionManager.h"
#import "OneSignalCommonDefines.h"
#import "OneSignalHelper.h"
#import "OSOutcomesUtils.h"
#import "OneSignal.h"

const int TWENTY_FOUR_HOURS_SECONDS = 24 * 60 * 60;
const int MAX_DIRECT_SESSION_TIME_SET = 10;

@implementation OneSignalSessionManager

NSArray *notificationsReceived = nil;
NSString *lastNotificationId = nil;

static id<SessionStatusDelegate> _delegate;
+ (void)setDelegate:(id<SessionStatusDelegate>)delegate {
    _delegate = delegate;
}

static SessionState _session = UNATTRIBUTED;
+ (SessionState)session { return _session; }

+ (void)initLastSession {
    NSArray *notificationsIds;
    SessionState lastSession = [OSOutcomesUtils getLastSession:&notificationsIds];
    
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"Session lastSession: %@ notificationsIds: %@", sessionStateString(lastSession), notificationsIds]];
    _session = lastSession;
    
    switch (_session) {
        case DIRECT:
            lastNotificationId = [notificationsIds firstObject];
            break;
        case INDIRECT:
            [self setDirectSession];
            if (lastNotificationId) {
                _session = DIRECT;
            } else {
                notificationsReceived = notificationsIds;
            }
            break;
        default:
            //Override session if one with more priority recently happened
            [self onSessionStarted];
            break;
    }
}

+ (void)restartSession {
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"Session restarted"];
    [self clearSessionData];
    
    [self onSessionStarted];
    if (_delegate)
        [_delegate onSessionRestart];
}

+ (void)clearSessionData {
    _session = UNATTRIBUTED;
    lastNotificationId = nil;
    notificationsReceived = nil;
    [OSOutcomesUtils saveLastSession:UNATTRIBUTED notificationIds:nil];
}

+ (void)onSessionStarted {
    [self setNotificationsReceived];
    NSArray *notificationIds;
    
    if (lastNotificationId) {
        notificationIds = [NSArray arrayWithObject:lastNotificationId];
        [self onSessionDirect];
    } else if (notificationsReceived && [notificationsReceived count] > 0) {
        notificationIds = notificationsReceived;
        [self onSessionInfluenced];
    } else {
        notificationIds = nil;
        [self onSessionNotInfluenced];
    }
    
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"Session saveLastSession: %@ notificationsIds: %@", sessionStateString(_session), notificationIds]];
    [OSOutcomesUtils saveLastSession:_session notificationIds:notificationIds];
}

+ (void)setDirectSession {
    if (lastNotificationId)
        //Direct session was recently set
        return;
    
    NSString *directNotificationId = [OSOutcomesUtils wasOpenedByNotification];
    if (directNotificationId) {
        //Direct session from application being closed and opened by notification
        lastNotificationId = directNotificationId;
        notificationsReceived = nil;
        [OSOutcomesUtils saveOpenedByNotification:nil];
    }
}

+ (void)setNotificationsReceived {
    [self setDirectSession];
    if (lastNotificationId)
        return;
    
    NSArray *lastNotifications = [OSOutcomesUtils getNotifications];
    if (!lastNotifications || [lastNotifications count] == 0)
        //Unattributed session
        return;
    
    NSMutableArray *notificationsIds = [NSMutableArray new];
    NSInteger attributionWindowInSeconds = [OSOutcomesUtils getIndirectAttributionWindow] * 60;
    NSTimeInterval currentTime = [[NSDate date] timeIntervalSince1970];
    
    for (OSLastNotification *notification in lastNotifications) {
        long difference = currentTime - notification.arrivalTime;
        if (difference <= attributionWindowInSeconds) {
            [notificationsIds addObject:notification.notificationId];
        }
    }
    
    lastNotificationId = nil;
    notificationsReceived = notificationsIds;
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"Session notifications: %@", notificationsReceived]];
}

+ (void)onSessionNotInfluenced {
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"Not influenced session"];
    _session = UNATTRIBUTED;
}

+ (void)onSessionInfluenced {
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"Indirect session"];
    _session = INDIRECT;
}

+ (void)onSessionDirect {
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"Direct session with notification: %@", lastNotificationId]];
    _session = DIRECT;
}

+ (void)onSessionFromNotification:(NSString *)notificationId {
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"onSessionFromNotification session with notification: %@", lastNotificationId]];
    lastNotificationId = notificationId;
    [self onSessionDirect];
    
    [OSOutcomesUtils saveOpenedByNotification:notificationId];
}

+ (OSSessionResult *)sessionResult {
    if (_session == DIRECT && lastNotificationId) {
        if ([OSOutcomesUtils isDirectSessionEnabled]) {
            NSArray *notificationIds = [NSArray arrayWithObject:lastNotificationId];
        
            return [[OSSessionResult alloc] initWithNotificationIds:notificationIds session:DIRECT];
        }
    } else if (_session == INDIRECT && notificationsReceived) {
        if ([OSOutcomesUtils isIndirectSessionEnabled])
             return [[OSSessionResult alloc] initWithNotificationIds:notificationsReceived session:INDIRECT];
    } else if ([OSOutcomesUtils isUnattributedSessionEnabled]) {
         return [[OSSessionResult alloc] initWithSession:UNATTRIBUTED];
    }
    
    return [[OSSessionResult alloc] initWithSession:DISABLED];
}
@end
