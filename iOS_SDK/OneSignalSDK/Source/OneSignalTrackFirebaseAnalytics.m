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

#import "OneSignalTrackFirebaseAnalytics.h"
#import "OneSignalHelper.h"

@implementation OneSignalTrackFirebaseAnalytics

static NSTimeInterval lastOpenedTime = 0;
static var trackingEnabled = false;

// Only need to download remote params if app includes Firebase analytics
+(BOOL)needsRemoteParams {
    return NSClassFromString(@"FIRAnalytics") != nil;
}

// Called from both main target and extension
// Note: Not checking for FIRAnalytics class existence here since the library isn't needed on the
//         extension target to track inflenced opens.
+(void)init {
    let userDefaults = [[NSUserDefaults alloc] initWithSuiteName:[self appGroupKey]];
    trackingEnabled = [userDefaults boolForKey:@"OS_ENABLE_FIREBASE_ANALYTICS"];
}


+(void)updateFromDownloadParams:(NSDictionary*)params {
    trackingEnabled = (BOOL)params[@"fba"];
    let userDefaults = [[NSUserDefaults alloc] initWithSuiteName:[self appGroupKey]];
    if (trackingEnabled)
        [userDefaults setBool:true forKey:@"OS_ENABLE_FIREBASE_ANALYTICS"];
    else
        [userDefaults removeObjectForKey:@"OS_ENABLE_FIREBASE_ANALYTICS"];
}

+(NSString*)appGroupKey {
    NSString *groupKey = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"OneSignal_app_groups_key"];
    return [groupKey stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
}

+(void)logEventWithName:(NSString*)name parameters:(NSDictionary*)params {
    id firAnalyticsClass = NSClassFromString(@"FIRAnalytics");
    if (!firAnalyticsClass)
        return;
    
    [firAnalyticsClass performSelector:@selector(logEventWithName:parameters:)
                            withObject:name
                            withObject:params];
}

+(NSString*)getCampaignNameFromPayload:(OSNotificationPayload*)payload {
    if (payload.templateName && payload.templateID)
        return [NSString stringWithFormat:@"%@ - %@", payload.templateName, payload.templateID];
    if (!payload.title)
        return @"";
    
    var titleLength = payload.title.length;
    if (titleLength > 10)
        titleLength = 10;
    
    return [payload.title substringToIndex:titleLength];
}

+(void)trackOpenEvent:(OSNotificationOpenedResult*)results {
    if (!trackingEnabled)
        return;
    
    lastOpenedTime = [[NSDate date] timeIntervalSince1970];
    
    [self logEventWithName:@"os_notification_opened"
                parameters:@{
                             @"source": @"OneSignal",
                             @"medium": @"notification",
                             @"notification_id": results.notification.payload.notificationID,
                             @"campaign": [self getCampaignNameFromPayload:results.notification.payload]
                             }];
}

+(void)trackReceivedEvent:(OSNotificationPayload*)payload {
    if (!trackingEnabled)
        return;
    
    let campaign = [self getCampaignNameFromPayload:payload];
    let userDefaults = [[NSUserDefaults alloc] initWithSuiteName:[self appGroupKey]];
    [userDefaults setObject:payload.notificationID forKey:@"OS_LAST_RECIEVED_NOTIFICATION_ID"];
    [userDefaults setObject:campaign forKey:@"OS_LAST_RECIEVED_GAF_CAMPAIGN"];
    [userDefaults setDouble:[[NSDate date] timeIntervalSince1970] forKey:@"OS_LAST_RECIEVED_TIME"];
    [userDefaults synchronize];
    
    [self logEventWithName:@"os_notification_received"
                parameters:@{
                             @"source": @"OneSignal",
                             @"medium": @"notification",
                             @"notification_id": payload.notificationID,
                             @"campaign": campaign
                             }];
}

+(void)trackInfluenceOpenEvent {
    if (!trackingEnabled)
        return;
    
    let userDefaults = [[NSUserDefaults alloc] initWithSuiteName:[self appGroupKey]];
    NSTimeInterval lastTimeReceived = [userDefaults doubleForKey:@"OS_LAST_RECIEVED_TIME"];
    
    if (lastTimeReceived == 0)
        return;
    
    let now = [[NSDate date] timeIntervalSince1970];
    
    // Attribute if app was opened in 2 minutes or less after displaying the notification
    if (now - lastTimeReceived > 120)
        return;
    
    // Don't attribute if we opened a notification in the last 30 secounds.
    //  To prevent an open and an influenced open from firing for the same notification.
    if (now - lastOpenedTime < 30)
        return;
    
    NSString *notificationId = [userDefaults objectForKey:@"OS_LAST_RECIEVED_NOTIFICATION_ID"];
    NSString *campaign = [userDefaults objectForKey:@"OS_LAST_RECIEVED_GAF_CAMPAIGN"];
    
    [self logEventWithName:@"os_notification_influence_open"
                parameters:@{
                             @"source": @"OneSignal",
                             @"medium": @"notification",
                             @"notification_id": notificationId,
                             @"campaign": campaign
                             }];
}

@end
