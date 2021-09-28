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
#import "OSIndirectInfluence.h"
#import <OneSignalCore/OneSignalCore.h>

@interface OSIndirectInfluence ()

@property (nonatomic, readwrite) NSString *channelIdTag;
@property (nonatomic, readwrite) NSString *influenceId;
@property (nonatomic, readwrite) double timestamp; // seconds

@end

@implementation OSIndirectInfluence

- (id)initWithParamsInfluenceId:(NSString *)influenceId forChannel:(NSString *)channelIdTag timestamp:(double)timestamp {
    _influenceId = influenceId;
    _channelIdTag = channelIdTag;
    _timestamp = timestamp;
    return self;
}

+ (instancetype _Nullable)instanceWithData:(NSData * _Nonnull)data {
    NSError *error;
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
   
    if (error || !json) {
        [OneSignal onesignal_Log:ONE_S_LL_ERROR message:[NSString stringWithFormat:@"Unable to decode indirect influence JSON: %@", error.description ?: @"No Data"]];
        return nil;
    }
   
    return [self instanceWithJson:json];
}

+ (instancetype)instanceWithJson:(NSDictionary * _Nonnull)json {
    let indirectInfluence = [OSIndirectInfluence new];
    
    if (json[@"influenceId"] && [json[@"influenceId"] isKindOfClass:[NSString class]])
        indirectInfluence.influenceId = json[@"influenceId"];
    
    if (json[@"channelIdTag"] && [json[@"channelIdTag"] isKindOfClass:[NSString class]])
        indirectInfluence.channelIdTag = json[@"channelIdTag"];
    
    if (json[@"timestamp"] && [json[@"timestamp"] isKindOfClass:[NSNumber class]])
        indirectInfluence.timestamp = [json[@"timestamp"] doubleValue];

    return indirectInfluence;
}

+ (instancetype)instancePreviewFromNotification:(OSNotification *)notification {
    return [OSIndirectInfluence new];
}

-(NSDictionary *)jsonRepresentation {
    let json = [NSMutableDictionary new];

    json[@"influenceId"] = _influenceId;
    json[@"channelIdTag"] = _channelIdTag;
    json[@"timestamp"] = @(_timestamp);

    return json;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeObject:_influenceId forKey:@"influenceId"];
    [encoder encodeObject:_channelIdTag forKey:@"channelIdTag"];
    [encoder encodeDouble:_timestamp forKey:@"timestamp"];
}

- (id)initWithCoder:(NSCoder *)decoder {
    if (self = [super init]) {
        id notificationId = [decoder decodeObjectForKey:@"notificationId"];
        if (notificationId == nil)
            _influenceId = [decoder decodeObjectForKey:@"influenceId"];
        else
            _influenceId = notificationId;
        id channelIdTag = [decoder decodeObjectForKey:@"channelIdTag"];
        if (channelIdTag == nil)
            _channelIdTag = @"notification_id";
        else
            _channelIdTag = channelIdTag;
        _timestamp = [decoder decodeDoubleForKey:@"timestamp"];
    }
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"OSIndirectInfluence channelIdTag: %@ Id: %@ Timestamp: %f", _channelIdTag, _influenceId, _timestamp];
}

@end
