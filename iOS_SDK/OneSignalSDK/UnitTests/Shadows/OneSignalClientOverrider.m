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

#import "OneSignalClientOverrider.h"
#import "TestHelperFunctions.h"

#import "OneSignal.h"
#import "OneSignalHelper.h"
#import "OneSignalClient.h"
#import "OneSignalSelectorHelpers.h"
#import "Requests.h"
#import "OneSignalCommonDefines.h"
#import "OSInAppMessagingHelpers.h"
#import "OSOutcomeEventsDefines.h"

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
static BOOL shouldUseProvisionalAuthorization = false; //new in iOS 12 (aka Direct to History)
static BOOL disableOverride = false;
static NSMutableArray<OneSignalRequest *> *executedRequests;
static NSMutableDictionary<NSString *, NSDictionary *> *mockResponses;
static NSDictionary* iOSParamsOutcomes;

+ (void)load {
    serialMockMainLooper = dispatch_queue_create("com.onesignal.unittest", DISPATCH_QUEUE_SERIAL);
    
    //with refactored networking code, need to replace the implementation of the execute request method so tests don't actually execite HTTP requests
    injectToProperClass(@selector(overrideExecuteRequest:onSuccess:onFailure:), @selector(executeRequest:onSuccess:onFailure:), @[], [OneSignalClientOverrider class], [OneSignalClient class]);
    injectToProperClass(@selector(overrideExecuteSimultaneousRequests:withSuccess:onFailure:), @selector(executeSimultaneousRequests:withSuccess:onFailure:), @[], [OneSignalClientOverrider class], [OneSignalClient class]);
    injectToProperClass(@selector(overrideExecuteDataRequest:onSuccess:onFailure:), @selector(executeDataRequest:onSuccess:onFailure:), @[], [OneSignalClientOverrider class], [OneSignalClient class]);


    executionQueue = dispatch_queue_create("com.onesignal.execution", NULL);
    
    executedRequests = [NSMutableArray new];

    mockResponses = [NSMutableDictionary new];
}

+ (NSDictionary*)iosParamsResponse {
    return @{
        @"fba": @true,
        IOS_REQUIRES_EMAIL_AUTHENTICATION : @(requiresEmailAuth),
        IOS_USES_PROVISIONAL_AUTHORIZATION : @(shouldUseProvisionalAuthorization),
        OUTCOMES_PARAM : iOSParamsOutcomes
    };
}

+ (void)enableOutcomes {
    iOSParamsOutcomes = @{
        DIRECT_PARAM: @{
            ENABLED_PARAM: @YES
        },
        INDIRECT_PARAM: @{
            NOTIFICATION_ATTRIBUTION_PARAM: @{
                MINUTES_SINCE_DISPLAYED_PARAM: @1440,
                LIMIT_PARAM: @10
            },
            ENABLED_PARAM: @YES
        },
        UNATTRIBUTED_PARAM: @{
            ENABLED_PARAM: @YES
        }
    };
}

// Calling this function twice results in reversing the swizzle
+ (void)disableExecuteRequestOverride:(BOOL)disable {
    disableOverride = disable;
}

- (void)overrideExecuteSimultaneousRequests:(NSDictionary<NSString *, OneSignalRequest *> *)requests withSuccess:(OSMultipleSuccessBlock)successBlock onFailure:(OSMultipleFailureBlock)failureBlock {
    if (disableOverride)
        return [self overrideExecuteSimultaneousRequests:requests withSuccess:successBlock onFailure:failureBlock];
    
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
    
    if (disableOverride)
        return [self overrideExecuteRequest:request onSuccess:successBlock onFailure:failureBlock];
    
    [executedRequests addObject:request];
    
    if (executeInstantaneously) {
        [OneSignalClientOverrider finishExecutingRequest:request onSuccess:successBlock onFailure:failureBlock];
    } else {
        dispatch_async(executionQueue, ^{
            [OneSignalClientOverrider finishExecutingRequest:request onSuccess:successBlock onFailure:failureBlock];
        });
    }
}

