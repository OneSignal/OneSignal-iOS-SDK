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
#import "OSInfluence.h"
#import "OSIndirectInfluence.h"
#import "OSInAppMessageTracker.h"
#import <OneSignalCore/OneSignalCore.h>

@interface OSChannelTracker ()

- (NSArray * _Nonnull)lastReceivedIds;

@end

@implementation OSInAppMessageTracker

- (NSString * _Nonnull)idTag {
    return @"iam_id";
}

- (OSInfluenceChannel)channelType {
    return IN_APP_MESSAGE;
}

- (NSArray * _Nonnull)lastChannelObjectsReceivedByNewId:(NSString *)identifier {
    NSArray *lastChannelObjectReceived = [self lastChannelObjects];
    // For IAM we handle redisplay, we need to remove duplicates for new influence Id
    NSMutableArray *auxLastChannelObjectReceived = [NSMutableArray new];
    if (lastChannelObjectReceived) {
        for (var i = 0; i < lastChannelObjectReceived.count; i++) {
            OSIndirectInfluence* indirectInfluence = [lastChannelObjectReceived objectAtIndex:i];
            if (![indirectInfluence.influenceId isEqualToString:identifier])
                [auxLastChannelObjectReceived addObject:indirectInfluence];
        }
    }
    return auxLastChannelObjectReceived;
}

- (NSArray * _Nullable)lastChannelObjects {
    return [self.dataRepository lastIAMsReceivedData];
}

- (NSInteger)channelLimit {
    return [self.dataRepository iamLimit];
}

- (NSInteger)indirectAttributionWindow {
    return [self.dataRepository iamIndirectAttributionWindow];
}

- (void)saveChannelObjects:(NSArray * _Nonnull)channelObjects {
    [self.dataRepository saveIAMs:channelObjects];
}

- (void)initInfluencedTypeFromCache {
    self.influenceType = [self.dataRepository iamCachedInfluenceType];
    if (self.influenceType == INDIRECT)
        self.indirectIds = [self lastReceivedIds];
    
    [OneSignalLog onesignalLog:ONE_S_LL_DEBUG message:[NSString stringWithFormat:@"InAppMessageTracker initInfluencedTypeFromCache: %@", [self description]]];
}

- (void)cacheState {
    // We only need to cache INDIRECT and UNATTRIBUTED influence types
    // DIRECT is downgrade to INDIRECT to avoid inconsistency state
    // where the app might be close before dismissing current displayed IAM
    [self.dataRepository cacheIAMInfluenceType:self.influenceType == DIRECT ? INDIRECT : self.influenceType];
}

@end
