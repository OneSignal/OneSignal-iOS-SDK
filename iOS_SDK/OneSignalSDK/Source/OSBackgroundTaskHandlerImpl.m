/*
 Modified MIT License

 Copyright 2022 OneSignal

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

#import "OSBackgroundTaskHandlerImpl.h"
#import <OneSignalOSCore/OneSignalOSCore-Swift.h>
#import <OneSignalCore/OneSignalCore.h>
#import <UIKit/UIKit.h>

@implementation OSBackgroundTaskHandlerImpl {
    // A name can be begun again before its earlier task ends, so each name keeps every task still open.
    NSMutableDictionary<NSString *, NSMutableArray<NSNumber *> *> *_tasks;
}

- (instancetype)init {
    self = [super init];
    _tasks = [NSMutableDictionary new];
    return self;
}

- (void)beginBackgroundTask:(NSString * _Nonnull)taskIdentifier {
    [OneSignalLog onesignalLog:ONE_S_LL_DEBUG
                     message:[NSString stringWithFormat:
                              @"OSBackgroundTaskManagerImpl:beginBackgroundTask: %@", taskIdentifier]];
    __block UIBackgroundTaskIdentifier uiIdentifier = UIBackgroundTaskInvalid;
    uiIdentifier = [UIApplication.sharedApplication beginBackgroundTaskWithName:taskIdentifier expirationHandler:^{
        [OneSignalLog onesignalLog:ONE_S_LL_DEBUG
                         message:[NSString stringWithFormat:
                                  @"OSBackgroundTaskManagerImpl: expirationHandler called for %@", taskIdentifier]];
        [self endExpiredTask:uiIdentifier named:taskIdentifier];
    }];
    if (uiIdentifier == UIBackgroundTaskInvalid) {
        return;
    }
    @synchronized (_tasks) {
        NSMutableArray<NSNumber *> *uiIdentifiers = _tasks[taskIdentifier];
        if (!uiIdentifiers) {
            uiIdentifiers = [NSMutableArray new];
            _tasks[taskIdentifier] = uiIdentifiers;
        }
        [uiIdentifiers addObject:@(uiIdentifier)];
    }
}

- (void)endBackgroundTask:(NSString * _Nonnull)taskIdentifier {
    NSArray<NSNumber *> *uiIdentifiers;
    @synchronized (_tasks) {
        uiIdentifiers = _tasks[taskIdentifier];
        [_tasks removeObjectForKey:taskIdentifier];
    }
    for (NSNumber *uiIdentifier in uiIdentifiers) {
        [OneSignalLog onesignalLog:ONE_S_LL_DEBUG
                         message:[NSString stringWithFormat:
                                  @"OSBackgroundTaskManagerImpl:endBackgroundTask: %@ with UIBackgroundTaskIdentifier %@",
                                  taskIdentifier, uiIdentifier]];
        [UIApplication.sharedApplication endBackgroundTask:uiIdentifier.unsignedIntegerValue];
    }
}

- (void)endExpiredTask:(UIBackgroundTaskIdentifier)uiIdentifier named:(NSString *)taskIdentifier {
    @synchronized (_tasks) {
        NSMutableArray<NSNumber *> *uiIdentifiers = _tasks[taskIdentifier];
        [uiIdentifiers removeObject:@(uiIdentifier)];
        if (uiIdentifiers.count == 0) {
            [_tasks removeObjectForKey:taskIdentifier];
        }
    }
    [UIApplication.sharedApplication endBackgroundTask:uiIdentifier];
}

// A task that is forgotten while open can never be ended, so this ends it.
- (void)setTaskInvalid:(NSString * _Nonnull)taskIdentifier {
    [self endBackgroundTask:taskIdentifier];
}

@end
