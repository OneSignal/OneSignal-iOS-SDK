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
#import "OneSignalOutcomeEventsController.h"
#import "Requests.h"
#import "OneSignalClient.h"
#import "OneSignalSessionManager.h"
#import "OSOutcomesUtils.h"
#import "OneSignalSharedUserDefaults.h"
#import "OneSignalCommonDefines.h"

@implementation OneSignalOutcomeEventsController

NSString * const WEIGHT = @"weight";
NSString * const TIMESTAMP = @"timestamp";

// Keeps track of unique outcome events sent for UNATTRIBUTED sessions on a per session level
NSMutableSet *unattributedUniqueOutcomeEventsSentSet;

- (instancetype _Nonnull)init:(OneSignalSessionManager * _Nonnull)sessionManager {
    if (self = [super init]) {
        self.osSessionManager = sessionManager;
        unattributedUniqueOutcomeEventsSentSet = [NSMutableSet set];
    }
    return self;
}

- (void)clearOutcomes {
    unattributedUniqueOutcomeEventsSentSet = [NSMutableSet set];
}

- (void)sendOutcomeEventRequest:(OneSignalRequest * _Nonnull)request
                   successBlock:(OSResultSuccessBlock _Nullable)success
                   failureBlock:(OSFailureBlock _Nullable)failure  {
    
    [OneSignalClient.sharedClient executeRequest:request onSuccess:^(NSDictionary *result) {
        if (success != nil) {
            success(result);
        }
    } onFailure:^(NSError *error) {
        //TODO save on cache
        if (failure != nil) {
            failure(error);
        }
    }];
}

- (void)sendUniqueOutcomeEvent:(NSString * _Nonnull)name
                         appId:(NSString * _Nonnull)appId
                    deviceType:(NSNumber * _Nonnull)deviceType
                  successBlock:(OSResultSuccessBlock _Nullable)success
                  failureBlock:(OSFailureBlock _Nullable)failure {
    OSSessionResult *sessionResult = [self.osSessionManager getSessionResult];
    
     // Special handling for unique outcomes in the attributed and unattributed scenarios
    if ([OSOutcomesUtils isAttributedSession:sessionResult.session]) {
        // Make sure unique notificationIds exist before trying to make measure request
       
    } else if (sessionResult.session == UNATTRIBUTED) {
        // Make sure unique outcome has not been sent for current unattributed session
        if ([unattributedUniqueOutcomeEventsSentSet containsObject:name]) {
            
            NSString* message = @"Measure endpoint will not send because unique outcome already sent for: Session %@ Outcome name %@";
            [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:message, OS_SESSION_TO_STRING(sessionResult.session), name]];
            
            // Return null within the callback to determine not a failure, but not a success in terms of the request made
            if (success != nil)
                success(nil);
            
            return;
        }
        
        [unattributedUniqueOutcomeEventsSentSet addObject:name];
        [self sendOutcomeEvent:name appId:appId deviceType:deviceType successBlock:success failureBlock:failure];
    }
}

- (void)sendOutcomeEvent:(NSString * _Nonnull)name
                   appId:(NSString * _Nonnull)appId
              deviceType:(NSNumber * _Nonnull)deviceType
            successBlock:(OSResultSuccessBlock _Nullable)success
            failureBlock:(OSFailureBlock _Nullable)failure {
    
    [self sendOutcomeEvent:name value:nil appId:appId deviceType:deviceType successBlock:success failureBlock:failure];
}

- (void)sendOutcomeEvent:(NSString * _Nonnull)name
                   value:(NSNumber * _Nullable)weight
                   appId:(NSString * _Nonnull)appId
              deviceType:(NSNumber * _Nonnull)deviceType
            successBlock:(OSResultSuccessBlock _Nullable)success
            failureBlock:(OSFailureBlock _Nullable)failure {
    
    OSSessionResult *sessionResult = [self.osSessionManager getSessionResult];
    NSDictionary *requestParams = nil;
    if (weight != nil) {
        requestParams = @{ WEIGHT : weight };
    }

    switch ([sessionResult session]) {
        case DIRECT:
            [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"Sending direct outcome"];
            [self sendOutcomeEventRequest:[OSRequestSendOutcomesToServer
                                           directWithOutcomeId:name
                                           appId:appId
                                           notificationIds:[sessionResult notificationIds]
                                           deviceType:deviceType
                                           requestParams:requestParams]
                             successBlock:success
                             failureBlock:failure];
            break;
        case INDIRECT:
            [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"Sending indirect outcome"];
            [self sendOutcomeEventRequest:[OSRequestSendOutcomesToServer
                                           indirectWithOutcomeId:name
                                           appId:appId
                                           notificationIds:[sessionResult notificationIds]
                                           deviceType:deviceType
                                           requestParams:requestParams]
                             successBlock:success
                             failureBlock:failure];
            break;
        case UNATTRIBUTED:
            [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"Sending unattributed outcome"];
            [self sendOutcomeEventRequest:[OSRequestSendOutcomesToServer
                                           unattributedWithOutcomeId:name
                                           appId:appId
                                           deviceType:deviceType
                                           requestParams:requestParams]
                             successBlock:success
                             failureBlock:failure];
            break;
        case DISABLED:
            [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"Outcomes for current session are disabled"];
            break;
    }
}

// Save the current set of UNATTRIBUTED unique outcome names to UserDefaults
- (void)saveUnattributedUniqueOutcomeEvent {
    [OneSignalSharedUserDefaults saveSet:unattributedUniqueOutcomeEventsSentSet withKey:CACHED_UNATTRIBUTED_UNIQUE_OUTCOME_EVENTS_SENT];
}

@end
