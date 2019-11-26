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

#import "OneSignalHelper.h"
#import "OneSignalUserDefaults.h"
#import "OneSignalCommonDefines.h"
#import "OneSignalExtensionBadgeHandler.h"
#import "OneSignalTrackFirebaseAnalytics.h"

@implementation OneSignalTrackFirebaseAnalytics

static NSTimeInterval lastOpenedTime = 0;
static var trackingEnabled = false;

// Only need to download remote params if app includes Firebase analytics
+ (BOOL)needsRemoteParams {
    return NSClassFromString(@"FIRAnalytics") != nil;
}

// Called from both main target and extension
// Note: Not checking for FIRAnalytics class existence here since the library isn't needed on the
//         extension target to track inflenced opens.
+ (void)init {
    trackingEnabled = [OneSignalUserDefaults.initShared getSavedBoolForKey:ONESIGNAL_FB_ENABLE_FIREBASE defaultValue:false];
}


+ (void)updateFromDownloadParams:(NSDictionary*)params {
    trackingEnabled = (BOOL)params[@"fba"];
    let sharedUserDefaults = OneSignalUserDefaults.initShared;
    if (trackingEnabled)
        [sharedUserDefaults saveBoolForKey:ONESIGNAL_FB_ENABLE_FIREBASE withValue:true];
    else
        [sharedUserDefaults removeValueForKey:ONESIGNAL_FB_ENABLE_FIREBASE];
}

+ (NSString*)appGroupKey {
    return [OneSignalExtensionBadgeHandler appGroupName];
}

+ (void)logEventWithName:(NSString*)name parameters:(NSDictionary*)params {
    id firAnalyticsClass = NSClassFromString(@"FIRAnalytics");
    if (!firAnalyticsClass)
        return;
    
    [firAnalyticsClass performSelector:@selector(logEventWithName:parameters:)
                            withObject:name
                            withObject:params];
}

+ (NSString*)getCampaignNameFromPayload:(OSNotificationPayload*)payload {
    if (payload.templateName && payload.templateID)
        return [NSString stringWithFormat:@"%@ - %@", payload.templateName, payload.templateID];
    if (!payload.title)
        return @"";
    
    var titleLength = payload.title.length;
    if (titleLength > 10)
        titleLength = 10;
    
    return [payload.title substringToIndex:titleLength];
}

+ (void)trackOpenEvent:(OSNotificationOpenedResult*)results {
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

+ (void)trackReceivedEvent:(OSNotificationPayload*)payload {
    if (!trackingEnabled)
        return;
    
    let campaign = [self getCampaignNameFromPayload:payload];
    let sharedUserDefaults = OneSignalUserDefaults.initShared;
    [sharedUserDefaults saveStringForKey:ONESIGNAL_FB_LAST_NOTIFICATION_ID_RECEIVED withValue:payload.notificationID];
    [sharedUserDefaults saveStringForKey:ONESIGNAL_FB_LAST_GAF_CAMPAIGN_RECEIVED withValue:campaign];
    [sharedUserDefaults saveDoubleForKey:ONESIGNAL_FB_LAST_TIME_RECEIVED withValue:[[NSDate date] timeIntervalSince1970]];
    
    [self logEventWithName:@"os_notification_received"
                parameters:@{
                    @"source": @"OneSignal",
                    @"medium": @"notification",
                    @"notification_id": payload.notificationID,
                    @"campaign": campaign
                }];
}

+ (void)trackInfluenceOpenEvent {
    if (!trackingEnabled)
        return;
    
    let sharedUserDefaults = OneSignalUserDefaults.initShared;
    NSTimeInterval lastTimeReceived = [sharedUserDefaults getSavedDoubleForKey:ONESIGNAL_FB_LAST_TIME_RECEIVED defaultValue:0];
    
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
    
    NSString *notificationId = [sharedUserDefaults getSavedStringForKey:ONESIGNAL_FB_LAST_NOTIFICATION_ID_RECEIVED defaultValue:nil];
    NSString *campaign = [sharedUserDefaults getSavedStringForKey:ONESIGNAL_FB_LAST_GAF_CAMPAIGN_RECEIVED defaultValue:nil];
    
    [self logEventWithName:@"os_notification_influence_open"
                parameters:@{
                    @"source": @"OneSignal",
                    @"medium": @"notification",
                    @"notification_id": notificationId,
                    @"campaign": campaign
                }];
}

@end
