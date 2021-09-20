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

#import <Foundation/Foundation.h>
#import "OneSignalCacheCleaner.h"
#import "OneSignalCommonDefines.h"
#import "OSCachedUniqueOutcome.h"
#import "OneSignalUserDefaults.h"
#import "OneSignalHelper.h"
//#import <OneSignalSwift/OneSignalSwift-Swift.h>

@implementation OneSignalCacheCleaner

+ (void)cleanCachedUserData {
    [self cleanUniqueOutcomeNotifications];
    [OneSignalHelper clearCachedMedia];
    //[OneSignalSwift swiftTest];
}

/*
 Iterate through all stored cached OSUniqueOutcomeNotification and clean any items over 7 days old
 */
+ (void)cleanUniqueOutcomeNotifications {
    NSArray *uniqueOutcomeNotifications = [OneSignalUserDefaults.initShared getSavedCodeableDataForKey:OSUD_CACHED_ATTRIBUTED_UNIQUE_OUTCOME_EVENT_NOTIFICATION_IDS_SENT defaultValue:nil];
    
    NSTimeInterval timeInSeconds = [[NSDate date] timeIntervalSince1970];
    NSMutableArray *finalNotifications = [NSMutableArray new];
    for (OSCachedUniqueOutcome *notif in uniqueOutcomeNotifications) {
        
        // Save notif if it has been stored for less than or equal to a week
        NSTimeInterval diff = timeInSeconds - [notif.timestamp doubleValue];
        if (diff <= WEEK_IN_SECONDS)
            [finalNotifications addObject:notif];
    }
    
    [OneSignalUserDefaults.initShared saveCodeableDataForKey:OSUD_CACHED_ATTRIBUTED_UNIQUE_OUTCOME_EVENT_NOTIFICATION_IDS_SENT withValue:finalNotifications];
}

@end
