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

#import "OneSignalExtensionBadgeHandler.h"

@implementation OneSignalExtensionBadgeHandler

+ (void)handleBadgeCountWithNotificationRequest:(UNNotificationRequest *)request withNotification:(OSNotification *)notification withMutableNotificationContent:(UNMutableNotificationContent *)replacementContent {
    
    //if the user is setting the badge directly instead of incrementing/decrementing,
    //make sure the OneSignal cached value is updated to this value
    if (!notification.badgeIncrement) {
        if (notification.hasBadge)
            [OneSignalBadgeHelpers updateCachedBadgeValue:notification.badge usePreviousBadgeCount:false];
        
        return;
    }
    
    int currentValue = (int)OneSignalExtensionBadgeHandler.currentCachedBadgeValue ?: 0;
    
    currentValue += (int)notification.badgeIncrement;
    
    //cannot have negative badge values
    if (currentValue < 0)
        currentValue = 0;
    
    replacementContent.badge = @(currentValue);
    
    [OneSignalBadgeHelpers updateCachedBadgeValue:currentValue usePreviousBadgeCount:false];
}

+ (NSInteger)currentCachedBadgeValue {
    return [OneSignalUserDefaults.initShared getSavedIntegerForKey:ONESIGNAL_BADGE_KEY defaultValue:0];
}

@end
