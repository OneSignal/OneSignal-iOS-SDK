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

-(instancetype)initWithData:(NSData *)data {
    NSError *error;
    let json = (NSDictionary *)[NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
    
    if (error || !json) {
        [OneSignal onesignal_Log:ONE_S_LL_ERROR message:[NSString stringWithFormat:@"Encountered an error parsing OSTrigger JSON: %@", error.description ?: @"None"]];
        return nil;
    }
    
    return [self initWithJson:json];
}

-(instancetype)initWithJson:(NSDictionary *)json {
    if (self = [super init]) {
        if (json[@"property"] && [json[@"property"] isKindOfClass:[NSString class]])
            self.property = (NSString *)json[@"property"];
        else return nil;
        
        if (json[@"operator"] && [json[@"operator"] isKindOfClass:[NSString class]]) {
            let num = operatorFromString((NSString *)json[@"operator"]);
            
            if (num >= 0)
                self.operatorType = (OSTriggerOperatorType)num;
            else return nil;
        } else return nil;
        
        // A value will not exist if the operator type is OSTriggerOperatorTypeExists
        if (json[@"value"])
            self.value = json[@"value"];
        else if (self.operatorType != OSTriggerOperatorTypeExists)
            return nil;
        
    }
    
    return self;
}

int operatorFromString(NSString *operator) {
    let operators = @[@">", @"<", @"==", @"<=", @">="];
    
    for (int i = 0; i < operators.count; i++)
        if ([operators[i] isEqualToString:operator])
            return i;
    
    return -1;
}

@end
