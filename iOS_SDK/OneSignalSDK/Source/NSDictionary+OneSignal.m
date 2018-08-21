//
//  NSDictionary+OneSignal.m
//  OneSignal
//
//  Created by Brad Hesse on 8/20/18.
//  Copyright © 2018 Hiptic. All rights reserved.
//

#import "NSDictionary+OneSignal.h"
#import "NSArray+OneSignal.h"

@implementation NSDictionary (OneSignal)

- (NSDictionary *)os_dictionaryByRemovingNullValues {
    NSMutableDictionary *newDictionary = [NSMutableDictionary new];
    
    [self enumerateKeysAndObjectsUsingBlock:^(id key, id obj, __unused BOOL * stop) {
        if ([obj isKindOfClass:[NSNull class]]) {
            // skip
        } else if ([obj isKindOfClass:[NSDictionary class]]) {
            newDictionary[key] = [(NSDictionary *)obj os_dictionaryByRemovingNullValues];
        } else if ([obj isKindOfClass:[NSArray class]]) {
            newDictionary[key] = [(NSArray *)obj os_arrayByRemovingNullValues];
        } else {
            newDictionary[key] = obj;
        }
    }];
    
    return newDictionary.copy;
}

- (nullable id)os_getOptionalValueForKey:(NSString *)key asTargetClass:(Class)class {
    id value = self[key];
    
    if (value &&
        [value isKindOfClass:class]) {
        return value;
    }
    
    return nil;
}

- (nullable NSNumber *)os_numberForKey:(NSString *)key {
    return [self os_getOptionalValueForKey:key asTargetClass:[NSNumber class]];
}

- (nullable NSString *)os_stringForKey:(NSString *)key {
    return [self os_getOptionalValueForKey:key asTargetClass:[NSString class]];
}

- (nullable NSURL *)os_urlForKey:(NSString *)key {
    NSString * _Nullable value = [self os_getOptionalValueForKey:key asTargetClass:[NSString class]];
    
    if (value) {
        return [NSURL URLWithString:value];
    }
    
    return nil;
}

- (nullable NSDictionary *)os_dictionaryForKey:(NSString *)key {
    return [self os_getOptionalValueForKey:key asTargetClass:[NSDictionary class]];
}

@end
