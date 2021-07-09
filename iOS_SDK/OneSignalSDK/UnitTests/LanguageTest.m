/**
 * Modified MIT License
 *
 * Copyright 2021 OneSignal
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
#import "UnitTestCommonMethods.h"
#import "OneSignalUserDefaults.h"
#import "OneSignal.h"
#import "OneSignalClientOverrider.h"
#import "OneSignalHelper.h"
#import "NSDateOverrider.h"

@interface LanguageTest : XCTestCase

@end

@implementation LanguageTest

- (void)setUp {
    [super setUp];
    [UnitTestCommonMethods beforeEachTest:self];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testSetLanguageOnPlayerCreate {
    [UnitTestCommonMethods initOneSignal_andThreadWait];
    [OneSignal setLanguage:@"fr"];
    [UnitTestCommonMethods runBackgroundThreads];

    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"language"], @"fr");
}

- (void)testSetLanguageRequest {
    [UnitTestCommonMethods initOneSignal_andThreadWait];
    [OneSignal setLanguage:@"fr"];
    [UnitTestCommonMethods runBackgroundThreads];

    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"language"], @"fr");
}

-(void)testSetLanguage_afterOnSession {
    // 1. Open app
    [UnitTestCommonMethods initOneSignal_andThreadWait];
    [UnitTestCommonMethods foregroundApp];
    [UnitTestCommonMethods runBackgroundThreads];

    // 2. Kill the app and wait 31 seconds
    [UnitTestCommonMethods backgroundApp];
    [UnitTestCommonMethods clearStateForAppRestart:self];
    [NSDateOverrider advanceSystemTimeBy:31];
    [UnitTestCommonMethods runBackgroundThreads];

    // 4. Open app
    [UnitTestCommonMethods initOneSignal_andThreadWait];
    [UnitTestCommonMethods foregroundApp];
    [UnitTestCommonMethods runBackgroundThreads];
    
    // 5. Set language
    [OneSignal setLanguage:@"fr"];
    [UnitTestCommonMethods runBackgroundThreads];

    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"language"], @"fr");
}

@end
