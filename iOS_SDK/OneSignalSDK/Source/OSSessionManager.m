/**
 Modified MIT License

 Copyright 2019 OneSignal

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 1. The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.

 2. All copies of substantial portions of the Software may only be used in connection
 with services provided by OneSignal.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
 */

#import <Foundation/Foundation.h>
#import "OneSignal.h"
#import "OneSignalHelper.h"
#import "OSInfluenceDataDefines.h"
#import "OneSignalInternal.h"
#import "OneSignalCommonDefines.h"
#import "OSSessionManager.h"

@interface OSSessionManager ()

@property (strong, nonatomic, readwrite, nonnull) OSTrackerFactory *trackerFactory;

@end

@implementation OSSessionManager

- (instancetype _Nonnull)init:(Class<SessionStatusDelegate>)delegate withTrackerFactory:(OSTrackerFactory *)trackerFactory {
    if (self = [super init]) {
        _delegate = delegate;
        _trackerFactory = trackerFactory;
        [self initSessionFromCache];
    }
    return self;
}

- (NSArray <OSInfluence *> *)getInfluences {
    return [_trackerFactory influences];
}

- (NSArray<OSInfluence *> *)getSessionInfluences {
    return [_trackerFactory sessionInfluences];
}

- (void)initSessionFromCache {
    [OneSignal onesignal_Log:ONE_S_LL_DEBUG message:@"OneSignal SessionManager initSessionFromCache"];
    [_trackerFactory initFromCache];
    [OneSignal onesignal_Log:ONE_S_LL_DEBUG message:[NSString stringWithFormat:@"SessionManager restored from cache with influences: %@", [self getInfluences].description]];
}

- (void)restartSessionIfNeeded:(AppEntryAction)entryAction {
    NSArray<OSChannelTracker *> *channelTrackers = [_trackerFactory channelsToResetByEntryAction:entryAction];
    NSMutableArray<OSInfluence *> *updatedInfluences = [NSMutableArray new];
    
    [OneSignal onesignal_Log:ONE_S_LL_DEBUG message:[NSString stringWithFormat:@"OneSignal SessionManager restartSessionIfNeeded with entryAction:: %u channelTrackers: %@", entryAction, channelTrackers.description]];

    for (OSChannelTracker *channelTracker in channelTrackers) {
        NSArray *lastIds = [channelTracker lastReceivedIds];
        [OneSignal onesignal_Log:ONE_S_LL_DEBUG message:[NSString stringWithFormat:@"OneSignal SessionManager restartSessionIfNeeded lastIds: %@", lastIds]];

        OSInfluence *influence = [channelTracker currentSessionInfluence];
        BOOL updated;
        if (lastIds.count > 0)
            updated = [self setSessionForChannel:channelTracker withInfluenceType:INDIRECT directNotificationId:nil indirectNotificationIds:lastIds];
        else
            updated = [self setSessionForChannel:channelTracker withInfluenceType:UNATTRIBUTED directNotificationId:nil indirectNotificationIds:nil];

        if (updated)
            [updatedInfluences addObject:influence];
    }
    
    [self sendSessionEndingWithInfluences:updatedInfluences];
}

- (void)onInAppMessageReceived:(NSString *)messageId {
    [OneSignal onesignal_Log:ONE_S_LL_DEBUG message:[NSString stringWithFormat:@"OneSignal SessionManager onInAppMessageReceived messageId: %@", messageId]];
    
    OSChannelTracker *inAppMessageTracker = [_trackerFactory iamChannelTracker];
    [inAppMessageTracker saveLastId:messageId];
    [inAppMessageTracker resetAndInitInfluence];
}

- (void)onDirectInfluenceFromIAMClick:(NSString *)directIAMId {
    [OneSignal onesignal_Log:ONE_S_LL_DEBUG message:[NSString stringWithFormat:@"OneSignal SessionManager onDirectInfluenceFromIAMClick messageId: %@", directIAMId]];
    
    OSChannelTracker *inAppMessageTracker = [_trackerFactory iamChannelTracker];
    // We don't care about ending the session duration because IAM doesn't influence a session
    [self setSessionForChannel:inAppMessageTracker withInfluenceType:DIRECT directNotificationId:directIAMId indirectNotificationIds:nil];
}

