/**
* Modified MIT License
*
* Copyright 2020 OneSignal
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
#import "OneSignal.h"
#import "OneSignalInternal.h"
#import "OneSignalHelper.h"
#import "OneSignalCommonDefines.h"

@implementation OSDeviceState

- (id)init {
    return [[OSDeviceState alloc] initWithSubscriptionState:[OneSignal getPermissionSubscriptionState]];
}

- (instancetype)initWithSubscriptionState:(OSPermissionSubscriptionState *)state {
    self = [super init];
    if (self) {
        _hasNotificationPermission = [[state permissionStatus] reachable];
        
        _isPushDisabled = ![[state subscriptionStatus] userSubscriptionSetting];
        
        _isSubscribed = [[state subscriptionStatus] isSubscribed];
        
        _notificationPermissionStatus = [[state permissionStatus] status];
        
        _userId = [[state subscriptionStatus] userId];
        
        _pushToken = [[state subscriptionStatus] pushToken];
        
        _emailUserId = [[state emailSubscriptionStatus] emailUserId];
        
        _emailAddress = [[state emailSubscriptionStatus] emailAddress];
        
        _isEmailSubscribed = [[state emailSubscriptionStatus] isSubscribed];
    }
    return self;
}

// Convert the class into a NSDictionary
- (NSDictionary *_Nonnull)jsonRepresentation {
    let json = [NSMutableDictionary new];

    json[@"hasNotificationPermission"] = @(_hasNotificationPermission);
    json[@"isPushDisabled"] = @(_isPushDisabled);
    json[@"isSubscribed"] = @(_isSubscribed);
    json[@"userId"] = _userId;
    json[@"pushToken"] = _pushToken;
    json[@"emailUserId"] = _emailUserId;
    json[@"emailAddress"] = _emailAddress;
    json[@"isEmailSubscribed"] = @(_isEmailSubscribed);
    json[@"notificationPermissionStatus"] = @(_notificationPermissionStatus);

    return json;
}

@end
