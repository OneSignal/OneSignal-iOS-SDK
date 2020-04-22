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

#import "OSOutcomeEvent.h"
#import "OneSignalHelper.h"
#import "OneSignalCommonDefines.h"

@implementation OSOutcomeEvent

- (id _Nonnull)initWithSession:(OSSession)influenceType
               notificationIds:(NSArray * _Nullable)notificationIds
                          name:(NSString * _Nonnull)name
                     timestamp:(NSNumber * _Nonnull)timestamp
                        weight:(NSNumber * _Nonnull)value {
    
    if (self = [super init]) {
        _session = influenceType;
        _notificationIds = notificationIds;
        _name = name;
        _timestamp = timestamp;
        _weight = [NSDecimalNumber decimalNumberWithDecimal:value.decimalValue];
    }
    return self;
}

- (id)initFromOutcomeEventParams:(OSOutcomeEventParams *)outcomeEventParams {
    if (self = [super init]) {
        OSOutcomeSource *source = outcomeEventParams.outcomeSource;
        Session influenceType = UNATTRIBUTED;
        NSArray *notificationId = nil;

        if (source) {
            if (source.directBody && source.directBody.notificationIds && source.directBody.notificationIds.count > 0) {
                influenceType = DIRECT;
                notificationId = source.directBody.notificationIds;
            } else if (source.indirectBody && source.indirectBody.notificationIds && source.indirectBody.notificationIds.count > 0) {
                influenceType = INDIRECT;
                notificationId = source.indirectBody.notificationIds;
            }
        }

        _session = influenceType;
        _notificationIds = notificationId;
        _name = outcomeEventParams.outcomeId;
        _timestamp = outcomeEventParams.timestamp;
        _weight = [NSDecimalNumber decimalNumberWithDecimal:outcomeEventParams.weight.decimalValue];
    }
    return self;
}

- (NSDictionary * _Nonnull)jsonRepresentation {
    let json = [NSMutableDictionary new];
    
    json[@"session"] = OS_INFLUENCE_TYPE_TO_STRING(self.session);
    json[@"id"] = self.name;
    json[@"timestamp"] = @(self.timestamp.intValue);
    json[@"weight"] = self.weight.stringValue;
    
    if (!self.notificationIds) {
        json[@"notification_ids"] = [NSArray new];
        return json;
    }
    
    NSError *error;
    NSData *jsonNotificationIds = [NSJSONSerialization dataWithJSONObject:self.notificationIds options:NSJSONWritingPrettyPrinted error:&error];
    NSString *stringNotificationIds = [[NSString alloc] initWithData:jsonNotificationIds encoding:NSUTF8StringEncoding];
    json[@"notification_ids"] = stringNotificationIds;
    
    return json;
}

@end
