/**
 * Modified MIT License
 *
 * Copyright 2023 OneSignal
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
#import <OneSignalCore/OneSignalCore.h>
#import "OneSignalLiveActivityController.h"

@interface OSPendingLiveActivityUpdate: NSObject
    @property NSString* activityId;
    @property NSString* appId;
    @property NSString* token;
    @property BOOL isEnter;
    @property OSResultSuccessBlock successBlock;
    @property OSFailureBlock failureBlock;
    - (id)initWith:(NSString * _Nonnull)activityId
         appId:(NSString * _Nonnull)appId
         withToken:(NSString * _Nonnull)token
           isEnter:(BOOL)isEnter
       withSuccess:(OSResultSuccessBlock _Nullable)successBlock
       withFailure:(OSFailureBlock _Nullable)failureBlock;
@end

@implementation OSPendingLiveActivityUpdate

- (id)initWith:(NSString * _Nonnull)activityId
         appId:(NSString * _Nonnull)appId
     withToken:(NSString *)token
       isEnter:(BOOL)isEnter
   withSuccess:(OSResultSuccessBlock)successBlock
   withFailure:(OSFailureBlock)failureBlock {
    self.token = token;
    self.activityId = activityId;
    self.appId = appId;
    self.isEnter = isEnter;
    self.successBlock = successBlock;
    self.failureBlock = failureBlock;
    return self;
};
@end

@implementation OneSignalLiveActivityController

static NSMutableArray* pendingLiveActivityUpdates;
static NSString* subscriptionId;

static OneSignalLiveActivityController *sharedInstance = nil;
static dispatch_once_t once;
+ (OneSignalLiveActivityController *)sharedInstance {
    dispatch_once(&once, ^{
        sharedInstance = [OneSignalLiveActivityController new];
    });
    return sharedInstance;
}

+ (Class<OSLiveActivities>)LiveActivities {
    return self;
}

+ (void)initialize {
    subscriptionId = OneSignalUserManagerImpl.sharedInstance.pushSubscriptionId;
    OneSignalLiveActivityController *shared = OneSignalLiveActivityController.sharedInstance;
    [OneSignalUserManagerImpl.sharedInstance addObserver:shared];
}

- (void)onPushSubscriptionDidChangeWithState:(OSPushSubscriptionChangedState * _Nonnull)state {
    if(state.current.id){
        subscriptionId = OneSignalUserManagerImpl.sharedInstance.pushSubscriptionId;
        [OneSignalLiveActivityController executePendingLiveActivityUpdates];
    }
}

+ (void)enter:(NSString * _Nonnull)activityId withToken:(NSString * _Nonnull)token {
    
    if ([OSPrivacyConsentController shouldLogMissingPrivacyConsentErrorWithMethodName:@"enterLiveActivity:"])
        return;
    
    [self enter:activityId withToken:token withSuccess:nil withFailure:nil];
}

+ (void)enter:(NSString * _Nonnull)activityId withToken:(NSString * _Nonnull)token withSuccess:(OSResultSuccessBlock _Nullable)successBlock withFailure:(OSFailureBlock _Nullable)failureBlock{
    
    if ([OSPrivacyConsentController shouldLogMissingPrivacyConsentErrorWithMethodName:@"enterLiveActivity:onSuccess:onFailure:"]) {
        if (failureBlock) {
            NSError *error = [NSError errorWithDomain:@"OneSignal.LiveActivities" code:0 userInfo:@{@"error" : @"Your application has called enterLiveActivity:onSuccess:onFailure: before the user granted privacy permission. Please call `consentGranted(bool)` in order to provide user privacy consent"}];
            failureBlock(error);
        }
        return;
    }
    
    [self enterLiveActivity:activityId appId:[OneSignalConfigManager getAppId] withToken:token withSuccess: successBlock withFailure: failureBlock];
}

+ (void)enterLiveActivity:(NSString * _Nonnull)activityId appId:(NSString *)appId withToken:(NSString * _Nonnull)token withSuccess:(OSResultSuccessBlock _Nullable)successBlock withFailure:(OSFailureBlock _Nullable)failureBlock{
    [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"enterLiveActivity called with activityId: %@ token: %@", activityId, token]];
    
    if ([OSPrivacyConsentController shouldLogMissingPrivacyConsentErrorWithMethodName:@"enterLiveActivity:onSuccess:onFailure:"]) {
        if (failureBlock) {
            NSError *error = [NSError errorWithDomain:@"OneSignal.LiveActivities" code:0 userInfo:@{@"error" : @"Your application has called enterLiveActivity:onSuccess:onFailure: before the user granted privacy permission. Please call `consentGranted(bool)` in order to provide user privacy consent"}];
            failureBlock(error);
        }
        return;
    }

    if(subscriptionId) {
        [OneSignalClient.sharedClient executeRequest:[OSRequestLiveActivityEnter withSubscriptionId:subscriptionId appId:appId activityId:activityId token:token]
                                           onSuccess:^(NSDictionary *result) {
            [self callSuccessBlockOnMainThread:successBlock withResult:result];
        } onFailure:^(NSError *error) {
            [self callFailureBlockOnMainThread:failureBlock withError:error];
        }];
    } else {
        [self addPendingLiveActivityUpdate:activityId appId:appId withToken:token isEnter:true withSuccess:successBlock withFailure:failureBlock];
    }
}

+ (void)exit:(NSString * _Nonnull)activityId{
    
    if ([OSPrivacyConsentController shouldLogMissingPrivacyConsentErrorWithMethodName:@"enterLiveActivity:"])
        return;
    
    [self exit:activityId withSuccess:nil withFailure:nil];
}

+ (void)exit:(NSString * _Nonnull)activityId withSuccess:(OSResultSuccessBlock _Nullable)successBlock withFailure:(OSFailureBlock _Nullable)failureBlock{

    if ([OSPrivacyConsentController shouldLogMissingPrivacyConsentErrorWithMethodName:@"exitLiveActivity:onSuccess:onFailure:"]) {
        if (failureBlock) {
            NSError *error = [NSError errorWithDomain:@"OneSignal.LiveActivities" code:0 userInfo:@{@"error" : @"Your application has called exitLiveActivity:onSuccess:onFailure: before the user granted privacy permission. Please call `consentGranted(bool)` in order to provide user privacy consent"}];
            failureBlock(error);
        }
        return;
    }
    
    [self exitLiveActivity:activityId appId:[OneSignalConfigManager getAppId] withSuccess: successBlock withFailure: failureBlock];
}

+ (void)exitLiveActivity:(NSString * _Nonnull)activityId appId:(NSString *)appId withSuccess:(OSResultSuccessBlock _Nullable)successBlock withFailure:(OSFailureBlock _Nullable)failureBlock{
    [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"exitLiveActivity called with activityId: %@", activityId]];
    if ([OSPrivacyConsentController shouldLogMissingPrivacyConsentErrorWithMethodName:@"exitLiveActivity:onSuccess:onFailure:"]) {
        if (failureBlock) {
            NSError *error = [NSError errorWithDomain:@"OneSignal.LiveActivities" code:0 userInfo:@{@"error" : @"Your application has called exitLiveActivity:onSuccess:onFailure: before the user granted privacy permission. Please call `consentGranted(bool)` in order to provide user privacy consent"}];
            failureBlock(error);
        }
        return;
    }
    
    if(subscriptionId) {
        [OneSignalClient.sharedClient executeRequest:[OSRequestLiveActivityExit withSubscriptionId:subscriptionId appId:appId activityId:activityId]
                                           onSuccess:^(NSDictionary *result) {
            [self callSuccessBlockOnMainThread:successBlock withResult:result];
        } onFailure:^(NSError *error) {
            [self callFailureBlockOnMainThread:failureBlock withError:error];
        }];
    } else {
        [self addPendingLiveActivityUpdate:activityId appId:appId withToken:nil isEnter:false  withSuccess:successBlock withFailure:failureBlock];
    }
}

+ (void)callFailureBlockOnMainThread:(OSFailureBlock)failureBlock withError:(NSError *)error {
    if (failureBlock) {
        dispatch_async(dispatch_get_main_queue(), ^{
            failureBlock(error);
        });
    }
}

+ (void)callSuccessBlockOnMainThread:(OSResultSuccessBlock)successBlock withResult:(NSDictionary *)result{
    if (successBlock) {
        dispatch_async(dispatch_get_main_queue(), ^{
            successBlock(result);
        });
    }
}

+ (void)addPendingLiveActivityUpdate:(NSString * _Nonnull)activityId
                               appId:(NSString * _Nonnull)appId
                           withToken:(NSString * _Nullable)token
                             isEnter:(BOOL)isEnter
                         withSuccess:(OSResultSuccessBlock _Nullable)successBlock
                         withFailure:(OSFailureBlock _Nullable)failureBlock {
    [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"addPendingLiveActivityUpdate called with activityId: %@", activityId]];
    OSPendingLiveActivityUpdate *pendingLiveActivityUpdate = [[OSPendingLiveActivityUpdate alloc] initWith:activityId appId:appId withToken:token isEnter:isEnter withSuccess:successBlock withFailure:failureBlock];
    
    if (!pendingLiveActivityUpdates) {
        pendingLiveActivityUpdates = [NSMutableArray new];
    }
    [pendingLiveActivityUpdates addObject:pendingLiveActivityUpdate];
}

+ (void)executePendingLiveActivityUpdates {
    subscriptionId =  OneSignalUserManagerImpl.sharedInstance.pushSubscriptionId;
    [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"executePendingLiveActivityUpdates called with subscriptionId: %@", subscriptionId]];
    if(pendingLiveActivityUpdates.count <= 0) {
        return;
    }
    
    OSPendingLiveActivityUpdate * updateToProcess = [pendingLiveActivityUpdates objectAtIndex:0];
    [pendingLiveActivityUpdates removeObjectAtIndex: 0];
    if (updateToProcess.isEnter) {
        [OneSignalClient.sharedClient executeRequest:[OSRequestLiveActivityEnter withSubscriptionId:subscriptionId appId:updateToProcess.appId activityId:updateToProcess.activityId token:updateToProcess.token]
                                           onSuccess:^(NSDictionary *result) {
            [self callSuccessBlockOnMainThread:updateToProcess.successBlock withResult:result];
            [self executePendingLiveActivityUpdates];
        } onFailure:^(NSError *error) {
            [self callFailureBlockOnMainThread:updateToProcess.failureBlock withError:error];
            [self executePendingLiveActivityUpdates];
        }];
    } else {
        [OneSignalClient.sharedClient executeRequest:[OSRequestLiveActivityExit withSubscriptionId:subscriptionId appId:updateToProcess.appId activityId:updateToProcess.activityId]
                                           onSuccess:^(NSDictionary *result) {
            [self callSuccessBlockOnMainThread:updateToProcess.successBlock withResult:result];
            [self executePendingLiveActivityUpdates];
        } onFailure:^(NSError *error) {
            [self callFailureBlockOnMainThread:updateToProcess.failureBlock withError:error];
            [self executePendingLiveActivityUpdates];
        }];
    }
}
@end