- (void)overrideExecuteDataRequest:(OneSignalRequest *)request onSuccess:(OSDataRequestSuccessBlock)successBlock onFailure:(OSFailureBlock)failureBlock {
    if (disableOverride)
        return [self overrideExecuteDataRequest:request onSuccess:successBlock onFailure:failureBlock];

    if (executeInstantaneously) {
        [OneSignalClientOverrider finishExecutingDataRequest:request onSuccess:successBlock onFailure:failureBlock];
    } else {
        dispatch_async(executionQueue, ^{
            [OneSignalClientOverrider finishExecutingDataRequest:request onSuccess:successBlock onFailure:failureBlock];
        });
    }
}

+ (void)finishExecutingDataRequest:(OneSignalRequest *)request onSuccess:(OSDataRequestSuccessBlock)successBlock onFailure:(OSFailureBlock)failureBlock {
    @synchronized (lastHTTPRequest) {
        NSLog(@"completing HTTP data request: %@", NSStringFromClass([request class]));

        [self didCompleteRequest:request];

        if (successBlock) {
            let resultData = [OS_DUMMY_HTML dataUsingEncoding:NSUTF8StringEncoding];

            successBlock(resultData);
        }
    }
}

+ (void)finishExecutingRequest:(OneSignalRequest *)request onSuccess:(OSResultSuccessBlock)successBlock onFailure:(OSFailureBlock)failureBlock {
    @synchronized(lastHTTPRequest) {
        NSLog(@"completing HTTP request: %@", NSStringFromClass([request class]));
        
        NSMutableDictionary *parameters = [request.parameters mutableCopy];
        
        if (!parameters[@"app_id"] && ![request.urlRequest.URL.absoluteString containsString:@"/apps/"])
            _XCTPrimitiveFail(currentTestInstance, @"All request should include an app_id");
        
        [self didCompleteRequest:request];

        if (successBlock) {
            if ([request isKindOfClass:[OSRequestGetIosParams class]])
                successBlock(self.iosParamsResponse);
            else if (mockResponses[NSStringFromClass([request class])])
                successBlock(mockResponses[NSStringFromClass([request class])]);
            else
                successBlock(@{@"id": @"1234"});
        }
    }
}

+ (void)didCompleteRequest:(OneSignalRequest *)request {
    NSMutableDictionary *parameters = [request.parameters mutableCopy];

    networkRequestCount++;

    let url = [request.urlRequest URL];
    NSLog(@"url(%d): %@\n params: %@", networkRequestCount, url, parameters);

    lastUrl = [url absoluteString];
    lastHTTPRequest = parameters;
    lastHTTPRequestType = NSStringFromClass([request class]);
}

+ (BOOL)hasExecutedRequestOfType:(Class)type {
    for (OneSignalRequest *request in executedRequests)
        if ([request isKindOfClass:type])
            return true;
    
    return false;
}

+ (dispatch_queue_t)getHTTPQueue {
    return executionQueue;
}

+ (NSString *)lastHTTPRequestType {
    return lastHTTPRequestType;
}

+ (void)setShouldExecuteInstantaneously:(BOOL)instant {
    executeInstantaneously = instant;
}

+ (void)reset:(XCTestCase*)testInstance {
    currentTestInstance = testInstance;
    shouldUseProvisionalAuthorization = false;
    networkRequestCount = 0;
    lastUrl = nil;
    lastHTTPRequest = nil;
    lastHTTPRequestType = nil;
    [executedRequests removeAllObjects];
    mockResponses = [NSMutableDictionary new];
    iOSParamsOutcomes = @{};
}

+ (void)setLastHTTPRequest:(NSDictionary*)value {
    lastHTTPRequest = value;
}
+ (NSDictionary*)lastHTTPRequest {
    return lastHTTPRequest;
}

+ (int)networkRequestCount {
    return networkRequestCount;
}

+ (void)setLastUrl:(NSString*)value {
    lastUrl = value;
}

+ (NSString*)lastUrl {
    return lastUrl;
}

+ (void)runBackgroundThreads {
    dispatch_sync(executionQueue, ^{});
}

+ (void)setRequiresEmailAuth:(BOOL)required {
    requiresEmailAuth = required;
}

+ (void)setShouldUseProvisionalAuth:(BOOL)provisional {
    shouldUseProvisionalAuthorization = provisional;
}

+ (NSArray<OneSignalRequest *> *)executedRequests {
    return executedRequests;
}

+ (void)setMockResponseForRequest:(NSString *)request withResponse:(NSDictionary *)response {
    [mockResponses setObject:response forKey:request];
}

@end