- (void)onDirectInfluenceFromIAMClickFinished {
    [OneSignal onesignal_Log:ONE_S_LL_DEBUG message:@"OneSignal SessionManager onDirectInfluenceFromIAMClickFinished"];
    
    OSChannelTracker *inAppMessageTracker = [_trackerFactory iamChannelTracker];
    [inAppMessageTracker resetAndInitInfluence];
}

- (void)onNotificationReceived:(NSString *)notificationId {
    [OneSignal onesignal_Log:ONE_S_LL_DEBUG message:[NSString stringWithFormat:@"OneSignal SessionManager onNotificationReceived notificationId: %@", notificationId]];

    if (notificationId == nil || notificationId.length == 0)
        return;

    OSChannelTracker *notificationTracker = [_trackerFactory notificationChannelTracker];
    [notificationTracker saveLastId:notificationId];
}

- (void)onDirectInfluenceFromNotificationOpen:(AppEntryAction)entryAction withNotificationId:(NSString *)directNotificationId {
    [OneSignal onesignal_Log:ONE_S_LL_DEBUG message:[NSString stringWithFormat:@"OneSignal SessionManager onDirectInfluenceFromNotificationOpen notificationId: %@", directNotificationId]];

    if (directNotificationId == nil || directNotificationId.length == 0)
        return;
    
    [self attemptSessionUpgrade:entryAction withDirectId:directNotificationId];
}

/*
 Attempt to override the current session before the 30 second session minimum
 This should only be done in a upward direction:
    * UNATTRIBUTED -> INDIRECT
    * UNATTRIBUTED -> DIRECT
    * INDIRECT     -> DIRECT
    * DIRECT       -> DIRECT
 */
- (void)attemptSessionUpgrade:(AppEntryAction)entryAction {
    [self attemptSessionUpgrade:entryAction withDirectId:nil];
}

- (void)attemptSessionUpgrade:(AppEntryAction)entryAction withDirectId:(NSString *)directId {
    [OneSignal onesignal_Log:ONE_S_LL_DEBUG message:[NSString stringWithFormat:@"OneSignal SessionManager attemptSessionUpgrade with entryAction: %u", entryAction]];
    
    OSChannelTracker *channelTrackerByAction = [_trackerFactory channelByEntryAction:entryAction];
    NSArray<OSChannelTracker *> *channelTrackersToReset = [_trackerFactory channelsToResetByEntryAction:entryAction];
    NSMutableArray<OSInfluence *> *influencesToEnd = [NSMutableArray new];
    OSInfluence *lastInfluence = nil;
    
    // We will try to override any session with DIRECT
    BOOL updated = NO;
    if (channelTrackerByAction) {
        lastInfluence = [channelTrackerByAction currentSessionInfluence];
        updated = [self setSessionForChannel:channelTrackerByAction withInfluenceType:DIRECT directNotificationId:directId == nil ? channelTrackerByAction.directId : directId indirectNotificationIds:nil];
    }
    
    if (updated) {
        [OneSignal onesignal_Log:ONE_S_LL_DEBUG message:[NSString stringWithFormat:@"OneSignal SessionManager attemptSessionUpgrade channel updated, search for ending direct influences on channels: %@", channelTrackersToReset]];
        [influencesToEnd addObject:lastInfluence];
       
        // Only one session influence channel can be DIRECT at the same time
        // Reset other DIRECT channels, they will init an INDIRECT influence
        // In that way we finish the session duration time for the last influenced session
        for (OSChannelTracker *tracker in channelTrackersToReset) {
            if (tracker.influenceType == DIRECT) {
                [influencesToEnd addObject:[tracker currentSessionInfluence]];
                [tracker resetAndInitInfluence];
            }
        }
    }
    
    [OneSignal onesignal_Log:ONE_S_LL_DEBUG message:@"OneSignal SessionManager attemptSessionUpgrade try UNATTRIBUTED to INDIRECT upgrade"];
    // We will try to override the UNATTRIBUTED session with INDIRECT
    for (OSChannelTracker *channelTracker in channelTrackersToReset) {
        if (channelTracker.influenceType == UNATTRIBUTED) {
            NSArray *lastIds = [channelTracker lastReceivedIds];
            // There are new ids for attribution and the application was open again without resetting session
            if (lastIds.count > 0 && entryAction != APP_CLOSE) {
                // Save influence to ended it later if needed
                // This influence will be unattributed
                OSInfluence *influence = [channelTracker currentSessionInfluence];
                updated = [self setSessionForChannel:channelTracker withInfluenceType:INDIRECT directNotificationId:nil indirectNotificationIds:lastIds];
                // Changed from UNATTRIBUTED to INDIRECT
                if (updated)
                    [influencesToEnd addObject:influence];
            }
        }
    }
    
    [OneSignal onesignal_Log:ONE_S_LL_DEBUG message:[NSString stringWithFormat:@"Trackers after update attempt: %@", [_trackerFactory channels].description]];
    [self sendSessionEndingWithInfluences:influencesToEnd];
}

