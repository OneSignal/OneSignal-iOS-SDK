//
//  NSArray+OneSignal.m
//  OneSignal
//
//  Created by Brad Hesse on 8/20/18.
//  Copyright © 2018 Hiptic. All rights reserved.
//

#import "NSArray+OneSignal.h"
#import "NSDictionary+OneSignal.h"

@implementation NSArray (OneSignal)

- (nonnull NSArray *)os_arrayByRemovingNullValues {
    NSMutableArray *newArray = [NSMutableArray new];
    
    [self enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj isKindOfClass:[NSNull class]]) {
            //skip
        } else if ([obj isKindOfClass:[NSDictionary class]]) {
            [newArray addObject:[(NSDictionary *)obj os_dictionaryByRemovingNullValues]];
        } else if ([obj isKindOfClass:[NSArray class]]) {
            [newArray addObject:[(NSArray *)obj os_arrayByRemovingNullValues]];
        } else {
            [newArray addObject:obj];
        }
    }];
    
    return newArray.copy;
}

@end
