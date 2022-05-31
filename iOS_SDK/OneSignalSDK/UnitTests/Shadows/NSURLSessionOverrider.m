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

#import "NSURLSessionOverrider.h"
#import "OneSignalSelectorHelpers.h"
#import "TestHelperFunctions.h"
#import "OneSignalHelper.h"



@implementation NSURLSessionOverrider

+ (void)load {
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wundeclared-selector"
    // Swizzle an injected method defined in OneSignalHelper
    injectStaticSelector([NSURLSessionOverrider class], @selector(overrideDownloadItemAtURL:toFile:error:), [NSURLSession class], @selector(downloadItemAtURL:toFile:error:));
    #pragma clang diagnostic pop
    injectSelector(
        [NSURLSession class],
        @selector(dataTaskWithRequest:completionHandler:),
        [NSURLSessionOverrider class],
        @selector(overrideDataTaskWithRequest:completionHandler:)
   );
}

// Override downloading of media attachment
+ (NSString *)overrideDownloadItemAtURL:(NSURL*)url toFile:(NSString*)localPath error:(NSError**)error {
    NSString *content = @"File Contents";
    NSData *fileContents = [content dataUsingEncoding:NSUTF8StringEncoding];
    [[NSFileManager defaultManager] createFileAtPath:localPath
                                            contents:fileContents
                                          attributes:nil];
    
    if ([url.absoluteString isEqualToString:@"http://domain.com/file"])
        return @"image/png";
    else if ([url.path isEqualToString:@"/secondFile"])
        return @"image/heic";
    else
        return @"image/jpg";
}

- (NSURLSessionDataTask *)overrideDataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error))completionHandler {
    
    // mimics no active network connection
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.001 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:request.URL statusCode:0 HTTPVersion:@"1.1" headerFields:@{}];
        NSError *error = [NSError errorWithDomain:@"OneSignal Error" code:0 userInfo:@{@"error" : @"The user is not currently connected to the network."}];
        NSLog(@"Calling completion handler");
        completionHandler(nil, response, error);
    });
    
    return [MockNSURLSessionDataTask new];
}

@end

@implementation MockNSURLSessionDataTask

-(void)resume {
    //unimplemented
}

@end
