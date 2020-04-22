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

#import "OSOutcomeEventParams.h"
#import "OSInfluence.h"
#import "OSOutcomeEventsCache.h"
#import "OneSignal.h"

#ifndef OSOutcomeEventsRepository_h
#define OSOutcomeEventsRepository_h

@interface OSOutcomeEventsRepository : NSObject

@property (strong, nonatomic, readonly, nonnull) OSOutcomeEventsCache *outcomeEventsCache;

- (id)initWithCache:(OSOutcomeEventsCache *)outcomeEventsCache;
- (void)requestMeasureOutcomeEventWithAppId:(NSString *)appId
                                 deviceType:(NSNumber *)deviceType
                                      event:(OSOutcomeEventParams *)event
                                  onSuccess:(OSResultSuccessBlock)successBlock
                                  onFailure:(OSFailureBlock)failureBlock;

- (NSSet *)getUnattributedUniqueOutcomeEventsSent;
- (void)saveUnattributedUniqueOutcomeEventsSent:(NSSet *)unattributedUniqueOutcomeEventsSentSet;

- (NSArray *)getNotCachedUniqueInfluencesForOutcome:(NSString *)name influences:(NSArray<OSInfluence *> *)influences;
- (void)saveUniqueOutcomeEventParams:(OSOutcomeEventParams *)eventParams;

@end

#endif /* OSOutcomeEventsRepository_h */
