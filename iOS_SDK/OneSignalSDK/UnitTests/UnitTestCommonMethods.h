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
#import <XCTest/XCTest.h>
#import "OneSignal.h"
#import "OneSignalNotificationCategoryController.h"

#define TEST_EXTERNAL_USER_ID @"i_am_a_test_external_user_id"

NSString * serverUrlWithPath(NSString *path);

@interface UnitTestCommonMethods : NSObject

+ (void)setCurrentNotificationPermissionAsUnanswered;
+ (void)foregroundApp;
+ (void)backgroundApp;
+ (void)initOneSignal;
+ (void)initOneSignalAndThreadWait;
+ (void)runBackgroundThreads;
+ (void)beforeAllTest;
+ (void)beforeAllTest:(XCTestCase *)testCase;
+ (void)beforeEachTest:(XCTestCase *)testCase;
+ (void)clearStateForAppRestart:(XCTestCase *)testCase;
+ (UNNotificationResponse*)createBasiciOSNotificationResponseWithPayload:(NSDictionary*)userInfo;
+ (void)answerNotificationPrompt:(BOOL)accept;
+ (void)setCurrentNotificationPermission:(BOOL)accepted;
+ (void)receiveNotification:(NSString*)notificationId wasOpened:(BOOL)opened;
+ (void)handleNotificationReceived:(NSString*)notificationId messageDict:(NSDictionary*)messageDict wasOpened:(BOOL)opened;
+ (XCTestCase*)currentXCTestCase;
@end

// Expose OneSignal test methods
@interface OneSignal (UN_extra)
+ (dispatch_queue_t) getRegisterQueue;
+ (void)setDelayIntervals:(NSTimeInterval)apnsMaxWait withRegistrationDelay:(NSTimeInterval)registrationDelay;
@end

// Expose methods on OneSignalNotificationCategoryController
@interface OneSignalNotificationCategoryController ()
- (void)pruneCategories:(NSMutableArray <NSString *> *)currentCategories;
- (NSArray<NSString *> *)existingRegisteredCategoryIds;
@end

// START - Start Observers

@interface OSPermissionStateTestObserver : NSObject<OSPermissionObserver> {
    @package OSPermissionStateChanges* last;
    @package int fireCount;
}
- (void)onOSPermissionChanged:(OSPermissionStateChanges*)stateChanges;
@end

@interface OSSubscriptionStateTestObserver : NSObject<OSSubscriptionObserver> {
    @package OSSubscriptionStateChanges* last;
    @package int fireCount;
}
- (void)onOSSubscriptionChanged:(OSSubscriptionStateChanges*)stateChanges;
@end

@interface OSEmailSubscriptionStateTestObserver : NSObject<OSEmailSubscriptionObserver> {
    @package OSEmailSubscriptionStateChanges *last;
    @package int fireCount;
}
- (void)onOSEmailSubscriptionChanged:(OSEmailSubscriptionStateChanges *)stateChanges;
@end

// END - Observers
