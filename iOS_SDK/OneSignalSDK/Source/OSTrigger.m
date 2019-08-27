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

#import "OSTrigger.h"
#import "OneSignalHelper.h"
#import "OneSignal.h"

@implementation OSTrigger

+ (instancetype)instanceWithData:(NSData *)data {
    NSError *error;
    let json = (NSDictionary *)[NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
    
    if (error || !json) {
        [OneSignal onesignal_Log:ONE_S_LL_ERROR message:[NSString stringWithFormat:@"Encountered an error parsing OSTrigger JSON: %@", error.description ?: @"None"]];
        return nil;
    }
    
    return [self instanceWithJson:json];
}

+ (instancetype)instanceWithJson:(NSDictionary *)json {
    let newTrigger = [OSTrigger new];
    
    if (json[@"id"] && [json[@"id"] isKindOfClass:[NSString class]])
        newTrigger.triggerId = (NSString *)json[@"id"];
    else return nil;
    
    if (json[@"property"] && [json[@"property"] isKindOfClass:[NSString class]])
        newTrigger.property = (NSString *)json[@"property"];
    else return nil;
    
    if (json[@"kind"] && [json[@"kind"] isKindOfClass:[NSString class]])
        newTrigger.kind = (NSString *)json[@"kind"];
    else return nil;
    
    if (json[@"operator"] && [json[@"operator"] isKindOfClass:[NSString class]]) {
        int num = (int)OS_OPERATOR_FROM_STRING(json[@"operator"]);
        
        if (num >= 0)
            newTrigger.operatorType = (OSTriggerOperatorType)num;
        else return nil;
    } else return nil;
    
    // A value will not exist if the operator type is OSTriggerOperatorTypeExists
    if (json[@"value"])
        newTrigger.value = json[@"value"];
    else if (newTrigger.operatorType != OSTriggerOperatorTypeExists)
        return nil;
    
    return newTrigger;
}

- (NSDictionary *)jsonRepresentation {
    let json = [NSMutableDictionary new];
    
    json[@"id"] = self.triggerId;
    json[@"kind"] = self.kind;
    json[@"property"] = self.property;
    json[@"operator"] = OS_OPERATOR_TO_STRING(self.operatorType);
    
    if (self.value)
        json[@"value"] = self.value;
    
    return json;
}

- (NSString *)description {
    return [NSString stringWithFormat: @"OSTrigger: triggerId=%@ property=%@ operatorType=%lu value=%@", _triggerId, _property, (unsigned long)_operatorType, _value];
}

@end
