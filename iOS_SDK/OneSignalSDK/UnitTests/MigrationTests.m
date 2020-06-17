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
#import "OSMigrationController.h"
#import "OSInfluenceDataRepository.h"
#import "OSOutcomeEventsCache.h"
#import "OSIndirectInfluence.h"
#import "OSIndirectNotification.h"
#import "OSCachedUniqueOutcome.h"
#import "OSUniqueOutcomeNotification.h"
#import "OneSignalHelper.h"
#import "UnitTestCommonMethods.h"
#import "OneSignalUserDefaults.h"
#import "OneSignalCommonDefines.h"
#import "CommonAsserts.h"
  
@interface MigrationTests : XCTestCase
@end

@implementation MigrationTests {
    OSMigrationController *migrationController;
    OSInfluenceDataRepository *dataRepository;
    OSOutcomeEventsCache *outcomesCache;
}

- (void)setUp {
    [super setUp];
    [UnitTestCommonMethods beforeEachTest:self];
    migrationController = [OSMigrationController new];
    dataRepository = [OSInfluenceDataRepository new];
    outcomesCache = [OSOutcomeEventsCache new];
}

- (void)testNoIndirectInfluenceDataAvailableToMigrate {
    NSArray *lastNotificationReceived = [dataRepository lastNotificationsReceivedData];
    NSInteger sdkVersion = [OneSignalUserDefaults.initShared getSavedIntegerForKey:OSUD_CACHED_SDK_VERSION defaultValue:0];
    XCTAssertNil(lastNotificationReceived);
    XCTAssertEqual(0, sdkVersion);
    [migrationController migrate];
    
    NSArray *lastNotificationReceivedAfterMigration = [dataRepository lastNotificationsReceivedData];
    XCTAssertNil(lastNotificationReceivedAfterMigration);
    
    NSInteger sdkVersionAfterMigration = [OneSignalUserDefaults.initShared getSavedIntegerForKey:OSUD_CACHED_SDK_VERSION defaultValue:0];
    XCTAssertEqual([[OneSignal sdk_version_raw] intValue], sdkVersionAfterMigration);
}

- (void)testIndirectNotificationToIndirectInfluenceMigration {
    NSString *notificationId = @"1234-5678-1234-5678-1234";
    double timestamp = 10;
    OSIndirectNotification *indirectNotification = [[OSIndirectNotification alloc] initWithParamsNotificationId:notificationId timestamp:timestamp];
    NSMutableArray *indirectNotifications = [NSMutableArray new];
    [indirectNotifications addObject:indirectNotification];
    
    [dataRepository saveNotifications:indirectNotifications];
    NSArray *lastNotificationReceived = [dataRepository lastNotificationsReceivedData];
    NSInteger sdkVersion = [OneSignalUserDefaults.initShared getSavedIntegerForKey:OSUD_CACHED_SDK_VERSION defaultValue:0];
    XCTAssertEqual(1, [lastNotificationReceived count]);
    XCTAssertEqual(0, sdkVersion);
    
    [migrationController migrate];

    NSArray<OSIndirectInfluence *> *lastNotificationReceivedAfterMigration = [dataRepository lastNotificationsReceivedData];
    XCTAssertEqual(1, [lastNotificationReceivedAfterMigration count]);

    OSIndirectInfluence *indirectInfluence = [lastNotificationReceivedAfterMigration objectAtIndex:0];
    XCTAssertTrue([indirectInfluence.influenceId isEqualToString:notificationId]);
    XCTAssertTrue([indirectInfluence.channelIdTag isEqualToString:@"notification_id"]);
    XCTAssertEqual(timestamp, indirectInfluence.timestamp);
    
    NSInteger sdkVersionAfterMigration = [OneSignalUserDefaults.initShared getSavedIntegerForKey:OSUD_CACHED_SDK_VERSION defaultValue:0];
    XCTAssertEqual([[OneSignal sdk_version_raw] intValue], sdkVersionAfterMigration);
}

- (void)testIndirectInfluenceToIndirectInfluenceMigration {
    NSString *notificationId = @"1234-5678-1234-5678-1234";
    NSString *channelId = @"notification_id";
    double timestamp = 10;
    OSIndirectInfluence *indirectInfluence = [[OSIndirectInfluence alloc] initWithParamsInfluenceId:notificationId forChannel:channelId timestamp:timestamp];
    NSMutableArray *indirectNotifications = [NSMutableArray new];
    [indirectNotifications addObject:indirectInfluence];
    
    [dataRepository saveNotifications:indirectNotifications];
    NSArray *lastNotificationReceived = [dataRepository lastNotificationsReceivedData];
    NSInteger sdkVersion = [OneSignalUserDefaults.initShared getSavedIntegerForKey:OSUD_CACHED_SDK_VERSION defaultValue:0];
    XCTAssertEqual(1, [lastNotificationReceived count]);
    XCTAssertEqual(0, sdkVersion);
    
    [migrationController migrate];

    NSArray<OSIndirectInfluence *> *lastNotificationReceivedAfterMigration = [dataRepository lastNotificationsReceivedData];
    XCTAssertEqual(1, [lastNotificationReceivedAfterMigration count]);

    OSIndirectInfluence *indirectInfluenceAfterMigration = [lastNotificationReceivedAfterMigration objectAtIndex:0];
    XCTAssertTrue([indirectInfluenceAfterMigration.influenceId isEqualToString:notificationId]);
    XCTAssertTrue([indirectInfluenceAfterMigration.channelIdTag isEqualToString:channelId]);
    XCTAssertEqual(timestamp, indirectInfluenceAfterMigration.timestamp);
    
    NSInteger sdkVersionAfterMigration = [OneSignalUserDefaults.initShared getSavedIntegerForKey:OSUD_CACHED_SDK_VERSION defaultValue:0];
    XCTAssertEqual([[OneSignal sdk_version_raw] intValue], sdkVersionAfterMigration);
}

