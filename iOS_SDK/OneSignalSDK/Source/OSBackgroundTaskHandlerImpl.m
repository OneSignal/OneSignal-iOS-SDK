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

// iOS allows a backgrounded app about 30 s, and UIKit runs expiration handlers only on the main thread.
// A 20 s off-main-thread limit ends stalled tasks inside that allowance.
static const NSTimeInterval DEFAULT_BACKGROUND_TASK_TIME_LIMIT = 20;

@interface _OSOpenBackgroundTask : NSObject
@property (nonatomic, readonly) UIBackgroundTaskIdentifier uiIdentifier;
@property (nonatomic, strong, nullable) dispatch_source_t timeoutTimer;
@end

@implementation _OSOpenBackgroundTask

- (instancetype)initWithUIIdentifier:(UIBackgroundTaskIdentifier)uiIdentifier {
    self = [super init];
    if (self) {
        _uiIdentifier = uiIdentifier;
    }
    return self;
}

@end

@implementation OSBackgroundTaskHandlerImpl {
    // A name can begin again before its earlier task ends, so each name keeps every open task.
    NSMutableDictionary<NSString *, NSMutableArray<_OSOpenBackgroundTask *> *> *_tasks;
    NSTimeInterval _timeLimit;
    UIBackgroundTaskIdentifier (^_beginTask)(NSString *taskIdentifier, void (^expirationHandler)(void));
    void (^_endTask)(UIBackgroundTaskIdentifier uiIdentifier);
}

- (instancetype)init {
    return [self initWithTimeLimit:DEFAULT_BACKGROUND_TASK_TIME_LIMIT
                         beginTask:^UIBackgroundTaskIdentifier(NSString *taskIdentifier, void (^expirationHandler)(void)) {
                             return [UIApplication.sharedApplication beginBackgroundTaskWithName:taskIdentifier
                                                                               expirationHandler:expirationHandler];
                         }
                           endTask:^(UIBackgroundTaskIdentifier uiIdentifier) {
                               [UIApplication.sharedApplication endBackgroundTask:uiIdentifier];
                           }];
}

- (instancetype)initWithTimeLimit:(NSTimeInterval)timeLimit
                        beginTask:(UIBackgroundTaskIdentifier (^)(NSString *taskIdentifier, void (^expirationHandler)(void)))beginTask
                          endTask:(void (^)(UIBackgroundTaskIdentifier uiIdentifier))endTask {
    self = [super init];
    if (self) {
        _tasks = [NSMutableDictionary new];
        _timeLimit = timeLimit;
        _beginTask = [beginTask copy];
        _endTask = [endTask copy];
    }
    return self;
}

- (void)dealloc {
    for (NSArray<_OSOpenBackgroundTask *> *openTasks in _tasks.allValues) {
        for (_OSOpenBackgroundTask *openTask in openTasks) {
            if (openTask.timeoutTimer) {
                dispatch_source_cancel(openTask.timeoutTimer);
            }
        }
    }
}

- (void)beginBackgroundTask:(NSString * _Nonnull)taskIdentifier {
    [OneSignalLog onesignalLog:ONE_S_LL_DEBUG
                     message:[NSString stringWithFormat:
                              @"OSBackgroundTaskManagerImpl:beginBackgroundTask: %@", taskIdentifier]];
    __block UIBackgroundTaskIdentifier trackedIdentifier = UIBackgroundTaskInvalid;
    __block BOOL expired = NO;
    UIBackgroundTaskIdentifier uiIdentifier = _beginTask(taskIdentifier, ^{
        [OneSignalLog onesignalLog:ONE_S_LL_DEBUG
                         message:[NSString stringWithFormat:
                                  @"OSBackgroundTaskManagerImpl: expirationHandler called for %@", taskIdentifier]];
        _OSOpenBackgroundTask *expiredTask = nil;
        @synchronized (self->_tasks) {
            expired = YES;
            if (trackedIdentifier != UIBackgroundTaskInvalid) {
                expiredTask = [self removeOpenTaskLockedWithUIIdentifier:trackedIdentifier named:taskIdentifier];
            }
        }
        if (expiredTask) {
            [self finishOpenTask:expiredTask named:taskIdentifier];
        }
    });
    if (uiIdentifier == UIBackgroundTaskInvalid) {
        return;
    }

    _OSOpenBackgroundTask *openTask = [[_OSOpenBackgroundTask alloc] initWithUIIdentifier:uiIdentifier];
    BOOL alreadyExpired = NO;
    @synchronized (_tasks) {
        if (expired) {
            alreadyExpired = YES;
        } else {
            trackedIdentifier = uiIdentifier;
            NSMutableArray<_OSOpenBackgroundTask *> *openTasks = _tasks[taskIdentifier];
            if (!openTasks) {
                openTasks = [NSMutableArray new];
                _tasks[taskIdentifier] = openTasks;
            }
            [openTasks addObject:openTask];
            if (_timeLimit > 0) {
                openTask.timeoutTimer = [self startTimeoutTimerForUIIdentifier:uiIdentifier named:taskIdentifier];
            }
        }
    }
    if (alreadyExpired) {
        [self finishUIIdentifier:uiIdentifier named:taskIdentifier];
    }
}

