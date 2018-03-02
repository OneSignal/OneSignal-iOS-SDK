//
//  NSMutableDictionary+OneSignal.m
//  OneSignal
//
//  Created by Brad Hesse on 3/2/18.
//  Copyright © 2018 Hiptic. All rights reserved.
//

#import "NSMutableDictionary+OneSignal.h"

@implementation NSMutableDictionary (OneSignal)

//NSJSONSerialization will not handle NSDates
//this method converts any occurrences of NSDate into an ISO8061 compliant string

- (void)convertDatesToISO8061Strings {
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    NSLocale *enUSPOSIXLocale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    [dateFormatter setLocale:enUSPOSIXLocale];
    [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZZZZZ"];
    
    for (NSString *key in self.allKeys) {
        id value = self[key];
        
        if ([value isKindOfClass:[NSDate class]])
            self[key] = [dateFormatter stringFromDate:(NSDate *)value];
    }
}
@end
