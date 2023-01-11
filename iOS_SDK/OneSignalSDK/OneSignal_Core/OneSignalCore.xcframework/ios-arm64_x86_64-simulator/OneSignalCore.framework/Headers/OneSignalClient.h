/**
 * Modified MIT License
 *
 * Copyright 2016 OneSignal
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

#import <Foundation/Foundation.h>
#import <OneSignalCore/OneSignalRequest.h>

#ifndef OneSignalClient_h
#define OneSignalClient_h

typedef void (^OSDataRequestSuccessBlock)(NSData *data);

typedef void (^OSMultipleCompletionBlock)(NSDictionary *responses);
typedef void (^OSMultipleFailureBlock)(NSDictionary<NSString *, NSError *> *errors);
typedef void (^OSMultipleSuccessBlock)(NSDictionary<NSString *, NSDictionary *> *results);

@interface OneSignalClient : NSObject
+ (OneSignalClient *)sharedClient;
- (void)executeRequest:(OneSignalRequest *)request onSuccess:(OSResultSuccessBlock)successBlock onFailure:(OSFailureBlock)failureBlock;
- (void)executeSynchronousRequest:(OneSignalRequest *)request onSuccess:(OSResultSuccessBlock)successBlock onFailure:(OSFailureBlock)failureBlock;

// ie. for loading HTML or other non-JSON based requests
- (void)executeDataRequest:(OneSignalRequest *)request onSuccess:(OSDataRequestSuccessBlock)successBlock onFailure:(OSFailureBlock)failureBlock;

// Executes multiple OneSignalRequest's simultaneously, needs a unique identifier for each request
- (void)executeSimultaneousRequests:(NSDictionary<NSString *, OneSignalRequest *> *)requests withSuccess:(OSMultipleSuccessBlock)successBlock onFailure:(OSMultipleFailureBlock)failureBlock;

/*
 TODO: We want to eventually migrate over to using this method for executing simultaneous requests:
  This allows us to combine multiple async concurrent requests to return from a single callback with the proper formatted responses from each reuqest (successful or not, account for params returning from GETs).
  A generalized format should be followed and we should make sure not to break form that as it could break peoples apps in the future if we add params and remove params from this callback.
  Currently for the only implementation this is used for "setExternalUserId:withCOmpletion:" the format is as follows:
  
     NSDictionary response = @{
        (required) @"push" : {
            @"success" : @(true) or @(false)
        },
        
        (optional) @"email" : {
            @"success" : @(true) or @(false)
        }
     }

 
  Building off of this format now will require:
 
    1. Including other attributes and whether they are required or not
        ex. @"push" is always going to be within the callback resposne (required), meanwhile,
            @"email" will not always exist in the callback resposne (optoinal)
    
    2. Can't remove params that are required as an app may be expecting them and removing/modifying a key could break there app with an SDK upgrade
    
    3. Add more requirements...
 
 */
- (void)executeSimultaneousRequests:(NSDictionary<NSString *, OneSignalRequest *> *)requests withCompletion:(OSMultipleCompletionBlock)completionBlock;
@end

#endif
