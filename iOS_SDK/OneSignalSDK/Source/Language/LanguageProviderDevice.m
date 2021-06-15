//
//  LanguageProviderDevice.m
//  OneSignal
//
//  Created by Tanay Nigam on 6/3/21.
//  Copyright © 2021 Hiptic. All rights reserved.
//

#import "LanguageProviderDevice.h"
#import "OneSignalHelper.h"

@implementation LanguageProviderDevice

- (NSString *)language {
    let preferredLanguages = [NSLocale preferredLanguages];
    if (preferredLanguages && preferredLanguages.count > 0)
        return [preferredLanguages objectAtIndex:0];
    return DEFAULT_LANGUAGE;
}

@end
