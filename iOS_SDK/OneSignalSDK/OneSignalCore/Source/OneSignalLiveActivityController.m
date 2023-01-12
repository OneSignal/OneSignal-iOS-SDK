//
//  OneSignalLiveActivityController.m
//  OneSignalCore
//
//  Created by Henry Boswell on 1/11/23.
//  Copyright © 2023 Hiptic. All rights reserved.
//

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

- (void)onOSPushSubscriptionChangedWithStateChanges:(OSPushSubscriptionStateChanges * _Nonnull)stateChanges {
    if(stateChanges.to.id){
        subscriptionId = OneSignalUserManagerImpl.sharedInstance.pushSubscriptionId;
        [OneSignalLiveActivityController executePendingLiveActivityUpdates];
    }
}

+ (void)enterLiveActivity:(NSString * _Nonnull)activityId appId:(NSString *)appId withToken:(NSString * _Nonnull)token withSuccess:(OSResultSuccessBlock _Nullable)successBlock withFailure:(OSFailureBlock _Nullable)failureBlock{
    
    if ([OSPrivacyConsentController shouldLogMissingPrivacyConsentErrorWithMethodName:@"enterLiveActivity:onSuccess:onFailure:"]) {
        if (failureBlock) {
            NSError *error = [NSError errorWithDomain:@"com.onesignal.tags" code:0 userInfo:@{@"error" : @"Your application has called enterLiveActivity:onSuccess:onFailure: before the user granted privacy permission. Please call `consentGranted(bool)` in order to provide user privacy consent"}];
            failureBlock(error);
        }
        return;
    }

    if(subscriptionId) {
        [OneSignalClient.sharedClient executeRequest:[OSRequestLiveActivityEnter withUserId:subscriptionId appId:appId activityId:activityId token:token]
                                           onSuccess:^(NSDictionary *result) {
            [self callSuccessBlockOnMainThread:successBlock withResult:result];
        } onFailure:^(NSError *error) {
            [self callFailureBlockOnMainThread:failureBlock withError:error];
        }];
    } else {
        [self addPendingLiveActivityUpdate:activityId appId:appId withToken:token isEnter:true withSuccess:successBlock withFailure:failureBlock];
    }
}

+ (void)exitLiveActivity:(NSString * _Nonnull)activityId appId:(NSString *)appId withSuccess:(OSResultSuccessBlock _Nullable)successBlock withFailure:(OSFailureBlock _Nullable)failureBlock{

    if ([OSPrivacyConsentController shouldLogMissingPrivacyConsentErrorWithMethodName:@"exitLiveActivity:onSuccess:onFailure:"]) {
        if (failureBlock) {
            NSError *error = [NSError errorWithDomain:@"com.onesignal.tags" code:0 userInfo:@{@"error" : @"Your application has called exitLiveActivity:onSuccess:onFailure: before the user granted privacy permission. Please call `consentGranted(bool)` in order to provide user privacy consent"}];
            failureBlock(error);
        }
        return;
    }
    
    if(subscriptionId) {
        [OneSignalClient.sharedClient executeRequest:[OSRequestLiveActivityExit withUserId:subscriptionId appId:appId activityId:activityId]
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
    OSPendingLiveActivityUpdate *pendingLiveActivityUpdate = [[OSPendingLiveActivityUpdate alloc] initWith:activityId appId:appId withToken:token isEnter:isEnter withSuccess:successBlock withFailure:failureBlock];
    
    if (!pendingLiveActivityUpdates) {
        pendingLiveActivityUpdates = [NSMutableArray new];
    }
    [pendingLiveActivityUpdates addObject:pendingLiveActivityUpdate];
}

+ (void)executePendingLiveActivityUpdates {
    subscriptionId =  OneSignalUserManagerImpl.sharedInstance.pushSubscriptionId;
    if(pendingLiveActivityUpdates.count <= 0) {
        return;
    }
    
    OSPendingLiveActivityUpdate * updateToProcess = [pendingLiveActivityUpdates objectAtIndex:0];
    [pendingLiveActivityUpdates removeObjectAtIndex: 0];
    if (updateToProcess.isEnter) {
        [OneSignalClient.sharedClient executeRequest:[OSRequestLiveActivityEnter withUserId:subscriptionId appId:updateToProcess.appId activityId:updateToProcess.activityId token:updateToProcess.token]
                                           onSuccess:^(NSDictionary *result) {
            [self callSuccessBlockOnMainThread:updateToProcess.successBlock withResult:result];
            [self executePendingLiveActivityUpdates];
        } onFailure:^(NSError *error) {
            [self callFailureBlockOnMainThread:updateToProcess.failureBlock withError:error];
            [self executePendingLiveActivityUpdates];
        }];
    } else {
        [OneSignalClient.sharedClient executeRequest:[OSRequestLiveActivityExit withUserId:subscriptionId appId:updateToProcess.appId activityId:updateToProcess.activityId]
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
