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

#import <OneSignalCore/OneSignalCore.h>
#import <OneSignalOutcomes/OneSignalOutcomes.h>
#import "OneSignalNotificationServiceExtensionHandler.h"
#import "OneSignalExtensionBadgeHandler.h"
#import "OneSignalReceiveReceiptsController.h"
#import "OSSessionManager.h"
//#import "OSMigrationController.h"
#import "OneSignalAttachmentHandler.h"

@implementation OneSignalNotificationServiceExtensionHandler

+ (UNMutableNotificationContent*)didReceiveNotificationExtensionRequest:(UNNotificationRequest*)request
                                         withMutableNotificationContent:(UNMutableNotificationContent*)replacementContent {
    return [OneSignalNotificationServiceExtensionHandler
            didReceiveNotificationExtensionRequest:request
            withMutableNotificationContent:replacementContent
            withContentHandler:nil];
}

+ (UNMutableNotificationContent*)didReceiveNotificationExtensionRequest:(UNNotificationRequest*)request             withMutableNotificationContent:(UNMutableNotificationContent*)replacementContent
                withContentHandler:(void (^)(UNNotificationContent * _Nonnull))contentHandler {
    [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:@"NSE request received"];
    
    if (!replacementContent)
        replacementContent = [request.content mutableCopy];
    
    /*
        Add the collapse Id (request.identifier) to userInfo
        so it can be parsed by parseWithApns outside of the extension
    */
    replacementContent.userInfo = [self userInfoWithCollapseId:replacementContent.userInfo
                                                     identifier:request.identifier];
    
    OSNotification *notification = [OSNotification parseWithApns:replacementContent.userInfo];

    // Handle badge count
    [OneSignalExtensionBadgeHandler handleBadgeCountWithNotificationRequest:request withNotification:notification withMutableNotificationContent:replacementContent];
    
    // Track receieved
    [OneSignalTrackFirebaseAnalytics trackReceivedEvent:notification];

    // Action Buttons
    [self addActionButtonsToExtentionRequest:request
                                 withNotification:notification
              withMutableNotificationContent:replacementContent];
    
    // Get and check the received notification id
    NSString *receivedNotificationId = notification.notificationId;
    
    // Trigger the notification to be shown with the replacementContent
    if (contentHandler) {
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
        [self onNotificationReceived:receivedNotificationId withBlockingTask:semaphore];
        // Download Media Attachments after kicking off the confirmed delivery task
        [OneSignalAttachmentHandler addAttachments:notification toNotificationContent:replacementContent];
        contentHandler(replacementContent);
        dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, MAX_NSE_LIFETIME_SECOUNDS * NSEC_PER_SEC));
    } else {
        [self onNotificationReceived:receivedNotificationId withBlockingTask:nil];
        // Download Media Attachments
        [OneSignalAttachmentHandler addAttachments:notification toNotificationContent:replacementContent];
    }

    return replacementContent;
}

+ (NSDictionary *)userInfoWithCollapseId:(NSDictionary *)userInfo identifier:(NSString *)identifier {
    NSMutableDictionary *userInfoWithCollapseId = [NSMutableDictionary dictionaryWithDictionary:userInfo];
    if (userInfoWithCollapseId[@"os_data"]) {
        NSMutableDictionary *osdataDict = [NSMutableDictionary dictionaryWithDictionary:userInfoWithCollapseId[@"os_data"]];
        osdataDict[@"collapse_id"] = identifier;
        userInfoWithCollapseId[@"os_data"] = osdataDict;
    } else if (userInfoWithCollapseId[@"custom"]) {
        NSMutableDictionary *customDict = [NSMutableDictionary dictionaryWithDictionary:userInfoWithCollapseId[@"custom"]];
        customDict[@"collapse_id"] = identifier;
        userInfoWithCollapseId[@"custom"] = customDict;
    }
    
    return userInfoWithCollapseId;
}

+ (UNMutableNotificationContent*)serviceExtensionTimeWillExpireRequest:(UNNotificationRequest*)request
                                        withMutableNotificationContent:(UNMutableNotificationContent*)replacementContent {
    if (!replacementContent)
        replacementContent = [request.content mutableCopy];
    
    let notification = [OSNotification parseWithApns:request.content.userInfo];
    
    [self addActionButtonsToExtentionRequest:request
                                 withNotification:notification
              withMutableNotificationContent:replacementContent];
    
    return replacementContent;
}

+ (void)addActionButtonsToExtentionRequest:(UNNotificationRequest*)request
                               withNotification:(OSNotification*)notification
            withMutableNotificationContent:(UNMutableNotificationContent*)replacementContent {
    
    // If the developer already set a category don't replace it with our generated one.
    if (request.content.categoryIdentifier && ![request.content.categoryIdentifier isEqualToString:@""])
        return;
    
    [OneSignalAttachmentHandler addActionButtons:notification toNotificationContent:replacementContent];
}

+ (void)onNotificationReceived:(NSString *)receivedNotificationId withBlockingTask:(dispatch_semaphore_t)semaphore {
    if (receivedNotificationId && ![receivedNotificationId isEqualToString:@""]) {
        // ECM TODO: We probably need to rearchitect migrations a bit. Each module needs to migrate the models it is responsible for
        // If update was made without app being initialized/launched before -> migrate
//        [[OSMigrationController new] migrate];
        [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"NSE request received, sessionManager: %@", [OSSessionManager sharedSessionManager]]];
        // Save received notification id
        [[OSSessionManager sharedSessionManager] onNotificationReceived:receivedNotificationId];
        
        // Track confirmed delivery
        let sharedUserDefaults = OneSignalUserDefaults.initShared;
        let playerId = [sharedUserDefaults getSavedStringForKey:OSUD_PLAYER_ID_TO defaultValue:nil];
        let appId = [sharedUserDefaults getSavedStringForKey:OSUD_APP_ID defaultValue:nil];
        // Randomize send of confirmed deliveries to lessen traffic for high recipient notifications
        int randomDelay = semaphore != nil ? arc4random_uniform(MAX_CONF_DELIVERY_DELAY) : 0;
        [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"OneSignal onNotificationReceived sendReceiveReceipt with delay: %i", randomDelay]];
        
        OneSignalReceiveReceiptsController *controller = [OneSignalReceiveReceiptsController new];
        [controller sendReceiveReceiptWithPlayerId:playerId notificationId:receivedNotificationId appId:appId delay:randomDelay successBlock:^(NSDictionary *result) {
            [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"OneSignal onNotificationReceived sendReceiveReceipt Success for playerId: %@ result: %@", playerId, result]];
            if (semaphore) {
                dispatch_semaphore_signal(semaphore);
            }
        } failureBlock:^(NSError *error) {
            [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"OneSignal onNotificationReceived sendReceiveReceipt Failed for playerId: %@ error:%@", playerId, error.localizedDescription]];
            if (semaphore) {
                dispatch_semaphore_signal(semaphore);
            }
        }];
   }
}

@end
