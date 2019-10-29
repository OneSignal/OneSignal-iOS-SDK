/**
 * Modified MIT License
 *
 * Copyright 2019 OneSignal
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

#import <Foundation/Foundation.h>
#import "OSLastNotification.h"

@implementation OSLastNotification

- (id)initWithParamsNotificationId:(NSString *)notificationId arrivalTime:(double)arrivalTime wasOnBackground:(BOOL) wasOnBackground {
    _notificationId = notificationId;
    _arrivalTime = arrivalTime;
    _wasOnBackground = wasOnBackground;
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeObject:_notificationId forKey:@"notificationId"];
    [encoder encodeDouble:_arrivalTime forKey:@"arrivalTime"];
    [encoder encodeBool:_wasOnBackground forKey:@"wasOnBackground"];
}

- (id)initWithCoder:(NSCoder *)decoder {
    if (self = [super init]) {
        _notificationId = [decoder decodeObjectForKey:@"notificationId"];
        _arrivalTime = [decoder decodeDoubleForKey:@"arrivalTime"];
        _wasOnBackground = [decoder decodeBoolForKey:@"wasOnBackground"];
    }
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"Notification id: %@ arrivalTime: %f wasOnBackground: %@", _notificationId, _arrivalTime, _wasOnBackground ? @"YES" : @"NO"];
}

- (BOOL)isEqual:(OSLastNotification *)other {
    if (other == self) {
        return YES;
    } else if (![super isEqual:other]) {
        return NO;
    } else {
        return [other notificationId] == _notificationId;
    }
}

- (NSUInteger)hash {
    return [_notificationId hash];
}

@end
