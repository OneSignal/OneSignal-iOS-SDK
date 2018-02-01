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

#import "OneSignalClient.h"
#import "UIApplicationDelegate+OneSignal.h"
#import "ReattemptRequest.h"

#define REATTEMPT_DELAY 30.0
#define REQUEST_TIMEOUT_REQUEST 60.0 //for most HTTP requests
#define REQUEST_TIMEOUT_RESOURCE 100.0 //for loading a resource like an image
#define MAX_ATTEMPT_COUNT 3

@interface OneSignalClient ()
@property (strong, nonatomic) NSURLSession *sharedSession;
@end

@implementation OneSignalClient

+ (OneSignalClient *)sharedClient {
    static OneSignalClient *sharedClient = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        sharedClient = [OneSignalClient new];
    });
    return sharedClient;
}

-(instancetype)init {
    if (self = [super init]) {
        let configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
        configuration.timeoutIntervalForRequest = REQUEST_TIMEOUT_REQUEST;
        configuration.timeoutIntervalForResource = REQUEST_TIMEOUT_RESOURCE;
        
        _sharedSession = [NSURLSession sessionWithConfiguration:configuration];
    }
    
    return self;
}

- (void)executeSimultaneousRequests:(NSDictionary<NSString *, OneSignalRequest *> *)requests withSuccess:(OSMultipleSuccessBlock)successBlock onFailure:(OSMultipleFailureBlock)failureBlock {
    
    if (requests.allKeys.count == 0)
        return;
    
    //execute on a background thread or the semaphore will block the caller thread
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
        
        __block NSMutableDictionary<NSString *, NSError *> *errors = [NSMutableDictionary new];
        __block NSMutableDictionary<NSString *, NSDictionary *> *results = [NSMutableDictionary new];
        
        for (NSString *identifier in requests.allKeys) {
            let request = requests[identifier];
            
            [self executeRequest:request onSuccess:^(NSDictionary *result) {
                results[identifier] = result;
                dispatch_semaphore_signal(semaphore);
            } onFailure:^(NSError *error) {
                errors[identifier] = error;
                dispatch_semaphore_signal(semaphore);
            }];
        }
        
        for (int i = 0; i < requests.count; i++) {
            dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
        }
        
        //requests should all be completed at this point
        dispatch_async(dispatch_get_main_queue(), ^{
            if (errors.allKeys.count > 0 && failureBlock) {
                failureBlock(errors);
            } else if (errors.allKeys.count == 0 && successBlock) {
                successBlock(results);
            }
        });
    });
}

- (void)executeRequest:(OneSignalRequest *)request onSuccess:(OSResultSuccessBlock)successBlock onFailure:(OSFailureBlock)failureBlock {
    if (![self validRequest:request]) {
        [self handleMissingAppIdError:failureBlock withRequest:request];
        return;
    }
    
    let task = [self.sharedSession dataTaskWithRequest:request.request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        [self handleJSONNSURLResponse:response data:data error:error isAsync:true withRequest:request onSuccess:successBlock onFailure:failureBlock];
    }];
    
    [task resume];
}

// while this method still uses completion blocks like the asynchronous method,
// it pauses execution of the thread until the request is finished
- (void)executeSynchronousRequest:(OneSignalRequest *)request onSuccess:(OSResultSuccessBlock)successBlock onFailure:(OSFailureBlock)failureBlock {
    if (![self validRequest:request]) {
        [self handleMissingAppIdError:failureBlock withRequest:request];
        return;
    }
    
    __block NSURLResponse *httpResponse;
    __block NSError *httpError;
    
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    let dataTask = [self.sharedSession dataTaskWithRequest:request.request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        httpResponse = response;
        httpError = error;
        
        dispatch_semaphore_signal(semaphore);
    }];
    
    [dataTask resume];
    
    dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, REQUEST_TIMEOUT_RESOURCE * NSEC_PER_SEC));
    
    [self handleJSONNSURLResponse:httpResponse data:nil error:httpError isAsync:false withRequest:request onSuccess:successBlock onFailure:failureBlock];
}

