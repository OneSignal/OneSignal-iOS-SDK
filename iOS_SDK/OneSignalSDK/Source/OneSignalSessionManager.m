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

NSArray *indirectNotificationIds = nil;
NSString *directNotificationId = nil;

static id<SessionStatusDelegate> _delegate;
+ (void)setDelegate:(id<SessionStatusDelegate>)delegate {
    _delegate = delegate;
}

static SessionState _session = NONE;
+ (SessionState)session { return _session; }

+ (void)initLastSession {
    NSArray *notificationsIds;
    SessionState lastSession = [OSOutcomesUtils getLastSession:&notificationsIds];
    
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"Session lastSession: %@ notificationsIds: %@", sessionStateString(lastSession), notificationsIds]];
    _session = lastSession;
    
    if (_session == NONE) {
        //First Session Init
        [self onSessionStarted];
        return;
    }
    
    switch (_session) {
        case DIRECT:
            directNotificationId = [notificationsIds firstObject];
            break;
        case INDIRECT:
            indirectNotificationIds = notificationsIds;
            break;
        default:
            break;
    }
    
    OSSessionResult *lastSessionResult = [self sessionResult];
    //Override session if one with more priority recently happened
    BOOL upgraded = [self attemptSessionUpgrade];
    
    if (upgraded) {
        NSArray *notificationIds = _session == DIRECT ? [NSArray arrayWithObject:directNotificationId] : indirectNotificationIds;
        [OSOutcomesUtils saveLastSession:_session notificationIds:notificationIds];
        
        if (_delegate)
            [_delegate onSessionEnding:lastSessionResult];
    }
}

+ (void)restartSession {
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"Session restarted"];
    OSSessionResult *lastSessionResult = [self sessionResult];
    SessionState lastSession = _session;
    NSString *lastDirectNotificationId = directNotificationId;
    NSArray *lastIndirectNotificationIds = indirectNotificationIds;
    
    [self clearSessionData];
    [self onSessionStarted];
    
    BOOL sessionChanged = [self hasSessionChanged:lastSession lastDirectNotificationId:lastDirectNotificationId lastIndirectNotificationIds:lastIndirectNotificationIds];
    if (sessionChanged &&_delegate) {
        [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"Session changed ending last session"];
        [_delegate onSessionEnding:lastSessionResult];
    }
}

+ (void)clearSessionData {
    _session = NONE;
    directNotificationId = nil;
    indirectNotificationIds = nil;
    [OSOutcomesUtils saveLastSession:NONE notificationIds:nil];
}

+ (void)onSessionStarted {
    [self setNotificationsReceived];
    NSArray *notificationIds;
    
    if (directNotificationId) {
        notificationIds = [NSArray arrayWithObject:directNotificationId];
        [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"Direct session with notification: %@", directNotificationId]];
        _session = DIRECT;
    } else if (indirectNotificationIds && [indirectNotificationIds count] > 0) {
        notificationIds = indirectNotificationIds;
        [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"Indirect session"];
        _session = INDIRECT;
    } else {
        notificationIds = nil;
        [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"Not influenced session"];
        _session = UNATTRIBUTED;
    }
    
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"Session saveLastSession: %@ notificationsIds: %@", sessionStateString(_session), notificationIds]];
    [OSOutcomesUtils saveLastSession:_session notificationIds:notificationIds];
}

+ (void)onSessionFromNotification:(NSString *)notificationId {
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"onSessionFromNotification session with notification: %@", directNotificationId]];
    BOOL sessionUpdated = [self setSession:DIRECT newDirectNotificationId:notificationId newIndirectNotificationIds:nil];
    if (sessionUpdated) {
        [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"Direct session with notification: %@", directNotificationId]];
        //What will happend if application was closen and not in background
        [OSOutcomesUtils saveOpenedByNotification:notificationId];
    }
}

+ (BOOL)compareSessions:(SessionState)currentSession currentDirectNotificationId:(NSString *)currentDirectNotificationId currentIndirectNotificationIds:(NSArray *)currentIndirectNotificationIds newSession:(SessionState)newSession newDirectNotificationId:(NSString *)newDirectNotificationId newIndirectNotificationIds:(NSArray *)newIndirectNotificationIds {
      if (currentSession != newSession)
          return true;

      // Allow updating a direct session to a new direct when a new notification is clicked
      if (currentSession == DIRECT &&
          newDirectNotificationId != nil &&
              currentDirectNotificationId != newDirectNotificationId) {
          return true;
      }

      // Allow updating an indirect session to a new indirect when a new notification is received
      if (currentSession == INDIRECT &&
         newIndirectNotificationIds != nil &&
         [newIndirectNotificationIds count] > 0 &&
          ![newIndirectNotificationIds isEqualToArray:currentIndirectNotificationIds]) {
          return true;
      }

      return false;
}

+ (BOOL)hasSessionChanged:(SessionState)lastSession lastDirectNotificationId:(NSString *)lastDirectNotificationId lastIndirectNotificationIds:(NSArray *)lastIndirectNotificationIds {
    return [self compareSessions:lastSession currentDirectNotificationId:lastDirectNotificationId currentIndirectNotificationIds:lastIndirectNotificationIds newSession:_session newDirectNotificationId:directNotificationId newIndirectNotificationIds:indirectNotificationIds];
}

