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
#import "OSTrackerFactory.h"
#import "OSInAppMessageTracker.h"
#import "OSNotificationTracker.h"

@implementation OSTrackerFactory

NSDictionary<NSString *, OSChannelTracker *> *_trackers;
OSInfluenceDataRepository *_dataRepository;

- (id)initWithRepository:(OSInfluenceDataRepository *)dataRepository {
    self = [super init];
    if (self) {
        _dataRepository = dataRepository;
        _trackers = @{
            @"iam"          : [[OSInAppMessageTracker alloc] initWithRepository:_dataRepository],
            @"notification" : [[OSNotificationTracker alloc] initWithRepository:_dataRepository],
        };
    }
    return self;
}

- (void)saveInfluenceParams:(NSDictionary *)params {
    [_dataRepository saveInfluenceParams:params];
}

- (void)initFromCache {
    for (NSString* key in _trackers) {
        OSChannelTracker * channel = _trackers[key];
        [channel initInfluencedTypeFromCache];
    }
}

- (NSArray<OSInfluence *> * _Nonnull)influences {
    NSMutableArray *influences = [NSMutableArray new];
    for (NSString* key in _trackers) {
        OSChannelTracker * channel = _trackers[key];
        [influences addObject:[channel currentSessionInfluence]];
    }

    return influences;
}

- (NSArray<OSInfluence *> *)sessionInfluences {
    NSMutableArray *influences = [NSMutableArray new];
    for (NSString* key in _trackers) {
        OSChannelTracker * channel = _trackers[key];

        // IAM doesnt influence session calls
        if ([channel class] == [OSInAppMessageTracker class] )
            continue;

        [influences addObject:[channel currentSessionInfluence]];
    }

    return influences;
}

- (OSChannelTracker * _Nonnull)iamChannelTracker {
    return [_trackers objectForKey:@"iam"];
}

- (OSChannelTracker * _Nonnull)notificationChannelTracker {
    return [_trackers objectForKey:@"notification"];
}

- (OSChannelTracker * _Nullable)channelByEntryAction:(AppEntryAction)entryAction {
    if (entryAction == NOTIFICATION_CLICK)
        return [self notificationChannelTracker];

    return nil;
}

- (NSArray<OSChannelTracker *> * _Nonnull)channels {
    NSMutableArray *channels = [NSMutableArray new];
    [channels addObject:[self notificationChannelTracker]];
    [channels addObject:[self iamChannelTracker]];
    return channels;
}

- (NSArray<OSChannelTracker *> * _Nonnull)channelsToResetByEntryAction:(AppEntryAction)entryAction {
    NSMutableArray *channels = [NSMutableArray new];

    // Avoid reset session if application is closed
    if (entryAction == APP_CLOSE)
        return channels;

    // Avoid reset session if app was focused due to a notification click (direct session recently set)
    if (entryAction == APP_OPEN)
        [channels addObject:[self notificationChannelTracker]];

    [channels addObject:[self iamChannelTracker]];
    return channels;
}

@end
