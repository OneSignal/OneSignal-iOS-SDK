/**
 * Modified MIT License
 *
 * Copyright 2021 OneSignal
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

#import "OneSignalHelper.h"
#import "OSSMSSubscription.h"
#import "OneSignalUserDefaults.h"
#import "OneSignalCommonDefines.h"

@implementation OSSMSSubscriptionState

- (ObservableSMSSubscriptionStateType *)observable {
    if (!_observable)
        _observable = [OSObservable new];
    return _observable;
}

- (instancetype)init {
    let standardUserDefaults = OneSignalUserDefaults.initStandard;
    _smsNumber = [standardUserDefaults getSavedStringForKey:OSUD_SMS_NUMBER defaultValue:nil];
    _requiresSMSAuth = [standardUserDefaults getSavedBoolForKey:OSUD_REQUIRE_SMS_AUTH defaultValue:false];
    _smsAuthCode = [standardUserDefaults getSavedStringForKey:OSUD_SMS_AUTH_CODE defaultValue:nil];
    _smsUserId = [standardUserDefaults getSavedStringForKey:OSUD_SMS_PLAYER_ID defaultValue:nil];
    
    return self;
}

-(BOOL)isSubscribed {
    return self.smsUserId != nil;
}

- (void)persist {
    let standardUserDefaults = OneSignalUserDefaults.initStandard;
    [standardUserDefaults saveStringForKey:OSUD_SMS_NUMBER withValue:_smsNumber];
    [standardUserDefaults saveBoolForKey:OSUD_REQUIRE_SMS_AUTH withValue:_requiresSMSAuth];
    [standardUserDefaults saveStringForKey:OSUD_SMS_AUTH_CODE withValue:_smsAuthCode];
    [standardUserDefaults saveStringForKey:OSUD_SMS_PLAYER_ID withValue:_smsUserId];
}

- (NSString *)description {
    @synchronized (self) {
        return [NSString stringWithFormat:@"<OSSMSSubscriptionState: smsNumber: %@, smsUserId: %@, smsAuthCode: %@, requireAuthCode: %@>",
                self.smsUserId, self.smsUserId, self.smsAuthCode, self.requiresSMSAuth ? @"YES" : @"NO"];
    }
}

- (instancetype)copyWithZone:(NSZone *)zone {
    OSSMSSubscriptionState *copy = [OSSMSSubscriptionState new];
    
    if (copy) {
        copy->_requiresSMSAuth = _requiresSMSAuth;
        copy->_smsAuthCode = [_smsAuthCode copy];
        copy->_smsUserId = [_smsUserId copy];
        copy->_smsNumber = [_smsNumber copy];
    }
    
    return copy;
}

- (void)setSMSUserId:(NSString *)smsUserId {
    BOOL changed = smsUserId != _smsUserId;
    _smsUserId = smsUserId;
    
    if (changed)
        [self.observable notifyChange:self];
}

- (void)setSMSNumber:(NSString *)smsNumber {
    _smsNumber = smsNumber;
}

- (BOOL)isSMSSetup {
    return _smsUserId && (!_requiresSMSAuth || _smsAuthCode);
}

- (NSDictionary *)toDictionary {
    return @{
       @"smsUserId": _smsUserId ?: [NSNull null],
       @"smsNumber": _smsNumber ?: [NSNull null],
       @"isSubscribed": @(self.isSubscribed)
    };
}

-(BOOL)compare:(OSSMSSubscriptionState *)from {
    return ![self.smsNumber ?: @"" isEqualToString:from.smsNumber ?: @""] || ![self.smsUserId ?: @"" isEqualToString:from.smsUserId ?: @""];
}

@end

@implementation OSSMSSubscriptionChangedInternalObserver

- (void)onChanged:(OSSMSSubscriptionState*)state {
    [OSSMSSubscriptionChangedInternalObserver fireChangesObserver:state];
}

+ (void)fireChangesObserver:(OSSMSSubscriptionState*)state {
    OSSMSSubscriptionStateChanges* stateChanges = [[OSSMSSubscriptionStateChanges alloc] init];
    stateChanges.from = OneSignal.lastSMSSubscriptionState;
    stateChanges.to = [state copy];
    
    // wants OSSMSSubscriptionState
    
    BOOL hasReceiver = [OneSignal.smsSubscriptionStateChangesObserver notifyChange:stateChanges];
    if (hasReceiver) {
        OneSignal.lastSMSSubscriptionState = [state copy];
        [OneSignal.lastSMSSubscriptionState persist];
    }
}

@end

@implementation OSSMSSubscriptionStateChanges
- (NSString*)description {
    static NSString* format = @"<OSSMSSubscriptionStateChanges:\nfrom: %@,\nto:   %@\n>";
    return [NSString stringWithFormat:format, _from, _to];
}

- (NSDictionary*)toDictionary {
    return @{@"from": [_from toDictionary],
             @"to": [_to toDictionary]};
}

@end
