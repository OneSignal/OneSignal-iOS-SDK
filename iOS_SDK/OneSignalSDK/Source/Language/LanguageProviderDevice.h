//
//  LanguageProviderDevice.h
//  OneSignal
//
//  Created by Tanay Nigam on 6/3/21.
//  Copyright © 2021 Hiptic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LanguageProvider.h"

#define DEFAULT_LANGUAGE                                                    @"en"                                                               // * OSUD_LANGUAGE

NS_ASSUME_NONNULL_BEGIN

@interface LanguageProviderDevice : NSObject<LanguageProvider>

@property (readonly, nonnull)NSString* language;

@end

NS_ASSUME_NONNULL_END
