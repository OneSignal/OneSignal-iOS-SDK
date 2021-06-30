//
//  LanguageTest.m
//  OneSignal
//
//  Created by Tanay Nigam on 6/24/21.
//  Copyright © 2021 Hiptic. All rights reserved.
//

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
    [UnitTestCommonMethods runBackgroundThreads];
    [OneSignal setLanguage:@"fr"];
    [UnitTestCommonMethods runBackgroundThreads];

    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"language"], @"fr");
}

-(void)testSetLanguage_afterOnSession {
    // 2. Open app
    [UnitTestCommonMethods initOneSignal_andThreadWait];
    [UnitTestCommonMethods foregroundApp];
    [UnitTestCommonMethods runBackgroundThreads];

    // 3. Kill the app and wait 31 seconds
    [UnitTestCommonMethods backgroundApp];
    [UnitTestCommonMethods clearStateForAppRestart:self];
    [NSDateOverrider advanceSystemTimeBy:31];
    [UnitTestCommonMethods runBackgroundThreads];

    // 4. Open app
    [UnitTestCommonMethods initOneSignal_andThreadWait];
    [UnitTestCommonMethods foregroundApp];
    [UnitTestCommonMethods runBackgroundThreads];
    
    [OneSignal setLanguage:@"fr"];
    [UnitTestCommonMethods runBackgroundThreads];

    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"language"], @"fr");
}

@end
