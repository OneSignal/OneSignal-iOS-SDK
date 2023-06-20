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

#import <Foundation/Foundation.h>
#import "OneSignalCoreHelper.h"

#ifdef __cplusplus
extern "C" {
#endif

#define CC_DIGEST_DEPRECATION_WARNING                                                                                          \
    "This function is cryptographically broken and should not be used in security contexts. Clients should migrate to SHA256 (or stronger)."

/*
 * For compatibility with legacy implementations, the *Init(), *Update(),
 * and *Final() functions declared here *always* return a value of 1 (one).
 * This corresponds to "success" in the similar openssl implementations.
 * There are no errors of any kind which can be, or are, reported here,
 * so you can safely ignore the return values of all of these functions
 * if you are implementing new code.
 *
 * The one-shot functions (CC_MD2(), CC_SHA1(), etc.) perform digest
 * calculation and place the result in the caller-supplied buffer
 * indicated by the md parameter. They return the md parameter.
 * Unlike the opensssl counterparts, these one-shot functions require
 * a non-NULL md pointer. Passing in NULL for the md parameter
 * results in a NULL return and no digest calculation.
 */

typedef uint32_t CC_LONG;       /* 32 bit unsigned integer */
typedef uint64_t CC_LONG64;     /* 64 bit unsigned integer */

/*** MD2 ***/

#define CC_MD2_DIGEST_LENGTH    16          /* digest length in bytes */
#define CC_MD2_BLOCK_BYTES      64          /* block size in bytes */
#define CC_MD2_BLOCK_LONG       (CC_MD2_BLOCK_BYTES / sizeof(CC_LONG))

typedef struct CC_MD2state_st
{
    int num;
    unsigned char data[CC_MD2_DIGEST_LENGTH];
    CC_LONG cksm[CC_MD2_BLOCK_LONG];
    CC_LONG state[CC_MD2_BLOCK_LONG];
} CC_MD2_CTX;

extern int CC_MD2_Init(CC_MD2_CTX *c)
API_DEPRECATED(CC_DIGEST_DEPRECATION_WARNING, macos(10.4, 10.15), ios(2.0, 13.0));

extern int CC_MD2_Update(CC_MD2_CTX *c, const void *data, CC_LONG len)
API_DEPRECATED(CC_DIGEST_DEPRECATION_WARNING, macos(10.4, 10.15), ios(2.0, 13.0));

extern int CC_MD2_Final(unsigned char *md, CC_MD2_CTX *c)
API_DEPRECATED(CC_DIGEST_DEPRECATION_WARNING, macos(10.4, 10.15), ios(2.0, 13.0));

extern unsigned char *CC_MD2(const void *data, CC_LONG len, unsigned char *md)
API_DEPRECATED(CC_DIGEST_DEPRECATION_WARNING, macos(10.4, 10.15), ios(2.0, 13.0));

/*** MD4 ***/

#define CC_MD4_DIGEST_LENGTH    16          /* digest length in bytes */
#define CC_MD4_BLOCK_BYTES      64          /* block size in bytes */
#define CC_MD4_BLOCK_LONG       (CC_MD4_BLOCK_BYTES / sizeof(CC_LONG))

typedef struct CC_MD4state_st
{
    CC_LONG A,B,C,D;
    CC_LONG Nl,Nh;
    CC_LONG data[CC_MD4_BLOCK_LONG];
    uint32_t num;
} CC_MD4_CTX;

extern int CC_MD4_Init(CC_MD4_CTX *c)
API_DEPRECATED(CC_DIGEST_DEPRECATION_WARNING, macos(10.4, 10.15), ios(2.0, 13.0));

extern int CC_MD4_Update(CC_MD4_CTX *c, const void *data, CC_LONG len)
API_DEPRECATED(CC_DIGEST_DEPRECATION_WARNING, macos(10.4, 10.15), ios(2.0, 13.0));

extern int CC_MD4_Final(unsigned char *md, CC_MD4_CTX *c)
API_DEPRECATED(CC_DIGEST_DEPRECATION_WARNING, macos(10.4, 10.15), ios(2.0, 13.0));

extern unsigned char *CC_MD4(const void *data, CC_LONG len, unsigned char *md)
API_DEPRECATED(CC_DIGEST_DEPRECATION_WARNING, macos(10.4, 10.15), ios(2.0, 13.0));


/*** MD5 ***/

#define CC_MD5_DIGEST_LENGTH    16          /* digest length in bytes */
#define CC_MD5_BLOCK_BYTES      64          /* block size in bytes */
#define CC_MD5_BLOCK_LONG       (CC_MD5_BLOCK_BYTES / sizeof(CC_LONG))

typedef struct CC_MD5state_st
{
    CC_LONG A,B,C,D;
    CC_LONG Nl,Nh;
    CC_LONG data[CC_MD5_BLOCK_LONG];
    int num;
} CC_MD5_CTX;

extern int CC_MD5_Init(CC_MD5_CTX *c)
API_DEPRECATED(CC_DIGEST_DEPRECATION_WARNING, macos(10.4, 10.15), ios(2.0, 13.0));
    
extern int CC_MD5_Update(CC_MD5_CTX *c, const void *data, CC_LONG len)
API_DEPRECATED(CC_DIGEST_DEPRECATION_WARNING, macos(10.4, 10.15), ios(2.0, 13.0));
    
extern int CC_MD5_Final(unsigned char *md, CC_MD5_CTX *c)
API_DEPRECATED(CC_DIGEST_DEPRECATION_WARNING, macos(10.4, 10.15), ios(2.0, 13.0));

extern unsigned char *CC_MD5(const void *data, CC_LONG len, unsigned char *md)
API_DEPRECATED(CC_DIGEST_DEPRECATION_WARNING, macos(10.4, 10.15), ios(2.0, 13.0));

/*** SHA1 ***/

#define CC_SHA1_DIGEST_LENGTH   20          /* digest length in bytes */
#define CC_SHA1_BLOCK_BYTES     64          /* block size in bytes */
#define CC_SHA1_BLOCK_LONG      (CC_SHA1_BLOCK_BYTES / sizeof(CC_LONG))

typedef struct CC_SHA1state_st
{
    CC_LONG h0,h1,h2,h3,h4;
    CC_LONG Nl,Nh;
    CC_LONG data[CC_SHA1_BLOCK_LONG];
    int num;
} CC_SHA1_CTX;

extern int CC_SHA1_Init(CC_SHA1_CTX *c);

extern int CC_SHA1_Update(CC_SHA1_CTX *c, const void *data, CC_LONG len);

extern int CC_SHA1_Final(unsigned char *md, CC_SHA1_CTX *c);

extern unsigned char *CC_SHA1(const void *data, CC_LONG len, unsigned char *md);

/*** SHA224 ***/
#define CC_SHA224_DIGEST_LENGTH     28          /* digest length in bytes */
#define CC_SHA224_BLOCK_BYTES       64          /* block size in bytes */

/* same context struct is used for SHA224 and SHA256 */
typedef struct CC_SHA256state_st
{   CC_LONG count[2];
    CC_LONG hash[8];
    CC_LONG wbuf[16];
} CC_SHA256_CTX;

extern int CC_SHA224_Init(CC_SHA256_CTX *c)
API_AVAILABLE(macos(10.4), ios(2.0));

extern int CC_SHA224_Update(CC_SHA256_CTX *c, const void *data, CC_LONG len)
API_AVAILABLE(macos(10.4), ios(2.0));

extern int CC_SHA224_Final(unsigned char *md, CC_SHA256_CTX *c)
API_AVAILABLE(macos(10.4), ios(2.0));

extern unsigned char *CC_SHA224(const void *data, CC_LONG len, unsigned char *md)
API_AVAILABLE(macos(10.4), ios(2.0));


/*** SHA256 ***/

#define CC_SHA256_DIGEST_LENGTH     32          /* digest length in bytes */
#define CC_SHA256_BLOCK_BYTES       64          /* block size in bytes */

extern int CC_SHA256_Init(CC_SHA256_CTX *c)
API_AVAILABLE(macos(10.4), ios(2.0));

extern int CC_SHA256_Update(CC_SHA256_CTX *c, const void *data, CC_LONG len)
API_AVAILABLE(macos(10.4), ios(2.0));

extern int CC_SHA256_Final(unsigned char *md, CC_SHA256_CTX *c)
API_AVAILABLE(macos(10.4), ios(2.0));

extern unsigned char *CC_SHA256(const void *data, CC_LONG len, unsigned char *md)
API_AVAILABLE(macos(10.4), ios(2.0));


/*** SHA384 ***/

#define CC_SHA384_DIGEST_LENGTH     48          /* digest length in bytes */
#define CC_SHA384_BLOCK_BYTES      128          /* block size in bytes */

/* same context struct is used for SHA384 and SHA512 */
typedef struct CC_SHA512state_st
{   CC_LONG64 count[2];
    CC_LONG64 hash[8];
    CC_LONG64 wbuf[16];
} CC_SHA512_CTX;

extern int CC_SHA384_Init(CC_SHA512_CTX *c)
API_AVAILABLE(macos(10.4), ios(2.0));

extern int CC_SHA384_Update(CC_SHA512_CTX *c, const void *data, CC_LONG len)
API_AVAILABLE(macos(10.4), ios(2.0));

extern int CC_SHA384_Final(unsigned char *md, CC_SHA512_CTX *c)
API_AVAILABLE(macos(10.4), ios(2.0));

extern unsigned char *CC_SHA384(const void *data, CC_LONG len, unsigned char *md)
API_AVAILABLE(macos(10.4), ios(2.0));


/*** SHA512 ***/

#define CC_SHA512_DIGEST_LENGTH     64          /* digest length in bytes */
#define CC_SHA512_BLOCK_BYTES      128          /* block size in bytes */

extern int CC_SHA512_Init(CC_SHA512_CTX *c)
API_AVAILABLE(macos(10.4), ios(2.0));

extern int CC_SHA512_Update(CC_SHA512_CTX *c, const void *data, CC_LONG len)
API_AVAILABLE(macos(10.4), ios(2.0));

extern int CC_SHA512_Final(unsigned char *md, CC_SHA512_CTX *c)
API_AVAILABLE(macos(10.4), ios(2.0));

extern unsigned char *CC_SHA512(const void *data, CC_LONG len, unsigned char *md)
API_AVAILABLE(macos(10.4), ios(2.0));

@implementation OneSignalCoreHelper

+ (void)runOnMainThread:(void(^)())block {
    if ([NSThread isMainThread])
        block();
    else
        dispatch_sync(dispatch_get_main_queue(), block);
}

+ (void)dispatch_async_on_main_queue:(void(^)())block {
    dispatch_async(dispatch_get_main_queue(), block);
}

+ (void)performSelector:(SEL)aSelector onMainThreadOnObject:(nullable id)targetObj withObject:(nullable id)anArgument afterDelay:(NSTimeInterval)delay {
    [self dispatch_async_on_main_queue:^{
        [targetObj performSelector:aSelector withObject:anArgument afterDelay:delay];
    }];
}

+ (NSString*)hashUsingSha1:(NSString*)string {
    const char *cstr = [string UTF8String];
    uint8_t digest[CC_SHA1_DIGEST_LENGTH];
    CC_SHA1(cstr, (CC_LONG)strlen(cstr), digest);
    NSMutableString *output = [NSMutableString stringWithCapacity:CC_SHA1_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_SHA1_DIGEST_LENGTH; i++)
        [output appendFormat:@"%02x", digest[i]];
    return output;
}

+ (NSString*)hashUsingMD5:(NSString*)string {
    const char *cstr = [string UTF8String];
    uint8_t digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5(cstr, (CC_LONG)strlen(cstr), digest);
    NSMutableString *output = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_MD5_DIGEST_LENGTH; i++)
        [output appendFormat:@"%02x", digest[i]];
    return output;
}

