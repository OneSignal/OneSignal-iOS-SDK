//
//  NSObject+Extras.m
//  OneSignal
//
//  Created by Joseph Kalash on 7/27/16.
//  Copyright © 2016 Hiptic. All rights reserved.
//

#import "NSObject+Extras.h"

@implementation NSObject (Extras)

- (id) performSelector2: (SEL) selector withObjects: (NSArray<id>*)objs {
    NSMethodSignature *sig = [self methodSignatureForSelector:selector];
    if (!sig)
        return nil;
    
    
    NSInvocation* invo = [NSInvocation invocationWithMethodSignature:sig];
    [invo setTarget:self];
    [invo setSelector:selector];
    
    for(int i = 0; i < [objs count]; ++i) {
        id obj = [objs objectAtIndex:i];
        if([obj isKindOfClass:[NSNumber class]]) {
            if (strcmp([obj objCType], "c") == 0) {
                bool val = [obj boolValue];
                [invo setArgument:&val atIndex:2+i];
            }
            else if (strcmp([obj objCType], @encode(int)) == 0) {
                int val = [obj intValue];
                [invo setArgument:&val atIndex:2+i];
            }
            else if (strcmp([obj objCType], @encode(double)) == 0) {
                double val = [obj doubleValue];
                [invo setArgument:&val atIndex:2+i];
            }
        }
        else {
            
            [invo setArgument:&obj atIndex:2+i];
        }
    }
    
    [invo invoke];
    if (sig.methodReturnLength) {
        void *anObject;
        [invo getReturnValue:&anObject];
        return (__bridge id)anObject;
    }
    return nil;
}

@end
