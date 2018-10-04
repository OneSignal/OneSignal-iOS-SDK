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
#import "OneSignalCommonDefines.h"
#import "OneSignalTrackFirebaseAnalytics.h"
#import "OSNotificationPayload+Internal.h"
#import "OneSignalShared.h"

@implementation OneSignalExtensionBadgeHandler

+ (void)handleBadgeCountWithNotificationRequest:(UNNotificationRequest *)request withNotificationPayload:(OSNotificationPayload *)payload withMutableNotificationContent:(UNMutableNotificationContent *)replacementContent {
    
    //if the user is setting the badge directly instead of incrementing/decrementing,
    //make sure the OneSignal cached value is updated to this value
    if (!payload.badgeIncrement) {
        if (payload.badge)
            [OneSignalExtensionBadgeHandler updateCachedBadgeValue:payload.badge];
        
        return;
    }
    
    var currentValue = (int)OneSignalExtensionBadgeHandler.currentCachedBadgeValue ?: 0;
    
    currentValue += (int)payload.badgeIncrement;
    
    //cannot have negative badge values
    if (currentValue < 0)
        currentValue = 0;
    
    replacementContent.badge = @(currentValue);
    
    [OneSignalExtensionBadgeHandler updateCachedBadgeValue:currentValue];
}

+ (NSInteger)currentCachedBadgeValue {
    let userDefaults = [[NSUserDefaults alloc] initWithSuiteName:OneSignalExtensionBadgeHandler.appGroupName];
    
    return [(NSNumber *)[userDefaults objectForKey:ONESIGNAL_BADGE_KEY] integerValue];
}

//gets the NSBundle of the primary application - NOT the app extension
//this way we can determine the bundle ID for the host (primary) application.
+ (NSString *)primaryBundleIdentifier {
    var bundle = [NSBundle mainBundle];
    if ([[bundle.bundleURL pathExtension] isEqualToString:@"appex"])
        bundle = [NSBundle bundleWithURL:[[bundle.bundleURL URLByDeletingLastPathComponent] URLByDeletingLastPathComponent]];
    
    return [bundle bundleIdentifier];
    
}

+ (void)updateCachedBadgeValue:(NSInteger)value {
    //since badge logic can be executed in an extension, we need to use app groups to get
    //a shared NSUserDefaults from the app group suite name
    let userDefaults = [[NSUserDefaults alloc] initWithSuiteName:OneSignalExtensionBadgeHandler.appGroupName];
    
    [userDefaults setObject:@(value) forKey:ONESIGNAL_BADGE_KEY];
    
    [userDefaults synchronize];
}

+ (NSString *)appGroupName {
    var appGroupName = (NSString *)[[NSBundle mainBundle] objectForInfoDictionaryKey:ONESIGNAL_APP_GROUP_NAME_KEY];
    
    if (!appGroupName)
        appGroupName = [NSString stringWithFormat:@"group.%@.%@", OneSignalExtensionBadgeHandler.primaryBundleIdentifier, @"onesignal"];
    
    return [appGroupName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
}

@end