+ (NSString*)trimURLSpacing:(NSString*)url {
    if (!url)
        return url;
    
    return [url stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
}

+ (NSString*)parseNSErrorAsJsonString:(NSError*)error {
    NSString* jsonResponse;
    
    if (error.userInfo && error.userInfo[@"returned"]) {
        @try {
            NSData* jsonData = [NSJSONSerialization dataWithJSONObject:error.userInfo[@"returned"] options:0 error:nil];
            jsonResponse = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        } @catch(NSException* e) {
            jsonResponse = @"{\"error\": \"Unknown error parsing error response.\"}";
        }
    }
    else
        jsonResponse = @"{\"error\": \"HTTP no response error\"}";
    
    return jsonResponse;
}

// Prevent the OSNotification blocks from firing if we receive a Non-OneSignal remote push
+ (BOOL)isOneSignalPayload:(NSDictionary *)payload {
    if (!payload)
        return NO;
    return payload[@"custom"][@"i"] || payload[@"os_data"][@"i"];
}


+ (NSMutableDictionary*)formatApsPayloadIntoStandard:(NSDictionary*)remoteUserInfo identifier:(NSString*)identifier {
    NSMutableDictionary* userInfo, *customDict, *additionalData, *optionsDict;
    BOOL is2dot4Format = false;
    
    if (remoteUserInfo[@"os_data"]) {
        userInfo = [remoteUserInfo mutableCopy];
        additionalData = [NSMutableDictionary dictionary];
        
        if (remoteUserInfo[@"os_data"][@"buttons"]) {
            
            is2dot4Format = [userInfo[@"os_data"][@"buttons"] isKindOfClass:[NSArray class]];
            if (is2dot4Format)
                optionsDict = userInfo[@"os_data"][@"buttons"];
            else
                optionsDict = userInfo[@"os_data"][@"buttons"][@"o"];
        }
    }
    else if (remoteUserInfo[@"custom"]) {
        userInfo = [remoteUserInfo mutableCopy];
        customDict = [userInfo[@"custom"] mutableCopy];
        if (customDict[@"a"])
            additionalData = [[NSMutableDictionary alloc] initWithDictionary:customDict[@"a"]];
        else
            additionalData = [[NSMutableDictionary alloc] init];
        optionsDict = userInfo[@"o"];
    }
    else {
        return nil;
    }
    
    if (optionsDict) {
        NSMutableArray* buttonArray = [[NSMutableArray alloc] init];
        for (NSDictionary* button in optionsDict) {
            [buttonArray addObject: @{@"text" : button[@"n"],
                                      @"id" : (button[@"i"] ? button[@"i"] : button[@"n"])}];
        }
        additionalData[@"actionButtons"] = buttonArray;
    }
    
    if (![@"com.apple.UNNotificationDefaultActionIdentifier" isEqualToString:identifier])
        additionalData[@"actionSelected"] = identifier;
    
    if ([additionalData count] == 0)
        additionalData = nil;
    else if (remoteUserInfo[@"os_data"]) {
        [userInfo addEntriesFromDictionary:additionalData];
        if (!is2dot4Format && userInfo[@"os_data"][@"buttons"])
            userInfo[@"aps"] = @{@"alert" : userInfo[@"os_data"][@"buttons"][@"m"]};
    }
    
    else {
        customDict[@"a"] = additionalData;
        userInfo[@"custom"] = customDict;
        
        if (userInfo[@"m"])
            userInfo[@"aps"] = @{@"alert" : userInfo[@"m"]};
    }
    
    return userInfo;
}

+ (BOOL)isDisplayableNotification:(NSDictionary*)msg {
    if ([self isRemoteSilentNotification:msg]) {
        return false;
    }
    return msg[@"aps"][@"alert"] != nil;
}

+ (BOOL)isRemoteSilentNotification:(NSDictionary*)msg {
    //no alert, sound, or badge payload
    if(msg[@"badge"] || msg[@"aps"][@"badge"] || msg[@"m"] || msg[@"o"] || msg[@"s"] || (msg[@"title"] && [msg[@"title"] length] > 0) || msg[@"sound"] || msg[@"aps"][@"sound"] || msg[@"aps"][@"alert"] || msg[@"os_data"][@"buttons"])
        return false;
    return true;
}

+ (NSString *)randomStringWithLength:(int)length {
    NSString * letters = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    NSMutableString *randomString = [[NSMutableString alloc] initWithCapacity:length];
    for(int i = 0; i < length; i++) {
        uint32_t ln = (uint32_t)letters.length;
        uint32_t rand = arc4random_uniform(ln);
        [randomString appendFormat:@"%C", [letters characterAtIndex:rand]];
    }
    return randomString;
}

+ (BOOL)verifyURL:(NSString *)urlString {
    if (urlString) {
        NSURL* url = [NSURL URLWithString:urlString];
        if (url)
            return YES;
    }
    
    return NO;
}

+ (BOOL)isWWWScheme:(NSURL*)url {
    NSString* urlScheme = [url.scheme lowercaseString];
    return [urlScheme isEqualToString:@"http"] || [urlScheme isEqualToString:@"https"];
}

/*
 Given a UIDeviceOrientation return the custom enum ViewOrientation
 */
+ (ViewOrientation)validateOrientation:(UIDeviceOrientation)orientation {
    if (UIDeviceOrientationIsPortrait(orientation))
        return OrientationPortrait;
    else if (UIDeviceOrientationIsLandscape(orientation))
        return OrientationLandscape;
    
    return OrientationInvalid;
}

/*
 Given a float convert it to the phone scaled CGFloat
 Multiplies float by iPhones scale value
 */
+ (CGFloat)sizeToScale:(float)size {
    float scale = [self getScreenScale];
    return (CGFloat) (size * scale);
}

/*
 Get currentDevice screen bounds
 Contains point of origin (x, y) and the size (height, width) of the screen
 Changes in regards to the phones current orientation
 */
+ (CGRect)getScreenBounds {
    return UIScreen.mainScreen.bounds;
}

/*
 Get currentDevice screen scale
 Important for specific constraints so that phones of different resolution scale properly
 */
+ (float)getScreenScale {
    return UIScreen.mainScreen.scale;
}

@end
