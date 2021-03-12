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
#import "OSUserStateSMSSynchronizer.h"
#import "OSSMSSubscription.h"
#import "OSSubscription.h"

@interface OSUserStateSMSSynchronizer ()

@property (strong, nonatomic, readwrite, nonnull) OSSMSSubscriptionState *currentSMSSubscriptionState;
@property (strong, nonatomic, readwrite, nonnull) OSSubscriptionState *currentSubscriptionState;

@end

@implementation OSUserStateSMSSynchronizer

- (instancetype)initWithSMSSubscriptionState:(OSSMSSubscriptionState *)smsSubscriptionState
                        withSubcriptionState:(OSSubscriptionState *)subscriptionState {
    self = [super init];
    if (self) {
        _currentSMSSubscriptionState = smsSubscriptionState;
        _currentSubscriptionState = subscriptionState;
    }
    return self;
}

- (NSString *)getId {
    return _currentSMSSubscriptionState.smsUserId;
}

- (NSString *)getIdAuthHashToken {
    return _currentSMSSubscriptionState.smsAuthCode;
}

- (NSString *)getExternalIdAuthHashToken {
    return _currentSubscriptionState.externalIdAuthCode;
}

- (NSString *)getEmailAuthHashToken {
    return nil;
}

- (NSString *)getSMSAuthHashToken {
    return [self getIdAuthHashToken];
}

- (NSString *)getChannelId {
    return OS_SMS;
}

- (NSNumber *)getDeviceType {
    return @(DEVICE_TYPE_SMS);
}

- (NSDictionary *)getRegistrationData:(OSUserState *)registrationState {
    NSMutableDictionary *smsDataDic = (NSMutableDictionary *)[registrationState.toDictionary mutableCopy];
    smsDataDic[@"device_type"] = self.getDeviceType;
    smsDataDic[SMS_NUMBER_AUTH_HASH_KEY] = self.getSMSAuthHashToken;
    smsDataDic[SMS_NUMBER_KEY] = _currentSMSSubscriptionState.smsNumber;
    smsDataDic[@"device_player_id"] = _currentSubscriptionState.userId;
    [smsDataDic removeObjectForKey:@"notification_types"];

    // If push device has external id we want to add it to the SMS device also
    if (registrationState.externalUserId)
        smsDataDic[@"external_user_id"] = registrationState.externalUserId;
    
    return smsDataDic;
}

- (OSRequestUpdateExternalUserId *)setExternalUserId:(NSString *)externalId
                         withExternalIdAuthHashToken:(NSString *)hashToken
                                           withAppId:(NSString *)appId {
    return [OSRequestUpdateExternalUserId withUserId:externalId withUserIdHashToken:hashToken withOneSignalUserId:[self getId] withSMSHashToken:[self getSMSAuthHashToken] appId:appId];
}

- (OSRequestSendTagsToServer *)sendTagsWithAppId:(NSString *)appId
                                      sendingTags:(NSDictionary *)tags
                                      networkType:(NSNumber *)networkType{
    return [OSRequestSendTagsToServer withUserId:[self getId] appId:appId tags:tags networkType:networkType withSMSAuthHashToken:[self getSMSAuthHashToken] withExternalIdAuthHashToken:[self getExternalIdAuthHashToken]];
}

- (OSRequestBadgeCount *)sendBadgeCount:(NSNumber *)badgeCount
                                  appId:(NSString *)appId{
    return [OSRequestBadgeCount withUserId:[self getId] appId:appId badgeCount:badgeCount smsAuthToken:[self getSMSAuthHashToken] externalIdAuthToken:[self getExternalIdAuthHashToken]];
}

@end
