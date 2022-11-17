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
#import "OneSignalOutcomeEventsController.h"
#import <OneSignalCore/OneSignalCore.h>
#import "OSOutcomeEvent.h"
#import "OSCachedUniqueOutcome.h"
#import "OSSessionManager.h"
#import "OSOutcomeEventsRepository.h"
#import "OSInfluenceDataDefines.h"
#import "OSInAppMessageOutcome.h"

@interface OneSignalOutcomeEventsController ()

@property (strong, nonatomic, readonly, nonnull) OSSessionManager *sessionManager;
@property (strong, nonatomic, readonly, nonnull) OSOutcomeEventsFactory *outcomeEventsFactory;

@end

@implementation OneSignalOutcomeEventsController

// Keeps track of unique outcome events sent for UNATTRIBUTED sessions on a per session level
NSMutableSet *unattributedUniqueOutcomeEventsSentSet;

- (instancetype _Nonnull)initWithSessionManager:(OSSessionManager * _Nonnull)sessionManager
                           outcomeEventsFactory:(OSOutcomeEventsFactory *)outcomeEventsFactory {
    if (self = [super init]) {
        _sessionManager = sessionManager;
        _outcomeEventsFactory = outcomeEventsFactory;
        [self initUniqueOutcomeEventsFromCache];
    }
    return self;
}

- (void)initUniqueOutcomeEventsFromCache {
    NSSet *tempUnattributedUniqueOutcomeEventsSentSet = [_outcomeEventsFactory.repository getUnattributedUniqueOutcomeEventsSent];
    if (tempUnattributedUniqueOutcomeEventsSentSet)
        unattributedUniqueOutcomeEventsSentSet = [NSMutableSet setWithSet:tempUnattributedUniqueOutcomeEventsSentSet];
}

- (void)clearOutcomes {
    [OneSignalLog onesignalLog:ONE_S_LL_DEBUG message:@"Outcomes cleared for current session"];
    unattributedUniqueOutcomeEventsSentSet = [NSMutableSet set];
    [self saveUnattributedUniqueOutcomeEvents];
}

/*
 Iterate through all stored cached OSUniqueOutcomeNotification and clean any items over 7 days old
 */
- (void)cleanUniqueOutcomeNotifications {
    NSArray *uniqueOutcomeNotifications = [OneSignalUserDefaults.initShared getSavedCodeableDataForKey:OSUD_CACHED_ATTRIBUTED_UNIQUE_OUTCOME_EVENT_NOTIFICATION_IDS_SENT defaultValue:nil];
    
    NSTimeInterval timeInSeconds = [[NSDate date] timeIntervalSince1970];
    NSMutableArray *finalNotifications = [NSMutableArray new];
    for (OSCachedUniqueOutcome *notif in uniqueOutcomeNotifications) {
        
        // Save notif if it has been stored for less than or equal to a week
        NSTimeInterval diff = timeInSeconds - [notif.timestamp doubleValue];
        if (diff <= WEEK_IN_SECONDS)
            [finalNotifications addObject:notif];
    }

    [OneSignalUserDefaults.initShared saveCodeableDataForKey:OSUD_CACHED_ATTRIBUTED_UNIQUE_OUTCOME_EVENT_NOTIFICATION_IDS_SENT withValue:finalNotifications];
}

- (void)sendClickActionOutcomes:(NSArray<OSInAppMessageOutcome *> *)outcomes
                   appId:(NSString * _Nonnull)appId
              deviceType:(NSNumber * _Nonnull)deviceType {
    for (OSInAppMessageOutcome *outcome in outcomes) {
        NSString *name = outcome.name;

        if (outcome.unique)
            [self sendUniqueOutcomeEvent:name appId:appId deviceType:deviceType successBlock:nil];
        else if (outcome.weight.intValue > 0)
            [self sendOutcomeEventWithValue:name value:outcome.weight appId:appId deviceType:deviceType successBlock:nil];
        else
            [self sendOutcomeEvent:name appId:appId deviceType:deviceType successBlock:nil];
    }
}

- (void)sendUniqueOutcomeEvent:(NSString * _Nonnull)name
                   appId:(NSString * _Nonnull)appId
              deviceType:(NSNumber * _Nonnull)deviceType
            successBlock:(OSSendOutcomeSuccess _Nullable)success {
    NSArray <OSInfluence *>* influences = [_sessionManager getInfluences];
    [self sendUniqueOutcomeEvent:name appId:appId deviceType:deviceType influences:influences successBlock:success];
}

/*
 Create an OSOutcomeEvent and send an outcome request using measure 'endpoint'
 */
