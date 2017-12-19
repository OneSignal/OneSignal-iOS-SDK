//
//  OneSignalClient.m
//  OneSignal
//
//  Created by Brad Hesse on 12/19/17.
//  Copyright © 2017 Hiptic. All rights reserved.
//

#import "OneSignalClient.h"
#import "UIApplicationDelegate+OneSignal.h"

@implementation OneSignalClient

+ (OneSignalClient *)sharedClient {
    static OneSignalClient *sharedClient = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        sharedClient = [OneSignalClient new];
    });
    return sharedClient;
}

- (void)executeRequest:(OneSignalRequest *)request onSuccess:(OSResultSuccessBlock)successBlock onFailure:(OSFailureBlock)failureBlock {
    if (!request.hasAppId) {
        [OneSignal onesignal_Log:ONE_S_LL_DEBUG message:@"HTTP Requests must contain app_id parameter"];
        return;
    }
    
    let sess = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    
    let task = [sess dataTaskWithRequest:request.request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        [OneSignalHelper handleJSONNSURLResponse:response data:data error:error onSuccess:successBlock onFailure:failureBlock];
        
        if (error || ((NSHTTPURLResponse *)response).statusCode > 300) {
            NSLog(@"Request with subclass name %@ failed with error: %@ with status code: %i", NSStringFromClass([request class]), error, (int)((NSHTTPURLResponse *)response).statusCode);
        }
    }];
    
    [task resume];
}

- (void)executeSynchronousRequest:(OneSignalRequest *)request onSuccess:(OSResultSuccessBlock)successBlock onFailure:(OSFailureBlock)failureBlock {
    if (!request.hasAppId) {
        [OneSignal onesignal_Log:ONE_S_LL_DEBUG message:@"HTTP Requests must contain app_id parameter"];
        return;
    }
    
    let sess = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    
    __block NSURLResponse *httpResponse;
    __block NSError *httpError;
    
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    let dataTask = [sess dataTaskWithRequest:request.request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        httpResponse = response;
        httpError = error;
        
        dispatch_semaphore_signal(semaphore);
    }];
    
    [dataTask resume];
    
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    
    [OneSignalHelper handleJSONNSURLResponse:httpResponse data:nil error:httpError onSuccess:successBlock onFailure:failureBlock];
}

@end
