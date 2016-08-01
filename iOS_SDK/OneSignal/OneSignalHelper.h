//
//  OneSignalHelper.h
//  OneSignal
//
//  Created by Joseph Kalash on 7/27/16.
//  Copyright © 2016 Hiptic. All rights reserved.
//

#import "OneSignal.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@interface OneSignalHelper : NSObject

// - Web
+ (void) displayWebView:(NSURL*)url;

// - Notification Opened
+ (NSArray<NSString*>*)getPushTitleBody:(NSDictionary*)messageDict;
+ (NSArray*)getActionButtons;
+ (void)lastMessageReceived:(NSDictionary*)message;
+ (void)notificationBlocks:(OSHandleNotificationReceivedBlock)receivedBlock :(OSHandleNotificationActionBlock)actionBlock;
+ (void)handleNotificationReceived:(OSNotificationDisplayType)displayType;
+ (void)handleNotificationAction:(OSNotificationActionType)actionType actionID:(NSString*)actionID displayType:(OSNotificationDisplayType)displayType;

// - iOS 10
+ (void) requestAuthorization;
+ (void)conformsToUNProtocol;
+ (void)registerAsUNNotificationCenterDelegate;
+ (void)clearCachedMedia;

// - Notifications
+ (BOOL) isCapableOfGettingNotificationTypes;
+ (UILocalNotification*)prepareUILocalNotification:(NSDictionary*)data :(NSDictionary*)userInfo;
+ (id)prepareUNNotificationRequest:(NSDictionary *)data :(NSDictionary *)userInfo;
+ (BOOL)verifyURL:(NSString *)urlString;
+ (BOOL) isRemoteSilentNotification:(NSDictionary*)msg;

// - Networking
+ (NSNumber*)getNetType;
+ (void)enqueueRequest:(NSURLRequest*)request onSuccess:(OSResultSuccessBlock)successBlock onFailure:(OSFailureBlock)failureBlock;
+ (void)enqueueRequest:(NSURLRequest*)request onSuccess:(OSResultSuccessBlock)successBlock onFailure:(OSFailureBlock)failureBlock isSynchronous:(BOOL)isSynchronous;
+ (void)handleJSONNSURLResponse:(NSURLResponse*) response data:(NSData*) data error:(NSError*) error onSuccess:(OSResultSuccessBlock)successBlock onFailure:(OSFailureBlock)failureBlock;

#pragma clang diagnostic pop
@end
