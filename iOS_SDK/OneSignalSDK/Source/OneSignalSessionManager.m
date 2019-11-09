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
#import "OneSignal.h"
#import "OneSignalHelper.h"
#import "OSOutcomesUtils.h"
#import "OneSignalInternal.h"
#import "OneSignalCommonDefines.h"
#import "OneSignalSessionManager.h"

@implementation OneSignalSessionManager

- (instancetype _Nonnull)init:(id<SessionStatusDelegate>)delegate {
    if (self = [super init]) {
        [self initSessionFromCache];
        self.delegate = delegate;
    }
    return self;
}

/*
 TODO: comment
 */
- (void)initSessionFromCache {
    self.session = [OSOutcomesUtils getCachedSession];
    self.directNotificationId = [OSOutcomesUtils getCachedDirectNotificationId];
    self.indirectNotificationIds = [OSOutcomesUtils getCachedIndirectNotificationIds];
    
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"Session restored from cache with:  \nsession: %@  \ndirectNotificationsId: %@  \nindirectNotificationsIds: %@",
                                                       OS_SESSION_TO_STRING(self.session),
                                                       self.directNotificationId,
                                                       self.indirectNotificationIds]];
}

/*
 TODO: comment
 */
- (void)restartSessionIfNeeded {
    if (OneSignal.appEntryState && OneSignal.appEntryState == NOTIFICATION_CLICK)
        return;
    
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"Session is restarting, checking if the session should be INDIRECT or DIRECT"];
    
    NSArray *indirectNotificationIds = [self getIndirectNotificationIds];
    if (indirectNotificationIds && [indirectNotificationIds count] > 0)
        [self setSession:INDIRECT directNotificationId:nil indirectNotificationIds:indirectNotificationIds];
    else
        [self setSession:UNATTRIBUTED directNotificationId:nil indirectNotificationIds:nil];
}

/*
 TODO: comment
 */
- (void)onDirectSessionFromNotificationOpen:(NSString *)directNotificationId {
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"Session from notification open with:  \nsession: %@  \ndirectNotificationsId: %@  \nindirectNotificationsIds: %@",
                                                       OS_SESSION_TO_STRING(DIRECT),
                                                       directNotificationId,
                                                       nil]];
    
    [self setSession:DIRECT directNotificationId:directNotificationId indirectNotificationIds:nil];
}

/*
 TODO: comment
 */
- (BOOL)willChangeSession:(Session)session directNotificationId:(NSString *)directNotificationId indirectNotificationIds:(NSArray *)indirectNotificationIds {
    if (self.session != session)
        return true;

    // Allow updating a direct session to a new direct when a new notification is clicked
    if (session == DIRECT &&
        directNotificationId &&
        ![self.directNotificationId isEqualToString:directNotificationId]) {
        return true;
    }

    // Allow updating an indirect session to a new indirect when a new notification is received
    if (session == INDIRECT &&
        indirectNotificationIds &&
        [indirectNotificationIds count] > 0 &&
        ![self.indirectNotificationIds isEqualToArray:indirectNotificationIds]) {
        return true;
    }

    return false;
}

- (Session)getSession {
    return self.session;
}

/*
 TODO: comment
 */
- (void)setSession:(Session)session directNotificationId:(NSString *)directNotificationId indirectNotificationIds:(NSArray *)indirectNotificationIds {
    if (![self willChangeSession:session directNotificationId:directNotificationId indirectNotificationIds:indirectNotificationIds])
        return;
    
    NSString *message = @"OSSession changed  \nfrom:  \nsession: %@  \n, directNotificationId: %@  \n, indirectNotificationIds: %@  \nto:  \nsession: %@  \n, directNotificationId: %@  \n, indirectNotificationIds: %@";
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:message,
                                                       OS_SESSION_TO_STRING(self.session),
                                                       self.directNotificationId,
                                                       self.indirectNotificationIds,
                                                       OS_SESSION_TO_STRING(session),
                                                       directNotificationId,
                                                       indirectNotificationIds]];
    
    // Cache all new session data
    [OSOutcomesUtils saveSession:session];
    [OSOutcomesUtils saveDirectNotificationId:directNotificationId];
    [OSOutcomesUtils saveIndirectNotifications:indirectNotificationIds];
    
    // Call delegate for ending the session
    OSSessionResult *sessionResult = [self getSessionResult];
    if (self.delegate)
        [self.delegate onSessionEnding:sessionResult];
    
    // Assign all new data to session manager instance attributes
    self.session = session;
    self.directNotificationId = directNotificationId;
    self.indirectNotificationIds = indirectNotificationIds;
}

/*
 Attempt to override the current session before the 30 second session minimum
 This should only be done in a upward direction:
    * UNATTRIBUTED -> INDIRECT
    * UNATTRIBUTED -> DIRECT
    * INDIRECT     -> DIRECT
    * DIRECT       -> DIRECT
 */
- (void)attemptSessionUpgrade {
    NSString *directNotificationId = [OSOutcomesUtils getCachedDirectNotificationId];
    if (directNotificationId) {
        [self setSession:DIRECT directNotificationId:directNotificationId indirectNotificationIds:nil];
        return;
    }
        
    if (self.getSession == UNATTRIBUTED) {
        NSArray *indirectNotificationIds = [self getIndirectNotificationIds];
        if (indirectNotificationIds && [indirectNotificationIds count] > 0) {
            [self setSession:INDIRECT directNotificationId:nil indirectNotificationIds:indirectNotificationIds];
        }
    }
}

/*
 TODO: comment
 */
- (OSSessionResult *)getSessionResult {
    if (self.session == DIRECT && self.directNotificationId) {
        if ([OSOutcomesUtils isDirectSessionEnabled]) {
            NSArray *notificationIds = [NSArray arrayWithObject:self.directNotificationId];
            return [[OSSessionResult alloc] init:DIRECT withNotificationIds:notificationIds];
        }
        
    } else if (self.session == INDIRECT && self.indirectNotificationIds) {
        if ([OSOutcomesUtils isIndirectSessionEnabled]) {
            return [[OSSessionResult alloc] init:INDIRECT withNotificationIds:self.indirectNotificationIds];
        }
        
    } else if ([OSOutcomesUtils isUnattributedSessionEnabled]) {
        return [[OSSessionResult alloc] init:UNATTRIBUTED];
    }
    
    return [[OSSessionResult alloc] init:DISABLED];
}

/*
 TODO: comment
 */
- (NSArray *)getIndirectNotificationIds {
    NSArray *receivedNotifications = [OSOutcomesUtils getCachedReceivedNotifications];
    if (!receivedNotifications || [receivedNotifications count] == 0)
        // Unattributed session
        return nil;
    
    NSMutableArray *notificationsIds = [NSMutableArray new];
    NSInteger attributionWindowInSeconds = [OSOutcomesUtils getIndirectAttributionWindow] * 60;
    NSTimeInterval currentTime = [[NSDate date] timeIntervalSince1970];

    for (OSIndirectNotification *notification in receivedNotifications) {
        long difference = currentTime - notification.arrivalTime;
        if (difference <= attributionWindowInSeconds) {
            [notificationsIds addObject:notification.notificationId];
        }
    }
    
    return notificationsIds;
}

@end
