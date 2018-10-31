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

/**
 Test to make sure that OSInAppMessage correctly
 implements the OSJSONDecodable protocol
 and all properties are parsed correctly
 */

@interface InAppMessagingTests : XCTestCase

@end

@implementation InAppMessagingTests {
    OSInAppMessage *testMessage;
}

-(void)setUp {
    [super setUp];
    
    let messageJson = @{
        @"type" : @"centered_modal",
        @"id" : @"a4b3gj7f-d8cc-11e4-bed1-df8f05be55ba",
        @"content_id" : @"m8dh7234f-d8cc-11e4-bed1-df8f05be55ba",
        @"triggers" : @[
            @{
                @"property" : @"view_controller",
                @"operator" : @"==",
                @"value" : @"home_vc"
            }
        ]
    };
    
    let data = [NSJSONSerialization dataWithJSONObject:messageJson options:0 error:nil];
    
    testMessage = [[OSInAppMessage alloc] initWithData:data];
}

- (void)testCorrectlyParsedType {
    XCTAssertTrue(testMessage.type == OSInAppMessageDisplayTypeCenteredModal);
}

-(void)testCorrectlyParsedMessageId {
    XCTAssertTrue([testMessage.messageId isEqualToString:@"a4b3gj7f-d8cc-11e4-bed1-df8f05be55ba"]);
}

-(void)testCorrectlyParsedContentId {
    XCTAssertTrue([testMessage.contentId isEqualToString:@"m8dh7234f-d8cc-11e4-bed1-df8f05be55ba"]);
}

-(void)testCorrectlyParsedTriggers {
    XCTAssertTrue(testMessage.triggers.count == 1);
    XCTAssertTrue([testMessage.triggers.firstObject[@"property"] isEqualToString:@"view_controller"]);
}

@end