- (void)handleMissingAppIdError:(OSFailureBlock)failureBlock withRequest:(OneSignalRequest *)request {
    let errorDescription = [NSString stringWithFormat:@"HTTP Request (%@) must contain app_id parameter", NSStringFromClass([request class])];
    
    [OneSignal onesignal_Log:ONE_S_LL_ERROR message:errorDescription];
    
    failureBlock([NSError errorWithDomain:@"OneSignalError" code:-1 userInfo:@{@"error" : errorDescription}]);
}

- (BOOL)validRequest:(OneSignalRequest *)request {
    if (request.missingAppId) {
        return false;
    }
    
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"HTTP Request (%@) with URL: %@, with parameters: %@", NSStringFromClass([request class]), request.request.URL.absoluteString, request.parameters]];
    
    return true;
}

// reattempts a failed HTTP request
// only occurs if the request encountered a 500+ server error (or timeout) code.
// only asynchronous HTTP requests will get reattempted with a delay
// synchronous requests (ie. image downloads) will be reattempted immediately
- (void)reattemptRequest:(ReattemptRequest *)reattempt {
    if (!reattempt) {
        return;
    }
    
    //very important to increment this variable otherwise the request will continue to reattempt infinitely until it stops getting a 500+ error code.
    //we want requests to only retry one time after a delay.
    reattempt.request.reattemptCount++;
    
    [self executeRequest:reattempt.request onSuccess:reattempt.successBlock onFailure:reattempt.failureBlock];
}

- (void)handleJSONNSURLResponse:(NSURLResponse*)response data:(NSData*)data error:(NSError*)error isAsync:(BOOL)async withRequest:(OneSignalRequest *)request onSuccess:(OSResultSuccessBlock)successBlock onFailure:(OSFailureBlock)failureBlock {
    
    NSHTTPURLResponse* HTTPResponse = (NSHTTPURLResponse*)response;
    NSInteger statusCode = [HTTPResponse statusCode];
    NSError* jsonError = nil;
    NSMutableDictionary* innerJson;
    
    if (data != nil && [data length] > 0) {
        innerJson = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&jsonError];
        [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"network response: %@", innerJson]];
        if (jsonError) {
            if (failureBlock != nil)
                failureBlock([NSError errorWithDomain:@"OneSignal Error" code:statusCode userInfo:@{@"returned" : jsonError}]);
            return;
        }
    }
    
    // in the event that there is no network connection, NSURLSession will return status code 0
    if ((statusCode >= 500 || statusCode == 0) && request.reattemptCount < MAX_ATTEMPT_COUNT - 1) {
        let reattempt = [ReattemptRequest withRequest:request successBlock:successBlock failureBlock:failureBlock];
        
        if (async) {
            //retry again in 15 seconds
            [OneSignal onesignal_Log:ONE_S_LL_DEBUG message:[NSString stringWithFormat:@"Re-scheduling request (%@) to be re-attempted in %i seconds due to failed HTTP request with status code %i", NSStringFromClass([request class]), (int)REATTEMPT_DELAY, (int)statusCode]];
            
            [OneSignalHelper performSelector:@selector(reattemptRequest:) onMainThreadOnObject:self withObject:reattempt afterDelay:REATTEMPT_DELAY];
        } else {
            //retry again immediately
            [self reattemptRequest: reattempt];
        }
        
        return;
    }
    
    if (error == nil && statusCode == 200) {
        if (successBlock != nil) {
            if (innerJson != nil)
                successBlock(innerJson);
            else
                successBlock(nil);
        }
    } else if (failureBlock != nil) {
        if (innerJson != nil && error == nil)
            failureBlock([NSError errorWithDomain:@"OneSignalError" code:statusCode userInfo:@{@"returned" : innerJson}]);
        else if (error != nil)
            failureBlock([NSError errorWithDomain:@"OneSignalError" code:statusCode userInfo:@{@"error" : error}]);
        else
            failureBlock([NSError errorWithDomain:@"OneSignalError" code:statusCode userInfo:nil]);
    }
}

@end
