/**
Modified MIT License

Copyright 2020 OneSignal

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

#import <Foundation/Foundation.h>
#import "OSOutcomeEventsFactory.h"
#import "OSOutcomeEventsRepository.h"
#import "OSOutcomeEventsV1Repository.h"
#import "OSOutcomeEventsV2Repository.h"

@interface OSOutcomeEventsFactory ()

@property (strong, nonatomic, readonly, nonnull) OSOutcomeEventsCache *cache;
@property (strong, nonatomic, readwrite, nonnull) OSOutcomeEventsRepository *repository;

@end

@implementation OSOutcomeEventsFactory

- (instancetype)initWithCache:(OSOutcomeEventsCache *)cache {
    self = [super init];
    if (self) {
        _cache = cache;
    }
    return self;
}

- (OSOutcomeEventsRepository *)repository {
    if (!_repository)
        [self createRepository];
    else
        [self checkVersionChanged];
    return _repository;
}

- (void)checkVersionChanged {
    if (![_cache isOutcomesV2ServiceEnabled] && [_repository class] == [OSOutcomeEventsV1Repository class])
        return;
    if ([_cache isOutcomesV2ServiceEnabled] && [_repository class] == [OSOutcomeEventsV2Repository class])
        return;

    [self createRepository];
}

- (void)createRepository {
    if ([_cache isOutcomesV2ServiceEnabled])
        _repository = [[OSOutcomeEventsV2Repository alloc] initWithCache:_cache];
    else
        _repository = [[OSOutcomeEventsV1Repository alloc] initWithCache:_cache];
}

@end
