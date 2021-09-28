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
#import "OSReattemptRequest.h"
#import "OneSignalCommonDefines.h"
#import "OneSignalLog.h"
#import "OneSignalCoreHelper.h"

//@interface OneSignal (OneSignalClientExtra)
//+ (BOOL)shouldLogMissingPrivacyConsentErrorWithMethodName:(NSString *)methodName;
//@end

@interface OneSignalClient ()
@property (strong, nonatomic) NSURLSession *sharedSession;
@property (strong, nonatomic) NSURLSession *noCacheSession;
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
        _sharedSession = [NSURLSession sessionWithConfiguration:[self configurationWithCachingPolicy:NSURLRequestUseProtocolCachePolicy]];
        _noCacheSession = [NSURLSession sessionWithConfiguration:[self configurationWithCachingPolicy:NSURLRequestReloadIgnoringLocalCacheData]];
    }
    
    return self;
}

- (NSURLSessionConfiguration *)configurationWithCachingPolicy:(NSURLRequestCachePolicy)policy {
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    configuration.timeoutIntervalForRequest = REQUEST_TIMEOUT_REQUEST;
    configuration.timeoutIntervalForResource = REQUEST_TIMEOUT_RESOURCE;
    
    //prevent caching of requests, this mainly impacts OSRequestGetIosParams,
    //since the OSRequestGetTags endpoint has a caching header policy
    configuration.requestCachePolicy = policy;
    
    return configuration;
}

- (NSError *)privacyConsentErrorWithRequestType:(NSString *)type {
    return [NSError errorWithDomain:@"OneSignal Error" code:0 userInfo:@{@"error" : [NSString stringWithFormat: @"Attempted to perform an HTTP request (%@) before the user provided privacy consent.", type]}];
}

- (NSError *)genericTimedOutError {
    return [NSError errorWithDomain:@"OneSignal Error" code:0 userInfo:@{@"error" : @"The request timed out"}];
}

- (void)executeSimultaneousRequests:(NSDictionary<NSString *, OneSignalRequest *> *)requests withCompletion:(OSMultipleCompletionBlock)completionBlock {
    if (requests.allKeys.count == 0)
        return;
    
    // Execute on a background thread or the semaphore will block the caller thread
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        dispatch_group_t group = dispatch_group_create();
        
        __block NSMutableDictionary<NSString *, NSError *> *errors = [NSMutableDictionary new];
        __block NSMutableDictionary<NSString *, NSDictionary *> *results = [NSMutableDictionary new];
        
        // Used as the reasposne for the completion callback
        __block NSMutableDictionary *response = [NSMutableDictionary new];
        
        for (NSString *identifier in requests.allKeys) {
            OneSignalRequest *request = requests[identifier];
            
            // Use a dispatch_group instead of a semaphore, in case the failureBlock gets called synchronously
            // This will prevent the SDK from waiting/blocking on a request that instantly failed
            dispatch_group_enter(group);
            [self executeRequest:request onSuccess:^(NSDictionary *result) {
                results[identifier] = result;
                // Add a success as 1 (success) to the response
                response[identifier] = @{ @"success" : @(true) };
                NSLog(@"Request %@ success result %@", request, result);
                dispatch_group_leave(group);
            } onFailure:^(NSError *error) {
                errors[identifier] = error;
                // Add a success as 0 (failed) to the response
                response[identifier] = @{ @"success" : @(false) };
                NSLog(@"Request %@ fail result error %@", request, error);
                dispatch_group_leave(group);
            }];
        }
        
        // Will wait for up to (maxTimeout) seconds and will then give up and call
        //  the failure block if the request times out.
        BOOL timedOut = (bool)(0 != dispatch_group_wait(group, dispatch_time(DISPATCH_TIME_NOW, MAX_TIMEOUT)));
        
        // Add a generic 'timed out' error if the request timed out
        //  and there are no other errors present.
        if (timedOut && errors.allKeys.count == 0) {
            for (NSString *key in requests.allKeys) {
                errors[key] = [self genericTimedOutError];
                // Add a success as 0 (timeout/failed) to the response
                response[key] = @{ @"success" : @(false) };
            }
        }
        
        // Requests should all be completed at this point, the response NSDictionary will be passed back
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completionBlock)
                completionBlock(response);
        });
    });
}

