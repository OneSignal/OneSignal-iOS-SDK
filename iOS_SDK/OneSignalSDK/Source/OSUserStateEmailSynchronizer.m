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
#import "OSUserStateEmailSynchronizer.h"
#import "OSEmailSubscription.h"
#import "OSSubscription.h"

@interface OSUserStateEmailSynchronizer ()

@property (strong, nonatomic, readwrite, nonnull) OSEmailSubscriptionState *currentEmailSubscriptionState;
@property (strong, nonatomic, readwrite, nonnull) OSSubscriptionState *currentSubscriptionState;

@end

@implementation OSUserStateEmailSynchronizer

- (instancetype)initWithEmailSubscriptionState:(OSEmailSubscriptionState *)emailSubscriptionState
                          withSubcriptionState:(OSSubscriptionState *)subscriptionState {
    self = [super init];
    if (self){
        _currentEmailSubscriptionState = emailSubscriptionState;
        _currentSubscriptionState = subscriptionState;
    }
    return self;
}

- (NSString *)getId {
    return _currentEmailSubscriptionState.emailUserId;
}

- (NSString *)getIdAuthHashToken {
    return _currentEmailSubscriptionState.emailAuthCode;
}

- (NSString *)getExternalIdAuthHashToken {
    return _currentSubscriptionState.externalIdAuthCode;
}

- (NSString *)getEmailAuthHashToken {
    return [self getIdAuthHashToken];
}

- (NSString *)getChannelId {
    return OS_EMAIL;
}

- (NSNumber *)getDeviceType {
    return @(DEVICE_TYPE_EMAIL);
}

- (NSDictionary *)getRegistrationData:(OSUserState *)registrationState {
    NSMutableDictionary *emailDataDic = (NSMutableDictionary *)[registrationState.toDictionary mutableCopy];
    emailDataDic[@"device_type"] = self.getDeviceType;
    emailDataDic[@"email_auth_hash"] = self.getEmailAuthHashToken;
    emailDataDic[@"identifier"] = _currentEmailSubscriptionState.emailAddress;
    emailDataDic[@"device_player_id"] = _currentSubscriptionState.userId;
    
    // If push device has external id we want to add it to the email device also
    if (registrationState.externalUserId)
        emailDataDic[@"external_user_id"] = registrationState.externalUserId;
    
    return emailDataDic;
}

- (OSRequestUpdateExternalUserId *)setExternalUserId:(NSString *)externalId
                         withExternalIdAuthHashToken:(NSString *)hashToken
                                           withAppId:(NSString *)appId {
    return [OSRequestUpdateExternalUserId withUserId:externalId withUserIdHashToken:hashToken withOneSignalUserId:[self getId] withEmailHashToken:[self getEmailAuthHashToken] appId:appId];
}

@end
