/**
 * Modified MIT License
 *
 * Copyright 2017 OneSignal
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

#import "OSInAppMessage.h"
#import "OneSignalHelper.h"
#import "OneSignalCommonDefines.h"

@interface OSInAppMessage ()

@property (strong, nonatomic, nonnull) NSMutableSet <NSString *> *clickedClickIds;

@end

@implementation OSInAppMessage

- (instancetype)init {
    if (self = [super init]) {
        self.clickedClickIds = [[NSMutableSet alloc] init];
        self.isTriggerChanged = false;
    }
    
    return self;
}

- (BOOL)isBanner {
    return self.position == OSInAppMessageDisplayPositionTop || self.position == OSInAppMessageDisplayPositionBottom;
}

- (BOOL)takeActionAsUnique {
    if (self.actionTaken)
        return false;
    return self.actionTaken = true;
}

- (BOOL)isClickAvailable:(NSString *)clickId {
    return ![_clickedClickIds containsObject:clickId];
}

- (void)clearClickIds {
    _clickedClickIds = [[NSMutableSet alloc] init];
}

- (void)addClickId:(NSString *)clickId {
    [_clickedClickIds addObject:clickId];
}

- (NSSet<NSString *> *)getClickedClickIds {
    return _clickedClickIds;
}

+ (instancetype)instanceWithData:(NSData *)data {
    NSError *error;
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    
    if (error || !json) {
        [OneSignal onesignal_Log:ONE_S_LL_ERROR message:[NSString stringWithFormat:@"Unable to decode in-app message JSON: %@", error.description ?: @"No Data"]];
        return nil;
    }
    
    return [self instanceWithJson:json];
}

+ (instancetype)instanceWithJson:(NSDictionary * _Nonnull)json {
    let message = [OSInAppMessage new];
    
    if (json[@"id"] && [json[@"id"] isKindOfClass:[NSString class]])
        message.messageId = json[@"id"];
    else
        return nil;
    
    if (json[@"variants"] && [json[@"variants"] isKindOfClass:[NSDictionary class]])
        message.variants = json[@"variants"];
    else
        return nil;
    
    if (json[@"redisplay"] && [json[@"redisplay"] isKindOfClass:[NSDictionary class]])
        message.displayStats = [OSInAppMessageDisplayStats instanceWithJson:json[@"redisplay"]];
    else
        message.displayStats = [[OSInAppMessageDisplayStats alloc] init];

    if (json[@"triggers"] && [json[@"triggers"] isKindOfClass:[NSArray class]]) {
        let triggers = [NSMutableArray new];
        
        for (NSArray *list in (NSArray *)json[@"triggers"]) {
            let subTriggers = [NSMutableArray new];
            
            for (NSDictionary *triggerJson in list) {
                let trigger = [OSTrigger instanceWithJson:triggerJson];
                
                if (trigger)
                    [subTriggers addObject:trigger];
                else {
                    [OneSignal onesignal_Log:ONE_S_LL_WARN message:[NSString stringWithFormat:@"Trigger JSON is invalid: %@", triggerJson]];
                    return nil;
                }
            }
            
            [triggers addObject:subTriggers];
        }
        
        message.triggers = triggers;
    }
    else
        return nil;
    
    //TODO: This will need to be changed when we add core data or database to iOS, see android implementation for reference
    if (json[@"displayed_in_session"]) {
        message.isDisplayedInSession = json[@"displayed_in_session"];
    }
    return message;
}

+ (instancetype)instancePreviewFromPayload:(OSNotificationPayload *)payload {
    let message = [OSInAppMessage new];
    message.messageId = [payload additionalData][ONESIGNAL_IAM_PREVIEW];
    message.isPreview = true;
    return message;
}

-(NSDictionary *)jsonRepresentation {
    let json = [NSMutableDictionary new];
    
    json[@"id"] = self.messageId;
    json[@"variants"] = self.variants;
    
    let triggers = [NSMutableArray new];
    
    for (NSArray *andBlock in self.triggers) {
        let andConditions = [NSMutableArray new];
        
        for (OSTrigger *trigger in andBlock)
            [andConditions addObject:trigger.jsonRepresentation];
        
        [triggers addObject:andConditions];
    }
    
    json[@"triggers"] = triggers;
    
    if ([_displayStats isRedisplayEnabled]) {
        json[@"redisplay"] = [_displayStats jsonRepresentation];
    }
    //TODO: This will need to be changed when we add core data or database to iOS, see android implementation for reference
    json[@"displayed_in_session"] = @(_isDisplayedInSession);
    
    return json;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"OSInAppMessage:  \nmessageId: %@  \ntriggers: %@ \ndisplayStats: %@", self.messageId, self.triggers, self.displayStats];
}

- (BOOL)isEqual:(id)object {
  if (self == object) {
    return YES;
  }

  if (![object isKindOfClass:[OSInAppMessage class]]) {
    return NO;
  }

  OSInAppMessage *iam = object;
    
  return [self.messageId isEqualToString:iam.messageId];
}

- (NSUInteger)hash {
    return [self.messageId hash];
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeObject:_messageId forKey:@"messageId"];
    [encoder encodeObject:_variants forKey:@"variants"];
    [encoder encodeObject:_triggers forKey:@"triggers"];
    [encoder encodeObject:_displayStats forKey:@"displayStats"];
}

- (id)initWithCoder:(NSCoder *)decoder {
    if (self = [super init]) {
        _messageId = [decoder decodeObjectForKey:@"messageId"];
        _variants = [decoder decodeObjectForKey:@"variants"];
        _triggers = [decoder decodeObjectForKey:@"triggers"];
        _displayStats = [decoder decodeObjectForKey:@"displayStats"];
    }
    return self;
}

@end