- (void)testNoAttributedUniqueOutcomeDataAvailableToMigrate {
    NSArray *uniqueOutcomes = [outcomesCache getAttributedUniqueOutcomeEventSent];
    NSInteger sdkVersion = [OneSignalUserDefaults.initShared getSavedIntegerForKey:OSUD_CACHED_SDK_VERSION defaultValue:0];
    XCTAssertNil(uniqueOutcomes);
    XCTAssertEqual(0, sdkVersion);
    [migrationController migrate];
    
    NSArray *uniqueOutcomesAfterMigration = [outcomesCache getAttributedUniqueOutcomeEventSent];
    XCTAssertNil(uniqueOutcomesAfterMigration);
    
    NSInteger sdkVersionAfterMigration = [OneSignalUserDefaults.initShared getSavedIntegerForKey:OSUD_CACHED_SDK_VERSION defaultValue:0];
    XCTAssertEqual([[OneSignal sdk_version_raw] intValue], sdkVersionAfterMigration);
}

- (void)testUniqueOutcomeNotificationToCacheUniqueOutcomeMigration {
    NSString *notificationId = @"1234-5678-1234-5678-1234";
    NSString *outcome = @"test";
    NSNumber *timestamp = @(10);
    OSUniqueOutcomeNotification *uniqueOutcome = [[OSUniqueOutcomeNotification alloc] initWithParamsNotificationId:outcome notificationId:notificationId timestamp:timestamp];
    NSMutableArray *uniqueOutcomes = [NSMutableArray new];
    [uniqueOutcomes addObject:uniqueOutcome];

    [outcomesCache saveAttributedUniqueOutcomeEventNotificationIds:uniqueOutcomes];

    NSArray *lastUniqueOutcomeSaved = [outcomesCache getAttributedUniqueOutcomeEventSent];
    NSInteger sdkVersion = [OneSignalUserDefaults.initShared getSavedIntegerForKey:OSUD_CACHED_SDK_VERSION defaultValue:0];
    XCTAssertEqual(1, [lastUniqueOutcomeSaved count]);
    XCTAssertEqual(0, sdkVersion);
    
    [migrationController migrate];

    NSArray *lastUniqueOutcomeAfterMigration = [outcomesCache getAttributedUniqueOutcomeEventSent];
    XCTAssertEqual(1, [lastUniqueOutcomeAfterMigration count]);

    OSCachedUniqueOutcome *cachedUniqueOutcome = [lastUniqueOutcomeAfterMigration objectAtIndex:0];
    XCTAssertTrue([cachedUniqueOutcome.uniqueId isEqualToString:notificationId]);
    XCTAssertEqual(cachedUniqueOutcome.channel, NOTIFICATION);
    XCTAssertEqual([timestamp intValue], [cachedUniqueOutcome.timestamp intValue]);
    
    NSInteger sdkVersionAfterMigration = [OneSignalUserDefaults.initShared getSavedIntegerForKey:OSUD_CACHED_SDK_VERSION defaultValue:0];
    XCTAssertEqual([[OneSignal sdk_version_raw] intValue], sdkVersionAfterMigration);
}

- (void)testCachedUniqueOutcomeToCachedUniqueOutcomeMigration {
    NSString *notificationId = @"1234-5678-1234-5678-1234";
    NSString *outcome = @"test";
    NSNumber *timestamp = @(10);
    OSCachedUniqueOutcome *cachedUniqueOutcome = [[OSCachedUniqueOutcome alloc] initWithParamsName:outcome uniqueId:notificationId timestamp:timestamp channel:NOTIFICATION];
    NSMutableArray *cacheUniqueOutcomes = [NSMutableArray new];
    [cacheUniqueOutcomes addObject:cachedUniqueOutcome];
    
    [outcomesCache saveAttributedUniqueOutcomeEventNotificationIds:cacheUniqueOutcomes];
    NSArray *lastCachedUniqueOutcomes = [outcomesCache getAttributedUniqueOutcomeEventSent];
    NSInteger sdkVersion = [OneSignalUserDefaults.initShared getSavedIntegerForKey:OSUD_CACHED_SDK_VERSION defaultValue:0];
    XCTAssertEqual(1, [lastCachedUniqueOutcomes count]);
    XCTAssertEqual(0, sdkVersion);
    
    [migrationController migrate];

    NSArray<OSCachedUniqueOutcome *> *lastCachedUniqueOutcomesAfterMigration = [outcomesCache getAttributedUniqueOutcomeEventSent];
    XCTAssertEqual(1, [lastCachedUniqueOutcomesAfterMigration count]);

    OSCachedUniqueOutcome *cachedUniqueOutcomeAfterMigration = [lastCachedUniqueOutcomesAfterMigration objectAtIndex:0];
    XCTAssertTrue([cachedUniqueOutcomeAfterMigration.name isEqualToString:outcome]);
    XCTAssertTrue([cachedUniqueOutcomeAfterMigration.uniqueId isEqualToString:notificationId]);
    XCTAssertEqual(NOTIFICATION, cachedUniqueOutcomeAfterMigration.channel);
    XCTAssertEqual([timestamp intValue], [cachedUniqueOutcomeAfterMigration.timestamp intValue]);
    
    NSInteger sdkVersionAfterMigration = [OneSignalUserDefaults.initShared getSavedIntegerForKey:OSUD_CACHED_SDK_VERSION defaultValue:0];
    XCTAssertEqual([[OneSignal sdk_version_raw] intValue], sdkVersionAfterMigration);
}

@end
