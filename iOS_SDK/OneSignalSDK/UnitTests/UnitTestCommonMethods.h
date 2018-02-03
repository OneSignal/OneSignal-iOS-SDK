//
//  UnitTestCommonMethods.h
//  UnitTests
//
//  Created by Brad Hesse on 1/30/18.
//  Copyright © 2018 Hiptic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>
#import "OneSignal.h"

@interface UnitTestCommonMethods : NSObject

+ (void)setCurrentNotificationPermissionAsUnanswered;
+ (void)resumeApp;
+ (void)initOneSignal;
+ (void)runBackgroundThreads;
+ (void)beforeAllTest;
+ (void)clearStateForAppRestart:(XCTestCase *)testCase;

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

// END - Observers