+ (BOOL)willChangeSession:(SessionState)newSession newDirectNotificationId:(NSString *)newDirectNotificationId newIndirectNotificationIds:(NSArray *)newIndirectNotificationIds {
    return [self compareSessions:_session currentDirectNotificationId:directNotificationId currentIndirectNotificationIds:indirectNotificationIds newSession:newSession newDirectNotificationId:newDirectNotificationId newIndirectNotificationIds:newIndirectNotificationIds];
}

+ (BOOL)setSession:(SessionState)newSession newDirectNotificationId:(NSString *)newDirectNotificationId newIndirectNotificationIds:(NSArray *)newIndirectNotificationIds {
    if (![self willChangeSession:newSession newDirectNotificationId:newDirectNotificationId newIndirectNotificationIds:newIndirectNotificationIds])
        return false;
    
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:[NSString
                                                       stringWithFormat:@"OSSession changed from session %@ with direct notification %@ indirect notification %@ to session %@ direct notification %@ indirect notification %@", sessionStateString(_session), directNotificationId, indirectNotificationIds, sessionStateString(newSession), newDirectNotificationId, newIndirectNotificationIds]];
    
    OSSessionResult *lastSessionResult = [self sessionResult];
    if (_delegate)
        [_delegate onSessionEnding:lastSessionResult];

    _session = newSession;
    directNotificationId = newDirectNotificationId;
    indirectNotificationIds = newIndirectNotificationIds;
    
    return true;
}

/**
    Attempt to override the current session before the 30 second session minimum
    This should only be done in a upward direction:
      * UNATTRIBUTED can become INDIRECT or DIRECT
      * INDIRECT can become DIRECT
      * DIRECT can become DIRECT
*/
+ (BOOL)attemptSessionUpgrade {
    NSString *lastDirectNotificationId = [OSOutcomesUtils wasOpenedByNotification];
    if (lastDirectNotificationId) {
        return [self setSession:DIRECT newDirectNotificationId:lastDirectNotificationId newIndirectNotificationIds:nil];
    }
        
    if (_session == UNATTRIBUTED) {
        NSArray *lastNotificationsReceivedIds = [self getLastNotificationsReceivedIds];
        if (lastNotificationsReceivedIds && [lastNotificationsReceivedIds count] > 0) {
            return [self setSession:INDIRECT newDirectNotificationId:nil newIndirectNotificationIds:lastNotificationsReceivedIds];
        }
    }
    
    return false;
}

+ (OSSessionResult *)sessionResult {
    if (_session == DIRECT && directNotificationId) {
        if ([OSOutcomesUtils isDirectSessionEnabled]) {
            NSArray *notificationIds = [NSArray arrayWithObject:directNotificationId];
        
            return [[OSSessionResult alloc] initWithNotificationIds:notificationIds session:DIRECT];
        }
    } else if (_session == INDIRECT && indirectNotificationIds) {
        if ([OSOutcomesUtils isIndirectSessionEnabled])
             return [[OSSessionResult alloc] initWithNotificationIds:indirectNotificationIds session:INDIRECT];
    } else if ([OSOutcomesUtils isUnattributedSessionEnabled]) {
         return [[OSSessionResult alloc] initWithSession:UNATTRIBUTED];
    }
    
    return [[OSSessionResult alloc] initWithSession:DISABLED];
}

+ (void)setNotificationsReceived {
    [self setDirectSessionIfExists];
    if (directNotificationId)
        return;
    
    directNotificationId = nil;
    indirectNotificationIds = [self getLastNotificationsReceivedIds];
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"Session notifications: %@", indirectNotificationIds]];
}

+ (void)setDirectSessionIfExists {
    if (directNotificationId) {
        //Direct session was recently set
        indirectNotificationIds = nil;
        return;
    }
    
    NSString *lastDirectNotificationId = [OSOutcomesUtils wasOpenedByNotification];
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"Session lastDirectNotificationId: %@", lastDirectNotificationId]];
    
    if (lastDirectNotificationId) {
        //Direct session from application being closed and opened by notification
        directNotificationId = lastDirectNotificationId;
        indirectNotificationIds = nil;
        [OSOutcomesUtils saveOpenedByNotification:nil];
    }
}

+ (NSArray *)getLastNotificationsReceivedIds {
    NSArray *lastNotifications = [OSOutcomesUtils getNotifications];
    if (!lastNotifications || [lastNotifications count] == 0)
        //Unattributed session
        return nil;
    
    NSMutableArray *notificationsIds = [NSMutableArray new];
    NSInteger attributionWindowInSeconds = [OSOutcomesUtils getIndirectAttributionWindow] * 60;
    NSTimeInterval currentTime = [[NSDate date] timeIntervalSince1970];
   
    for (OSLastNotification *notification in lastNotifications) {
        long difference = currentTime - notification.arrivalTime;
        if (difference <= attributionWindowInSeconds) {
            [notificationsIds addObject:notification.notificationId];
        }
    }
    
    return notificationsIds;
}

@end
