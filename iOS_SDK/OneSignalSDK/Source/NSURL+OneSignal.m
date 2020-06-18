/**
 * Modified MIT License
 *
 * Copyright 2017 OneSignal
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

#import "NSURL+OneSignal.h"
#import "OneSignalCommonDefines.h"

@implementation NSURL (OneSignal)
- (NSString *)valueFromQueryParameter:(NSString *)parameter {
    NSURLComponents *components = [NSURLComponents componentsWithURL:self resolvingAgainstBaseURL:false];
    
    for (NSURLQueryItem *item in components.queryItems)
        if([item.name isEqualToString:parameter])
            return item.value;
    
    return nil;
}

- (NSString *)supportedFileExtensionFromQueryItems {
    NSURLComponents *components = [NSURLComponents componentsWithURL:self resolvingAgainstBaseURL:false];
    
    for (NSURLQueryItem *item in [components.queryItems reverseObjectEnumerator]) {
        NSString *value = item.value;
        NSString *extension = [self findExtensionInParam:value];
        if (extension)
            return extension;
    }
    return nil;
}

- (NSString*)findExtensionInParam:(NSString *)parameter {
    NSArray *paramComponents = [parameter componentsSeparatedByString:@"."];
    for (NSString *component in [paramComponents reverseObjectEnumerator]) {
        if ([ONESIGNAL_SUPPORTED_ATTACHMENT_TYPES containsObject:component])
            return component;
    }
    return nil;
}

@end
