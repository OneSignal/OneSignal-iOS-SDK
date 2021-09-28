//
//  OneSignalCoreHelper.m
//  OneSignal
//
//  Created by Elliot Mawby on 9/28/21.
//  Copyright © 2021 Hiptic. All rights reserved.
//

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

@end
