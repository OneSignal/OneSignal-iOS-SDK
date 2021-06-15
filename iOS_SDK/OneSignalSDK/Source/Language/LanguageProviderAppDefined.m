//
//  LanguageProviderAppDefined.m
//  OneSignal
//
//  Created by Tanay Nigam on 6/3/21.
//  Copyright © 2021 Hiptic. All rights reserved.
//

#import "LanguageProviderAppDefined.h"
#import "OneSignalUserDefaults.h"

@implementation LanguageProviderAppDefined

- (void)setLanguage:(NSString *)language {
    [OneSignalUserDefaults.initStandard saveStringForKey:OSUD_LANGUAGE withValue:language];
}

- (NSString *)language {
    return [OneSignalUserDefaults.initStandard  getSavedStringForKey:OSUD_LANGUAGE defaultValue:DEFAULT_LANGUAGE];
}

@end
