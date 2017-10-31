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

#import "OneSignalHelperOverrider.h"

#import "TestHelperFunctions.h"

#import "OneSignal.h"
#import "OneSignalHelper.h"

@implementation OneSignalHelperOverrider

static dispatch_queue_t serialMockMainLooper;
static NSString* lastUrl;
static NSDictionary* lastHTTPRequset;
static int networkRequestCount;

static XCTestCase* currentTestInstance;

static float mockIOSVersion;

+ (void)load {
    serialMockMainLooper = dispatch_queue_create("com.onesignal.unittest", DISPATCH_QUEUE_SERIAL);
    
    injectStaticSelector([OneSignalHelperOverrider class], @selector(overrideEnqueueRequest:onSuccess:onFailure:isSynchronous:), [OneSignalHelper class], @selector(enqueueRequest:onSuccess:onFailure:isSynchronous:));
    injectStaticSelector([OneSignalHelperOverrider class], @selector(overrideGetAppName), [OneSignalHelper class], @selector(getAppName));
    injectStaticSelector([OneSignalHelperOverrider class], @selector(overrideIsIOSVersionGreaterOrEqual:), [OneSignalHelper class], @selector(isIOSVersionGreaterOrEqual:));
    injectStaticSelector([OneSignalHelperOverrider class], @selector(overrideDispatch_async_on_main_queue:), [OneSignalHelper class], @selector(dispatch_async_on_main_queue:));
}

+(void)reset:(XCTestCase*)testInstance {
    currentTestInstance = testInstance;
    
    networkRequestCount = 0;
    lastUrl = nil;
    lastHTTPRequset = nil;
}

+(void)setMockIOSVersion:(float)value {
    mockIOSVersion = value;
}
+(float)mockIOSVersion {
    return mockIOSVersion;
}

+(void)setLastHTTPRequset:(NSDictionary*)value {
    lastHTTPRequset = value;
}
+(NSDictionary*)lastHTTPRequset {
    return lastHTTPRequset;
}

+(int)networkRequestCount {
    return networkRequestCount;
}

+(void)setLastUrl:(NSString*)value {
    lastUrl = value;
}

+(NSString*)lastUrl {
    return lastUrl;
}

+ (NSString*) overrideGetAppName {
    return @"App Name";
}

+ (void)overrideEnqueueRequest:(NSURLRequest*)request onSuccess:(OSResultSuccessBlock)successBlock onFailure:(OSFailureBlock)failureBlock isSynchronous:(BOOL)isSynchronous {
    NSError *error = nil;
    
    NSLog(@"request.URL: %@", request.URL);
    
    NSMutableDictionary *parameters;
    
    NSData* httpData = [request HTTPBody];
    if (httpData)
        parameters = [NSJSONSerialization JSONObjectWithData:[request HTTPBody] options:0 error:&error];
    else {
        NSURLComponents *components = [NSURLComponents componentsWithString:request.URL.absoluteString];
        parameters = [NSMutableDictionary new];
        for(NSURLQueryItem *item in components.queryItems) {
            parameters[item.name] = item.value;
        }
    }
    
    // We should always send an app_id with every request.
    if (!parameters[@"app_id"])
        _XCTPrimitiveFail(currentTestInstance);
    
    networkRequestCount++;
    
    id url = [request URL];
    NSLog(@"url: %@", url);
    NSLog(@"parameters: %@", parameters);
    
    lastUrl = [url absoluteString];
    lastHTTPRequset = parameters;
    
    if (successBlock)
        successBlock(@{@"id": @"1234"});
}

+ (BOOL)overrideIsIOSVersionGreaterOrEqual:(float)version {
    return mockIOSVersion >= version;
}

+ (void) overrideDispatch_async_on_main_queue:(void(^)())block {
    dispatch_async(serialMockMainLooper, block);
}

+ (void)runBackgroundThreads {
    dispatch_sync(serialMockMainLooper, ^{});
}

@end
