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

#import "RestClientAsserts.h"

#import <XCTest/XCTest.h>
// TODO: Commented out 🧪
//#import "OSRequests.h"
//#import "OSFocusRequests.h"
//#import "OSInAppMessagingRequests.h"
//#import "OSLocationRequests.h"
//#import "OSOutcomesRequests.h"
//#import "OneSignalHelper.h"
//#import "UnitTestCommonMethods.h"
//#import "OneSignalClientOverrider.h"
//
///*
// _XCTPrimitive* functions are used here as we need to pass the current XCTestCase being run.
// This has a side effect of Xcode pointing to lines in this file instead of the unit test itself
//    if the assert fails.
//    - We could also make helpers for each _XCTPrimitive* to make them shorter with less params.
// 2nd option woud be to defined with a perprocessor so we can use normal XCTAssert*'s.
//   However this has draw backs;
//      1. No syntax highlighting
//      2. Must end each line with a '/' to support multiline
//      3. Can't define input types, they are oddly just inferred.
//      4. Possibly others.
// Example of a #define that could be used if we find it is a better fit:
//     #define AssertOnFocusAtIndex(index) \
//        let request = [OneSignalClientOverrider.executedRequests objectAtIndex:index]; \
//        XCTAssertFalse([request isKindOfClass:OSRequestOnFocus.self], @"");
// 3rd options is using recordFailureWithDescription noted here:
//      - https://www.objc.io/issues/15-testing/xctest/
//   It looks like it could be even cleaner with Swift
//      - http://masilotti.com/xctest-helpers/
// */
//
//@implementation RestClientAsserts
//
///*
// Assert that a 'on_session' request was made at a specific index in executedRequests
// */
//+ (void)assertOnSessionAtIndex:(int)index {
//    let request = [OneSignalClientOverrider.executedRequests objectAtIndex:index];
//    _XCTPrimitiveAssertTrue(
//        UnitTestCommonMethods.currentXCTestCase,
//        [request isKindOfClass:OSRequestRegisterUser.self],
//        @"isKindOfClass:OSRequestRegisterUser"
//    );
//}
//
///*
// Assert that a 'on_focus' request was made at a specific index in executedRequests and with specific parameters
// */
//+ (void)assertOnFocusAtIndex:(int)index withTime:(int)time {    
//    [self assertOnFocusAtIndex:index payload:@{@"active_time": @(time)}];
//}
//
//+ (void)assertOnFocusAtIndex:(int)index withTime:(int)time withNotifications:(NSArray *)notifications direct:(BOOL)direct {
//    [self assertOnFocusAtIndex:index payload:@{
//        @"active_time": @(time),
//        @"direct": @(direct),
//        @"notification_ids": notifications,
//    }];
//}
//
///*
// Assert that a 'on_focus' request was made at a specific index in executedRequests and with specific parameters
// */
//+ (void)assertOnFocusAtIndex:(int)index payload:(NSDictionary*)payload {
//    let request = [OneSignalClientOverrider.executedRequests objectAtIndex:index];
//    _XCTPrimitiveAssertTrue(
//        UnitTestCommonMethods.currentXCTestCase,
//        [request isKindOfClass:OSRequestOnFocus.self],
//        @"isKindOfClass:OSRequestOnFocus"
//    );
//    
//    [self assertDictionarySubset:payload actual:request.parameters];
//}
//
///*
// Assert number of 'measure' requests made in executedRequests
// */
//+ (void)assertNumberOfMeasureRequests:(int)expectedCount {
//    int actualCount = 0;
//    for (id request in OneSignalClientOverrider.executedRequests) {
//        if ([request isKindOfClass:OSRequestSendOutcomesV1ToServer.self])
//            actualCount++;
//    }
//    
//    _XCTPrimitiveAssertEqual(
//        UnitTestCommonMethods.currentXCTestCase,
//        actualCount,
//        @"actualCount",
//        expectedCount,
//        @"expectedCount",
//        @"actualCount == expectedCount"
//    );
//}
//
///*
// Assert number of 'measure_sources' requests made in executedRequests
// */
//+ (void)assertNumberOfMeasureSourcesRequests:(int)expectedCount {
//    int actualCount = 0;
//    for (id request in OneSignalClientOverrider.executedRequests) {
//        if ([request isKindOfClass:OSRequestSendOutcomesV2ToServer.self])
//            actualCount++;
//    }
//    
//    _XCTPrimitiveAssertEqual(
//        UnitTestCommonMethods.currentXCTestCase,
//        actualCount,
//        @"actualCount",
//        expectedCount,
//        @"expectedCount",
//        @"actualCount == expectedCount"
//    );
//}
//
///*
// Assert that a 'measure' request was made at a specific index in executedRequests and with specific parameters
// */
//+ (void)assertMeasureAtIndex:(int)index payload:(NSDictionary*)payload {
//    let request = [OneSignalClientOverrider.executedRequests objectAtIndex:index];
//    _XCTPrimitiveAssertTrue(
//        UnitTestCommonMethods.currentXCTestCase,
//        [request isKindOfClass:OSRequestSendOutcomesV1ToServer.self],
//        @"isKindOfClass:OSRequestSendOutcomesV1ToServer"
//    );
//    
//    [self assertDictionarySubset:payload actual:request.parameters];
//}
//
///*
// Assert that a 'measure_sources' request was made at a specific index in executedRequests and with specific parameters
// */
//+ (void)assertMeasureSourcesAtIndex:(int)index payload:(NSDictionary*)payload {
//    let request = [OneSignalClientOverrider.executedRequests objectAtIndex:index];
//    _XCTPrimitiveAssertTrue(
//        UnitTestCommonMethods.currentXCTestCase,
//        [request isKindOfClass:OSRequestSendOutcomesV2ToServer.self],
//        @"isKindOfClass:OSRequestSendOutcomesV2ToServer"
//    );
//    
//    [self assertDictionarySubset:payload actual:request.parameters];
//}
//
///*
// Assert in a single direction if the expected payload is a subset of the actual payload
// All keys and values of expected exist and equal each other in actual
// */
//+ (void)assertDictionarySubset:(NSDictionary*)expected actual:(NSDictionary*)actual {
//    for (NSString* key in expected.allKeys) {
//        _XCTPrimitiveAssertTrue(
//            UnitTestCommonMethods.currentXCTestCase,
//            [actual objectForKey:key] != nil,
//            @"objectForKey:"
//        );
//        
//        id expectedValue = [expected objectForKey:key];
//        id actualValue = [actual objectForKey:key];
//        _XCTPrimitiveAssertEqualObjects(
//            UnitTestCommonMethods.currentXCTestCase,
//            actualValue,
//            @"actualValue",
//            expectedValue,
//            @"expectedValue",
//            @"actualValue == expectedValue"
//        );
//    }
//}
//
//@end
