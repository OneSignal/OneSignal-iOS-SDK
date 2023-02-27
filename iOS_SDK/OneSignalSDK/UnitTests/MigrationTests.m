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
// TODO: Commented out 🧪
//#import "OSMigrationController.h"
//#import "OSInfluenceDataRepository.h"
//#import "OSOutcomeEventsCache.h"
//#import "OSIndirectInfluence.h"
//#import "OSIndirectNotification.h"
//#import "OSCachedUniqueOutcome.h"
//#import "OSUniqueOutcomeNotification.h"
//#import "OneSignalHelper.h"
//#import "UnitTestCommonMethods.h"
//#import "OneSignalUserDefaults.h"
//#import "OneSignalCommonDefines.h"
//#import "OSInAppMessagingDefines.h"
//#import "OneSignalUserDefaults.h"
//#import "OSInAppMessageInternal.h"
//#import "OSInAppMessagingHelpers.h"
//#import "CommonAsserts.h"
//
//@interface MigrationTests : XCTestCase
//@end
//
//@implementation MigrationTests {
//    OSMigrationController *migrationController;
//    OSInfluenceDataRepository *dataRepository;
//    OSOutcomeEventsCache *outcomesCache;
//}
//
//- (void)setUp {
//    [super setUp];
//    [UnitTestCommonMethods beforeEachTest:self];
//    migrationController = [OSMigrationController new];
//    dataRepository = [OSInfluenceDataRepository new];
//    outcomesCache = [OSOutcomeEventsCache new];
//}
//
//- (void)testNoIndirectInfluenceDataAvailableToMigrate {
//    NSArray *lastNotificationReceived = [dataRepository lastNotificationsReceivedData];
//    NSInteger sdkVersion = [OneSignalUserDefaults.initShared getSavedIntegerForKey:OSUD_CACHED_SDK_VERSION defaultValue:0];
//    XCTAssertNil(lastNotificationReceived);
//    XCTAssertEqual(0, sdkVersion);
//    [migrationController migrate];
//
//    NSArray *lastNotificationReceivedAfterMigration = [dataRepository lastNotificationsReceivedData];
//    XCTAssertNil(lastNotificationReceivedAfterMigration);
//
//    NSInteger sdkVersionAfterMigration = [OneSignalUserDefaults.initShared getSavedIntegerForKey:OSUD_CACHED_SDK_VERSION defaultValue:0];
//    XCTAssertEqual([[OneSignal sdkVersionRaw] intValue], sdkVersionAfterMigration);
//}
//
//- (void)testIndirectNotificationToIndirectInfluenceMigration {
//    NSString *notificationId = @"1234-5678-1234-5678-1234";
//    double timestamp = 10;
//    OSIndirectNotification *indirectNotification = [[OSIndirectNotification alloc] initWithParamsNotificationId:notificationId timestamp:timestamp];
//    NSMutableArray *indirectNotifications = [NSMutableArray new];
//    [indirectNotifications addObject:indirectNotification];
//
//    [NSKeyedArchiver setClassName:@"OSIndirectNotification" forClass:[OSIndirectNotification class]];
//    [dataRepository saveNotifications:indirectNotifications];
//    [NSKeyedUnarchiver setClass:[OSIndirectNotification class] forClassName:@"OSIndirectNotification"];
//    NSArray<OSIndirectNotification *> *lastNotificationReceived = [dataRepository lastNotificationsReceivedData];
//    OSIndirectNotification *lastIndirectNotificationReceived = [lastNotificationReceived objectAtIndex:0];
//    NSInteger sdkVersion = [OneSignalUserDefaults.initShared getSavedIntegerForKey:OSUD_CACHED_SDK_VERSION defaultValue:0];
//    XCTAssertTrue([lastIndirectNotificationReceived.notificationId isEqualToString:notificationId]);
//    XCTAssertEqual(1, [lastNotificationReceived count]);
//    XCTAssertEqual(0, sdkVersion);
//
//    [migrationController migrate];
//
//    NSArray<OSIndirectInfluence *> *lastNotificationReceivedAfterMigration = [dataRepository lastNotificationsReceivedData];
//    XCTAssertEqual(1, [lastNotificationReceivedAfterMigration count]);
//
//    OSIndirectInfluence *indirectInfluence = [lastNotificationReceivedAfterMigration objectAtIndex:0];
//    XCTAssertTrue([indirectInfluence.influenceId isEqualToString:notificationId]);
//    XCTAssertTrue([indirectInfluence.channelIdTag isEqualToString:@"notification_id"]);
//    XCTAssertEqual(timestamp, indirectInfluence.timestamp);
//
//    NSInteger sdkVersionAfterMigration = [OneSignalUserDefaults.initShared getSavedIntegerForKey:OSUD_CACHED_SDK_VERSION defaultValue:0];
//    XCTAssertEqual([[OneSignal sdkVersionRaw] intValue], sdkVersionAfterMigration);
//}
//
//- (void)testIndirectInfluenceToIndirectInfluenceMigration {
//    NSString *notificationId = @"1234-5678-1234-5678-1234";
//    NSString *channelId = @"notification_id";
//    double timestamp = 10;
//    OSIndirectInfluence *indirectInfluence = [[OSIndirectInfluence alloc] initWithParamsInfluenceId:notificationId forChannel:channelId timestamp:timestamp];
//    NSMutableArray *indirectNotifications = [NSMutableArray new];
//    [indirectNotifications addObject:indirectInfluence];
//
//    [dataRepository saveNotifications:indirectNotifications];
//    NSArray *lastNotificationReceived = [dataRepository lastNotificationsReceivedData];
//    NSInteger sdkVersion = [OneSignalUserDefaults.initShared getSavedIntegerForKey:OSUD_CACHED_SDK_VERSION defaultValue:0];
//    XCTAssertEqual(1, [lastNotificationReceived count]);
//    XCTAssertEqual(0, sdkVersion);
//
//    [migrationController migrate];
//
//    NSArray<OSIndirectInfluence *> *lastNotificationReceivedAfterMigration = [dataRepository lastNotificationsReceivedData];
//    XCTAssertEqual(1, [lastNotificationReceivedAfterMigration count]);
//
//    OSIndirectInfluence *indirectInfluenceAfterMigration = [lastNotificationReceivedAfterMigration objectAtIndex:0];
//    XCTAssertTrue([indirectInfluenceAfterMigration.influenceId isEqualToString:notificationId]);
//    XCTAssertTrue([indirectInfluenceAfterMigration.channelIdTag isEqualToString:channelId]);
//    XCTAssertEqual(timestamp, indirectInfluenceAfterMigration.timestamp);
//
//    NSInteger sdkVersionAfterMigration = [OneSignalUserDefaults.initShared getSavedIntegerForKey:OSUD_CACHED_SDK_VERSION defaultValue:0];
//    XCTAssertEqual([[OneSignal sdkVersionRaw] intValue], sdkVersionAfterMigration);
//}
//
//- (void)testIndirectNotificationToIndirectInfluenceMigration_NotificationServiceExtensionHandler {
//    NSString *notificationId = @"1234-5678-1234-5678-1234";
//    double timestamp = 10;
//    OSIndirectNotification *indirectNotification = [[OSIndirectNotification alloc] initWithParamsNotificationId:notificationId timestamp:timestamp];
//    NSMutableArray *indirectNotifications = [NSMutableArray new];
//    [indirectNotifications addObject:indirectNotification];
//
//    [NSKeyedArchiver setClassName:@"OSIndirectNotification" forClass:[OSIndirectNotification class]];
//    [dataRepository saveNotifications:indirectNotifications];
//    [NSKeyedUnarchiver setClass:[OSIndirectNotification class] forClassName:@"OSIndirectNotification"];
//    NSArray<OSIndirectNotification *> *lastNotificationReceived = [dataRepository lastNotificationsReceivedData];
//    OSIndirectNotification *lastIndirectNotificationReceived = [lastNotificationReceived objectAtIndex:0];
//    NSInteger sdkVersion = [OneSignalUserDefaults.initShared getSavedIntegerForKey:OSUD_CACHED_SDK_VERSION defaultValue:0];
//    XCTAssertTrue([lastIndirectNotificationReceived.notificationId isEqualToString:notificationId]);
//    XCTAssertEqual(1, [lastNotificationReceived count]);
//    XCTAssertEqual(0, sdkVersion);
//
//    // Receive notification
//    [UnitTestCommonMethods receiveNotification:@"test_notification_1" wasOpened:NO];
//
//    NSArray<OSIndirectInfluence *> *lastNotificationReceivedAfterMigration = [dataRepository lastNotificationsReceivedData];
//    XCTAssertEqual(2, [lastNotificationReceivedAfterMigration count]);
//
//    OSIndirectInfluence *indirectInfluenceMigrated = [lastNotificationReceivedAfterMigration objectAtIndex:0];
//    XCTAssertTrue([indirectInfluenceMigrated.influenceId isEqualToString:notificationId]);
//    XCTAssertTrue([indirectInfluenceMigrated.channelIdTag isEqualToString:@"notification_id"]);
//    XCTAssertEqual(timestamp, indirectInfluenceMigrated.timestamp);
//
//    OSIndirectInfluence *indirectInfluenceReceived = [lastNotificationReceivedAfterMigration objectAtIndex:1];
//    XCTAssertTrue([indirectInfluenceReceived.influenceId isEqualToString:@"test_notification_1"]);
//    XCTAssertTrue([indirectInfluenceReceived.channelIdTag isEqualToString:@"notification_id"]);
//
//    NSInteger sdkVersionAfterMigration = [OneSignalUserDefaults.initShared getSavedIntegerForKey:OSUD_CACHED_SDK_VERSION defaultValue:0];
//    XCTAssertEqual([[OneSignal sdkVersionRaw] intValue], sdkVersionAfterMigration);
//}
//
//- (void)testNoAttributedUniqueOutcomeDataAvailableToMigrate {
//    NSArray *uniqueOutcomes = [outcomesCache getAttributedUniqueOutcomeEventSent];
//    NSInteger sdkVersion = [OneSignalUserDefaults.initShared getSavedIntegerForKey:OSUD_CACHED_SDK_VERSION defaultValue:0];
//    XCTAssertNil(uniqueOutcomes);
//    XCTAssertEqual(0, sdkVersion);
//    [migrationController migrate];
//
//    NSArray *uniqueOutcomesAfterMigration = [outcomesCache getAttributedUniqueOutcomeEventSent];
//    XCTAssertNil(uniqueOutcomesAfterMigration);
//
//    NSInteger sdkVersionAfterMigration = [OneSignalUserDefaults.initShared getSavedIntegerForKey:OSUD_CACHED_SDK_VERSION defaultValue:0];
//    XCTAssertEqual([[OneSignal sdkVersionRaw] intValue], sdkVersionAfterMigration);
//}
//
//- (void)testUniqueOutcomeNotificationToCacheUniqueOutcomeMigration {
//    NSString *notificationId = @"1234-5678-1234-5678-1234";
//    NSString *outcome = @"test";
//    NSNumber *timestamp = @(10);
//    OSUniqueOutcomeNotification *uniqueOutcome = [[OSUniqueOutcomeNotification alloc] initWithParamsNotificationId:outcome notificationId:notificationId timestamp:timestamp];
//    NSMutableArray *uniqueOutcomes = [NSMutableArray new];
//    [uniqueOutcomes addObject:uniqueOutcome];
//
//    [outcomesCache saveAttributedUniqueOutcomeEventNotificationIds:uniqueOutcomes];
//
//    NSArray *lastUniqueOutcomeSaved = [outcomesCache getAttributedUniqueOutcomeEventSent];
//    NSInteger sdkVersion = [OneSignalUserDefaults.initShared getSavedIntegerForKey:OSUD_CACHED_SDK_VERSION defaultValue:0];
//    XCTAssertEqual(1, [lastUniqueOutcomeSaved count]);
//    XCTAssertEqual(0, sdkVersion);
//
//    [migrationController migrate];
//
//    NSArray *lastUniqueOutcomeAfterMigration = [outcomesCache getAttributedUniqueOutcomeEventSent];
//    XCTAssertEqual(1, [lastUniqueOutcomeAfterMigration count]);
//
//    OSCachedUniqueOutcome *cachedUniqueOutcome = [lastUniqueOutcomeAfterMigration objectAtIndex:0];
//    XCTAssertTrue([cachedUniqueOutcome.uniqueId isEqualToString:notificationId]);
//    XCTAssertEqual(cachedUniqueOutcome.channel, NOTIFICATION);
//    XCTAssertEqual([timestamp intValue], [cachedUniqueOutcome.timestamp intValue]);
//
//    NSInteger sdkVersionAfterMigration = [OneSignalUserDefaults.initShared getSavedIntegerForKey:OSUD_CACHED_SDK_VERSION defaultValue:0];
//    XCTAssertEqual([[OneSignal sdkVersionRaw] intValue], sdkVersionAfterMigration);
//}
//
//- (void)testCachedUniqueOutcomeToCachedUniqueOutcomeMigration {
//    NSString *notificationId = @"1234-5678-1234-5678-1234";
//    NSString *outcome = @"test";
//    NSNumber *timestamp = @(10);
//    OSCachedUniqueOutcome *cachedUniqueOutcome = [[OSCachedUniqueOutcome alloc] initWithParamsName:outcome uniqueId:notificationId timestamp:timestamp channel:NOTIFICATION];
//    NSMutableArray *cacheUniqueOutcomes = [NSMutableArray new];
//    [cacheUniqueOutcomes addObject:cachedUniqueOutcome];
//
//    [outcomesCache saveAttributedUniqueOutcomeEventNotificationIds:cacheUniqueOutcomes];
//    NSArray *lastCachedUniqueOutcomes = [outcomesCache getAttributedUniqueOutcomeEventSent];
//    NSInteger sdkVersion = [OneSignalUserDefaults.initShared getSavedIntegerForKey:OSUD_CACHED_SDK_VERSION defaultValue:0];
//    XCTAssertEqual(1, [lastCachedUniqueOutcomes count]);
//    XCTAssertEqual(0, sdkVersion);
//
//    [migrationController migrate];
//
//    NSArray<OSCachedUniqueOutcome *> *lastCachedUniqueOutcomesAfterMigration = [outcomesCache getAttributedUniqueOutcomeEventSent];
//    XCTAssertEqual(1, [lastCachedUniqueOutcomesAfterMigration count]);
//
//    OSCachedUniqueOutcome *cachedUniqueOutcomeAfterMigration = [lastCachedUniqueOutcomesAfterMigration objectAtIndex:0];
//    XCTAssertTrue([cachedUniqueOutcomeAfterMigration.name isEqualToString:outcome]);
//    XCTAssertTrue([cachedUniqueOutcomeAfterMigration.uniqueId isEqualToString:notificationId]);
//    XCTAssertEqual(NOTIFICATION, cachedUniqueOutcomeAfterMigration.channel);
//    XCTAssertEqual([timestamp intValue], [cachedUniqueOutcomeAfterMigration.timestamp intValue]);
//
//    NSInteger sdkVersionAfterMigration = [OneSignalUserDefaults.initShared getSavedIntegerForKey:OSUD_CACHED_SDK_VERSION defaultValue:0];
//    XCTAssertEqual([[OneSignal sdkVersionRaw] intValue], sdkVersionAfterMigration);
//}
//
//- (void)testIAMCachedEmptyDictionaryToCachedCodeableMigration {
//    NSDictionary<NSString *, OSInAppMessageInternal *>*emptyDict = [NSMutableDictionary new];
//    [OneSignalUserDefaults.initStandard saveDictionaryForKey:OS_IAM_REDISPLAY_DICTIONARY withValue:emptyDict];
//
//    [migrationController migrate];
//}
//
//- (void)testIAMCachedDictionaryToCachedCodeableMigration {
//    NSMutableDictionary <NSString *, OSInAppMessageInternal *> *emptyDict = [NSMutableDictionary new];
//
//    [OneSignalUserDefaults.initStandard saveDictionaryForKey:OS_IAM_REDISPLAY_DICTIONARY withValue:emptyDict];
//
//    [migrationController migrate];
//
//    NSDictionary<NSString *, OSInAppMessageInternal *>*retrievedDict = [OneSignalUserDefaults.initStandard
//                                                                getSavedCodeableDataForKey:OS_IAM_REDISPLAY_DICTIONARY defaultValue:nil];
//    XCTAssertEqualObjects(nil, retrievedDict);
//}
//
//- (void)testIAMCachedCodeableMigration {
//    let limit = 5;
//    let delay = 60;
//    let message = [OSInAppMessageTestHelper testMessageWithRedisplayLimit:limit delay:@(delay)];
//    message.isDisplayedInSession = true;
//    NSMutableDictionary <NSString *, OSInAppMessageInternal *> *redisplayedInAppMessages = [NSMutableDictionary new];
//    [redisplayedInAppMessages setObject:message forKey:message.messageId];
//
//    [OneSignalUserDefaults.initStandard saveCodeableDataForKey:OS_IAM_REDISPLAY_DICTIONARY withValue:redisplayedInAppMessages];
//
//    [migrationController migrate];
//
//    NSDictionary<NSString *, OSInAppMessageInternal *>*retrievedDict = [OneSignalUserDefaults.initStandard
//                                                                getSavedCodeableDataForKey:OS_IAM_REDISPLAY_DICTIONARY defaultValue:nil];
//    XCTAssertEqualObjects(redisplayedInAppMessages, retrievedDict);
//}
//
//- (void)testIAMNilCacheToNilMigration {
//
//    [OneSignalUserDefaults.initStandard saveDictionaryForKey:OS_IAM_REDISPLAY_DICTIONARY withValue:nil];
//
//    [migrationController migrate];
//
//    NSDictionary<NSString *, OSInAppMessageInternal *>*retrievedDict = [OneSignalUserDefaults.initStandard
//                                                                getSavedCodeableDataForKey:OS_IAM_REDISPLAY_DICTIONARY defaultValue:nil];
//    XCTAssertNil(retrievedDict);
//}
//
//- (void)testIAMMessagesToInternalMigration {
//    let limit = 5;
//    let delay = 60;
//    let message = [OSInAppMessageTestHelper testMessageWithRedisplayLimit:limit delay:@(delay)];
//    message.isDisplayedInSession = true;
//
//    // Cached Messages
//    NSArray<OSInAppMessageInternal *> *messages = [[NSArray alloc] initWithObjects:message, nil];
//
//    [NSKeyedArchiver setClassName:@"OSInAppMessage" forClass:[OSInAppMessageInternal class]];
//
//    [OneSignalUserDefaults.initStandard saveCodeableDataForKey:OS_IAM_MESSAGES_ARRAY withValue:messages];
//
//    [migrationController migrate];
//
//    NSArray<OSInAppMessageInternal *>*retrievedArray = [OneSignalUserDefaults.initStandard
//                                                                getSavedCodeableDataForKey:OS_IAM_MESSAGES_ARRAY defaultValue:nil];
//    XCTAssertEqualObjects(messages, retrievedArray);
//}
//
//- (void)testIAMRedisplayToInternalMigration {
//    let limit = 5;
//    let delay = 60;
//    let message = [OSInAppMessageTestHelper testMessageWithRedisplayLimit:limit delay:@(delay)];
//    message.isDisplayedInSession = true;
//    // Cached Redisplay Messages
//    NSMutableDictionary <NSString *, OSInAppMessageInternal *> *redisplayedInAppMessages = [NSMutableDictionary new];
//    [redisplayedInAppMessages setObject:message forKey:message.messageId];
//
//    [NSKeyedArchiver setClassName:@"OSInAppMessage" forClass:[OSInAppMessageInternal class]];
//
//    [OneSignalUserDefaults.initStandard saveCodeableDataForKey:OS_IAM_REDISPLAY_DICTIONARY withValue:redisplayedInAppMessages];
//
//    [migrationController migrate];
//
//    NSDictionary<NSString *, OSInAppMessageInternal *>*retrievedDict = [OneSignalUserDefaults.initStandard
//                                                                getSavedCodeableDataForKey:OS_IAM_REDISPLAY_DICTIONARY defaultValue:nil];
//    XCTAssertEqualObjects(redisplayedInAppMessages, retrievedDict);
//}
//
//
//@end
