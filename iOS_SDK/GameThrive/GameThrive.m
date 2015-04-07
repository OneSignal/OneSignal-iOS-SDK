/**
 * Modified MIT License
 *
 * Copyright 2015 OneSignal
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

#import "OneSignal.h"
#import "GameThrive.h"

NSString* const GT_VERSION = @"010700";

static GameThrive* defaultClient = nil;

@interface GameThrive ()

@end

@implementation GameThrive

OneSignal* oneSignal;

- (id)initWithLaunchOptions:(NSDictionary*)launchOptions {
    return [self initWithLaunchOptions:launchOptions appId:nil handleNotification:nil autoRegister:true];
}

- (id)initWithLaunchOptions:(NSDictionary*)launchOptions autoRegister:(BOOL)autoRegister {
    return [self initWithLaunchOptions:launchOptions appId:nil handleNotification:nil autoRegister:autoRegister];
}

- (id)initWithLaunchOptions:(NSDictionary*)launchOptions handleNotification:(GTHandleNotificationBlock)callback {
    return [self initWithLaunchOptions:launchOptions appId:nil handleNotification:callback autoRegister:true];
}

- (id)initWithLaunchOptions:(NSDictionary*)launchOptions appId:(NSString*)appId handleNotification:(GTHandleNotificationBlock)callback {
    return [self initWithLaunchOptions:launchOptions appId:appId handleNotification:callback autoRegister:true];
}

- (id)initWithLaunchOptions:(NSDictionary*)launchOptions appId:(NSString*)appId handleNotification:(GTHandleNotificationBlock)callback autoRegister:(BOOL)autoRegister {
    self = [super init];
    
    oneSignal = [[OneSignal alloc] initWithLaunchOptions:launchOptions appId:appId handleNotification:callback autoRegister:autoRegister];
    
    return self;
}

- (void)registerForPushNotifications {
    [oneSignal registerForPushNotifications];
}

- (void)IdsAvailable:(GTIdsAvailableBlock)idsAvailableBlock {
    [oneSignal IdsAvailable:idsAvailableBlock];
}

- (void)sendTagsWithJsonString:(NSString*)jsonString {
    [oneSignal sendTagsWithJsonString:jsonString];
}

- (void)sendTags:(NSDictionary*)keyValuePair {
    [oneSignal sendTags:keyValuePair onSuccess:nil onFailure:nil];
}

- (void)sendTags:(NSDictionary*)keyValuePair onSuccess:(GTResultSuccessBlock)successBlock onFailure:(GTFailureBlock)failureBlock {
    [oneSignal sendTags:keyValuePair onSuccess:successBlock onFailure:failureBlock];
}

- (void)sendTag:(NSString*)key value:(NSString*)value {
    [oneSignal sendTag:key value:value onSuccess:nil onFailure:nil];
}

- (void)sendTag:(NSString*)key value:(NSString*)value onSuccess:(GTResultSuccessBlock)successBlock onFailure:(GTFailureBlock)failureBlock {
    [oneSignal sendTags:[NSDictionary dictionaryWithObjectsAndKeys: value, key, nil] onSuccess:successBlock onFailure:failureBlock];
}

- (void)getTags:(GTResultSuccessBlock)successBlock onFailure:(GTFailureBlock)failureBlock {
    [oneSignal getTags:successBlock onFailure:failureBlock];
}

- (void)getTags:(GTResultSuccessBlock)successBlock {
    [oneSignal getTags:successBlock onFailure:nil];
}


- (void)deleteTag:(NSString*)key onSuccess:(GTResultSuccessBlock)successBlock onFailure:(GTFailureBlock)failureBlock {
    [oneSignal deleteTags:@[key] onSuccess:successBlock onFailure:failureBlock];
}

- (void)deleteTag:(NSString*)key {
    [oneSignal deleteTags:@[key] onSuccess:nil onFailure:nil];
}

- (void)deleteTags:(NSArray*)keys onSuccess:(GTResultSuccessBlock)successBlock onFailure:(GTFailureBlock)failureBlock {
    [oneSignal deleteTags:keys onSuccess:successBlock onFailure:failureBlock];
}

- (void)deleteTags:(NSArray*)keys {
    [oneSignal deleteTags:keys onSuccess:nil onFailure:nil];
}

- (void)deleteTagsWithJsonString:(NSString*)jsonString {
    [oneSignal deleteTagsWithJsonString:jsonString];
}

- (void)sendPurchase:(NSNumber*)amount onSuccess:(GTResultSuccessBlock)successBlock onFailure:(GTFailureBlock)failureBlock {
    NSLog(@"sendPurchase is deprecated as this is now automatic for Apple IAP purchases. The method does nothing!");
}

- (void)sendPurchase:(NSNumber*)amount {
    NSLog(@"sendPurchase is deprecated as this is now automatic for Apple IAP purchases. The method does nothing!");
}

+ (void)setDefaultClient:(GameThrive *)client {
    defaultClient = client;
}

+ (GameThrive *)defaultClient {
    return defaultClient;
}

@end