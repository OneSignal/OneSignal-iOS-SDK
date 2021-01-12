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

#import "OneSignalHelper.h"
#import "OSEmailSubscription.h"
#import "OneSignalUserDefaults.h"
#import "OneSignalCommonDefines.h"

@implementation OSEmailSubscriptionState

- (ObservableEmailSubscriptionStateType *)observable {
    if (!_observable)
        _observable = [OSObservable new];
    return _observable;
}

- (instancetype)init {
    let standardUserDefaults = OneSignalUserDefaults.initStandard;
    _emailAddress = [standardUserDefaults getSavedStringForKey:OSUD_EMAIL_ADDRESS defaultValue:nil];
    _requiresEmailAuth = [standardUserDefaults getSavedBoolForKey:OSUD_REQUIRE_EMAIL_AUTH defaultValue:false];
    _emailAuthCode = [standardUserDefaults getSavedStringForKey:OSUD_EMAIL_AUTH_CODE defaultValue:nil];
    _emailUserId = [standardUserDefaults getSavedStringForKey:OSUD_EMAIL_PLAYER_ID defaultValue:nil];
    
    return self;
}

-(BOOL)isSubscribed {
    return self.emailUserId != nil;
}

- (void)persist {
    let standardUserDefaults = OneSignalUserDefaults.initStandard;
    [standardUserDefaults saveStringForKey:OSUD_EMAIL_ADDRESS withValue:_emailAddress];
    [standardUserDefaults saveBoolForKey:OSUD_REQUIRE_EMAIL_AUTH withValue:_requiresEmailAuth];
    [standardUserDefaults saveStringForKey:OSUD_EMAIL_AUTH_CODE withValue:_emailAuthCode];
    [standardUserDefaults saveStringForKey:OSUD_EMAIL_PLAYER_ID withValue:_emailUserId];
}

- (NSString *)description {
    @synchronized (self) {
        return [NSString stringWithFormat:@"<OSEmailSubscriptionState: emailAddress: %@, emailUserId: %@, emailAuthCode: %@>", self.emailAddress, self.emailUserId, self.emailAuthCode];
    }
}

- (instancetype)copyWithZone:(NSZone *)zone {
    OSEmailSubscriptionState *copy = [OSEmailSubscriptionState new];
    
    if (copy) {
        copy->_requiresEmailAuth = _requiresEmailAuth;
        copy->_emailAuthCode = [_emailAuthCode copy];
        copy->_emailUserId = [_emailUserId copy];
        copy->_emailAddress = [_emailAddress copy];
    }
    
    return copy;
}

- (void)setEmailUserId:(NSString *)emailUserId {
    BOOL changed = emailUserId != _emailUserId;
    _emailUserId = emailUserId;
    
    if (changed)
        [self.observable notifyChange:self];
}

- (void)setEmailAddress:(NSString *)emailAddress {
    _emailAddress = emailAddress;
}

- (BOOL)isEmailSetup {
    return _emailUserId && (!_requiresEmailAuth || _emailAuthCode);
}

- (NSDictionary *)toDictionary {
    return @{
       @"emailUserId": _emailUserId ?: [NSNull null],
       @"emailAddress": _emailAddress ?: [NSNull null],
       @"isSubscribed": @(self.isSubscribed)
    };
}

-(BOOL)compare:(OSEmailSubscriptionState *)from {
    return ![self.emailAddress ?: @"" isEqualToString:from.emailAddress ?: @""] || ![self.emailUserId ?: @"" isEqualToString:from.emailUserId ?: @""];
}

@end


@implementation OSEmailSubscriptionChangedInternalObserver

- (void)onChanged:(OSEmailSubscriptionState*)state {
    [OSEmailSubscriptionChangedInternalObserver fireChangesObserver:state];
}

+ (void)fireChangesObserver:(OSEmailSubscriptionState*)state {
    OSEmailSubscriptionStateChanges* stateChanges = [[OSEmailSubscriptionStateChanges alloc] init];
    stateChanges.from = OneSignal.lastEmailSubscriptionState;
    stateChanges.to = [state copy];
    
    // wants OSEmailSubscriptionState
    
    
    BOOL hasReceiver = [OneSignal.emailSubscriptionStateChangesObserver notifyChange:stateChanges];
    if (hasReceiver) {
        OneSignal.lastEmailSubscriptionState = [state copy];
        [OneSignal.lastEmailSubscriptionState persist];
    }
}

@end

@implementation OSEmailSubscriptionStateChanges
- (NSString*)description {
    static NSString* format = @"<OSEmailSubscriptionStateChanges:\nfrom: %@,\nto:   %@\n>";
    return [NSString stringWithFormat:format, _from, _to];
}

- (NSDictionary*)toDictionary {
    return @{@"from": [_from toDictionary],
             @"to": [_to toDictionary]};
}

@end
