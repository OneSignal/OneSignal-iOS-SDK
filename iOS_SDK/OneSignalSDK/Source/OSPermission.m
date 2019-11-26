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

#import "OSPermission.h"
#import "OneSignalHelper.h"
#import "OneSignalInternal.h"
#import "OneSignalUserDefaults.h"

@implementation OSPermissionState

- (ObserablePermissionStateType*)observable {
    if (!_observable)
        _observable = [OSObservable new];
    return _observable;
}

- (instancetype)initAsTo {
    [OneSignal.osNotificationSettings getNotificationPermissionState];
    
    return self;
}

- (instancetype)initAsFrom {
    let standardUserDefaults = OneSignalUserDefaults.initStandard;
    _hasPrompted = [standardUserDefaults getSavedBoolForKey:PERMISSION_HAS_PROMPTED defaultValue:false];
    _answeredPrompt = [standardUserDefaults getSavedBoolForKey:PERMISSION_ANSWERED_PROMPT defaultValue:false];
    _accepted  = [standardUserDefaults getSavedBoolForKey:PERMISSION_ACCEPTED defaultValue:false];
    _provisional = [standardUserDefaults getSavedBoolForKey:PERMISSION_PROVISIONAL_STATUS defaultValue:false];
    _providesAppNotificationSettings = [standardUserDefaults getSavedBoolForKey:PERMISSION_PROVIDES_NOTIFICATION_SETTINGS defaultValue:false];
    
    return self;
}

- (void)persistAsFrom {
    let standardUserDefaults = OneSignalUserDefaults.initStandard;
    [standardUserDefaults saveBoolForKey:PERMISSION_HAS_PROMPTED withValue:_hasPrompted];
    [standardUserDefaults saveBoolForKey:PERMISSION_ANSWERED_PROMPT withValue:_answeredPrompt];
    [standardUserDefaults saveBoolForKey:PERMISSION_ACCEPTED withValue:_accepted];
    [standardUserDefaults saveBoolForKey:PERMISSION_PROVISIONAL_STATUS withValue:_provisional];
    [standardUserDefaults saveBoolForKey:PERMISSION_PROVIDES_NOTIFICATION_SETTINGS withValue:_providesAppNotificationSettings];
}


- (instancetype)copyWithZone:(NSZone*)zone {
    OSPermissionState* copy = [[self class] new];
    
    if (copy) {
        copy->_hasPrompted = _hasPrompted;
        copy->_answeredPrompt = _answeredPrompt;
        copy->_accepted = _accepted;
        copy->_provisional = _provisional;
        copy->_providesAppNotificationSettings = _providesAppNotificationSettings;
    }
    
    return copy;
}

- (void)setHasPrompted:(BOOL)inHasPrompted {
    if (_hasPrompted != inHasPrompted)
        [OneSignalUserDefaults.initStandard saveBoolForKey:HAS_PROMPTED_FOR_NOTIFICATIONS withValue:true];
    
    BOOL last = self.hasPrompted;
    _hasPrompted = inHasPrompted;
    if (last != self.hasPrompted)
        [self.observable notifyChange:self];
}

- (BOOL)hasPrompted {
    // If we know they answered turned notificaitons on then were prompted at some point.
    if (self.answeredPrompt) // self. triggers getter
        return true;
    return _hasPrompted;
}

-(BOOL)reachable {
    return self.provisional || self.accepted;
}

- (void)setProvisional:(BOOL)provisional {
    if (_provisional != provisional)
        [OneSignalUserDefaults.initStandard saveBoolForKey:PROVISIONAL_AUTHORIZATION withValue:provisional];
    
    BOOL previous = _provisional;
    _provisional = provisional;
    
    if (previous != _provisional)
        [self.observable notifyChange:self];
}

- (BOOL)isProvisional {
    return _provisional;
}

- (void)setAnsweredPrompt:(BOOL)inansweredPrompt {
    BOOL last = self.answeredPrompt;
    _answeredPrompt = inansweredPrompt;
    if (last != self.answeredPrompt)
        [self.observable notifyChange:self];
}

- (BOOL)answeredPrompt {
    // If we got an accepted permission then they answered the prompt.
    if (_accepted)
        return true;
    return _answeredPrompt;
}

- (void)setAccepted:(BOOL)accepted {
    BOOL changed = _accepted != accepted;
    _accepted = accepted;
    if (changed)
        [self.observable notifyChange:self];
}

- (void)setProvidesAppNotificationSettings:(BOOL)providesAppNotificationSettings {
    _providesAppNotificationSettings = providesAppNotificationSettings;
}

- (OSNotificationPermission)status {
    if (_accepted)
        return OSNotificationPermissionAuthorized;
    
    if (self.answeredPrompt)
        return OSNotificationPermissionDenied;
    
    if (self.provisional)
        return OSNotificationPermissionProvisional;
    
    return OSNotificationPermissionNotDetermined;
}

- (NSString*)statusAsString {
    switch(self.status) {
        case OSNotificationPermissionNotDetermined:
            return @"NotDetermined";
        case OSNotificationPermissionAuthorized:
            return @"Authorized";
        case OSNotificationPermissionDenied:
            return @"Denied";
        case OSNotificationPermissionProvisional:
            return @"Provisional";
    }
    return @"NotDetermined";
}

- (BOOL)compare:(OSPermissionState*)from {
    return self.accepted != from.accepted ||
           self.answeredPrompt != from.answeredPrompt ||
           self.hasPrompted != from.hasPrompted;
}

- (NSString*)description {
    static NSString* format = @"<OSPermissionState: hasPrompted: %d, status: %@, provisional: %d>";
    return [NSString stringWithFormat:format, self.hasPrompted, self.statusAsString, self.provisional];
}

- (NSDictionary*)toDictionary {
    return @{@"hasPrompted": @(self.hasPrompted),
             @"status": @(self.status),
             @"provisional" : @(self.provisional)};
}

@end


@implementation OSPermissionChangedInternalObserver

- (void)onChanged:(OSPermissionState*)state {
    [OSPermissionChangedInternalObserver fireChangesObserver:state];
}

+ (void)fireChangesObserver:(OSPermissionState*)state  {
    OSPermissionStateChanges* stateChanges = [OSPermissionStateChanges alloc];
    stateChanges.from = OneSignal.lastPermissionState;
    stateChanges.to = [state copy];
    
    BOOL hasReceiver = [OneSignal.permissionStateChangesObserver notifyChange:stateChanges];
    if (hasReceiver) {
        OneSignal.lastPermissionState = [state copy];
        [OneSignal.lastPermissionState persistAsFrom];
    }
}

@end

@implementation OSPermissionStateChanges
- (NSString*)description {
    static NSString* format = @"<OSSubscriptionStateChanges:\nfrom: %@,\nto:   %@\n>";
    return [NSString stringWithFormat:format, _from, _to];
}

- (NSDictionary*)toDictionary {
    return @{@"from": [_from toDictionary], @"to": [_to toDictionary]};
}

@end
