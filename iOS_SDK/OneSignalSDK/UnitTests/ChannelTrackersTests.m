/**
 * Modified MIT License
 *
 * Copyright 2020 OneSignal
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
#import <Foundation/Foundation.h>
// TODO: Commented out 🧪
//#import "OSTrackerFactory.h"
//#import "OneSignalHelper.h"
//
//#import "UnitTestCommonMethods.h"
//#import "CommonAsserts.h"
//
//@interface ChannelTrackersTests : XCTestCase
//@end
//
//@implementation ChannelTrackersTests {
//    NSString *testNotificationId;
//    NSString *testIAMId;
//    OSTrackerFactory *trackerFactory;
//}
//
//- (void)setUp {
//    [super setUp];
//    [UnitTestCommonMethods beforeEachTest:self];
//
//    testNotificationId = @"test_notification_id";
//    testIAMId = @"test_iam_id";
//    trackerFactory = [[OSTrackerFactory alloc] initWithRepository:[[OSInfluenceDataRepository alloc] init]];
//}
//
//- (void)setOutcomesParamsEnabled {
//    [trackerFactory saveInfluenceParams:@{
//        @"outcomes": @{
//                @"direct": @{
//                        @"enabled": @YES
//                },
//                @"indirect": @{
//                        @"notification_attribution": @{
//                                @"minutes_since_displayed": @1440,
//                                @"limit": @10
//                        },
//                        @"enabled": @YES
//                },
//                @"unattributed" : @{
//                        @"enabled": @YES
//                }
//        },
//    }];
//}
//
//- (void)setOutcomesParamsDisabled {
//    [trackerFactory saveInfluenceParams:@{
//        @"outcomes": @{
//                @"direct": @{
//                        @"enabled": @NO
//                },
//                @"indirect": @{
//                        @"notification_attribution": @{
//                                @"minutes_since_displayed": @1440,
//                                @"limit": @10
//                        },
//                        @"enabled": @NO
//                },
//                @"unattributed" : @{
//                        @"enabled": @NO
//                }
//        },
//    }];
//}
//
//- (void)testUnattributedInitInfluence {
//    [self setOutcomesParamsEnabled];
//    [trackerFactory initFromCache];
//
//    let sessionInfluences = [trackerFactory influences];
//    for (OSInfluence *influence in sessionInfluences) {
//        XCTAssertEqual(influence.influenceType, UNATTRIBUTED);
//        XCTAssertEqual(influence.ids, nil);
//    }
//}
//
//- (void)testInfluenceIdsSaved {
//    [self setOutcomesParamsEnabled];
//    [trackerFactory initFromCache];
//
//    XCTAssertEqual(0, [[trackerFactory notificationChannelTracker] lastReceivedIds].count);
//    XCTAssertEqual(0, [[trackerFactory iamChannelTracker] lastReceivedIds].count);
//
//    [[trackerFactory notificationChannelTracker] saveLastId:testNotificationId];
//    [[trackerFactory iamChannelTracker] saveLastId:testIAMId];
//
//    let lastNotificationIds = [[trackerFactory notificationChannelTracker] lastReceivedIds];
//    let lastIAMIds = [[trackerFactory iamChannelTracker] lastReceivedIds];
//
//    XCTAssertEqual(1, lastNotificationIds.count);
//    [CommonAsserts assertArrayEqualsWithExpected:@[testNotificationId] actual:lastNotificationIds];
//    XCTAssertEqual(1, lastIAMIds.count);
//    [CommonAsserts assertArrayEqualsWithExpected:@[testIAMId] actual:lastIAMIds];
//}
//
//- (void)testDisabledInitInfluence {
//    [self setOutcomesParamsDisabled];
//    [trackerFactory initFromCache];
//
//    let sessionInfluences = [trackerFactory influences];
//    for (OSInfluence *influence in sessionInfluences) {
//        XCTAssertEqual(influence.influenceType, DISABLED);
//        XCTAssertEqual(influence.ids, nil);
//    }
//}
//
//- (void)testSessionInfluences {
//    [self setOutcomesParamsDisabled];
//    [trackerFactory initFromCache];
//
//    let sessionInfluences = [trackerFactory sessionInfluences];
//    XCTAssertEqual(1, sessionInfluences.count);
//    XCTAssertEqual(NOTIFICATION, [[sessionInfluences objectAtIndex:0] influenceChannel]);
//}
//
//- (void)testGetChannelsByEntryPoint {
//    [self setOutcomesParamsDisabled];
//    [trackerFactory initFromCache];
//
//    let sessionInfluences = [trackerFactory influences];
//    for (OSInfluence *influence in sessionInfluences) {
//        XCTAssertEqual(influence.influenceType, DISABLED);
//        XCTAssertEqual(influence.ids, nil);
//    }
//
//    XCTAssertNil([trackerFactory channelByEntryAction:APP_OPEN]);
//    XCTAssertNil([trackerFactory channelByEntryAction:APP_CLOSE]);
//    XCTAssertEqualObjects(@"notification_id", [[trackerFactory channelByEntryAction:NOTIFICATION_CLICK] idTag]);
//}
//
//- (void)testGetChannelToResetByEntryAction {
//    [self setOutcomesParamsDisabled];
//    [trackerFactory initFromCache];
//
//    XCTAssertEqual(2, [trackerFactory channelsToResetByEntryAction:APP_OPEN].count);
//    XCTAssertEqual(0, [trackerFactory channelsToResetByEntryAction:APP_CLOSE].count);
//    XCTAssertEqual(1, [trackerFactory channelsToResetByEntryAction:NOTIFICATION_CLICK].count);
//    XCTAssertEqualObjects(@"iam_id", [[[trackerFactory channelsToResetByEntryAction:NOTIFICATION_CLICK] objectAtIndex:0] idTag]);
//}
//
//@end
