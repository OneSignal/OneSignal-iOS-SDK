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
#import "Requests.h"
#import "OSOutcomeEvent.h"
#import "OSUniqueOutcomeNotification.h"
#import "OneSignalClient.h"
#import "OneSignalSessionManager.h"
#import "OSOutcomesUtils.h"
#import "OneSignalUserDefaults.h"
#import "OneSignalCommonDefines.h"
#import "OSOutcomeEventsDefines.h"

@implementation OneSignalOutcomeEventsController

// Keeps track of unique outcome events sent for UNATTRIBUTED sessions on a per session level
NSMutableSet *unattributedUniqueOutcomeEventsSentSet;

// Keeps track of unique outcome events sent for ATTRIBUTED sessions on a per notification level
NSMutableArray<OSUniqueOutcomeNotification *> *attributedUniqueOutcomeEventNotificationIdsSentArray;

- (instancetype _Nonnull)init:(OneSignalSessionManager * _Nonnull)sessionManager {
    if (self = [super init]) {
        self.osSessionManager = sessionManager;
        [self initUniqueOutcomeEventsFromCache];
    }
    return self;
}

- (void)initUniqueOutcomeEventsFromCache {
    NSSet *tempUnattributedUniqueOutcomeEventsSentSet = [self getUnattributedUniqueOutcomeEventNames];
    if (tempUnattributedUniqueOutcomeEventsSentSet)
        unattributedUniqueOutcomeEventsSentSet = [NSMutableSet setWithSet:tempUnattributedUniqueOutcomeEventsSentSet];

    NSArray *tempAttributedUniqueOutcomeEventNotificationIdsSentArray = [self getAttributedUniqueOutcomeEventNotificationIds];
    if (tempAttributedUniqueOutcomeEventNotificationIdsSentArray)
        attributedUniqueOutcomeEventNotificationIdsSentArray = [NSMutableArray arrayWithArray:tempAttributedUniqueOutcomeEventNotificationIdsSentArray];
}

- (void)clearOutcomes {
    unattributedUniqueOutcomeEventsSentSet = [NSMutableSet set];
    [self saveUnattributedUniqueOutcomeEventNames];
}

// Save the current set of UNATTRIBUTED unique outcome names to NSUserDefaults
- (NSSet *)getUnattributedUniqueOutcomeEventNames {
    return [OneSignalUserDefaults.initShared getSavedSetForKey:OSUD_CACHED_UNATTRIBUTED_UNIQUE_OUTCOME_EVENTS_SENT defaultValue:nil];
}

// Save the current set of UNATTRIBUTED unique outcome names to NSUserDefaults
- (void)saveUnattributedUniqueOutcomeEventNames {
    [OneSignalUserDefaults.initShared saveSetForKey:OSUD_CACHED_UNATTRIBUTED_UNIQUE_OUTCOME_EVENTS_SENT withValue:unattributedUniqueOutcomeEventsSentSet];
}

// Save the current set of ATTRIBUTED unique outcome names and notificationIds to NSUserDefaults
- (NSArray *)getAttributedUniqueOutcomeEventNotificationIds {
    return [OneSignalUserDefaults.initShared getSavedCodeableDataForKey:OSUD_CACHED_ATTRIBUTED_UNIQUE_OUTCOME_EVENT_NOTIFICATION_IDS_SENT defaultValue:nil];
}

// Save the current set of ATTRIBUTED unique outcome names and notificationIds to NSUserDefaults
- (void)saveAttributedUniqueOutcomeEventNotificationIds {
    [OneSignalUserDefaults.initShared saveCodeableDataForKey:OSUD_CACHED_ATTRIBUTED_UNIQUE_OUTCOME_EVENT_NOTIFICATION_IDS_SENT withValue:attributedUniqueOutcomeEventNotificationIdsSentArray];
}

/*
 Create an OSOutcomeEvent and send an outcome request using measure 'endpoint'
 */
- (void)sendOutcomeEvent:(NSString * _Nonnull)name
                   appId:(NSString * _Nonnull)appId
              deviceType:(NSNumber * _Nonnull)deviceType
            successBlock:(OSSendOutcomeSuccess _Nullable)success {

    NSTimeInterval timestamp = [[NSDate date] timeIntervalSince1970];
    OSSessionResult *sessionResult = [self.osSessionManager getSessionResult];

    OSOutcomeEvent *outcome = [[OSOutcomeEvent new] initWithSession:sessionResult.session
                                                    notificationIds:sessionResult.notificationIds
                                                               name:name
                                                          timestamp:[NSNumber numberWithDouble:timestamp]
                                                             weight:@0];

    [self sendOutcomeEventRequest:appId deviceType:deviceType outcome:outcome successBlock:success];
}

