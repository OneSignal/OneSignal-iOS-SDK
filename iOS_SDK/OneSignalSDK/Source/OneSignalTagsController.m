/**
 * Modified MIT License
 *
 * Copyright 2018 OneSignal
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

#import "OneSignalTagsController.h"
#import "OneSignalCommonDefines.h"
#import "Requests.h"
#import "OneSignalClient.h"
#import "OneSignalHelper.h"
#import "OSEmailSubscription.h"
#import "OSPendingCallbacks.h"

@interface OneSignal (OSTags)
+ (OSEmailSubscriptionState *)currentEmailSubscriptionState;
+ (OSSubscriptionState *)currentSubscriptionState;
+ (NSString *)app_id;
@end


@interface OneSignalTagsController ()
@property (strong, nonatomic, nullable) NSMutableDictionary *pending;
@property (strong, nonatomic, nonnull) NSMutableArray<OSPendingCallbacks *> *pendingCallbacks;
@property (strong, nonatomic, nonnull) NSMutableArray<OSPendingCallbacks *> *inFlightCallbacks;

@property (nonatomic, nonnull) dispatch_queue_t tagsQueue;
@property (atomic) BOOL scheduled;
@end

@implementation OneSignalTagsController

+ (OneSignalTagsController * _Nonnull)sharedInstance {
    static OneSignalTagsController *sharedInstance = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        sharedInstance = [OneSignalTagsController new];
    });
    return sharedInstance;
}

- (instancetype _Nonnull)init {
    if (self = [super init]) {
        self.tagsQueue = dispatch_queue_create("com.onesignal.tags_queue", NULL);
        self.pendingCallbacks = [NSMutableArray new];
    }
    
    return self;
}

/*
    Batches sendTags requests, for a maximum rate of one API request every 5 seconds.
 
*/
- (void)sendTags:(NSDictionary * _Nonnull)tags successHandler:(OSResultSuccessBlock _Nullable)success failureHandler:(OSFailureBlock _Nullable)failure {
    //no need to initiate a request based on an empty tags object
    if (tags.count == 0)
        return;
    
    //create a copy of tags to prevent mutation/race condition issues
    let tagsCopy = (NSDictionary *)[tags copy];
    
    dispatch_async(self.tagsQueue, ^{
        //check for invalid tags
        if (![self mergeValidTags:tagsCopy])
            return;
        
        [self addCallbacksToQueueWithSuccessHandler:success failureHandler:failure];
        
        if (self.scheduled)
            return;
        
        self.scheduled = true;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(SEND_TAGS_DELAY * NSEC_PER_SEC)), self.tagsQueue, ^{
            self.scheduled = false;
            [self synchronize];
        });
    });
}

- (void)deleteTags:(NSArray<NSString *> *)keys successHandler:(OSResultSuccessBlock _Nullable)success failureHandler:(OSFailureBlock _Nullable)failure {
    let tags = [NSMutableDictionary new];
    
    //setting to empty string removes the value
    for (NSString *key in keys)
        tags[key] = @"";
    
    [self sendTags:tags successHandler:success failureHandler:failure];
}

/*
    Always called on the tagsQueue
    Returns false if the tags were invalid. Results in tags not being sent.
    Otherwise, the method returns true and the tags were successfully merged.
*/
- (BOOL)mergeValidTags:(NSDictionary * _Nonnull)tags {
    if (![NSJSONSerialization isValidJSONObject:tags]) {
        [OneSignal onesignal_Log:ONE_S_LL_WARN message:[NSString stringWithFormat:@"sendTags JSON invalid: The following key/value pairs you attempted to send as tags are not valid JSON: %@", tags]];
        return false;
    }
    
    for (NSString *key in tags.allKeys) {
        if ([tags[key] isKindOfClass:[NSDictionary class]]) {
            [OneSignal onesignal_Log:ONE_S_LL_WARN message:@"sendTags JSON must not contain nested objects."];
            return false;
        }
    }
    
    if (self.pending)
        [self.pending addEntriesFromDictionary:tags];
    else
        self.pending = [tags mutableCopy];
    
    return true;
}

//always called on the tagsQueue
- (void)addCallbacksToQueueWithSuccessHandler:(OSResultSuccessBlock _Nullable)success failureHandler:(OSFailureBlock _Nullable)failure {
    if (!success && !failure)
        return;
    
    [self.pendingCallbacks addObject:[[OSPendingCallbacks alloc] initWithSuccessHandler:success failureHandler:failure]];
}

//always called on the tagsQueue
- (void)synchronize {
    if (!self.hasPendingTags)
        return;
    
    let tagsToSend = [self prepareToSendTags];
    
    let emailState = OneSignal.currentEmailSubscriptionState;
    
    // generate the HTTP request, potentially two if there is also an email subscription
    let requests = [NSMutableDictionary new];
    
    requests[@"push"] = [OSRequestSendTagsToServer withUserId:OneSignal.currentSubscriptionState.userId appId:OneSignal.app_id tags:tagsToSend networkType:[OneSignalHelper getNetType] withEmailAuthHashToken:nil];
    
    if (emailState.emailUserId && (!emailState.requiresEmailAuth || emailState.emailAuthCode))
        requests[@"email"] = [OSRequestSendTagsToServer withUserId:emailState.emailUserId appId:OneSignal.app_id tags:tagsToSend networkType:[OneSignalHelper getNetType] withEmailAuthHashToken:emailState.emailAuthCode];
    
    [OneSignalClient.sharedClient executeSimultaneousRequests:requests withSuccess:^(NSDictionary<NSString *,NSDictionary *> *results) {
        var result = results[@"push"] ?: results[@"email"];
        
        [self successfullySentTagsWithResults:result];
    } onFailure:^(NSDictionary<NSString *,NSError *> *errors) {
        var error = errors[@"push"] ?: errors[@"email"];
        
        [self failedToSendTagsWithError:error];
    }];
}

#pragma mark External Methods
- (BOOL)hasPendingTags {
    return self.pending && self.pending.count > 0;
}

/*
    Called before initiating an HTTP request to send tags
    (either here in the Tags Controller, or in the OneSignal
    registration method).
*/
- (NSDictionary * _Nullable)prepareToSendTags {
    let pendingTags = (NSDictionary *)[self.pending copy];
    self.pending = nil;
    
    self.inFlightCallbacks = self.pendingCallbacks;
    self.pendingCallbacks = [NSMutableArray new];
    
    return pendingTags;
}

/*
    OneSignal can also send tags during registration. The following methods
    tell the tags controller if the request was successful or not, and call
    any pending callbacks. For simplicity, the tags controller also calls
    these methods after finishing an HTTP request
*/
- (void)successfullySentTagsWithResults:(NSDictionary *)result {
    if (self.inFlightCallbacks && self.inFlightCallbacks.count > 0)
        for (OSPendingCallbacks *set in self.inFlightCallbacks)
            if (set.successBlock)
                set.successBlock(result);
    
    [self.inFlightCallbacks removeAllObjects];
}

- (void)failedToSendTagsWithError:(NSError *)error {
    if (self.inFlightCallbacks && self.inFlightCallbacks.count > 0)
        for (OSPendingCallbacks *set in self.inFlightCallbacks)
            if (set.failureBlock)
                set.failureBlock(error);
    
    [self.inFlightCallbacks removeAllObjects];
}

@end
