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
#import "OSPrivacyConsentController.h"

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
    configuration.timeoutIntervalForRequest = REQUEST_TIMEOUT_REQUEST; // TODO: Are these anything?
    configuration.timeoutIntervalForResource = REQUEST_TIMEOUT_RESOURCE; // TODO: Are these anything?
    
    //prevent caching of requests, this mainly impacts OSRequestGetIosParams,
    //since the OSRequestGetTags endpoint has a caching header policy
    configuration.requestCachePolicy = policy;
    
    return configuration;
}

- (OneSignalClientError *)privacyConsentErrorWithRequestType:(NSString *)type {
    return [[OneSignalClientError alloc] initWithCode:0 message:[NSString stringWithFormat: @"Attempted to perform an HTTP request (%@) before the user provided privacy consent.", type] responseHeaders:nil response:nil underlyingError:nil];
}

- (void)executeRequest:(OneSignalRequest *)request onSuccess:(OSResultSuccessBlock)successBlock onFailure:(OSClientFailureBlock)failureBlock {
    // If privacy consent is required but not yet given, any non-GET request should be blocked.
    if (request.method != GET && [OSPrivacyConsentController shouldLogMissingPrivacyConsentErrorWithMethodName:nil]) {
        [OneSignalLog onesignalLog:ONE_S_LL_ERROR message:@"Attempted to perform an HTTP request (%@) before the user provided privacy consent."];
        if (failureBlock) {
            failureBlock([self privacyConsentErrorWithRequestType:NSStringFromClass(request.class)]);
        }
        
        return;
    }
    
    if (request.dataRequest) {
        if (failureBlock) {
            failureBlock([[OneSignalClientError alloc] initWithCode:0 message:[NSString stringWithFormat:@"Attempted to execute a data-only API request (%@) using OneSignalClient's executeRequest: method, which only accepts JSON-based API requests", NSStringFromClass(request.class)] responseHeaders:nil response:nil underlyingError:nil]);
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

- (void)handleMissingAppIdError:(OSClientFailureBlock)failureBlock withRequest:(OneSignalRequest *)request {
    NSString *errorDescription = [NSString stringWithFormat:@"HTTP Request (%@) must contain app_id parameter", NSStringFromClass([request class])];
    
    [OneSignalLog onesignalLog:ONE_S_LL_ERROR message:errorDescription];
    
    if (failureBlock)
        failureBlock([[OneSignalClientError alloc] initWithCode:-1 message:errorDescription responseHeaders:nil response:nil underlyingError:nil]);
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

- (BOOL)willReattemptRequest:(int)statusCode withRequest:(OneSignalRequest *)request success:(OSResultSuccessBlock)successBlock failure:(OSClientFailureBlock)failureBlock asyncRequest:(BOOL)async {
    // in the event that there is no network connection, NSURLSession will return status code 0
    if ((statusCode >= 500 || statusCode == 0) && request.reattemptCount < MAX_ATTEMPT_COUNT - 1) {
        OSReattemptRequest *reattempt = [OSReattemptRequest withRequest:request successBlock:successBlock failureBlock:failureBlock];
        
        if (async) {
            //retry again in an increasing interval calculated with reattemptDelay
            double reattemptDelay = [self calculateReattemptDelay:request.reattemptCount];
            [OneSignalLog onesignalLog:ONE_S_LL_DEBUG message:[NSString stringWithFormat:@"Re-scheduling request (%@) to be re-attempted in %.3f seconds due to failed HTTP request with status code %i", NSStringFromClass([request class]), reattemptDelay, (int)statusCode]];
            [OneSignalCoreHelper dispatch_async_on_main_queue:^{
                [self performSelector:@selector(reattemptRequest:) withObject:reattempt afterDelay:reattemptDelay];
            }];
        } else {
            //retry again immediately
            [self reattemptRequest: reattempt];
        }
        
        return true;
    }
    
    return false;
}

// A request will retry with intervals of 5, 15 , 45, 135 seconds...
- (double)calculateReattemptDelay:(int)reattemptCount {
    return REATTEMPT_DELAY * pow(3, reattemptCount);
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

    [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"HTTP Request (%@) with URL: %@, with parameters: %@ and headers: %@", NSStringFromClass([request class]), request.urlRequest.URL.absoluteString, jsonString, request.additionalHeaders]];
}

- (void)handleJSONNSURLResponse:(NSURLResponse*)response data:(NSData*)data error:(NSError*)error isAsync:(BOOL)async withRequest:(OneSignalRequest *)request onSuccess:(OSResultSuccessBlock)successBlock onFailure:(OSClientFailureBlock)failureBlock {
    
    NSHTTPURLResponse* HTTPResponse = (NSHTTPURLResponse*)response;
    NSInteger statusCode = [HTTPResponse statusCode];
    NSDictionary *headers = [HTTPResponse allHeaderFields]; // can be null
    NSError* jsonError = nil;
    NSMutableDictionary* innerJson;
    
    if (data != nil && [data length] > 0) {
        innerJson = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&jsonError];
        innerJson[@"httpStatusCode"] = [NSNumber numberWithLong:statusCode];
        innerJson[@"headers"] = headers;
        
        [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"network request (%@) with URL %@ and headers: %@", NSStringFromClass([request class]), request.urlRequest.URL.absoluteString, request.additionalHeaders]];

        [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"network response (%@) with URL %@: %@", NSStringFromClass([request class]), request.urlRequest.URL.absoluteString, innerJson]];
        if (jsonError) {
            if (failureBlock != nil)
                failureBlock([[OneSignalClientError alloc] initWithCode:statusCode message:@"Error parsing JSON" responseHeaders:headers response:nil underlyingError:jsonError]);
            return;
        }
    }
    
    if ([self willReattemptRequest:(int)statusCode withRequest:request success:successBlock failure:failureBlock asyncRequest:async])
        return;
    
    if (error == nil && (statusCode == 200 || statusCode == 201 || statusCode == 202)) {
        if (successBlock != nil) {
            if (innerJson != nil)
                successBlock(innerJson);
            else
                successBlock(nil);
        }
    } else if (failureBlock != nil) {
        // Make sure to send all the infomation available to the client
        failureBlock([[OneSignalClientError alloc] initWithCode:statusCode message:@"Error encountered making request" responseHeaders:headers response:innerJson underlyingError:error]);
    }
}


@end
