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
#import "OSNotificationTracker.h"
#import <OneSignalCore/OneSignalCore.h>

@interface OSChannelTracker ()

- (NSArray * _Nonnull)lastReceivedIds;

@end

@implementation OSNotificationTracker

- (NSString * _Nonnull)idTag {
    return @"notification_id";
}

- (OSInfluenceChannel)channelType {
    return NOTIFICATION;
}

- (NSArray * _Nullable)lastChannelObjectsReceivedByNewId:(NSString *)identifier {
    return [self lastChannelObjects];
}

- (NSArray * _Nullable)lastChannelObjects {
    return [self.dataRepository lastNotificationsReceivedData];
}

- (NSInteger)channelLimit {
    return [self.dataRepository notificationLimit];
}

- (NSInteger)indirectAttributionWindow {
    return [self.dataRepository notificationIndirectAttributionWindow];
}

- (void)saveChannelObjects:(NSArray * _Nonnull)channelObjects {
   [self.dataRepository saveNotifications:channelObjects];
}

- (void)initInfluencedTypeFromCache {
    OSInfluenceType influenceType = [self.dataRepository notificationCachedInfluenceType];
    self.influenceType = influenceType;

    if (influenceType == INDIRECT)
        self.indirectIds = [self.dataRepository cachedIndirectNotifications];
    else if (influenceType == DIRECT)
        self.directId = [self.dataRepository cachedNotificationOpenId];

    [OneSignalLog onesignalLog:ONE_S_LL_DEBUG message:[NSString stringWithFormat:@"NotificationTracker initInfluencedTypeFromCache: %@", [self description]]];
}

- (void)cacheState {
    [self.dataRepository cacheNotificationInfluenceType:self.influenceType];
    [self.dataRepository cacheIndirectNotifications:self.indirectIds];
    [self.dataRepository cacheNotificationOpenId:self.directId];
}

@end
