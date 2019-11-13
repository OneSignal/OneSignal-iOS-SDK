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

#import "Requests.h"
#import "OneSignalClientOverrider.h"
#import "OneSignalHelper.h"
#import "UnitTestCommonMethods.h"

/*
 _XCTPrimitive* functions are used here as we need to pass the current XCTestCase being run.
 This has a side effect of Xcode pointing to lines in this file instead of the unit test itself
    if the assert fails.
    - We could also make helpers for each _XCTPrimitive* to make them shorter with less params.
 2nd option woud be to defined with a perprocessor so we can use normal XCTAssert*'s.
   However this has draw backs;
      1. No syntax highlighting
      2. Must end each line with a '/' to support multiline
      3. Can't define input types, they are oddly just inferred.
      4. Possibly others.
 Example of a #define that could be used if we find it is a better fit:
     #define AssertOnFocusAtIndex(index) \
        let request = [OneSignalClientOverrider.executedRequests objectAtIndex:index]; \
        XCTAssertFalse([request isKindOfClass:OSRequestOnFocus.self], @"");
 3rd options is using recordFailureWithDescription noted here:
      - https://www.objc.io/issues/15-testing/xctest/
   It looks like it could be even cleaner with Swift
      - http://masilotti.com/xctest-helpers/
 */

@implementation RestClientAsserts
+(void) assertOnFocusAtIndex:(int)index withTime:(int)time {
    let request = [OneSignalClientOverrider.executedRequests objectAtIndex:index];
    _XCTPrimitiveAssertTrue(
        UnitTestCommonMethods.currentXCTestCase,
        [request isKindOfClass:OSRequestOnFocus.self],
        @"isKindOfClass:OSRequestOnFocus"
    );
    
    _XCTPrimitiveAssertEqual(
        UnitTestCommonMethods.currentXCTestCase,
        ((NSNumber*)request.parameters[@"active_time"]).doubleValue,
        @"active_time",
        time,
        @"time",
        @""
    );
}
@end
