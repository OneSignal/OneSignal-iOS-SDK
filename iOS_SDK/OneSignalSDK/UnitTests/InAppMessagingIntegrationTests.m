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

#import <XCTest/XCTest.h>
#import "OneSignal.h"
#import "OneSignalHelper.h"
#import "OSInAppMessage.h"
#import "OSTrigger.h"
#import "OSTriggerController.h"
#import "OSInAppMessagingDefines.h"
#import "OSDynamicTriggerController.h"
#import "NSTimerOverrider.h"
#import "UnitTestCommonMethods.h"
#import "OSInAppMessagingHelpers.h"
#import "OSMessagingController.h"
#import "OneSignalClientOverrider.h"
#import "UIApplicationOverrider.h"
#import "OneSignalHelperOverrider.h"
#import "UNUserNotificationCenterOverrider.h"
#import "NSUserDefaultsOverrider.h"
#import "NSBundleOverrider.h"
#import "UNUserNotificationCenter+OneSignal.h"

@interface InAppMessagingIntegrationTests : XCTestCase

@end

@implementation InAppMessagingIntegrationTests

- (void)setUp {
    [super setUp];
    
    OneSignalHelperOverrider.mockIOSVersion = 10;
    
    [OneSignalUNUserNotificationCenter setUseiOS10_2_workaround:true];
    
    UNUserNotificationCenterOverrider.notifTypesOverride = 7;
    UNUserNotificationCenterOverrider.authorizationStatus = [NSNumber numberWithInteger:UNAuthorizationStatusAuthorized];
    
    NSBundleOverrider.nsbundleDictionary = @{@"UIBackgroundModes": @[@"remote-notification"]};
    
    [NSUserDefaultsOverrider clearInternalDictionary];
    
    [UnitTestCommonMethods clearStateForAppRestart:self];
    
    [UnitTestCommonMethods beforeAllTest];
}

/**
    This test adds an in-app message with a dynamic trigger (session_duration = +30 seconds)
    When the SDK receives this message in the response to the registration request, that it
    correctly sets up a timer for the 30 seconds
*/
- (void)testMessageIsScheduled {
    
    let registrationResponse = [OSInAppMessage testRegistrationJsonWithTriggerProperty:@"os_session_duration" withOperator:@"==" withValue:@30];
    
    [OneSignalClientOverrider setMockResponseForRequest:@"OSRequestRegisterUser" withResponse:registrationResponse];
    
    [UnitTestCommonMethods initOneSignal];
    
    [UnitTestCommonMethods runBackgroundThreads];
    
    XCTAssertTrue(NSTimerOverrider.hasScheduledTimer);
    
    XCTAssertTrue(fabs(NSTimerOverrider.mostRecentTimerInterval - 30.0f) < 0.3f);
}



@end
