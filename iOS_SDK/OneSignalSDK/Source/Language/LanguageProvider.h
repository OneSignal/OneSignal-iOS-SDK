//
//  LanguageProvider.h
//  OneSignal
//
//  Created by Tanay Nigam on 6/3/21.
//  Copyright © 2021 Hiptic. All rights reserved.
//

#ifndef LanguageProvider_h
#define LanguageProvider_h

@protocol LanguageProvider <NSObject>

@property (readonly, nonnull)NSString* language;

@end
#endif /* LanguageProvider_h */
