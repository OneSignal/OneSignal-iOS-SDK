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

// Redefines are done so we can make properites writeable and backed internal variables accesiable to the SDK.
// Basicly the C# equivlent of a public gettter with an internal/protected settter.


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
@interface OSPermissionState : NSObject

@property (readonly, nonatomic) BOOL reachable;
@property (readonly, nonatomic) BOOL hasPrompted;
@property (readonly, nonatomic) BOOL provisional;
@property (readonly, nonatomic) BOOL providesAppNotificationSettings;
@property (readonly, nonatomic) OSNotificationPermission status;
- (NSDictionary* _Nonnull)toDictionary;
- (instancetype)initWithStatus:(OSNotificationPermission)status reachable:(BOOL)reachable hasPrompted:(BOOL)hasPrompted provisional:(BOOL)provisional providesAppNotificationSettings:(BOOL)providesAppNotificationSettings;
@end

@protocol OSPermissionStateObserver<NSObject>
- (void)onChanged:(OSPermissionState*)state;
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

@property (nonatomic) ObservablePermissionStateType* observable;

- (void) persistAsFrom;

- (instancetype)initAsTo;
- (instancetype)initAsFrom;

- (BOOL)compare:(OSPermissionStateInternal*)from;
- (OSPermissionState *)getExternalState;

@end

@interface OSPermissionStateChanges : NSObject

@property (readonly, nonnull) OSPermissionState* to;
@property (readonly, nonnull) OSPermissionState* from;
- (NSDictionary* _Nonnull)toDictionary;
- (instancetype)initAsTo:(OSPermissionState *)to from:(OSPermissionState *)from;
@end

@protocol OSPermissionObserver <NSObject>
- (void)onOSPermissionChanged:(OSPermissionStateChanges* _Nonnull)stateChanges;
@end

typedef OSObservable<NSObject<OSPermissionObserver>*, OSPermissionStateChanges*> ObservablePermissionStateChangesType;


@interface OSPermissionChangedInternalObserver : NSObject<OSPermissionStateObserver>
+ (void)fireChangesObserver:(OSPermissionStateInternal*)state;
@end