- (void)endBackgroundTask:(NSString * _Nonnull)taskIdentifier {
    NSArray<_OSOpenBackgroundTask *> *openTasks;
    @synchronized (_tasks) {
        openTasks = _tasks[taskIdentifier];
        [_tasks removeObjectForKey:taskIdentifier];
    }
    for (_OSOpenBackgroundTask *openTask in openTasks) {
        [self finishOpenTask:openTask named:taskIdentifier];
    }
}

// A task that is forgotten while open can never end, so this ends it.
- (void)setTaskInvalid:(NSString * _Nonnull)taskIdentifier {
    [self endBackgroundTask:taskIdentifier];
}

- (dispatch_source_t)startTimeoutTimerForUIIdentifier:(UIBackgroundTaskIdentifier)uiIdentifier
                                                named:(NSString *)taskIdentifier {
    dispatch_queue_t queue = dispatch_get_global_queue(QOS_CLASS_UTILITY, 0);
    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    int64_t delayNs = (int64_t)(_timeLimit * NSEC_PER_SEC);
    uint64_t leewayNs = (uint64_t)MIN(delayNs / 10, (int64_t)(NSEC_PER_SEC / 10));
    dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, delayNs), DISPATCH_TIME_FOREVER, leewayNs);
    __weak typeof(self) weakSelf = self;
    dispatch_source_set_event_handler(timer, ^{
        [weakSelf endTimedOutTask:uiIdentifier named:taskIdentifier];
    });
    dispatch_resume(timer);
    return timer;
}

- (void)endTimedOutTask:(UIBackgroundTaskIdentifier)uiIdentifier named:(NSString *)taskIdentifier {
    _OSOpenBackgroundTask *timedOutTask = nil;
    @synchronized (_tasks) {
        timedOutTask = [self removeOpenTaskLockedWithUIIdentifier:uiIdentifier named:taskIdentifier];
    }
    if (timedOutTask) {
        [OneSignalLog onesignalLog:ONE_S_LL_DEBUG
                         message:[NSString stringWithFormat:
                                  @"OSBackgroundTaskManagerImpl: time limit reached for %@ with UIBackgroundTaskIdentifier %lu",
                                  taskIdentifier, (unsigned long)uiIdentifier]];
        [self finishOpenTask:timedOutTask named:taskIdentifier];
    }
}

- (nullable _OSOpenBackgroundTask *)removeOpenTaskLockedWithUIIdentifier:(UIBackgroundTaskIdentifier)uiIdentifier
                                                                   named:(NSString *)taskIdentifier {
    NSMutableArray<_OSOpenBackgroundTask *> *openTasks = _tasks[taskIdentifier];
    for (NSUInteger i = 0; i < openTasks.count; i++) {
        if (openTasks[i].uiIdentifier == uiIdentifier) {
            _OSOpenBackgroundTask *task = openTasks[i];
            [openTasks removeObjectAtIndex:i];
            if (openTasks.count == 0) {
                [_tasks removeObjectForKey:taskIdentifier];
            }
            return task;
        }
    }
    return nil;
}

- (void)finishOpenTask:(_OSOpenBackgroundTask *)openTask named:(NSString *)taskIdentifier {
    if (openTask.timeoutTimer) {
        dispatch_source_cancel(openTask.timeoutTimer);
        openTask.timeoutTimer = nil;
    }
    [self finishUIIdentifier:openTask.uiIdentifier named:taskIdentifier];
}

- (void)finishUIIdentifier:(UIBackgroundTaskIdentifier)uiIdentifier named:(NSString *)taskIdentifier {
    [OneSignalLog onesignalLog:ONE_S_LL_DEBUG
                     message:[NSString stringWithFormat:
                              @"OSBackgroundTaskManagerImpl:endBackgroundTask: %@ with UIBackgroundTaskIdentifier %lu",
                              taskIdentifier, (unsigned long)uiIdentifier]];
    _endTask(uiIdentifier);
}

@end
