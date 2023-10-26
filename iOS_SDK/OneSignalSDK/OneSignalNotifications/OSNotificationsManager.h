/*
 Modified MIT License

 Copyright 2022 OneSignal

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 1. The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.

 2. All copies of substantial portions of the Software may only be used in connection
 with services provided by OneSignal.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
 */

#import <Foundation/Foundation.h>
#import <OneSignalNotifications/OneSignalNotificationSettings.h>
#import <OneSignalNotifications/OSPermission.h>
#import <OneSignalCore/OneSignalCore.h>
#import <UIKit/UIKit.h>
#import <OneSignalNotifications/OSNotification+OneSignal.h>

@protocol OSNotificationClickListener <NSObject>
- (void)onClickNotification:(OSNotificationClickEvent *_Nonnull)event
NS_SWIFT_NAME(onClick(event:));
@end

@interface OSNotificationWillDisplayEvent : NSObject

@property (readonly, strong, nonatomic, nonnull) OSDisplayableNotification *notification; // TODO: strong? nonatomic? nullable?
- (void)preventDefault;

@end

@protocol OSNotificationLifecycleListener <NSObject>
- (void)onWillDisplayNotification:(OSNotificationWillDisplayEvent *_Nonnull)event NS_SWIFT_NAME(onWillDisplay(event:));
@end

/**
 Public API for the Notifications namespace.
 */
@protocol OSNotifications <NSObject>
+ (BOOL)permission NS_REFINED_FOR_SWIFT;
+ (BOOL)canRequestPermission NS_REFINED_FOR_SWIFT;
+ (OSNotificationPermission)permissionNative NS_REFINED_FOR_SWIFT;
+ (void)addForegroundLifecycleListener:(NSObject<OSNotificationLifecycleListener> *_Nullable)listener;
+ (void)removeForegroundLifecycleListener:(NSObject<OSNotificationLifecycleListener> *_Nullable)listener;
+ (void)addClickListener:(NSObject<OSNotificationClickListener>*_Nonnull)listener NS_REFINED_FOR_SWIFT;
+ (void)removeClickListener:(NSObject<OSNotificationClickListener>*_Nonnull)listener NS_REFINED_FOR_SWIFT;
+ (void)requestPermission:(OSUserResponseBlock _Nullable )block;
+ (void)requestPermission:(OSUserResponseBlock _Nullable )block fallbackToSettings:(BOOL)fallback;
+ (void)registerForProvisionalAuthorization:(OSUserResponseBlock _Nullable )block NS_REFINED_FOR_SWIFT;
+ (void)addPermissionObserver:(NSObject<OSNotificationPermissionObserver>*_Nonnull)observer NS_REFINED_FOR_SWIFT;
+ (void)removePermissionObserver:(NSObject<OSNotificationPermissionObserver>*_Nonnull)observer NS_REFINED_FOR_SWIFT;
+ (void)clearAll;
@end


@protocol OneSignalNotificationsDelegate <NSObject>
// set delegate before user
// can check responds to selector
- (void)setNotificationTypes:(int)notificationTypes;
- (void)setPushToken:(NSString * _Nonnull)pushToken;

@end


@interface OSNotificationsManager : NSObject <OSNotifications>

@property (class, weak, nonatomic, nullable) id<OneSignalNotificationsDelegate> delegate;

+ (Class<OSNotifications> _Nonnull)Notifications;
+ (void)start;
+ (void)setColdStartFromTapOnNotification:(BOOL)coldStartFromTapOnNotification;
+ (BOOL)getColdStartFromTapOnNotification;

@property (class, readonly) OSPermissionStateInternal* _Nonnull currentPermissionState;
@property (class) OSPermissionStateInternal* _Nonnull lastPermissionState;

+ (void)clearStatics; // Used by Unit Tests

// Indicates if the app provides its own custom Notification customization settings UI
// To enable this, set kOSSettingsKeyProvidesAppNotificationSettings to true in init.
+ (BOOL)providesAppNotificationSettings;
/* Used to determine if the app is able to present it's own customized Notification Settings view (iOS 12+) */
+ (void)setProvidesNotificationSettingsView:(BOOL)providesView;

+ (BOOL)registerForAPNsToken;
+ (void)sendPushTokenToDelegate;

+ (int)getNotificationTypes:(BOOL)pushDisabled;
+ (void)updateNotificationTypes:(int)notificationTypes;
+ (void)sendNotificationTypesUpdateToDelegate;

// Used to manage observers added by the app developer.
@property (class, readonly) ObservablePermissionStateChangesType* _Nullable permissionStateChangesObserver;

@property (class, readonly) OneSignalNotificationSettings* _Nonnull osNotificationSettings;

// This is set by the user module
+ (void)setPushSubscriptionId:(NSString *_Nullable)pushSubscriptionId;

+ (void)handleWillShowInForegroundForNotification:(OSNotification *_Nonnull)notification completion:(OSNotificationDisplayResponse _Nonnull)completion;
+ (void)handleNotificationActionWithUrl:(NSString* _Nullable)url actionID:(NSString* _Nonnull)actionID;
+ (BOOL)clearBadgeCount:(BOOL)fromNotifOpened fromClearAll:(BOOL)fromClearAll;

+ (BOOL)receiveRemoteNotification:(UIApplication* _Nonnull)application UserInfo:(NSDictionary* _Nonnull)userInfo completionHandler:(void (^_Nonnull)(UIBackgroundFetchResult))completionHandler;
+ (void)notificationReceived:(NSDictionary* _Nonnull)messageDict wasOpened:(BOOL)opened;
+ (void)handleWillPresentNotificationInForegroundWithPayload:(NSDictionary * _Nonnull)payload withCompletion:(OSNotificationDisplayResponse _Nonnull)completion;
+ (void)didRegisterForRemoteNotifications:(UIApplication *_Nonnull)app deviceToken:(NSData *_Nonnull)inDeviceToken;
+ (void)handleDidFailRegisterForRemoteNotification:(NSError*_Nonnull)err;
+ (void)checkProvisionalAuthorizationStatus;
@end