- (void)sendUniqueClickOutcomeEvent:(NSString * _Nonnull)name
                   appId:(NSString * _Nonnull)appId
              deviceType:(NSNumber * _Nonnull)deviceType {
    OSSessionResult *sessionResult = [self.osSessionManager getIAMSessionResult];
    [self sendUniqueOutcomeEvent:name appId:appId deviceType:deviceType successBlock:nil sessionResult:sessionResult];
}

- (void)sendUniqueOutcomeEvent:(NSString * _Nonnull)name
                   appId:(NSString * _Nonnull)appId
              deviceType:(NSNumber * _Nonnull)deviceType
            successBlock:(OSSendOutcomeSuccess _Nullable)success {
    OSSessionResult *sessionResult = [self.osSessionManager getSessionResult];
    [self sendUniqueOutcomeEvent:name appId:appId deviceType:deviceType successBlock:success sessionResult:sessionResult];
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
            successBlock:(OSSendOutcomeSuccess _Nullable)success
           sessionResult:(OSSessionResult *)sessionResult{

    NSTimeInterval timestamp = [[NSDate date] timeIntervalSince1970];
    
    // Handle unique outcome event for ATTRIBUTED and UNATTRIBUTED
    if ([OSOutcomesUtils isAttributedSession:sessionResult.session]) {
        // For the ATTRIBUTED unique outcome send only the notificationIds not sent yet
        NSArray *notificationIds = [self getUniqueNotificationIdsNotSentWithOutcome:name timestamp:[NSNumber numberWithDouble:timestamp]];
        if (!notificationIds || [notificationIds count] == 0) {
            // Return null within the callback to determine not a failure, but not a success in terms of the request made
            NSString* message = @"Unique outcome already sent for: session: %@, name: %@, notificationIds: %@";
            [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:message, OS_SESSION_TO_STRING(sessionResult.session), name, sessionResult.notificationIds]];

            if (success)
                success(nil);

            return;
        }

        OSOutcomeEvent *outcome = [[OSOutcomeEvent new] initWithSession:sessionResult.session
                                                        notificationIds:notificationIds
                                                                   name:name
                                                              timestamp:[NSNumber numberWithDouble:timestamp]
                                                                 weight:@0];
        [self sendOutcomeEventRequest:appId deviceType:deviceType outcome:outcome successBlock:success];
       
    } else if (sessionResult.session == UNATTRIBUTED) {

        // If the UNATTRIBUTED unique outcome has been sent for this session, do not send it again
        if ([unattributedUniqueOutcomeEventsSentSet containsObject:name]) {
            // Return null within the callback to determine not a failure, but not a success in terms of the request made
            NSString* message = @"Unique outcome already sent for: session: %@, name: %@";
            [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:message, OS_SESSION_TO_STRING(sessionResult.session), name]];
            
            if (success)
                success(nil);
            
            return;
        }
        
        [unattributedUniqueOutcomeEventsSentSet addObject:name];

        OSOutcomeEvent *outcome = [[OSOutcomeEvent new] initWithSession:sessionResult.session
                                                        notificationIds:@[]
                                                                   name:name
                                                              timestamp:[NSNumber numberWithDouble:timestamp]
                                                                 weight:@0];
        [self sendOutcomeEventRequest:appId deviceType:deviceType outcome:outcome successBlock:success];
    }
}

/*
 Create an OSOutcomeEvent with a value and send an outcome request using measure 'endpoint'
 */
- (void)sendOutcomeEventWithValue:(NSString * _Nonnull)name
                   value:(NSNumber * _Nullable)weight
                   appId:(NSString * _Nonnull)appId
              deviceType:(NSNumber * _Nonnull)deviceType
            successBlock:(OSSendOutcomeSuccess _Nullable)success {
    
    OSSessionResult *sessionResult = [self.osSessionManager getSessionResult];

    NSTimeInterval timestamp = [[NSDate date] timeIntervalSince1970];
    OSOutcomeEvent *outcome = [[OSOutcomeEvent new] initWithSession:sessionResult.session
                                                    notificationIds:sessionResult.notificationIds
                                                               name:name
                                                          timestamp:[NSNumber numberWithDouble:timestamp]
                                                             weight:weight];

    [self sendOutcomeEventRequest:appId deviceType:deviceType outcome:outcome successBlock:success];
}

