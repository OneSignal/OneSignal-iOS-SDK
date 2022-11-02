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
#import <OneSignalNotificationSettings.h>
#import <OSPermission.h>

NS_ASSUME_NONNULL_BEGIN
// <- TODO: ^ this? And other items that should go here

/**
 Public API.
 */
@protocol OSNotifications <NSObject>

+ (void)requestPermission:(OSUserResponseBlock)block;
+ (void)requestPermission:(OSUserResponseBlock)block fallbackToSettings:(BOOL)fallback;
+ (void)registerForProvisionalAuthorization:(OSUserResponseBlock)block;
// clearAll

@end

@interface OSNotificationsManager : NSObject <OSNotifications>

+ (Class<OSNotifications>)Notifications;

@property (class) BOOL waitingForApnsResponse; // After moving more methods and properties over, we may not need to expose this.
@property (class, readonly) OSPermissionStateInternal* _Nonnull currentPermissionState;
@property (class) OSPermissionStateInternal* _Nonnull lastPermissionState;

+ (void)clearStatics; // Used by Unit Tests

// Indicates if the app provides its own custom Notification customization settings UI
// To enable this, set kOSSettingsKeyProvidesAppNotificationSettings to true in init.
+ (BOOL)providesAppNotificationSettings;
+ (void)setProvidesNotificationSettingsView:(BOOL)providesView;

+ (BOOL)registerForAPNsToken;

//+ (void)updateNotificationTypes:(int)notificationTypes;

// Used to manage observers added by the app developer.
@property (class, readonly) ObservablePermissionStateChangesType* permissionStateChangesObserver;

@property (class, readonly) OneSignalNotificationSettings* _Nonnull osNotificationSettings;

// TODO: This gets set by the user module's push sub
@property (class, readwrite) BOOL pushDisabled;

@end

NS_ASSUME_NONNULL_END // <- TODO: this?