- (void)sendOutcomeEvent:(NSString * _Nonnull)name
                   appId:(NSString * _Nonnull)appId
              deviceType:(NSNumber * _Nonnull)deviceType
            successBlock:(OSSendOutcomeSuccess _Nullable)success {
    NSArray <OSInfluence *>* influences = [_sessionManager getInfluences];
    [self sendAndCreateOutcomeEvent:name weight:@0 appId:appId deviceType:deviceType influences:influences successBlock:success];
}

/*
 Create an OSOutcomeEvent with a value and send an outcome request using measure 'endpoint'
 */
- (void)sendOutcomeEventWithValue:(NSString * _Nonnull)name
                   value:(NSNumber * _Nullable)weight
                   appId:(NSString * _Nonnull)appId
              deviceType:(NSNumber * _Nonnull)deviceType
            successBlock:(OSSendOutcomeSuccess _Nullable)success {
    NSArray <OSInfluence *>* influences = [_sessionManager getInfluences];
    [self sendAndCreateOutcomeEvent:name weight:weight appId:appId deviceType:deviceType influences:influences successBlock:success];
}

/*
Create an OSOutcomeEvent and send an outcome request using measure 'endpoint'
Unique outcome events are a little more complicated then a normal or valued outcome
Unique outcomes need to validate for UNATTRIBUTED and ATTRIBUTED sessions:
   1. ATTRIBUTED: Unique outcome events are stored per notification level
                  DIRECT or INDIRECT should have a clean list of notificationIds not sent with the specific outcome name
                  Cache containing events over 7 days old will be cleaned on OneSignal init
   2. UNATTRIBUTED: Unique outcome events are stored per session level
                    Cache is cleaned on every new session in onSessionEnding callback
*/
- (void)sendUniqueOutcomeEvent:(NSString * _Nonnull)name
                         appId:(NSString * _Nonnull)appId
                    deviceType:(NSNumber * _Nonnull)deviceType
                    influences:(NSArray<OSInfluence *> *)sessionInfluences
                  successBlock:(OSSendOutcomeSuccess _Nullable)success {
    NSArray<OSInfluence *> *influences = [self removeDisabledInfluences:sessionInfluences];
    if (influences.count == 0) {
        [OneSignalLog onesignalLog:ONE_S_LL_DEBUG message:@"Unique Outcome disabled for current session"];
        return;
    }
    
    BOOL attributed = NO;
    for (OSInfluence *influence in influences) {
        if (influence.influenceType == DIRECT || influence.influenceType == INDIRECT) {
            // At least one channel attributed this outcome
            attributed = YES;
            break;
        }
    }
    
    // Handle unique outcome event for ATTRIBUTED and UNATTRIBUTED
    if (attributed) {
        // For the ATTRIBUTED unique outcome send only the notificationIds not sent yet
        NSArray *uniqueInfluences = [_outcomeEventsFactory.repository getNotCachedUniqueInfluencesForOutcome:name influences:influences];
        if (!uniqueInfluences || [uniqueInfluences count] == 0) {
            // Return null within the callback to determine not a failure, but not a success in terms of the request made
            NSString* message = @"Measure endpoint will not send because unique outcome already sent for: SessionInfluences: %@, Outcome name: %@";
            [OneSignalLog onesignalLog:ONE_S_LL_DEBUG message:[NSString stringWithFormat:message, [influences description], name]];

            if (success)
                success(nil);

            return;
        }
        
        [self sendAndCreateOutcomeEvent:name weight:@0 appId:appId deviceType:deviceType influences:influences successBlock:success];
    } else {

        // If the UNATTRIBUTED unique outcome has been sent for this session, do not send it again
        if ([unattributedUniqueOutcomeEventsSentSet containsObject:name]) {
            // Return null within the callback to determine not a failure, but not a success in terms of the request made
            NSString* message = @"Unique outcome already sent for: session: %@, name: %@";
            [OneSignalLog onesignalLog:ONE_S_LL_DEBUG message:[NSString stringWithFormat:message, OS_INFLUENCE_TYPE_TO_STRING(UNATTRIBUTED), name]];
            
            if (success)
                success(nil);
            
            return;
        }
        
        [unattributedUniqueOutcomeEventsSentSet addObject:name];
        [self sendAndCreateOutcomeEvent:name weight:@0 appId:appId deviceType:deviceType influences:influences successBlock:success];
    }
}

- (OSOutcomeSourceBody *)setSourceChannelIdsWithInfluence:(OSInfluence *)influence sourceBody:(OSOutcomeSourceBody *) sourceBody {
    switch (influence.influenceChannel) {
        case IN_APP_MESSAGE:
            sourceBody.inAppMessagesIds = influence.ids;
            break;
        case NOTIFICATION:
            sourceBody.notificationIds = influence.ids;
            break;
    }

    return sourceBody;
}

