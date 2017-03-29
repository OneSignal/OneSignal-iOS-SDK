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

#import "OneSignalInternal.h"

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
    NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
    
    _hasPrompted = [userDefaults boolForKey:@"OS_HAS_PROMPTED_FOR_NOTIFICATIONS_LAST"];
    _anwseredPrompt = [userDefaults boolForKey:@"OS_NOTIFICATION_PROMPT_ANSWERED_LAST"];
    _accepted  = [userDefaults boolForKey:@"ONESIGNAL_ACCEPTED_NOTIFICATION_LAST"];
    
    return self;
}

- (void)persistAsFrom {
    NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
    
    [userDefaults setBool:_hasPrompted forKey:@"OS_HAS_PROMPTED_FOR_NOTIFICATIONS_LAST"];
    [userDefaults setBool:_anwseredPrompt forKey:@"OS_NOTIFICATION_PROMPT_ANSWERED_LAST"];
    [userDefaults setBool:_accepted forKey:@"ONESIGNAL_ACCEPTED_NOTIFICATION_LAST"];
    
    [userDefaults synchronize];
}


- (instancetype)copyWithZone:(NSZone*)zone {
    OSPermissionState* copy = [[self class] new];
    
    if (copy) {
        copy->_hasPrompted = _hasPrompted;
        copy->_anwseredPrompt = _anwseredPrompt;
        copy->_accepted = _accepted;
    }
    
    return copy;
}

- (void)setHasPrompted:(BOOL)inHasPrompted {
    BOOL last = self.hasPrompted;
    _hasPrompted = inHasPrompted;
    if (last != self.hasPrompted)
        [self.observable notifyChange:self];
}

- (BOOL)hasPrompted {
    // If we know they anwsered turned notificaitons on then were prompted at some point.
    if (self.anwseredPrompt) // self. triggers getter
        return true;
    return _hasPrompted;
}

- (void)setAnwseredPrompt:(BOOL)inAnwseredPrompt {
    BOOL last = self.anwseredPrompt;
    _anwseredPrompt = inAnwseredPrompt;
    if (last != self.anwseredPrompt)
        [self.observable notifyChange:self];
}

- (BOOL)anwseredPrompt {
    // If we got an accepted permission then they anwsered the prompt.
    if (_accepted)
        return true;
    return _anwseredPrompt;
}

- (void)setAccepted:(BOOL)accepted {
    BOOL changed = _accepted != accepted;
    _accepted = accepted;
    if (changed)
        [self.observable notifyChange:self];
}

- (NSString*)description {
    static NSString* format = @"<OSPermissionState: hasPrompted: %d, anwseredPrompt: %d, accepted: %d>";
    return [NSString stringWithFormat:format, self.hasPrompted, self.anwseredPrompt, self.accepted];
}

@end


@implementation OSPermissionStateChanges
- (NSString*)description {
    static NSString* format = @"<OSSubscriptionStateChanges:\nfrom: %@,\nto:   %@\n>";
    return [NSString stringWithFormat:format, _from, _to];
}
@end


@implementation OSPermissionChangedInternalObserver

- (void)onChanged:(OSPermissionState*)state {
    OSPermissionStateChanges* stateChanges = [OSPermissionStateChanges alloc];
    stateChanges.from = OneSignal.lastPermissionState;
    stateChanges.to = state;
    
    [OneSignal.permissionStateChangesObserver notifyChange:stateChanges];
    
    OneSignal.lastPermissionState = [state copy];
    
    [OneSignal.lastPermissionState persistAsFrom];
}

@end
