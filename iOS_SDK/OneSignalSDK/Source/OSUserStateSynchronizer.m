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
#import "OSUserStateSynchronizer.h"
#import "OSMacros.h"

@implementation OSUserStateSynchronizer

- (NSString *)getId { mustOverride(); }

- (NSString *)getIdAuthHashToken{ mustOverride(); };

- (NSString *)getExternalIdAuthHashToken { mustOverride(); }

- (NSString *)getEmailAuthHashToken { mustOverride(); }

- (NSNumber *)getDeviceType { mustOverride(); }

- (NSString *)getChannelId { mustOverride(); }

- (NSDictionary *)getRegistrationData:(OSUserState *)registrationState { mustOverride(); }

- (OSRequestRegisterUser *)registerUserWithData:(NSDictionary *)registrationData {
    return [OSRequestRegisterUser withData:registrationData userId:[self getId]];
}

- (OSRequestUpdateExternalUserId *)setExternalUserId:(NSString *)externalId
                         withExternalIdAuthHashToken:(NSString *)hashToken
                                           withAppId:(NSString *)appId {
    return [OSRequestUpdateExternalUserId withUserId:externalId withUserIdHashToken:hashToken withOneSignalUserId:[self getId] appId:appId];
}

- (OSRequestSendTagsToServer *)sendTagsWithAppId:(NSString *)appId
                                      sendingTags:(NSDictionary *)tags
                                      networkType:(NSNumber *)networkType{
    return [OSRequestSendTagsToServer withUserId:[self getId] appId:appId tags:tags networkType:networkType withEmailAuthHashToken:[self getEmailAuthHashToken] withExternalIdAuthHashToken:[self getExternalIdAuthHashToken]];
}

- (OSRequestSendPurchases *)sendPurchases:(NSArray *)purchases
                                    appId:(NSString *)appId {
    return [OSRequestSendPurchases withUserId:[self getId] externalIdAuthToken:[self getIdAuthHashToken] appId:appId withPurchases:purchases];
}

- (OSRequestBadgeCount *)sendBadgeCount:(NSNumber *)badgeCount
                                  appId:(NSString *)appId{
    return [OSRequestBadgeCount withUserId:[self getId] appId:appId badgeCount:badgeCount emailAuthToken:[self getEmailAuthHashToken] externalIdAuthToken:[self getExternalIdAuthHashToken]];
}

- (OSRequestSendLocation *)sendLocation:(os_last_location *)lastLocation
                                  appId:(NSString *)appId
                            networkType:(NSNumber *)networkType
                        backgroundState:(BOOL)background{
    return [OSRequestSendLocation withUserId:[self getId] appId:appId location:lastLocation networkType:networkType backgroundState:background emailAuthHashToken:[self getEmailAuthHashToken] externalIdAuthToken:[self getExternalIdAuthHashToken]];
}

- (OSRequestOnFocus *)sendOnFocusTime:(NSNumber *)activeTime
                                appId:(NSString *)appId
                              netType:(NSNumber *)netType
                      influenceParams:(NSArray <OSFocusInfluenceParam *> *)influenceParams {
    return [OSRequestOnFocus withUserId:[self getId] appId:appId activeTime:activeTime netType:netType deviceType:[self getDeviceType] influenceParams:influenceParams];
}

@end