- (void)executeSimultaneousRequests:(NSDictionary<NSString *, OneSignalRequest *> *)requests withSuccess:(OSMultipleSuccessBlock)successBlock onFailure:(OSMultipleFailureBlock)failureBlock {
    if (requests.allKeys.count == 0)
        return;
    
    //execute on a background thread or the semaphore will block the caller thread
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        dispatch_group_t group = dispatch_group_create();
        
        __block NSMutableDictionary<NSString *, NSError *> *errors = [NSMutableDictionary new];
        __block NSMutableDictionary<NSString *, NSDictionary *> *results = [NSMutableDictionary new];
        
        for (NSString *identifier in requests.allKeys) {
            OneSignalRequest *request = requests[identifier];
            
            //use a dispatch_group instead of a semaphore, in case the failureBlock gets called synchronously
            //this will prevent the SDK from waiting/blocking on a request that instantly failed
            dispatch_group_enter(group);
            [self executeRequest:request onSuccess:^(NSDictionary *result) {
                results[identifier] = result;
                NSLog(@"Request %@ success result %@", request, result);
                dispatch_group_leave(group);
            } onFailure:^(NSError *error) {
                errors[identifier] = error;
                NSLog(@"Request %@ fail result error %@", request, error);
                dispatch_group_leave(group);
            }];
        }
        
        // Will wait for up to (maxTimeout) seconds and will then give up and call
        // the failure block if the request times out.
        BOOL timedOut = (bool)(0 != dispatch_group_wait(group, dispatch_time(DISPATCH_TIME_NOW, MAX_TIMEOUT)));
        
        // add a generic 'timed out' error if the request timed out
        // and there are no other errors present.
        if (timedOut && errors.allKeys.count == 0)
            for (NSString *key in requests.allKeys)
                errors[key] = [self genericTimedOutError];
        
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
    // ECM TODO: We need to handle privacy consent 
    if (request.method != GET) { //&& [OneSignal shouldLogMissingPrivacyConsentErrorWithMethodName:nil]) {
        if (failureBlock) {
            failureBlock([self privacyConsentErrorWithRequestType:NSStringFromClass(request.class)]);
        }
        
        return;
    }
    
    if (request.dataRequest) {
        if (failureBlock) {
            failureBlock([NSError errorWithDomain:@"onesignal" code:0 userInfo:@{@"error" : [NSString stringWithFormat:@"Attempted to execute a data-only API request (%@) using OneSignalClient's executeRequest: method, which only accepts JSON-based API requests", NSStringFromClass(request.class)]}]);
        }
        
        return;
    }
    
    if (![self validRequest:request]) {
        [self handleMissingAppIdError:failureBlock withRequest:request];
        return;
    }
    
    /*
        None of our requests should currently be cached locally.
        However, to avoid any future confusion, each OneSignalRequest
        has a property indicating if local caching should be
        explicitly disabled for that request. The default is false.
    */
    NSURLSession *session = request.disableLocalCaching ? self.noCacheSession : self.sharedSession;
    
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request.urlRequest completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
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
    
    if (request.dataRequest) {
        if (failureBlock) {
            failureBlock([NSError errorWithDomain:@"onesignal" code:0 userInfo:@{@"error" : [NSString stringWithFormat:@"Attempted to execute a data-only API request (%@) using OneSignalClient's executeRequest: method, which only accepts JSON-based API requests", NSStringFromClass(request.class)]}]);
        }
        
        return;
    }
    
    __block NSURLResponse *httpResponse;
    __block NSError *httpError;
    
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    NSURLSessionDataTask *dataTask = [self.sharedSession dataTaskWithRequest:request.urlRequest completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        httpResponse = response;
        httpError = error;
        
        dispatch_semaphore_signal(semaphore);
    }];
    
    [dataTask resume];
    
    dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, REQUEST_TIMEOUT_RESOURCE * NSEC_PER_SEC));
    
    [self handleJSONNSURLResponse:httpResponse data:nil error:httpError isAsync:false withRequest:request onSuccess:successBlock onFailure:failureBlock];
}

- (void)executeDataRequest:(OneSignalRequest *)request onSuccess:(OSDataRequestSuccessBlock)successBlock onFailure:(OSFailureBlock)failureBlock {
    [self prettyPrintDebugStatementWithRequest:request];
    
    if (!request.dataRequest) {
        if (failureBlock) {
            failureBlock([NSError errorWithDomain:@"onesignal" code:0 userInfo:@{@"error" : [NSString stringWithFormat:@"Attempted to execute an API request (%@) using OneSignalClient's executeDataRequest: method, which only accepts data based requests", NSStringFromClass(request.class)]}]);
        }
        
        return;
    }
    
    NSURLSession *session = request.disableLocalCaching ? self.noCacheSession : self.sharedSession;
    
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request.urlRequest completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSError *requestError = error;
        int status = (int)((NSHTTPURLResponse *)response).statusCode;
        
        if (requestError || status >= 300) {
            if (!requestError)
                requestError = [NSError errorWithDomain:@"onesignal" code:0 userInfo:@{@"error" : [NSString stringWithFormat:@"Request (%@)encountered an unknown error with HTTP status code %i", NSStringFromClass([request class]), status]}];
            
            if (failureBlock)
                failureBlock(requestError);
            
            return;
        }
        
        if (successBlock)
            successBlock(data);
    }];
    
    [task resume];
}

- (void)handleMissingAppIdError:(OSFailureBlock)failureBlock withRequest:(OneSignalRequest *)request {
    NSString *errorDescription = [NSString stringWithFormat:@"HTTP Request (%@) must contain app_id parameter", NSStringFromClass([request class])];
    
    [OneSignalLog onesignalLog:ONE_S_LL_ERROR message:errorDescription];
    
    if (failureBlock)
        failureBlock([NSError errorWithDomain:@"OneSignalError" code:-1 userInfo:@{@"error" : errorDescription}]);
}

