//
//  OneSignalHelper.h
//  OneSignal
//
//  Created by Joseph Kalash on 7/27/16.
//  Copyright © 2016 Hiptic. All rights reserved.
//

#import "OneSignal.h"

@interface OneSignalHelper : NSObject

// - Web
+ (void) displayWebView:(NSURL*)url;

// - Notification Opened
+ (NSString*)getPushBody;
+ (NSDictionary*)getAdditionalData;
+ (void)handleNotification;
+ (void)lastMessageReceived:(NSDictionary*)message;
+ (void)notificationBlock:(OSHandleNotificationBlock)block;

// - Notifications
+ (NSArray*)getSoundFiles;
+ (BOOL) isCapableOfGettingNotificationTypes;
+ (UILocalNotification*)prepareUILocalNotification:(NSDictionary*)data :(NSDictionary*)userInfo;
+ (id)prepareUNNotificationRequest:(NSDictionary *)data :(NSDictionary *)userInfo;
+ (BOOL)verifyURL:(NSString *)urlString;

// - Networking
+ (NSNumber*)getNetType;
+ (void)enqueueRequest:(NSURLRequest*)request onSuccess:(OSResultSuccessBlock)successBlock onFailure:(OSFailureBlock)failureBlock;
+ (void)enqueueRequest:(NSURLRequest*)request onSuccess:(OSResultSuccessBlock)successBlock onFailure:(OSFailureBlock)failureBlock isSynchronous:(BOOL)isSynchronous;
+ (void)handleJSONNSURLResponse:(NSURLResponse*) response data:(NSData*) data error:(NSError*) error onSuccess:(OSResultSuccessBlock)successBlock onFailure:(OSFailureBlock)failureBlock;


@end
