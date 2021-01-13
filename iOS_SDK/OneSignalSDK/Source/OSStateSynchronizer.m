/**
Modified MIT License

Copyright 2021 OneSignal

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
#import "OSStateSynchronizer.h"
#import "OSUserStateSynchronizer.h"
#import "OSUserStatePushSynchronizer.h"
#import "OSUserStateEmailSynchronizer.h"
#import "Requests.h"
#import "OneSignalCommonDefines.h"
#import "OneSignalUserDefaults.h"
#import "OSPendingCallbacks.h"

@interface OneSignal ()

+ (BOOL)shouldUpdateExternalUserId:(NSString*)externalId withRequests:(NSDictionary*)requests;
+ (NSMutableDictionary*)getDuplicateExternalUserIdResponse:(NSString*)externalId withRequests:(NSDictionary*)requests;
+ (void)emailChangedWithNewEmailPlayerId:(NSString * _Nullable)emailPlayerId;
+ (void)setUserId:(NSString *)userId;
+ (void)setEmailUserId:(NSString *)emailUserId;
+ (void)saveExternalIdAuthToken:(NSString *)hashToken;

@end

@interface OSStateSynchronizer ()

@property (strong, nonatomic, readwrite, nonnull) NSDictionary<NSString *, OSUserStateSynchronizer *> *userStateSynchronizers;
@property (strong, nonatomic, readwrite, nonnull) OSSubscriptionState *currentSubscriptionState;
@property (strong, nonatomic, readwrite, nonnull) OSEmailSubscriptionState *currentEmailSubscriptionState;

@end

@implementation OSStateSynchronizer

- (instancetype)initWithSubscriptionState:(OSSubscriptionState *)subscriptionState
               withEmailSubscriptionState:(OSEmailSubscriptionState *)emailSubscriptionState {
    self = [super init];
    if (self) {
        _userStateSynchronizers = @{
            OS_PUSH  : [OSUserStatePushSynchronizer new],
            OS_EMAIL : [OSUserStateEmailSynchronizer new]
        };
        _currentSubscriptionState = subscriptionState;
        _currentEmailSubscriptionState = emailSubscriptionState;
    }
    return self;
}

- (OSUserStateSynchronizer *)getPushStateSynchronizer {
    return [_userStateSynchronizers objectForKey:OS_PUSH];
}

- (OSUserStateSynchronizer *)getEmailStateSynchronizer {
    if ([self.currentEmailSubscriptionState isEmailSetup])
        return [_userStateSynchronizers objectForKey:OS_EMAIL];
    else
        return nil;
}

- (void)registerUserWithState:(OSUserState *)registrationState withSuccess:(OSMultipleSuccessBlock)successBlock onFailure:(OSMultipleFailureBlock)failureBlock {
    let pushStateSyncronizer = [self getPushStateSynchronizer];
    let emailStateSyncronizer = [self getEmailStateSynchronizer];
    
    let pushDataDic = (NSMutableDictionary *)[registrationState.toDictionary mutableCopy];
    pushDataDic[@"identifier"] = _currentSubscriptionState.pushToken;
    
    let requests = [NSMutableDictionary new];
    requests[OS_PUSH] = [pushStateSyncronizer registerUserWithData:pushDataDic userId:self.currentSubscriptionState.userId];
    
    if (emailStateSyncronizer) {
        let emailDataDic = (NSMutableDictionary *)[registrationState.toDictionary mutableCopy];
        emailDataDic[@"device_type"] = [NSNumber numberWithInt:DEVICE_TYPE_EMAIL];
        emailDataDic[@"email_auth_hash"] = _currentEmailSubscriptionState.emailAuthCode;
        
        // If push device has external id we want to add it to the email device also
        if (registrationState.externalUserId)
            emailDataDic[@"external_user_id"] = registrationState.externalUserId;

        requests[OS_EMAIL] = [emailStateSyncronizer registerUserWithData:emailDataDic userId:_currentEmailSubscriptionState.emailUserId];
    } else {
        // If no email is setup clear the email external user id
        [OneSignalUserDefaults.initStandard saveStringForKey:OSUD_EMAIL_EXTERNAL_USER_ID withValue:nil];
    }
    
    [OneSignalClient.sharedClient executeSimultaneousRequests:requests withSuccess:^(NSDictionary<NSString *, NSDictionary *> *results) {
        [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"on_session result: %@", results]];

        // If the external user ID was sent as part of this request, we need to save it
        // Cache the external id if it exists within the registration payload
        if (registrationState.externalUserId)
            [OneSignalUserDefaults.initStandard saveStringForKey:OSUD_EXTERNAL_USER_ID withValue:registrationState.externalUserId];
        
        if (registrationState.externalUserIdHash)
            [OneSignal saveExternalIdAuthToken:registrationState.externalUserIdHash];

        // Update email player ID
        if (results[OS_EMAIL] && results[OS_EMAIL][@"id"]) {
            NSString *emailUserId = results[OS_EMAIL][@"id"];
            
            // Check to see if the email player_id or email_auth_token are different from what were previously saved
            // if so, we should update the server with this change
            if (_currentEmailSubscriptionState.emailUserId && ![_currentEmailSubscriptionState.emailUserId isEqualToString:emailUserId] && _currentEmailSubscriptionState.emailAuthCode) {
                [OneSignal emailChangedWithNewEmailPlayerId:emailUserId];
                [OneSignalUserDefaults.initStandard saveStringForKey:OSUD_EMAIL_EXTERNAL_USER_ID withValue:nil];
            }
            
            [OneSignal setEmailUserId:emailUserId];
            [OneSignalUserDefaults.initStandard saveStringForKey:OSUD_EMAIL_PLAYER_ID withValue:emailUserId];

            // Email successfully updated, so if there was an external user id we should cache it for email now
            if (registrationState.externalUserId)
                [OneSignalUserDefaults.initStandard saveStringForKey:OSUD_EMAIL_EXTERNAL_USER_ID withValue:registrationState.externalUserId];
        }
        
        //update push player id
        if (results.count > 0 && results[OS_PUSH][@"id"]) {
            NSString *userId = results[OS_PUSH][@"id"];
            [OneSignal setUserId:userId];
            
            // Save player_id to both standard and shared NSUserDefaults
            [OneSignalUserDefaults.initStandard saveStringForKey:OSUD_PLAYER_ID_TO withValue:userId];
            [OneSignalUserDefaults.initShared saveStringForKey:OSUD_PLAYER_ID_TO withValue:userId];
        }

        if (successBlock)
            successBlock(results);
    } onFailure:^(NSDictionary<NSString *, NSError *> *errors) {
        for (NSString *key in @[OS_PUSH, OS_EMAIL])
            [OneSignal onesignal_Log:ONE_S_LL_ERROR message:[NSString stringWithFormat: @"Encountered error during %@ registration with OneSignal: %@", key, errors[key]]];

        if (failureBlock)
            failureBlock(errors);
    }];
}

- (void)setExternalUserId:(NSString *)externalId withExternalIdAuthHashToken:(NSString *)hashToken withAppId:(NSString *)appId withSuccess:(OSUpdateExternalUserIdSuccessBlock _Nullable)successBlock withFailure:(OSUpdateExternalUserIdFailureBlock _Nullable)failureBlock {
    let pushStateSyncronizer = [self getPushStateSynchronizer];
    let emailStateSyncronizer = [self getEmailStateSynchronizer];
    
    // Begin constructing the request for the external id update
    let requests = [NSMutableDictionary new];
    requests[OS_PUSH] = [pushStateSyncronizer setExternalUserId:externalId
                                               withExternalIdAuthHashToken:hashToken
                                                                withUserId:_currentSubscriptionState.userId
                                                                 withAppId:appId];
    
    // Check if the email has been set, this will decide on updtaing the external id for the email channel
    if (emailStateSyncronizer)
        requests[OS_EMAIL] =  [emailStateSyncronizer setExternalUserId:externalId
                                                      withExternalIdAuthHashToken:hashToken
                                                                       withUserId:_currentEmailSubscriptionState.emailUserId
                                                                        withAppId:appId];

    // Make sure this is not a duplicate request, if the email and push channels are aligned correctly with the same external id
    if (![OneSignal shouldUpdateExternalUserId:externalId withRequests:requests]) {
        // Use callback to return success for both cases here, since push and
        // email (if email is not setup, email is not included) have been set already
        let results = [OneSignal getDuplicateExternalUserIdResponse:externalId withRequests:requests];
        if (successBlock)
            successBlock(results);
        return;
    }

    [OneSignalClient.sharedClient executeSimultaneousRequests:requests withCompletion:^(NSDictionary<NSString *,NSDictionary *> *results) {
        if (results[OS_PUSH] && results[OS_PUSH][OS_SUCCESS] && [results[OS_PUSH][OS_SUCCESS] boolValue]) {
            [OneSignalUserDefaults.initStandard saveStringForKey:OSUD_EXTERNAL_USER_ID withValue:externalId];

            [OneSignal saveExternalIdAuthToken:hashToken];
        }
        
        if (results[OS_EMAIL] && results[OS_EMAIL][OS_SUCCESS] && [results[OS_EMAIL][OS_SUCCESS] boolValue])
            [OneSignalUserDefaults.initStandard saveStringForKey:OSUD_EMAIL_EXTERNAL_USER_ID withValue:externalId];

        if (successBlock)
            successBlock(results);
    }];
}

- (void)sendTagsWithAppId:(NSString *)appId
              sendingTags:(NSDictionary *)tags
              networkType:(NSNumber *)networkType
      processingCallbacks:(NSArray *)nowProcessingCallbacks {
    let pushStateSyncronizer = [self getPushStateSynchronizer];
    let emailStateSyncronizer = [self getEmailStateSynchronizer];
    
    let requests = [NSMutableDictionary new];
    requests[OS_PUSH] = [pushStateSyncronizer sendTagsWithUserId:_currentSubscriptionState.userId appId:appId sendingTags:tags networkType:networkType emailAuthHashToken:nil externalIdAuthHashToken:_currentSubscriptionState.externalIdAuthCode];
    
    if (emailStateSyncronizer)
        requests[OS_EMAIL] = [emailStateSyncronizer sendTagsWithUserId:_currentEmailSubscriptionState.emailUserId appId:appId sendingTags:tags networkType:networkType emailAuthHashToken:_currentEmailSubscriptionState.emailAuthCode externalIdAuthHashToken:nil];
    
    [OneSignalClient.sharedClient executeSimultaneousRequests:requests withSuccess:^(NSDictionary<NSString *, NSDictionary *> *results) {
        // The tags for email & push are identical so it doesn't matter what we return in the success block
        if (nowProcessingCallbacks) {
            NSDictionary *resultTags = results[OS_PUSH] ?: results[OS_EMAIL];
            
            for (OSPendingCallbacks *callbackSet in nowProcessingCallbacks)
                if (callbackSet.successBlock)
                    callbackSet.successBlock(resultTags);
        }
    } onFailure:^(NSDictionary<NSString *, NSError *> *errors) {
        if (nowProcessingCallbacks) {
            for (OSPendingCallbacks *callbackSet in nowProcessingCallbacks) {
                if (callbackSet.failureBlock) {
                    callbackSet.failureBlock((NSError *)(errors[OS_PUSH] ?: errors[OS_EMAIL]));
                }
            }
        }
    }];
}

- (void)sendPurchases:(NSArray *)purchases appId:(NSString *)appId {
    if (!_currentSubscriptionState.userId)
        return;
    
    let pushStateSyncronizer = [self getPushStateSynchronizer];
    let emailStateSyncronizer = [self getEmailStateSynchronizer];
    
    let requests = [NSMutableDictionary new];
    requests[OS_PUSH] = [pushStateSyncronizer sendPurchases:purchases appId:appId userId:_currentSubscriptionState.userId externalIdAuthToken:_currentSubscriptionState.externalIdAuthCode];
    
    if (emailStateSyncronizer)
        requests[OS_EMAIL] = [emailStateSyncronizer sendPurchases:purchases appId:appId userId:_currentEmailSubscriptionState.emailUserId externalIdAuthToken:_currentEmailSubscriptionState.emailAuthCode];

    [OneSignalClient.sharedClient executeSimultaneousRequests:requests withSuccess:nil onFailure:nil];
}

@end
