/**
 * Modified MIT License
 *
 * Copyright 2017 OneSignal
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

#import "OSSubscription.h"
#import "OneSignalCommonDefines.h"


#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"

@implementation OSSubscriptionState

- (ObservableSubscriptionStateType*)observable {
    if (!_observable)
        _observable = [OSObservable new];
    return _observable;
}

- (instancetype)initAsToWithPermision:(BOOL)permission {
    _accpeted = permission;
    
    NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
    _userId = [userDefaults stringForKey:USERID];
    _pushToken = [userDefaults stringForKey:DEVICE_TOKEN];
    _userSubscriptionSetting = [userDefaults objectForKey:SUBSCRIPTION] == nil;
    
    return self;
}

- (BOOL)compare:(OSSubscriptionState*)from {
    return ![self.userId ?: @"" isEqualToString:from.userId ?: @""] ||
           ![self.pushToken ?: @"" isEqualToString:from.pushToken ?: @""] ||
           self.userSubscriptionSetting != from.userSubscriptionSetting ||
           self.accpeted != from.accpeted;
}

- (instancetype)initAsFrom {
    NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
    
    _userId = [userDefaults stringForKey:USERID_LAST];
    _pushToken = [userDefaults stringForKey:PUSH_TOKEN];
    _userSubscriptionSetting = [userDefaults objectForKey:SUBSCRIPTION_SETTING] == nil;
    _accpeted = [userDefaults boolForKey:ACCEPTED_PERMISSION];
    
    return self;
}

- (void)persistAsFrom {
    NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
    
    NSString* strUserSubscriptionSetting = nil;
    if (!_userSubscriptionSetting)
        strUserSubscriptionSetting = @"no";
    
    [userDefaults setObject:strUserSubscriptionSetting forKey:SUBSCRIPTION_SETTING];
    [userDefaults setObject:_userId forKey:USERID_LAST];
    [userDefaults setObject:_pushToken forKey:PUSH_TOKEN];
    [userDefaults setBool:_accpeted forKey:ACCEPTED_PERMISSION];
    
    [userDefaults synchronize];
}

- (instancetype)copyWithZone:(NSZone*)zone {
    OSSubscriptionState* copy = [[[self class] alloc] init];
    
    if (copy) {
        copy->_userId = [_userId copy];
        copy->_pushToken = [_pushToken copy];
        copy->_userSubscriptionSetting = _userSubscriptionSetting;
        copy->_accpeted = _accpeted;
    }
    
    return copy;
}


- (void)onChanged:(OSPermissionState*)state {
    [self setAccepted:state.accepted];
}

- (void)setUserId:(NSString*)userId {
    BOOL changed = ![[NSString stringWithString:userId] isEqualToString:_userId];
    _userId = userId;
    if (self.observable && changed)
        [self.observable notifyChange:self];
}

- (void)setPushToken:(NSString*)pushToken {
    BOOL changed = ![[NSString stringWithString:pushToken] isEqualToString:_pushToken];
    _pushToken = pushToken;
    if (changed) {
        [[NSUserDefaults standardUserDefaults] setObject:_pushToken forKey:DEVICE_TOKEN];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        if (self.observable)
            [self.observable notifyChange:self];
    }
}

- (void)setUserSubscriptionSetting:(BOOL)userSubscriptionSetting {
    BOOL changed = userSubscriptionSetting != _userSubscriptionSetting;
    _userSubscriptionSetting = userSubscriptionSetting;
    if (self.observable && changed)
        [self.observable notifyChange:self];
}


- (void)setAccepted:(BOOL)inAccpeted {
    BOOL lastSubscribed = self.subscribed;
    
    // checks to see if we should delay the observer update
    // This is to prevent a problem where the observer gets updated
    // before the OneSignal server does. (11f7f49841339317a334c5ec928db7edccb21cfe)
    
    if ([OneSignal performSelector:@selector(shouldDelaySubscriptionSettingsUpdate)]) {
        self.delayedObserverUpdate = true;
        return;
    }
    
    _accpeted = inAccpeted;
    if (lastSubscribed != self.subscribed)
        [self.observable notifyChange:self];
}

- (BOOL)subscribed {
    return _userId && _pushToken && _userSubscriptionSetting && _accpeted;
}

- (NSString*)description {
    static NSString* format = @"<OSSubscriptionState: userId: %@, pushToken: %@, userSubscriptionSetting: %d, subscribed: %d>";
    return [NSString stringWithFormat:format, self.userId, self.pushToken, self.userSubscriptionSetting, self.subscribed];
}

- (NSDictionary*)toDictionary {
    return @{
         @"userId": _userId ?: [NSNull null],
         @"pushToken": _pushToken ?: [NSNull null],
         @"userSubscriptionSetting": @(_userSubscriptionSetting),
         @"subscribed": @(self.subscribed)
     };
}

@end


@implementation OSSubscriptionChangedInternalObserver

- (void)onChanged:(OSSubscriptionState*)state {
    [OSSubscriptionChangedInternalObserver fireChangesObserver:state];
}

+ (void)fireChangesObserver:(OSSubscriptionState*)state {
    OSSubscriptionStateChanges* stateChanges = [OSSubscriptionStateChanges alloc];
    stateChanges.from = OneSignal.lastSubscriptionState;
    stateChanges.to = [state copy];
    
    BOOL hasReceiver = [OneSignal.subscriptionStateChangesObserver notifyChange:stateChanges];
    if (hasReceiver) {
        OneSignal.lastSubscriptionState = [state copy];
        [OneSignal.lastSubscriptionState persistAsFrom];
    }
}

@end

@implementation OSSubscriptionStateChanges
- (NSString*)description {
    static NSString* format = @"<OSSubscriptionStateChanges:\nfrom: %@,\nto:   %@\n>";
    return [NSString stringWithFormat:format, _from, _to];
}

- (NSDictionary*)toDictionary {
    return @{@"from": [_from toDictionary],
             @"to": [_to toDictionary]};
}

@end
