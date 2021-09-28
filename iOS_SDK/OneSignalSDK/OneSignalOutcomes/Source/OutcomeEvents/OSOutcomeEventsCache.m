/**
Modified MIT License

Copyright 2020 OneSignal

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

1. The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

2. All copies of substantial portions of the Software may only be used in connection
with services provided by OneSignal.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
*/

#import <Foundation/Foundation.h>
#import "OSOutcomeEventsCache.h"
#import "OneSignalUserDefaults.h"
#import "OneSignalCommonDefines.h"

@implementation OSOutcomeEventsCache

// Get current outcome service enabled. If V2 enabled return true otherwise false
- (BOOL)isOutcomesV2ServiceEnabled {
    return [OneSignalUserDefaults.initShared getSavedBoolForKey:OSUD_OUTCOMES_V2 defaultValue:NO];
}

// Save iOS param value for outcomes_v2_service_enabled
- (void)saveOutcomesV2ServiceEnabled:(BOOL)isEnabled {
    [OneSignalUserDefaults.initShared saveBoolForKey:OSUD_OUTCOMES_V2 withValue:isEnabled];
}

// Save the current set of UNATTRIBUTED unique outcome names to NSUserDefaults
- (NSSet *)getUnattributedUniqueOutcomeEventsSent {
    return [OneSignalUserDefaults.initShared getSavedSetForKey:OSUD_CACHED_UNATTRIBUTED_UNIQUE_OUTCOME_EVENTS_SENT defaultValue:nil];
}

// Save the current set of UNATTRIBUTED unique outcome names to NSUserDefaults
- (void)saveUnattributedUniqueOutcomeEventsSent:(NSSet *)unattributedUniqueOutcomeEventsSentSet {
    [OneSignalUserDefaults.initShared saveSetForKey:OSUD_CACHED_UNATTRIBUTED_UNIQUE_OUTCOME_EVENTS_SENT withValue:unattributedUniqueOutcomeEventsSentSet];
}

// Keeps track of unique outcome events sent for ATTRIBUTED sessions on a per notification level
- (NSArray *)getAttributedUniqueOutcomeEventSent {
    return [OneSignalUserDefaults.initShared getSavedCodeableDataForKey:OSUD_CACHED_ATTRIBUTED_UNIQUE_OUTCOME_EVENT_NOTIFICATION_IDS_SENT defaultValue:nil];
}

// Save the current set of ATTRIBUTED unique outcome names and notificationIds to NSUserDefaults
- (void)saveAttributedUniqueOutcomeEventNotificationIds:(NSArray *)attributedUniqueOutcomeEventNotificationIdsSent {
    [OneSignalUserDefaults.initShared saveCodeableDataForKey:OSUD_CACHED_ATTRIBUTED_UNIQUE_OUTCOME_EVENT_NOTIFICATION_IDS_SENT withValue:attributedUniqueOutcomeEventNotificationIdsSent];
}

@end
