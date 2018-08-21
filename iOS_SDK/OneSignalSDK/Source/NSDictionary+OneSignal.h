//
//  NSDictionary+OneSignal.h
//  OneSignal
//
//  Created by Brad Hesse on 8/20/18.
//  Copyright © 2018 Hiptic. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSDictionary (OneSignal)

- (nonnull NSDictionary *)os_dictionaryByRemovingNullValues;
- (nullable NSNumber *)os_numberForKey:(NSString *)key;
- (nullable NSString *)os_stringForKey:(NSString *)key;
- (nullable NSURL *)os_urlForKey:(NSString *)key;
- (nullable NSDictionary *)os_dictionaryForKey:(NSString *)key;

@end