- (BOOL)validRequest:(OneSignalRequest *)request {
    if (request.missingAppId) {
        return false;
    }
    
    [self prettyPrintDebugStatementWithRequest:request];
    
    return true;
}

// reattempts a failed HTTP request
// only occurs if the request encountered a 500+ server error (or timeout) code.
// only asynchronous HTTP requests will get reattempted with a delay
// synchronous requests (ie. image downloads) will be reattempted immediately
- (void)reattemptRequest:(OSReattemptRequest *)reattempt {
    if (!reattempt) {
        return;
    }
    
    //very important to increment this variable otherwise the request will continue to reattempt infinitely until it stops getting a 500+ error code.
    //we want requests to only retry one time after a delay.
    reattempt.request.reattemptCount++;
    
    [self executeRequest:reattempt.request onSuccess:reattempt.successBlock onFailure:reattempt.failureBlock];
}

- (BOOL)willReattemptRequest:(int)statusCode withRequest:(OneSignalRequest *)request success:(OSResultSuccessBlock)successBlock failure:(OSFailureBlock)failureBlock asyncRequest:(BOOL)async {
    // in the event that there is no network connection, NSURLSession will return status code 0
    if ((statusCode >= 500 || statusCode == 0) && request.reattemptCount < MAX_ATTEMPT_COUNT - 1) {
        OSReattemptRequest *reattempt = [OSReattemptRequest withRequest:request successBlock:successBlock failureBlock:failureBlock];
        
        if (async) {
            //retry again in 15 seconds
            [OneSignalLog onesignalLog:ONE_S_LL_DEBUG message:[NSString stringWithFormat:@"Re-scheduling request (%@) to be re-attempted in %.3f seconds due to failed HTTP request with status code %i", NSStringFromClass([request class]), REATTEMPT_DELAY, (int)statusCode]];
            [OneSignalCoreHelper dispatch_async_on_main_queue:^{
                [self performSelector:@selector(reattemptRequest:) withObject:reattempt afterDelay:REATTEMPT_DELAY];
            }];
        } else {
            //retry again immediately
            [self reattemptRequest: reattempt];
        }
        
        return true;
    }
    
    return false;
}

- (void)prettyPrintDebugStatementWithRequest:(OneSignalRequest *)request {
    if (![NSJSONSerialization isValidJSONObject:request.parameters])
        return;
    
    NSError *error;
    
    NSData *data = [NSJSONSerialization dataWithJSONObject:request.parameters options:NSJSONWritingPrettyPrinted error:&error];
    
    if (error || !data) {
        [OneSignalLog onesignalLog:ONE_S_LL_ERROR message:[NSString stringWithFormat:@"Unable to print the parameters of %@ with JSON serialization error: %@.", NSStringFromClass([request class]), error.description]];
        return;
    }
    
    NSString *jsonString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
    [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"HTTP Request (%@) with URL: %@, with parameters: %@", NSStringFromClass([request class]), request.urlRequest.URL.absoluteString, jsonString]];
}

- (void)handleJSONNSURLResponse:(NSURLResponse*)response data:(NSData*)data error:(NSError*)error isAsync:(BOOL)async withRequest:(OneSignalRequest *)request onSuccess:(OSResultSuccessBlock)successBlock onFailure:(OSFailureBlock)failureBlock {
    
    NSHTTPURLResponse* HTTPResponse = (NSHTTPURLResponse*)response;
    NSInteger statusCode = [HTTPResponse statusCode];
    NSError* jsonError = nil;
    NSMutableDictionary* innerJson;
    
    if (data != nil && [data length] > 0) {
        innerJson = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&jsonError];
        [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"network response (%@): %@", NSStringFromClass([request class]), innerJson]];
        if (jsonError) {
            if (failureBlock != nil)
                failureBlock([NSError errorWithDomain:@"OneSignal Error" code:statusCode userInfo:@{@"returned" : jsonError}]);
            return;
        }
    }
    
    if ([self willReattemptRequest:(int)statusCode withRequest:request success:successBlock failure:failureBlock asyncRequest:async])
        return;
    
    if (error == nil && (statusCode == 200 || statusCode == 202)) {
        if (successBlock != nil) {
            if (innerJson != nil)
                successBlock(innerJson);
            else
                successBlock(nil);
        }
    } else if (failureBlock != nil) {
        // Make sure to send all the infomation available to the client
        if (innerJson != nil && error != nil)
            failureBlock([NSError errorWithDomain:@"OneSignalError" code:statusCode userInfo:@{@"returned" : innerJson, @"error": error}]);
        else if (innerJson != nil)
            failureBlock([NSError errorWithDomain:@"OneSignalError" code:statusCode userInfo:@{@"returned" : innerJson}]);
        else if (error != nil)
            failureBlock([NSError errorWithDomain:@"OneSignalError" code:statusCode userInfo:@{@"error" : error}]);
        else
            failureBlock([NSError errorWithDomain:@"OneSignalError" code:statusCode userInfo:nil]);
    }
}

@end
