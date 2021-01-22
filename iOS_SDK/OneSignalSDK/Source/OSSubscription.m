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
#import "OneSignalHelper.h"
#import "OneSignalUserDefaults.h"
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
    
    let standardUserDefaults = OneSignalUserDefaults.initStandard;
    _userId = [standardUserDefaults getSavedStringForKey:OSUD_PLAYER_ID_TO defaultValue:nil];
    _pushToken = [standardUserDefaults getSavedStringForKey:OSUD_PUSH_TOKEN_TO defaultValue:nil];
    _isPushDisabled = [standardUserDefaults keyExists:OSUD_USER_SUBSCRIPTION_TO];
    _externalIdAuthCode = [standardUserDefaults getSavedStringForKey:OSUD_EXTERNAL_ID_AUTH_CODE defaultValue:nil];
    
    return self;
}

- (BOOL)compare:(OSSubscriptionState*)from {
    return ![self.userId ?: @"" isEqualToString:from.userId ?: @""] ||
           ![self.pushToken ?: @"" isEqualToString:from.pushToken ?: @""] ||
           self.isPushDisabled != from.isPushDisabled ||
           self.accpeted != from.accpeted;
}

- (instancetype)initAsFrom {
    let standardUserDefaults = OneSignalUserDefaults.initStandard;
    _accpeted = [standardUserDefaults getSavedBoolForKey:OSUD_PERMISSION_ACCEPTED_FROM defaultValue:false];
    _userId = [standardUserDefaults getSavedStringForKey:OSUD_PLAYER_ID_FROM defaultValue:nil];
    _pushToken = [standardUserDefaults getSavedStringForKey:OSUD_PUSH_TOKEN_FROM defaultValue:nil];
    _isPushDisabled = ![standardUserDefaults getSavedBoolForKey:OSUD_USER_SUBSCRIPTION_FROM defaultValue:NO];
    _externalIdAuthCode = [standardUserDefaults getSavedStringForKey:OSUD_EXTERNAL_ID_AUTH_CODE defaultValue:nil];
    
    return self;
}

- (void)persist {
    let standardUserDefaults = OneSignalUserDefaults.initStandard;
    [standardUserDefaults saveObjectForKey:OSUD_EXTERNAL_ID_AUTH_CODE withValue:_externalIdAuthCode];
}

- (void)persistAsFrom {
    NSString* strUserSubscriptionSetting = nil;
    if (_isPushDisabled)
        strUserSubscriptionSetting = @"no";
    
    let standardUserDefaults = OneSignalUserDefaults.initStandard;
    [standardUserDefaults saveBoolForKey:OSUD_PERMISSION_ACCEPTED_FROM withValue:_accpeted];
    [standardUserDefaults saveStringForKey:OSUD_PLAYER_ID_FROM withValue:_userId];
    [standardUserDefaults saveObjectForKey:OSUD_PUSH_TOKEN_FROM withValue:_pushToken];
    [standardUserDefaults saveObjectForKey:OSUD_USER_SUBSCRIPTION_FROM withValue:strUserSubscriptionSetting];
    [standardUserDefaults saveObjectForKey:OSUD_EXTERNAL_ID_AUTH_CODE withValue:_externalIdAuthCode];
}

- (instancetype)copyWithZone:(NSZone*)zone {
    OSSubscriptionState* copy = [[[self class] alloc] init];
    
    if (copy) {
        copy->_userId = [_userId copy];
        copy->_pushToken = [_pushToken copy];
        copy->_isPushDisabled = _isPushDisabled;
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
        [OneSignalUserDefaults.initStandard saveStringForKey:OSUD_PUSH_TOKEN_TO withValue:_pushToken];
        
        if (self.observable)
            [self.observable notifyChange:self];
    }
}

- (void)setIsPushDisabled:(BOOL)isPushDisabled {
    BOOL changed = isPushDisabled != _isPushDisabled;
    _isPushDisabled = isPushDisabled;

    if (self.observable && changed)
        [self.observable notifyChange:self];
}


- (void)setAccepted:(BOOL)inAccpeted {
    BOOL lastSubscribed = self.isSubscribed;
    
    // checks to see if we should delay the observer update
    // This is to prevent a problem where the observer gets updated
    // before the OneSignal server does. (11f7f49841339317a334c5ec928db7edccb21cfe)
    
    if ([OneSignal performSelector:@selector(shouldDelaySubscriptionSettingsUpdate)]) {
        self.delayedObserverUpdate = true;
        return;
    }
    
    _accpeted = inAccpeted;
    if (lastSubscribed != self.isSubscribed)
        [self.observable notifyChange:self];
}

- (BOOL)isSubscribed {
    return _userId && _pushToken && !_isPushDisabled && _accpeted;
}

- (NSString*)description {
    static NSString* format = @"<OSSubscriptionState: userId: %@, pushToken: %@, isPushDisabled: %d, isSubscribed: %d, externalIdAuthCode: %@>";
    return [NSString stringWithFormat:format, self.userId, self.pushToken, self.isPushDisabled, self.isSubscribed, self.externalIdAuthCode];
}

- (NSDictionary*)toDictionary {
    return @{
         @"userId": _userId ?: [NSNull null],
         @"pushToken": _pushToken ?: [NSNull null],
         @"isPushDisabled": @(_isPushDisabled),
         @"isSubscribed": @(self.isSubscribed)
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
    if (OneSignal.isRegisterUserFinished) {
        BOOL hasReceiver = [OneSignal.subscriptionStateChangesObserver notifyChange:stateChanges];
        
        if (hasReceiver) {
            OneSignal.lastSubscriptionState = [state copy];
            [OneSignal.lastSubscriptionState persistAsFrom];
        }
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
