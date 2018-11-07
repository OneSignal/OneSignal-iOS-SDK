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
#import "OneSignal.h"

@implementation OSInAppMessage

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
    
    if (json[@"type"] != nil && [json[@"type"] isKindOfClass:[NSString class]] && OS_IS_VALID_DISPLAY_TYPE(json[@"type"]))
        message.type = OS_DISPLAY_TYPE_FOR_STRING(json[@"type"]);
    else return nil;
    
    if (json[@"id"] && [json[@"id"] isKindOfClass:[NSString class]])
        message.messageId = json[@"id"];
    else return nil;
    
    if (json[@"content_id"] && [json[@"content_id"] isKindOfClass:[NSString class]])
        message.contentId = json[@"content_id"];
    else return nil;
    
    if (json[@"triggers"] && [json[@"triggers"] isKindOfClass:[NSArray class]]) {
        let triggers = [NSMutableArray new];
        
        for (NSArray *list in (NSArray *)json[@"triggers"]) {
            let subTriggers = [NSMutableArray new];
            
            for (NSDictionary *triggerJson in list) {
                let trigger = [OSTrigger instanceWithJson:triggerJson];
                
                if (trigger) {
                    [subTriggers addObject:trigger];
                } else {
                    [OneSignal onesignal_Log:ONE_S_LL_WARN message:[NSString stringWithFormat:@"Trigger JSON is invalid: %@", triggerJson]];
                    return nil;
                }
            }
            
            [triggers addObject:subTriggers];
        }
        
        message.triggers = triggers;
    } else return nil;
    
    message.position = OS_DISPLAY_POSITION_FOR_TYPE(message.type);
    
    return message;
}

@end

