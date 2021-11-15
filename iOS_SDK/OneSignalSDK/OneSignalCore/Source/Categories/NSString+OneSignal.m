/**
 * Modified MIT License
 *
 * Copyright 2021 OneSignal
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * 1. The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * 2. All copies of substantial portions of the Software may only be used in connection
 * with services provided by OneSignal.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

#import "NSString+OneSignal.h"
#import "OneSignalCommonDefines.h"

#define MIME_MAP @{@"audio/aiff" : @"aiff", @"audio/x-wav" : @"wav", @"audio/mpeg" : @"mp3", @"video/mp4" : @"mp4", @"image/jpeg" : @"jpeg", @"image/jpg" : @"jpg", @"image/png" : @"png", @"image/gif" : @"gif", @"video/mpeg" : @"mpeg", @"video/mpg" : @"mpg", @"video/avi" : @"avi", @"sound/m4a" : @"m4a", @"video/m4v" : @"m4v"}

@implementation NSString (OneSignal)


- (NSString *)one_substringAfter:(NSString *)needle
{
	NSRange r = [self rangeOfString:needle];
	if (r.location == NSNotFound) return self;
	return [self substringFromIndex:(r.location + r.length)];
}


- (NSString*)one_getVersionForRange:(NSRange)range {

	unichar myBuffer[2];
	[self getCharacters:myBuffer range:range];
	NSString *ver = [NSString stringWithCharacters:myBuffer length:2];
	if([ver hasPrefix:@"0"]){
		return [ver one_substringAfter:@"0"];
	}
	else{
		return ver;
	}
}

- (NSString*)one_getSemanticVersion {

	NSMutableString *tmpstr = [[NSMutableString alloc] initWithCapacity:5];

	for ( int i = 0; i <=4; i+=2 ){
		[tmpstr appendString:[self one_getVersionForRange:NSMakeRange(i, 2)]];
		if (i != 4)[tmpstr appendString:@"."];
	}

	return (NSString*)tmpstr;
}

- (NSString *)supportedFileExtension {
    NSArray <NSString *> *components = [self componentsSeparatedByString:@"."];
    
    if (components.count >= 2 && [ONESIGNAL_SUPPORTED_ATTACHMENT_TYPES containsObject:components.lastObject])
        return components.lastObject;
    
    return nil;
}

- (NSString *)fileExtensionForMimeType {
    return MIME_MAP[self];
}

// Converts a nonnull NSData into a NSString in a lower case hex format.
+ (nullable NSString *)hexStringFromData:(nonnull NSData *)data {
    NSUInteger dataLength = data.length;
    if (dataLength == 0)
        return nil;
    unsigned char *dataBtyes = (unsigned char *)data.bytes;
    NSMutableString *hexString  = [NSMutableString stringWithCapacity:dataLength * 2];
    for (int i = 0; i < dataLength; i++)
        [hexString appendFormat:@"%02x", dataBtyes[i]];
    
    // Copy to make immutable
    return hexString.copy;
}

@end
