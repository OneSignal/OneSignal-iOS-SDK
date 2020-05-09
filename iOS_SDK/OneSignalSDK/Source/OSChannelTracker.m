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
#import "OneSignal.h"
#import "OneSignalHelper.h"
#import "OneSignalCommonDefines.h"
#import "OSInfluence.h"
#import "OSChannelTracker.h"
#import "OSIndirectInfluence.h"

#define mustOverride() @throw [NSException exceptionWithName:NSInvalidArgumentException reason:[NSString stringWithFormat:@"%s must be overridden in a subclass/category", __PRETTY_FUNCTION__] userInfo:nil]
#define methodNotImplemented() mustOverride()

@implementation OSChannelTracker

- (id)initWithRepository:(OSInfluenceDataRepository *)dataRepository {
    self = [super init];
    if (self) {
        _dataRepository = dataRepository;
    }
    return self;
}

/*
 Start Methods implemented by childrens
 */
- (NSString * _Nonnull)idTag { mustOverride(); }
- (OSInfluenceChannel)channelType { mustOverride(); }
- (NSArray * _Nonnull)lastChannelObjectsReceivedByNewId:(NSString *)identifier { mustOverride(); }
- (NSArray * _Nonnull)lastChannelObjects { mustOverride(); }
- (NSInteger)channelLimit { mustOverride(); }
- (NSInteger)indirectAttributionWindow { mustOverride(); }
- (void)saveChannelObjects:(NSArray * _Nonnull)channelObjects { mustOverride(); }
- (void)initInfluencedTypeFromCache { mustOverride(); }
- (void)cacheState { mustOverride(); }
/*
 End Methods implemented by childrens
*/

- (BOOL)isDirectSessionEnabled {
    return [self.dataRepository isDirectInfluenceEnabled];
}

- (BOOL)isIndirectSessionEnabled {
    return [self.dataRepository isIndirectInfluenceEnabled];
}

- (BOOL)isUnattributedSessionEnabled {
    return [self.dataRepository isUnattributedInfluenceEnabled];
}

- (void)resetAndInitInfluence {
    _directId = nil;
    _indirectIds = [self lastReceivedIds];
    _influenceType = _indirectIds != nil && _indirectIds.count > 0 ? INDIRECT : UNATTRIBUTED;
    
    [self cacheState];
    [OneSignal onesignal_Log:ONE_S_LL_DEBUG message:[NSString stringWithFormat:@"OSChannelTracker resetAndInitInfluence for: %@ finish with influenceType: %@", [self idTag], OS_INFLUENCE_TYPE_TO_STRING(_influenceType)]];
}

- (NSArray * _Nonnull)lastReceivedIds {
    NSMutableArray *ids = [NSMutableArray new];
    NSArray *lastChannelObjectReceived = [self lastChannelObjects];
    [OneSignal onesignal_Log:ONE_S_LL_DEBUG message:[NSString stringWithFormat:@"OSChannelTracker for: %@ lastChannelObjectReceived: %@", [self idTag], lastChannelObjectReceived]];
    if (!lastChannelObjectReceived || lastChannelObjectReceived.count == 0)
        return ids; // Unattributed session
     
    NSInteger attributionWindowInSeconds = [self indirectAttributionWindow];
    NSTimeInterval currentTime = [[NSDate date] timeIntervalSince1970];
    
    // Add only valid indirectInfluences within the attribution window
    for (var i = 0; i < lastChannelObjectReceived.count; i++) {
        OSIndirectInfluence* indirectInfluence = [lastChannelObjectReceived objectAtIndex:i];
        long difference = currentTime - indirectInfluence.timestamp;
        if (difference <= attributionWindowInSeconds)
            [ids addObject:indirectInfluence.influenceId];
    }
    return ids;
}

- (void)saveLastId:(NSString *)lastId {
    [OneSignal onesignal_Log:ONE_S_LL_DEBUG message:[NSString stringWithFormat:@"OSChannelTracker for: %@ saveLastId id: %@", [self idTag], lastId]];
       
    let channelLimit = [self channelLimit];
    let lastChannelObjectsReceived = [self lastChannelObjectsReceivedByNewId:lastId];

    [OneSignal onesignal_Log:ONE_S_LL_DEBUG message:[NSString stringWithFormat:@"OSChannelTracker for: %@ saveLastId with lastChannelObjectReceived: %@", [self idTag], lastChannelObjectsReceived]];

    let timestamp = [NSDate date].timeIntervalSince1970;
    let indirectInfluence = [[OSIndirectInfluence alloc] initWithParamsInfluenceId:lastId forChannel:[self idTag] timestamp:timestamp];
       
    // Create channelObjectToSave to be saved at a limited size, removing any old notifications
    NSArray *channelObjectToSave;
    if (lastChannelObjectsReceived == nil || lastChannelObjectsReceived.count == 0) {
        channelObjectToSave = [NSArray arrayWithObject:indirectInfluence];
    } else if (lastChannelObjectsReceived.count < channelLimit) {
        NSMutableArray *lastChannelObjectsReceivedMutable = [lastChannelObjectsReceived mutableCopy];
        [lastChannelObjectsReceivedMutable addObject:indirectInfluence];
        channelObjectToSave = lastChannelObjectsReceivedMutable;
    } else {
        NSMutableArray *lastChannelObjectsReceivedMutable = [lastChannelObjectsReceived mutableCopy];
        [lastChannelObjectsReceivedMutable addObject:indirectInfluence];
        
        // Remove old indirectInfluences to keep final indirectInfluence at a limited size
        let lengthDifference = lastChannelObjectsReceivedMutable.count - channelLimit;
        for (int i = 0; i < lengthDifference; i++)
            [lastChannelObjectsReceivedMutable removeObjectAtIndex:0];
        
        channelObjectToSave = lastChannelObjectsReceivedMutable;
    }
       
    [OneSignal onesignal_Log:ONE_S_LL_DEBUG message:[NSString stringWithFormat:@"OSChannelTracker for: %@ with channelObjectToSave: %@", [self idTag], channelObjectToSave]];
    [self saveChannelObjects:channelObjectToSave];
}

- (OSInfluence *)currentSessionInfluence {
    OSInfluenceBuilder *builder = [OSInfluenceBuilder new];
    builder.influenceType = DISABLED;
    builder.influenceChannel = [self channelType];
    
    if (_influenceType == DIRECT) {
        if ([self isDirectSessionEnabled]) {
            NSArray *ids = [NSArray arrayWithObject:_directId];
            builder.ids = ids;
            builder.influenceType = DIRECT;
        }
    } else if (_influenceType == INDIRECT) {
        if ([self isIndirectSessionEnabled]) {
            builder.ids = _indirectIds;
            builder.influenceType = INDIRECT;
        }
    } else if ([self isUnattributedSessionEnabled]) {
        builder.influenceType = UNATTRIBUTED;
    }
    
    return [[OSInfluence alloc] initWithBuilder:builder];
}

- (NSString *)description {
    return [NSString stringWithFormat:
            @"OSChannelTracker tag: %@ influenceType: %@ indirectIds: %@ directIs: %@", [self idTag], OS_INFLUENCE_TYPE_TO_STRING(_influenceType), _indirectIds, _directId];
}

@end
