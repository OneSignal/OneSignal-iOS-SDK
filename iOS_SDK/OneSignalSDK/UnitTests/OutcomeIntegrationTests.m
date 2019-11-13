/**
 * Modified MIT License
 *
 * Copyright 2019 OneSignal
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

#import <XCTest/XCTest.h>
#import "OneSignalOutcomeEventsController.h"
#import "OneSignalSessionManager.h"
#import "OneSignalSharedUserDefaults.h"
#import "OSSessionResult.h"
#import "OSOutcomesUtils.h"
#import "OneSignalHelper.h"
#import "OneSignalTracker.h"
#import "UnitTestCommonMethods.h"
#import "OneSignalClientOverrider.h"
#import "Requests.h"
#import "NSDateOverrider.h"
#import "UNUserNotificationCenterOverrider.h"
#import "RestClientAsserts.h"
#import "OSOutcomesUtils.h"
#import "NSUserDefaultsOverrider.h"
#import "OneSignalClientOverrider.h"
#import "UIApplicationOverrider.h"

#define TEST_NOTIFICATION_ID @"TEST_NOTIFICATION_ID"

@interface OutcomeIntergrationTests : XCTestCase
@end

@implementation OutcomeIntergrationTests
- (void)setUp {
    [super setUp];
    [UnitTestCommonMethods beforeEachTest:self];
    
    [OneSignalClientOverrider enableOutcomes];
}

-(void)testOutcomesFoucsUnattributed {
    // 1. Open App
    [UnitTestCommonMethods initOneSignalAndThreadWait];
    
    // 2. Wait 60 secounds
    [NSDateOverrider advanceSystemTimeBy:60];
    
    // 3. Background app
    [OneSignalTracker onFocus:true];
    [UnitTestCommonMethods runBackgroundThreads];
    
    // 4. Ensure onfocus is made right away.
    [RestClientAsserts assertOnFocusAtIndex:2 withTime:60];
}

-(void)testOutcomesFoucsAttributedIndirect {
    [OneSignalClientOverrider enableOutcomes];
    // 1. Open App
    [UnitTestCommonMethods initOneSignalAndThreadWait];
    
    // 2. Background and and receive notification
    [OneSignalTracker onFocus:true];
    // TODO: This could be more end-to-end, should be called from the NSE
    [OSOutcomesUtils saveReceivedNotificationWithBackground:TEST_NOTIFICATION_ID fromBackground:YES];
    
    // 3. Swipe away app and reopen it 31 secounds later.
    [UnitTestCommonMethods clearStateForAppRestart:self];
    [NSDateOverrider advanceSystemTimeBy:31];
    [UnitTestCommonMethods initOneSignalAndThreadWait];
    
    // 4. Wait 15 secounds
    [NSDateOverrider advanceSystemTimeBy:15];
    
    // 5. Background app
    [OneSignalTracker onFocus:true];
    [UnitTestCommonMethods runBackgroundThreads];
    
    // TODO: 6. Ensure onfocus is sent after waiting 30 secounds in the background.
    // [RestClientAsserts assertOnFocusAtIndex:0 withTime:30];
}



- (void)backgroundApp {
    UIApplicationOverrider.currentUIApplicationState = UIApplicationStateBackground;
    UIApplication *sharedApp = [UIApplication sharedApplication];
    [sharedApp.delegate applicationWillResignActive:sharedApp];
}





@end
