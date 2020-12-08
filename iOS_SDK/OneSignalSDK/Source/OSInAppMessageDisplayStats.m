/**
* Modified MIT License
*
* Copyright 2020 OneSignal
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

#import "OSInAppMessageDisplayStats.h"
#import "OneSignalHelper.h"

@interface OSInAppMessageDisplayStats ()
@property (nonatomic, readwrite) BOOL redisplayEnabled;
@end

@implementation OSInAppMessageDisplayStats

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.displayLimit = NSIntegerMax;
        self.displayDelay = 0;
        self.displayQuantity = 0;
        self.lastDisplayTime = -1;
        self.redisplayEnabled = false;
    }
    return self;
}

+ (instancetype)instanceWithDisplayQuantity:(NSInteger)displayQuantity lastDisplayTime:(NSTimeInterval)lastDisplayTime {
    let displayStats = [OSInAppMessageDisplayStats new];
    
    displayStats.displayQuantity = displayQuantity;
    displayStats.lastDisplayTime = lastDisplayTime;

    return displayStats;
}

+ (instancetype _Nullable)instanceWithData:(NSData * _Nonnull)data {
    NSError *error;
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
   
    if (error || !json) {
        [OneSignal onesignal_Log:ONE_S_LL_ERROR message:[NSString stringWithFormat:@"Unable to decode in-app display state message JSON: %@", error.description ?: @"No Data"]];
        return nil;
    }
   
    return [self instanceWithJson:json];
}

+ (instancetype)instanceWithJson:(NSDictionary * _Nonnull)json {
    let displayStats = [OSInAppMessageDisplayStats new];
    
    if (json[@"limit"] && [json[@"limit"] isKindOfClass:[NSNumber class]])
        displayStats.displayLimit = [json[@"limit"] integerValue];
    else
        displayStats.displayLimit = NSIntegerMax;
    
    if (json[@"delay"] && [json[@"delay"] isKindOfClass:[NSNumber class]])
        displayStats.displayDelay = [json[@"delay"] doubleValue];
    else
        displayStats.displayDelay = 0;
    
    displayStats.displayQuantity = 0;
    displayStats.lastDisplayTime = -1;
    displayStats.redisplayEnabled = YES;

    return displayStats;
}

+ (instancetype)instancePreviewFromNotification:(OSNotification *)notification {
    return [OSInAppMessageDisplayStats new];
}

-(NSDictionary *)jsonRepresentation {
    let json = [NSMutableDictionary new];

    json[@"limit"] = @(_displayLimit);
    json[@"delay"] = @(_displayDelay);

    return json;
}

- (BOOL)isDelayTimeSatisfied:(NSTimeInterval)date {
    if (_lastDisplayTime < 0) {
        return true;
    }
    //Calculate gap between display times
    let diffInSeconds = date - _lastDisplayTime;
    return diffInSeconds >= _displayDelay;
}

- (BOOL)shouldDisplayAgain {
    BOOL result = _displayQuantity < _displayLimit;
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"In app message shouldDisplayAgain: %hhu", result]];
    return result;
}

- (void)incrementDisplayQuantity {
    _displayQuantity++;
}

- (BOOL)isRedisplayEnabled {
    return _redisplayEnabled;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"OSInAppMessageDisplayStats:  redisplayEnabled: %@ \nlastDisplayTime: %f  \ndisplayDelay: %f \ndisplayQuantity: %ld \ndisplayLimit: %ld", self.redisplayEnabled ? @"YES" : @"NO", self.lastDisplayTime, self.displayDelay, (long)self.displayQuantity, (long)self.displayLimit];
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeInteger:_displayLimit forKey:@"displayLimit"];
    [encoder encodeInteger:_displayQuantity forKey:@"displayQuantity"];
    [encoder encodeDouble:_displayDelay forKey:@"displayDelay"];
    [encoder encodeDouble:_lastDisplayTime forKey:@"lastDisplayTime"];
    [encoder encodeBool:_redisplayEnabled forKey:@"redisplayEnabled"];
}

- (id)initWithCoder:(NSCoder *)decoder {
    if (self = [super init]) {
        _displayLimit = [decoder decodeIntegerForKey:@"displayLimit"];
        _displayQuantity = [decoder decodeIntegerForKey:@"displayQuantity"];
        _displayDelay = [decoder decodeDoubleForKey:@"displayDelay"];
        _lastDisplayTime = [decoder decodeDoubleForKey:@"lastDisplayTime"];
        _redisplayEnabled = [decoder decodeBoolForKey:@"redisplayEnabled"];
    }
    return self;
}

@end
