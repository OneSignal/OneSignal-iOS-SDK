//
//  NSString+OneSignal.m
//
//  Created by James on 16/3/2017.
//
//

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

- (NSString *)stringByRemovingWhitespace {
    return [self stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
}

+(NSString*)randomStringWithLength:(int)length {
    NSString *letters = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    NSMutableString *randomString = [[NSMutableString alloc] initWithCapacity:length];
    for(int i = 0; i < length; i++) {
        uint32_t ln = (uint32_t)letters.length;
        uint32_t rand = arc4random_uniform(ln);
        [randomString appendFormat:@"%C", [letters characterAtIndex:rand]];
    }
    return randomString;
}

@end