- (void)sendClickOutcomeEventWithValue:(NSString * _Nonnull)name
                   value:(NSNumber * _Nullable)weight
                   appId:(NSString * _Nonnull)appId
              deviceType:(NSNumber * _Nonnull)deviceType {
    
    OSSessionResult *sessionResult = [self.osSessionManager getIAMSessionResult];

    NSTimeInterval timestamp = [[NSDate date] timeIntervalSince1970];
    OSOutcomeEvent *outcome = [[OSOutcomeEvent new] initWithSession:sessionResult.session
                                                    notificationIds:sessionResult.notificationIds
                                                               name:name
                                                          timestamp:[NSNumber numberWithDouble:timestamp]
                                                             weight:weight];

    [self sendOutcomeEventRequest:appId deviceType:deviceType outcome:outcome successBlock:nil];
}

/*
 Send an outcome request based on the current session of the app
 Handle the success and failure of the request
 */
- (void)sendOutcomeEventRequest:(NSString *)appId
                     deviceType:(NSNumber * _Nonnull)deviceType
                        outcome:(OSOutcomeEvent * _Nonnull)outcome
                   successBlock:(OSSendOutcomeSuccess _Nullable)success {

    OneSignalRequest *request;
    switch (outcome.session) {
        case DIRECT:
            [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"Sending direct outcome"];
            request = [OSRequestSendOutcomesToServer directWithOutcome:outcome
                                                       appId:appId
                                                  deviceType:deviceType];
            break;
        case INDIRECT:
            [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"Sending indirect outcome"];
            request = [OSRequestSendOutcomesToServer indirectWithOutcome:outcome
                                                         appId:appId
                                                    deviceType:deviceType];
            break;
        case UNATTRIBUTED:
            [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"Sending unattributed outcome"];
            request = [OSRequestSendOutcomesToServer unattributedWithOutcome:outcome
                                                             appId:appId
                                                        deviceType:deviceType];
            break;
        case DISABLED:
        default:
            [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"Outcomes for current session are disabled"];
            return;
    }

    [OneSignalClient.sharedClient executeRequest:request onSuccess:^(NSDictionary *result) {
        // Cache unique outcomes
        [self saveUnattributedUniqueOutcomeEventNames];
        [self saveAttributedUniqueOutcomeEventNotificationIds];

        if (success)
            success(outcome);

    } onFailure:^(NSError *error) {
        // Reset unique outcomes
        [self initUniqueOutcomeEventsFromCache];

        if (success)
            success(nil);
    }];
}

/*
 1. Iterate over all notifications and find the ones in the set that don't exist (ex. "<name> + "_" + <notificationId>"
 2. Create an NSArray of these notificationIds and return it
 3. If the array has notifications send the request for only these ids
 */
- (NSArray *)getUniqueNotificationIdsNotSentWithOutcome:(NSString *)name timestamp:(NSNumber *)timestamp {
    NSMutableArray *uniqueNotificationIds = [NSMutableArray new];
    NSArray *notificationIds = [NSArray arrayWithArray:[self.osSessionManager getNotificationIds]];

    for (NSString *notifId in notificationIds) {
        OSUniqueOutcomeNotification *uniqueNotifNotSent = [[OSUniqueOutcomeNotification new] initWithParamsNotificationId:name notificationId:notifId timestamp:timestamp];

        BOOL breakOut = false;
        for (OSUniqueOutcomeNotification *uniqueNotifSent in attributedUniqueOutcomeEventNotificationIdsSentArray) {
            // If the notif has been sent with this unique outcome, then it should not be included in the returned NSArray
            if ([uniqueNotifNotSent isEqual:uniqueNotifSent]) {
                NSString* message = @"Measure endpoint will not send because unique outcome already sent for: name: %@, notificationId: %@";
                [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:message, name, notifId]];
                breakOut = true;
                break;
            }
        }

        if (!breakOut) {
            [uniqueNotificationIds addObject:notifId];
            [attributedUniqueOutcomeEventNotificationIdsSentArray addObject:uniqueNotifNotSent];
        }
    }

    return uniqueNotificationIds;
}

@end
