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
#import "Requests.h"

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
static NSString *lastHTTPRequestType;
static BOOL requiresEmailAuth = false;

+ (void)load {
    serialMockMainLooper = dispatch_queue_create("com.onesignal.unittest", DISPATCH_QUEUE_SERIAL);
    
    
    //with refactored networking code, need to replace the implementation of the execute request method so tests don't actually execite HTTP requests
    injectToProperClass(@selector(overrideExecuteRequest:onSuccess:onFailure:), @selector(executeRequest:onSuccess:onFailure:), @[], [OneSignalClientOverrider class], [OneSignalClient class]);
    injectToProperClass(@selector(overrideExecuteSimultaneousRequests:withSuccess:onFailure:), @selector(executeSimultaneousRequests:withSuccess:onFailure:), @[], [OneSignalClientOverrider class], [OneSignalClient class]);
    
    executionQueue = dispatch_queue_create("com.onesignal.execution", NULL);
    
}

- (void)overrideExecuteSimultaneousRequests:(NSDictionary<NSString *, OneSignalRequest *> *)requests withSuccess:(OSMultipleSuccessBlock)successBlock onFailure:(OSMultipleFailureBlock)failureBlock {
    
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    __block NSMutableDictionary<NSString *, NSError *> *errors = [NSMutableDictionary new];
    __block NSMutableDictionary<NSString *, NSDictionary *> *results = [NSMutableDictionary new];
    
    for (NSString *key in requests.allKeys) {
        [OneSignalClient.sharedClient executeRequest:requests[key] onSuccess:^(NSDictionary *result) {
            results[key] = result;
            dispatch_semaphore_signal(semaphore);
        } onFailure:^(NSError *error) {
            errors[key] = error;
            dispatch_semaphore_signal(semaphore);
        }];
    }
    
    for (int i = 0; i < requests.count; i++) {
        dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, 0.1 * NSEC_PER_SEC));
    }
    
    if (errors.allKeys.count > 0 && failureBlock) {
        failureBlock(errors);
    } else if (errors.allKeys.count == 0 && successBlock) {
        successBlock(results);
    }
}

- (void)overrideExecuteRequest:(OneSignalRequest *)request onSuccess:(OSResultSuccessBlock)successBlock onFailure:(OSFailureBlock)failureBlock {
    if (executeInstantaneously) {
        [OneSignalClientOverrider finishExecutingRequest:request onSuccess:successBlock onFailure:failureBlock];
    } else {
        dispatch_async(executionQueue, ^{
            [OneSignalClientOverrider finishExecutingRequest:request onSuccess:successBlock onFailure:failureBlock];
        });
    }
}

+ (void)finishExecutingRequest:(OneSignalRequest *)request onSuccess:(OSResultSuccessBlock)successBlock onFailure:(OSFailureBlock)failureBlock {
    @synchronized(lastHTTPRequest) {
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
        lastHTTPRequestType = NSStringFromClass([request class]);
        
        if (successBlock) {
            if ([request isKindOfClass:[OSRequestGetIosParams class]])
                successBlock(@{@"fba": @true, @"require_email_auth" : @(requiresEmailAuth)});
            else
                successBlock(@{@"id": @"1234"});
        }
    }
}

+(dispatch_queue_t)getHTTPQueue {
    return executionQueue;
}

+ (NSString *)lastHTTPRequestType {
    return lastHTTPRequestType;
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

+(void)runBackgroundThreads {
    dispatch_sync(executionQueue, ^{});
}

+(void)setRequiresEmailAuth:(BOOL)required {
    requiresEmailAuth = required;
}

@end

