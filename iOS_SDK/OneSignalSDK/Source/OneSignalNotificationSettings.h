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

#ifndef OneSignalNotificationSettings_h
#define OneSignalNotificationSettings_h

#import "OneSignal.h"

#import <Foundation/Foundation.h>

@protocol OneSignalNotificationSettings <NSObject>

- (int) getNotificationTypes;
- (OSPermissionState*)getNotificationPermissionState;
- (void)getNotificationPermissionState:(void (^)(OSPermissionState *subscriptionState))completionHandler;
- (void)promptForNotifications:(void(^)(BOOL accepted))completionHandler;
- (void)registerForProvisionalAuthorization:(void(^)(BOOL accepted))completionHandler;
// Only used for iOS 8 & 9
- (void)onNotificationPromptResponse:(int)notificationTypes;

// Only used for iOS 7
- (void)onAPNsResponse:(BOOL)success;

@end

#endif /* OneSignaNotificationSettings_h */
