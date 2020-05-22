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
#import "OSCachedUniqueOutcome.h"
#import "OSOutcomeEventsRepository.h"

#define mustOverride() @throw [NSException exceptionWithName:NSInvalidArgumentException reason:[NSString stringWithFormat:@"%s must be overridden in a subclass/category", __PRETTY_FUNCTION__] userInfo:nil]
#define methodNotImplemented() mustOverride()

@implementation OSOutcomeEventsRepository

- (id)initWithCache:(OSOutcomeEventsCache *)outcomeEventsCache {
    self = [super init];
    if (self) {
        _outcomeEventsCache = outcomeEventsCache;
    }
    return self;
}

- (void)requestMeasureOutcomeEventWithAppId:(NSString *)appId
                                 deviceType:(NSNumber *)deviceType
                                      event:(OSOutcomeEventParams *)event
                                  onSuccess:(OSResultSuccessBlock)successBlock
                                  onFailure:(OSFailureBlock)failureBlock {
    mustOverride();
}

/*
    1. Iterate over all notifications and find the ones in the set that don't exist (ex. "<name> + "_" + <notificationId>"
    2. Create an NSArray of these notificationIds and return it
    3. If the array has notifications send the request for only these ids
*/
- (NSArray *)getNotCachedUniqueInfluencesForOutcome:(NSString *)name influences:(NSArray *)influences {
    NSArray * attributedUniqueOutcomeEventSent = [self getAttributedUniqueOutcomeEventSent];
    NSMutableArray *uniqueInfluences = [NSMutableArray new];
    for (OSInfluence *influence in influences) {
        NSMutableArray *availableInfluenceIds = [NSMutableArray new];
        NSArray *influenceIds = influence.ids;
      
        if (influenceIds == nil)
            continue;
        
        for (NSString *indentifier in influenceIds) {
            OSCachedUniqueOutcome *uniqueOutcome = [[OSCachedUniqueOutcome new] initWithParamsName:name uniqueId:indentifier channel:influence.influenceChannel];
            
            if (attributedUniqueOutcomeEventSent == nil || attributedUniqueOutcomeEventSent.count == 0) {
                [availableInfluenceIds addObject:uniqueOutcome.uniqueId];
                continue;
            }
            
            BOOL found = NO;
            for (OSCachedUniqueOutcome *uniqueOutcomeSent in attributedUniqueOutcomeEventSent) {
                if ([uniqueOutcome isEqual:uniqueOutcomeSent]) {
                    found = YES;
                    break;
                }
            }
            
            // If the outcome hasn't been sent with this influence, then it should be included in the returned NSArray
            if (!found)
                [availableInfluenceIds addObject:uniqueOutcome.uniqueId];
        }
        
        if (availableInfluenceIds.count > 0) {
            OSInfluence *newInfluence = [influence copy];
            newInfluence.ids = availableInfluenceIds;
            [uniqueInfluences addObject:newInfluence];
        }
    }
    
    return uniqueInfluences;
}


- (NSArray<OSCachedUniqueOutcome *> *)getCachedUniqueOutcomesByChannel:(OSInfluenceChannel)channel
                                                            channelIds:(NSArray<NSString *> *)channelIds
                                                           outcomeName:(NSString *)outcomeName {
    if (channelIds != nil) {
        NSMutableArray *cachedUniqueOutcomes = [NSMutableArray new];
        NSNumber *timestamp = [NSNumber numberWithDouble:[[NSDate date] timeIntervalSince1970]];
        for (NSString * influenceId in channelIds) {
            OSCachedUniqueOutcome * cachedUniqueOutcome = [[OSCachedUniqueOutcome alloc] initWithParamsName:outcomeName uniqueId:influenceId timestamp:timestamp channel:channel];
            [cachedUniqueOutcomes addObject:cachedUniqueOutcome];
        }
        return cachedUniqueOutcomes;
    }

    return [NSArray new];
}

- (NSArray<OSCachedUniqueOutcome *> *)getCachedUniqueOutcomesFromSourceBody:(OSOutcomeSourceBody *)sourceBody
                                                                outcomeName:(NSString *)outcomeName {
    if (sourceBody != nil) {
        NSArray *iamIds = sourceBody.inAppMessagesIds;
        NSArray *notificationIds = sourceBody.notificationIds;

         NSArray<OSCachedUniqueOutcome *> * iamUniqueOutcomes = [self getCachedUniqueOutcomesByChannel:IN_APP_MESSAGE channelIds:iamIds outcomeName:outcomeName];
         NSArray<OSCachedUniqueOutcome *> * notificationUniqueOutcomes = [self getCachedUniqueOutcomesByChannel:NOTIFICATION channelIds:notificationIds outcomeName:outcomeName];
        
        return [iamUniqueOutcomes arrayByAddingObjectsFromArray:notificationUniqueOutcomes];
    }
    
    return [NSArray new];
}

- (void)saveUniqueOutcomeEventParams:(OSOutcomeEventParams *)eventParams {
    [OneSignal onesignal_Log:ONE_S_LL_DEBUG message:[NSString stringWithFormat:@"OSOutcomeEventsRepository saveUniqueOutcomeEventParams: %@", eventParams.description]];
    if (eventParams.outcomeSource == nil)
        return;
    
    NSString *outcomeName = eventParams.outcomeId;
    OSOutcomeSourceBody *directBody = eventParams.outcomeSource.directBody;
    OSOutcomeSourceBody *indirectBody = eventParams.outcomeSource.indirectBody;

    NSArray<OSCachedUniqueOutcome *> *directIds = [self getCachedUniqueOutcomesFromSourceBody:directBody outcomeName:outcomeName];
    NSArray<OSCachedUniqueOutcome *> *indirectIds = [self getCachedUniqueOutcomesFromSourceBody:indirectBody outcomeName:outcomeName];

    NSArray<OSCachedUniqueOutcome *> *newAttributedIds = [directIds arrayByAddingObjectsFromArray:indirectIds];
    NSArray<OSCachedUniqueOutcome *> *attributedUniqueOutcomeEventSent = [self getAttributedUniqueOutcomeEventSent];
    
    NSArray *finalAttributedUniqueOutcomeEventSent = [attributedUniqueOutcomeEventSent arrayByAddingObjectsFromArray:newAttributedIds];
    
    [self saveAttributedUniqueOutcomeEventNotificationIds:finalAttributedUniqueOutcomeEventSent];
}

- (NSSet *)getUnattributedUniqueOutcomeEventsSent {
    return [_outcomeEventsCache getUnattributedUniqueOutcomeEventsSent];
}

- (void)saveUnattributedUniqueOutcomeEventsSent:(NSSet *)unattributedUniqueOutcomeEventsSentSet {
    [_outcomeEventsCache saveUnattributedUniqueOutcomeEventsSent:unattributedUniqueOutcomeEventsSentSet];
}

- (NSArray *)getAttributedUniqueOutcomeEventSent {
    return [_outcomeEventsCache getAttributedUniqueOutcomeEventSent];
}

- (void)saveAttributedUniqueOutcomeEventNotificationIds:(NSArray *)attributedUniqueOutcomeEventNotificationIdsSent {
    [_outcomeEventsCache saveAttributedUniqueOutcomeEventNotificationIds:attributedUniqueOutcomeEventNotificationIdsSent];
}

@end
