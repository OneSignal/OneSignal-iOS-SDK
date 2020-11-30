//
//  NSString+OneSignal.h
//
//  Created by James on 16/3/2017.
//
//

#import <Foundation/Foundation.h>

#ifndef NSString_OneSignal_h
#define NSString_OneSignal_h
@interface NSString (OneSignal)

- (NSString *_Nonnull)one_getVersionForRange:(NSRange)range;
- (NSString *_Nonnull)one_substringAfter:(NSString *_Nonnull)needle;
- (NSString *_Nonnull)one_getSemanticVersion;
- (NSString *_Nullable)fileExtensionForMimeType;
- (NSString *_Nullable)supportedFileExtension;

// returns a lower case hex representation of the data
+ (nullable NSString *)hexStringFromData:(nonnull NSData *)data;

@end
#endif