/*
 Called when the session for the app changes, caches the state, and broadcasts the session that just ended
 */
- (BOOL)setSessionForChannel:(OSChannelTracker *)channelTracker withInfluenceType:(Session)influenceType directNotificationId:(NSString *)directNotificationId indirectNotificationIds:(NSArray *)indirectNotificationIds {
    if (![self willChangeSessionForChannel:channelTracker withInfluenceType:influenceType directNotificationId:directNotificationId indirectNotificationIds:indirectNotificationIds])
        return NO;
    
    NSString *message = @"OSChannelTracker changed: %@  \nfrom:  \ninfluenceType: %@  \n, directNotificationId: %@  \n, indirectNotificationIds: %@  \nto:  \ninfluenceType: %@  \n, directNotificationId: %@  \n, indirectNotificationIds: %@";
    [OneSignal onesignal_Log:ONE_S_LL_DEBUG message:[NSString stringWithFormat:message,
                                                       [channelTracker idTag],
                                                       OS_INFLUENCE_TYPE_TO_STRING(channelTracker.influenceType),
                                                       channelTracker.directId,
                                                       channelTracker.indirectIds,
                                                       OS_INFLUENCE_TYPE_TO_STRING(influenceType),
                                                       directNotificationId,
                                                       indirectNotificationIds]];
    
    channelTracker.influenceType = influenceType;
    channelTracker.directId = directNotificationId;
    channelTracker.indirectIds = indirectNotificationIds;
    [channelTracker cacheState];
    
    [OneSignal onesignal_Log:ONE_S_LL_DEBUG message:[NSString stringWithFormat:@"Trackers changed to: %@", [_trackerFactory channels].description]];
    
    return YES;
}

/*
 Validates whether or not the session will change under certain circumstances:
    1. Is new session different from incoming session?
    2. Is DIRECT session data different from incoming DIRECT session data?
    3. Is INDIRECT session data different from incoming INDIRECT session data?
 */
- (BOOL)willChangeSessionForChannel:(OSChannelTracker *)channelTracker withInfluenceType:(Session)influenceType directNotificationId:(NSString *)directNotificationId indirectNotificationIds:(NSArray *)indirectNotificationIds {
    if (channelTracker.influenceType != influenceType)
        return true;

    // Allow updating a direct session to a new direct when a new notification is clicked
    if (channelTracker.influenceType == DIRECT &&
        channelTracker.directId &&
        ![channelTracker.directId isEqualToString:directNotificationId]) {
        return true;
    }

    // Allow updating an indirect session to a new indirect when a new notification is received
    if (channelTracker.influenceType == INDIRECT &&
        channelTracker.indirectIds &&
        channelTracker.indirectIds.count > 0 &&
        ![channelTracker.indirectIds isEqualToArray:indirectNotificationIds]) {
        return true;
    }

    return false;
}

- (void)sendSessionEndingWithInfluences:(NSArray<OSInfluence *> *)endingInfluences {
    [OneSignal onesignal_Log:ONE_S_LL_DEBUG message:[NSString stringWithFormat:@"OneSignal SessionManager sendSessionEndingWithInfluences with influences: %@", endingInfluences.description]];
    // Only end session if there are influences available to end
    if (endingInfluences.count > 0 && _delegate)
        [_delegate onSessionEnding:endingInfluences];
}

@end