/*
 Send an outcome request based on the current session of the app
 Handle the success and failure of the request
 */
- (void)sendAndCreateOutcomeEvent:(NSString * _Nonnull)name
                           weight:(NSNumber * _Nonnull)weight
                            appId:(NSString * _Nonnull)appId
                       deviceType:(NSNumber * _Nonnull)deviceType
                       influences:(NSArray<OSInfluence *> *)influences
                     successBlock:(OSSendOutcomeSuccess _Nullable)success {
    NSTimeInterval timestamp = [[NSDate date] timeIntervalSince1970];
    OSOutcomeSourceBody *directSourceBody = nil;
    OSOutcomeSourceBody *indirectSourceBody = nil;
    BOOL unattributed = NO;
    
    for (OSInfluence *influence in influences) {
        switch (influence.influenceType) {
            case DIRECT:
                directSourceBody = [self setSourceChannelIdsWithInfluence:influence sourceBody:directSourceBody == nil ? [[OSOutcomeSourceBody alloc] init] : directSourceBody];
                break;
            case INDIRECT:
                indirectSourceBody = [self setSourceChannelIdsWithInfluence:influence sourceBody:indirectSourceBody == nil ? [[OSOutcomeSourceBody alloc] init] : indirectSourceBody];
                break;
            case UNATTRIBUTED:
                unattributed = true;
                break;
            case DISABLED:
                [OneSignalLog onesignalLog:ONE_S_LL_DEBUG message:[NSString stringWithFormat:@"Outcomes disabled for channel: %@", OS_INFLUENCE_CHANNEL_TO_STRING(influence.influenceChannel)]];
                return; // finish method
        }
    }

    if (directSourceBody == nil && indirectSourceBody == nil && !unattributed) {
        // Disabled for all channels
        [OneSignalLog onesignalLog:ONE_S_LL_DEBUG message:@"Outcomes disabled for all channels"];
        return;
    }

    OSOutcomeSource *source = [[OSOutcomeSource alloc] initWithDirectBody:directSourceBody indirectBody:indirectSourceBody];
    OSOutcomeEventParams *eventParams = [[OSOutcomeEventParams alloc] initWithOutcomeId:name outcomeSource:source weight:weight timestamp:[NSNumber numberWithDouble:timestamp]];
    
    [_outcomeEventsFactory.repository requestMeasureOutcomeEventWithAppId:appId deviceType:deviceType event:eventParams onSuccess:^(NSDictionary *result) {
        // Cache unique outcomes
        [self saveUniqueOutcome:eventParams];

        if (success)
            success([[OSOutcomeEvent alloc] initFromOutcomeEventParams:eventParams]);

    } onFailure:^(NSError *error) {
        // Reset unique outcomes
        [self initUniqueOutcomeEventsFromCache];

        if (success)
            success(nil);
    }];
}
                 
- (NSArray<OSInfluence *> *)removeDisabledInfluences:(NSArray<OSInfluence *> *) influences {
    NSMutableArray<OSInfluence *> *availableInfluences = [influences mutableCopy];
    for (OSInfluence *influence in influences) {
        if (influence.influenceType == DISABLED) {
            [OneSignalLog onesignalLog:ONE_S_LL_DEBUG message:[NSString stringWithFormat:@"Outcomes disabled for channel: %@", OS_INFLUENCE_CHANNEL_TO_STRING(influence.influenceChannel)]];
            [availableInfluences removeObject:influence];
        }
    }

    return availableInfluences;
}

- (void)saveUniqueOutcome:(OSOutcomeEventParams *)eventParams {
    OSOutcomeSource * outcomeSource = eventParams.outcomeSource;
    if (outcomeSource == nil || (outcomeSource.directBody == nil && outcomeSource.indirectBody == nil))
        [self saveUnattributedUniqueOutcomeEvents];
    else
        [self saveAttributedUniqueOutcomeFromParams:eventParams];

}

/**
 * Save the ATTRIBUTED JSONArray of notification ids with unique outcome names to SQL
 */
- (void)saveAttributedUniqueOutcomeFromParams:(OSOutcomeEventParams *) eventParams {
   [_outcomeEventsFactory.repository saveUniqueOutcomeEventParams:eventParams];
}

/**
 * Save the current set of UNATTRIBUTED unique outcome names to SharedPrefs
 */
- (void)saveUnattributedUniqueOutcomeEvents {
    [_outcomeEventsFactory.repository saveUnattributedUniqueOutcomeEventsSent:unattributedUniqueOutcomeEventsSentSet];
}

@end
