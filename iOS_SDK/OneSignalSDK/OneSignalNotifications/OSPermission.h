/**
 * Modified MIT License
 *
 * Copyright 2017 OneSignal
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

#import <OneSignalCore/OSObservable.h>

typedef NS_ENUM(NSInteger, OSNotificationPermission) {
    // The user has not yet made a choice regarding whether your app can show notifications.
    OSNotificationPermissionNotDetermined = 0,
    
    // The application is not authorized to post user notifications.
    OSNotificationPermissionDenied,
    
    // The application is authorized to post user notifications.
    OSNotificationPermissionAuthorized,
    
    // the application is only authorized to post Provisional notifications (direct to history)
    OSNotificationPermissionProvisional,
    
    // the application is authorized to send notifications for 8 hours. Only used by App Clips.
    OSNotificationPermissionEphemeral
};

// Permission Classes

// TODO: this object can be REMOVED now that permission is a boolean
@interface OSPermissionState : NSObject
@property (readonly, nonatomic) BOOL permission;
- (NSDictionary * _Nonnull)jsonRepresentation;
- (instancetype _Nonnull )initWithPermission:(BOOL)permission;
@end

@protocol OSPermissionStateObserver<NSObject>
- (void)onChanged:(OSPermissionState * _Nonnull)state;
@end

typedef OSObservable<NSObject<OSPermissionStateObserver>*, OSPermissionState*> ObservablePermissionStateType;


// Redefine OSPermissionState
@interface OSPermissionStateInternal : NSObject {
@protected BOOL _hasPrompted;
@protected BOOL _answeredPrompt;
}
@property (readwrite, nonatomic) BOOL hasPrompted;
@property (readwrite, nonatomic) BOOL providesAppNotificationSettings;
@property (readwrite, nonatomic) BOOL answeredPrompt;
@property (readwrite, nonatomic) BOOL accepted;
@property (readwrite, nonatomic) BOOL provisional; //internal flag
@property (readwrite, nonatomic) BOOL ephemeral;
@property (readwrite, nonatomic) BOOL reachable;
@property (readonly, nonatomic) OSNotificationPermission status;
@property int notificationTypes;

@property (nonatomic) ObservablePermissionStateType * _Nonnull observable;

- (void) persistAsFrom;

- (instancetype _Nonnull )initAsTo;
- (instancetype _Nonnull )initAsFrom;

- (OSPermissionState * _Nonnull)getExternalState;
- (NSDictionary * _Nonnull)jsonRepresentation;
@end

@protocol OSNotificationPermissionObserver <NSObject>
- (void)onNotificationPermissionDidChange:(BOOL)permission;
@end

typedef OSBoolObservable<NSObject<OSNotificationPermissionObserver>*> ObservablePermissionStateChangesType;


@interface OSPermissionChangedInternalObserver : NSObject<OSPermissionStateObserver>
+ (void)fireChangesObserver:(OSPermissionStateInternal * _Nonnull)state;
@end


