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

#define mustOverride() @throw [NSException exceptionWithName:NSInvalidArgumentException reason:[NSString stringWithFormat:@"%s must be overridden in a subclass/category", __PRETTY_FUNCTION__] userInfo:nil]
#define methodNotImplemented() mustOverride()

@implementation OSUserStateSynchronizer

- (OSRequestRegisterUser *)registerUserWithData:(NSDictionary *)registrationData
                                         userId:(NSString *)userId {
    return [OSRequestRegisterUser withData:registrationData userId:userId];
}

- (OSRequestUpdateExternalUserId *)setExternalUserId:(NSString *)externalId
                         withExternalIdAuthHashToken:(NSString *)hashToken
                                          withUserId:(NSString *)userId
                                           withAppId:(NSString *)appId {
    return [OSRequestUpdateExternalUserId withUserId:externalId withUserIdHashToken:hashToken withOneSignalUserId:userId appId:appId];
}

- (OSRequestSendTagsToServer *)sendTagsWithUserId:(NSString *)userId
                                            appId:(NSString *)appId
                                      sendingTags:(NSDictionary *)tags
                                      networkType:(NSNumber *)networkType
                               emailAuthHashToken:(NSString *)emailAuthHashToken
                          externalIdAuthHashToken:(NSString *)externalIdAuthHashToken {
    return [OSRequestSendTagsToServer withUserId:userId appId:appId tags:tags networkType:networkType withEmailAuthHashToken:emailAuthHashToken withExternalIdAuthHashToken:externalIdAuthHashToken];
}

- (OSRequestSendPurchases *)sendPurchases:(NSArray *)purchases
                                    appId:(NSString *)appId
                                   userId:(NSString *)userId
                      externalIdAuthToken:(NSString *)externalIdAuthToken {
    return [OSRequestSendPurchases withUserId:userId externalIdAuthToken:externalIdAuthToken appId:appId withPurchases:purchases];
}

- (OSRequestBadgeCount *)sendBadgeCount:(NSNumber *)badgeCount
                                  appId:(NSString *)appId
                                 userId:(NSString *)userId
                     emailAuthHashToken:(NSString *)emailAuthHashToken
                externalIdAuthHashToken:(NSString *)externalIdAuthHashToken {
    return [OSRequestBadgeCount withUserId:userId appId:appId badgeCount:badgeCount emailAuthToken:emailAuthHashToken externalIdAuthToken:externalIdAuthHashToken];
}

- (OSRequestSendLocation *)sendLocation:(os_last_location *)lastLocation
                                  appId:(NSString *)appId
                                 userId:(NSString *)userId
                            networkType:(NSNumber *)networkType
                        backgroundState:(BOOL)background
                     emailAuthHashToken:(NSString *)emailAuthHashToken
                externalIdAuthHashToken:(NSString *)externalIdAuthHashToken {
    return [OSRequestSendLocation withUserId:userId appId:appId location:lastLocation networkType:networkType backgroundState:background emailAuthHashToken:emailAuthHashToken externalIdAuthToken:externalIdAuthHashToken];
}

- (OSRequestOnFocus *)sendOnFocusTime:(NSNumber *)activeTime
                               userId:(NSString *)userId
                                appId:(NSString *)appId
                              netType:(NSNumber *)netType
                       emailAuthToken:(NSString *)emailAuthHash
                  externalIdAuthToken:(NSString *)externalIdAuthToken
                           deviceType:(NSNumber *)deviceType
                      influenceParams:(NSArray <OSFocusInfluenceParam *> *)influenceParams {
    return [OSRequestOnFocus withUserId:userId appId:appId activeTime:activeTime netType:netType emailAuthToken:emailAuthHash externalIdAuthToken:externalIdAuthToken deviceType:deviceType influenceParams:influenceParams];
}

@end
