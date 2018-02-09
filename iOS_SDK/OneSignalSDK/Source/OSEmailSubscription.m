//
//  OSEmailSubscription.m
//  OneSignal
//
//  Created by Brad Hesse on 2/7/18.
//  Copyright © 2018 Hiptic. All rights reserved.
//

#import "OSEmailSubscription.h"
#import "OneSignalHelper.h"
#import "OneSignalCommonDefines.h"

@implementation OSEmailSubscriptionState

- (ObservableEmailSubscriptionStateType *)observable {
    if (!_observable)
        _observable = [OSObservable new];
    return _observable;
}

- (instancetype)init {
    let userDefaults = [NSUserDefaults standardUserDefaults];
    
    _emailAddress = [userDefaults objectForKey:EMAIL_ADDRESS];
    _requiresEmailAuth = [[userDefaults objectForKey:REQUIRE_EMAIL_AUTH] boolValue];
    _emailAuthCode = [userDefaults stringForKey:EMAIL_AUTH_CODE];
    _emailUserId = [userDefaults stringForKey:EMAIL_USERID];
    
    return self;
}

-(BOOL)subscribed {
    return self.emailUserId != nil;
}

- (void)persist {
    let userDefaults = [NSUserDefaults standardUserDefaults];
    
    [userDefaults setObject:_emailAddress forKey:EMAIL_ADDRESS];
    [userDefaults setObject:[NSNumber numberWithBool:_requiresEmailAuth] forKey:REQUIRE_EMAIL_AUTH];
    [userDefaults setObject:_emailAuthCode forKey:EMAIL_AUTH_CODE];
    [userDefaults setObject:_emailUserId forKey:EMAIL_USERID];
    
    [userDefaults synchronize];
}

- (NSString *)description {
    @synchronized (self) {
        return [NSString stringWithFormat:@"<OSEmailSubscriptionState: emailAddress: %@, emailUserId: %@>", self.emailAddress, self.emailUserId];
    }
}

- (instancetype)copyWithZone:(NSZone *)zone {
    OSEmailSubscriptionState *copy = [OSEmailSubscriptionState new];
    NSLog(@"COPYING SUBSCRIPTION EMAIL STATE");
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

- (NSDictionary *)toDictionary {
    return @{
       @"emailUserId": _emailUserId ?: [NSNull null],
       @"emailAddress": _emailAddress ?: [NSNull null]
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
