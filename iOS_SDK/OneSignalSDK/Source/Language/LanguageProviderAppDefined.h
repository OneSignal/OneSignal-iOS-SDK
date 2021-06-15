//
//  LanguageProviderAppDefined.h
//  OneSignal
//
//  Created by Tanay Nigam on 6/3/21.
//  Copyright © 2021 Hiptic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LanguageProvider.h"

#ifndef LanguageProviderAppDefined_h
#define LanguageProviderAppDefined_h

#define OSUD_LANGUAGE                                                       @"OSUD_LANGUAGE"                                                    // * OSUD_LANGUAGE
#define DEFAULT_LANGUAGE                                                    @"en"                                                               // * OSUD_LANGUAGE

NS_ASSUME_NONNULL_BEGIN

@interface LanguageProviderAppDefined : NSObject<LanguageProvider>

@property (nonnull)NSString* language;

@end

NS_ASSUME_NONNULL_END

#endif
