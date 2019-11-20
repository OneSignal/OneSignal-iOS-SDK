/**
 * Modified MIT License
 *
 * Copyright 2019 OneSignal
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

#import "OneSignal.h"
#import "OSSessionResult.h"
#import "OSBaseFocusTimeProcessor.h"
#import "OneSignalUserDefaults.h"
#import "OneSignalCommonDefines.h"

// This is an abstract class
@implementation OSBaseFocusTimeProcessor {
    NSNumber* unsentActiveTime;
}

// Must override
- (int)getMinSessionTime {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
      reason:[NSString stringWithFormat:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)] userInfo:nil];
}

- (BOOL)hasMinSyncTime:(NSTimeInterval)activeTime {
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"OSBaseFocusTimeProcessor hasMinSyncTime getMinSessionTime: %d activeTime: %f", [self getMinSessionTime], activeTime]];
    return activeTime >= [self getMinSessionTime];
}

- (void)resetUnsentActiveTime {
    unsentActiveTime = nil;
}

- (NSString*)unsentActiveTimeUserDefaultsKey {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
      reason:[NSString stringWithFormat:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)] userInfo:nil];
}

- (void)saveUnsentActiveTime:(NSTimeInterval)time {
    unsentActiveTime = @(time);
    [OneSignalUserDefaults.initShared saveObjectForKey:self.unsentActiveTimeUserDefaultsKey withValue:unsentActiveTime];
}

// Must override
- (void)sendOnFocusCall:(OSFocusCallParams *)params {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
      reason:[NSString stringWithFormat:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)] userInfo:nil];
}

// Must override
- (void)sendUnsentActiveTime:(OSFocusCallParams *)params {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
      reason:[NSString stringWithFormat:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)] userInfo:nil];
}

// Must override
- (void)cancelDelayedJob {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
      reason:[NSString stringWithFormat:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)] userInfo:nil];
}

- (NSTimeInterval)getUnsentActiveTime {
    if (!unsentActiveTime)
        unsentActiveTime = [OneSignalUserDefaults.initShared getSavedObject:self.unsentActiveTimeUserDefaultsKey defaultValue:@0];
    
    return [unsentActiveTime doubleValue];
}

@end
