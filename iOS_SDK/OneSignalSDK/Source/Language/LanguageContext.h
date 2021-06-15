//
//  LanguageContext.h
//  OneSignal
//
//  Created by Tanay Nigam on 6/3/21.
//  Copyright © 2021 Hiptic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LanguageProvider.h"

#ifndef LanguageContext_h
#define LanguageContext_h

#define OSUD_LANGUAGE                                                       @"OSUD_LANGUAGE"                                                    // * OSUD_LANGUAGE

NS_ASSUME_NONNULL_BEGIN

@interface LanguageContext : NSObject

- (void)setStrategy:(NSObject<LanguageProvider>*)strategy;

@property (nonatomic, nonnull)NSString* language;

@end

NS_ASSUME_NONNULL_END

#endif /* LanguageContext_h */
