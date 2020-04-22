/**
 Modified MIT License

 Copyright 2019 OneSignal

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
#import "OneSignalCommonDefines.h"

@implementation OSCachedUniqueOutcome

- (id)initWithParamsName:(NSString *)name uniqueId:(NSString *)uniqueId channel:(OSInfluenceChannel)channel {
    self = [super init];
    if (self) {
        _name = name;
        _uniqueId = uniqueId;
        _channel = channel;
        _timestamp = @0;
    }
    return self;
}

- (id)initWithParamsName:(NSString *)name uniqueId:(NSString *)uniqueId timestamp:(NSNumber *)timestamp channel:(OSInfluenceChannel)channel {
    self = [super init];
    if (self) {
        _name = name;
        _uniqueId = uniqueId;
        _channel = channel;
        _timestamp = timestamp;
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeObject:_name forKey:@"name"];
    [encoder encodeObject:_uniqueId forKey:@"uniqueId"];
    [encoder encodeInteger:[_timestamp integerValue] forKey:@"timestamp"];
    [encoder encodeObject:OS_INFLUENCE_CHANNEL_TO_STRINGS(_channel) forKey:@"channel"];
}

- (id)initWithCoder:(NSCoder *)decoder {
    if (self = [super init]) {
        _name = [decoder decodeObjectForKey:@"name"];
        id identifier = [decoder decodeObjectForKey:@"notificationId"];
        if (identifier)
            _uniqueId = identifier;
        else
            _uniqueId = [decoder decodeObjectForKey:@"uniqueId"];
        _timestamp = [NSNumber numberWithLong:[decoder decodeIntegerForKey:@"timestamp"]];
        id channel = [decoder decodeObjectForKey:@"channel"];
        if (channel)
            _channel = OS_INFLUENCE_CHANNEL_FROM_STRINGS(channel);
        else
            _channel = NOTIFICATION;
    }
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"Name: %@ Unique Id: %@ Timestamp: %@ Channel: %@", _name, _uniqueId, _timestamp, OS_INFLUENCE_CHANNEL_TO_STRINGS(_channel)];
}

- (BOOL)isEqual:(OSCachedUniqueOutcome *)other {
    NSString *key = [NSString stringWithFormat:@"%@_%@_%@", _name, _uniqueId, OS_INFLUENCE_CHANNEL_TO_STRINGS(_channel)];
    NSString *otherKey = [NSString stringWithFormat:@"%@_%@_%@", other.name, other.uniqueId, OS_INFLUENCE_CHANNEL_TO_STRINGS(other.channel)];
    return [key isEqualToString:otherKey];
}

- (NSUInteger)hash {
    NSUInteger result = [_name hash];
    result = 31 * result + [_uniqueId hash];
    result = 31 * result + [OS_INFLUENCE_CHANNEL_TO_STRINGS(_channel) hash];
    return result;
}

@end
