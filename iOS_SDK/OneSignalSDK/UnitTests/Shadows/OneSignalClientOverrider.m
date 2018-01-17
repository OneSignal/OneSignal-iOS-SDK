//
//  OneSignalClientOverrider.m
//  OneSignal
//
//  Created by Brad Hesse on 12/19/17.
//  Copyright © 2017 Hiptic. All rights reserved.
//

//
//  OneSignalClientOverrider.m
//  UnitTests
//
//  Created by Brad Hesse on 12/18/17.
//  Copyright © 2017 Hiptic. All rights reserved.
//

#import "OneSignalClientOverrider.h"
#import "TestHelperFunctions.h"

#import "OneSignal.h"
#import "OneSignalHelper.h"
#import "OneSignalClient.h"
#import "OneSignalRequest.h"
#import "OneSignalSelectorHelpers.h"

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"

@implementation OneSignalClientOverrider

static dispatch_queue_t serialMockMainLooper;
static NSString* lastUrl;
static int networkRequestCount;
static NSDictionary* lastHTTPRequest;
static XCTestCase* currentTestInstance;
static BOOL executeInstantaneously = true;
static dispatch_queue_t executionQueue;

+ (void)load {
    serialMockMainLooper = dispatch_queue_create("com.onesignal.unittest", DISPATCH_QUEUE_SERIAL);
    
    
    //with refactored networking code, need to replace the implementation of the execute request method so tests don't actually execite HTTP requests
    injectToProperClass(@selector(overrideExecuteRequest:onSuccess:onFailure:), @selector(executeRequest:onSuccess:onFailure:), @[], [OneSignalClientOverrider class], [OneSignalClient class]);
    
    executionQueue = dispatch_queue_create("com.onesignal.execution", NULL);
}

- (void)overrideExecuteRequest:(OneSignalRequest *)request onSuccess:(OSResultSuccessBlock)successBlock onFailure:(OSFailureBlock)failureBlock {
    NSLog(@"Executing request: %@", NSStringFromClass([request class]));
    if (executeInstantaneously) {
        [OneSignalClientOverrider finishExecutingRequest:request onSuccess:successBlock onFailure:failureBlock];
    } else {
        dispatch_async(executionQueue, ^{
            [OneSignalClientOverrider finishExecutingRequest:request onSuccess:successBlock onFailure:failureBlock];
        });
    }
}

+ (void)finishExecutingRequest:(OneSignalRequest *)request onSuccess:(OSResultSuccessBlock)successBlock onFailure:(OSFailureBlock)failureBlock {
    NSLog(@"completing HTTP request: %@", NSStringFromClass([request class]));
    
    NSMutableDictionary *parameters = [request.parameters mutableCopy];
    
    if (!parameters[@"app_id"] && ![request.request.URL.absoluteString containsString:@"/apps/"])
        _XCTPrimitiveFail(currentTestInstance, @"All request should include an app_id");
    
    networkRequestCount++;
    
    id url = [request.request URL];
    NSLog(@"url: %@", url);
    NSLog(@"parameters: %@", parameters);
    
    lastUrl = [url absoluteString];
    lastHTTPRequest = parameters;
    
    if (successBlock) {
        if ([request.request.URL.absoluteString hasPrefix:@"https://onesignal.com/api/v1/apps/"])
            successBlock(@{@"fba": @true});
        else
            successBlock(@{@"id": @"1234"});
    }
}

+(dispatch_queue_t)getHTTPQueue {
    return executionQueue;
}

+(void)setShouldExecuteInstantaneously:(BOOL)instant {
    executeInstantaneously = instant;
}

+(void)reset:(XCTestCase*)testInstance {
    currentTestInstance = testInstance;
    
    networkRequestCount = 0;
    lastUrl = nil;
    lastHTTPRequest = nil;
}

+(void)setLastHTTPRequest:(NSDictionary*)value {
    lastHTTPRequest = value;
}
+(NSDictionary*)lastHTTPRequest {
    return lastHTTPRequest;
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

@end

