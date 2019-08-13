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

#import <Foundation/Foundation.h>
#import "OneSignalHelper.h"
#import "OneSignalCommonDefines.h"
#import "NotificationData.h"
#import "LastNotification.h"
#import "OneSignalExtensionBadgeHandler.h"

@implementation NotificationData

+(NSString*)appGroupKey {
    return [OneSignalExtensionBadgeHandler appGroupName];
}

+ (void)saveLastNotificationFromBackground:(NSString * _Nullable)notificationId {
    if (notificationId == nil) {
        let lastNotificationId = [self getLastNotificationId];
        if (lastNotificationId != nil)
            [self saveLastNotificationWithBackground:lastNotificationId wasOnBackground:YES];
    } else {
        [self saveLastNotificationWithBackground:notificationId wasOnBackground:YES];
    }
}

+ (void)saveLastNotification:(NSString * _Nullable)notificationId {
    [self saveLastNotificationWithBackground:notificationId wasOnBackground:NO];
}

+ (void)saveLastNotificationWithBackground:(NSString * _Nullable)notificationId wasOnBackground:(BOOL)wasOnBackground {
    let userDefaults = [[NSUserDefaults alloc] initWithSuiteName:[self appGroupKey]];
    NSTimeInterval timeInSeconds = [[NSDate date] timeIntervalSince1970];
    
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"Last notification id : %@", notificationId]];
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"Last notification was on background: %@", wasOnBackground ? @"YES" : @"NO"]];
    
    [userDefaults setObject:notificationId forKey:NOTIFICATION_ID];
    [userDefaults setObject:[NSNumber numberWithDouble:timeInSeconds] forKey:NOTIFICATION_TIME];
    [userDefaults setBool:wasOnBackground forKey:NOTIFICATION_FROM_BACKGROUND];
    
    [userDefaults synchronize];
}

+ (LastNotification * _Nonnull)getLastNotification {
    let userDefaults = [[NSUserDefaults alloc] initWithSuiteName:[self appGroupKey]];
    return [[LastNotification alloc] initWithParamsNotificationId:[userDefaults stringForKey:NOTIFICATION_ID]
                                                       arrivalTime:[userDefaults doubleForKey:NOTIFICATION_TIME]
                                                   wasOnBackground:[userDefaults boolForKey:NOTIFICATION_FROM_BACKGROUND]];
}

+ (NSString * _Nullable)getLastNotificationId {
    let userDefaults = [[NSUserDefaults alloc] initWithSuiteName:[self appGroupKey]];
    return [userDefaults stringForKey:NOTIFICATION_ID];
}

@end
