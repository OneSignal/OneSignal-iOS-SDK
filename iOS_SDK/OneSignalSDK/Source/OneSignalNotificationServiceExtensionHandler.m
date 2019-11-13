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

#import "OneSignalNotificationServiceExtensionHandler.h"
#import "OneSignalExtensionBadgeHandler.h"
#import "OneSignalHelper.h"
#import "OSOutcomesUtils.h"
#import "OneSignalTrackFirebaseAnalytics.h"
#import "OSNotificationPayload+Internal.h"

@implementation OneSignalNotificationServiceExtensionHandler

+(UNMutableNotificationContent*)didReceiveNotificationExtensionRequest:(UNNotificationRequest*)request
                                        withMutableNotificationContent:(UNMutableNotificationContent*)replacementContent {
    if (!replacementContent)
        replacementContent = [request.content mutableCopy];
    
    let payload = [OSNotificationPayload parseWithApns:request.content.userInfo];
    
    //handle badge count
    [OneSignalExtensionBadgeHandler handleBadgeCountWithNotificationRequest:request withNotificationPayload:payload withMutableNotificationContent:replacementContent];
    
    // Track receieved
    [OneSignalTrackFirebaseAnalytics trackReceivedEvent:payload];
    
    [OSOutcomesUtils saveReceivedNotificationWithBackground:payload.notificationID fromBackground:[[UIApplication sharedApplication] applicationState] != UIApplicationStateActive];

    // Action Buttons
    [self addActionButtonsToExtentionRequest:request
                                 withPayload:payload
              withMutableNotificationContent:replacementContent];
    
    // Media Attachments
    [OneSignalHelper addAttachments:payload toNotificationContent:replacementContent];
    
    return replacementContent;
}

+(UNMutableNotificationContent*)serviceExtensionTimeWillExpireRequest:(UNNotificationRequest*)request
                                       withMutableNotificationContent:(UNMutableNotificationContent*)replacementContent {
    if (!replacementContent)
        replacementContent = [request.content mutableCopy];
    
    let payload = [OSNotificationPayload parseWithApns:request.content.userInfo];
    
    [self addActionButtonsToExtentionRequest:request
                                 withPayload:payload
              withMutableNotificationContent:replacementContent];
    
    return replacementContent;
}

+(void)addActionButtonsToExtentionRequest:(UNNotificationRequest*)request
                               withPayload:(OSNotificationPayload*)payload
            withMutableNotificationContent:(UNMutableNotificationContent*)replacementContent {
    // If the developer already set a category don't replace it with our generated one.
    if (request.content.categoryIdentifier && ![request.content.categoryIdentifier isEqualToString:@""])
        return;
    
    [OneSignalHelper addActionButtons:payload toNotificationContent:replacementContent];
}

@end
