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
#import "OneSignalClient.h"
#import "Requests.h"
#import "OneSignalCommonDefines.h"
#import "OneSignalUserDefaults.h"

@interface OneSignal ()

+ (BOOL)isEmailSetup;
+ (BOOL)shouldUpdateExternalUserId:(NSString*)externalId withRequests:(NSDictionary*)requests;
+ (NSMutableDictionary*)getDuplicateExternalUserIdResponse:(NSString*)externalId withRequests:(NSDictionary*)requests;

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
    return [_userStateSynchronizers objectForKey:OS_EMAIL];
}

- (void)setExternalUserId:(NSString *)externalId withExternalIdAuthHashToken:(NSString *)hashToken withAppId:(NSString *)appId withSuccess:(OSUpdateExternalUserIdSuccessBlock _Nullable)successBlock withFailure:(OSUpdateExternalUserIdFailureBlock _Nullable)failureBlock {
    // Begin constructing the request for the external id update
    let requests = [NSMutableDictionary new];
    requests[OS_PUSH] = [[self getPushStateSynchronizer] setExternalUserId:externalId
                                               withExternalIdAuthHashToken:hashToken
                                                                withUserId:_currentSubscriptionState.userId
                                                                 withAppId:appId];
    
    // Check if the email has been set, this will decide on updtaing the external id for the email channel
    if ([OneSignal isEmailSetup])
        requests[OS_EMAIL] =  [[self getEmailStateSynchronizer] setExternalUserId:externalId
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
            _currentSubscriptionState.externalIdAuthCode = hashToken;
            
            // Call persistAsFrom in order to save the externalIdAuthCode to NSUserDefaults
            [_currentSubscriptionState persist];
        }
        
        if (results[OS_EMAIL] && results[OS_EMAIL][OS_SUCCESS] && [results[OS_EMAIL][OS_SUCCESS] boolValue])
            [OneSignalUserDefaults.initStandard saveStringForKey:OSUD_EMAIL_EXTERNAL_USER_ID withValue:externalId];

        if (successBlock)
            successBlock(results);
    }];
}

@end
