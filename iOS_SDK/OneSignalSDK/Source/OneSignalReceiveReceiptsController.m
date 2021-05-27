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
#import "OneSignalReceiveReceiptsController.h"
#import "Requests.h"
#import "OneSignalClient.h"
#import "OSSubscription.h"
#import "OneSignalCommonDefines.h"
#import "OneSignalUserDefaults.h"

@implementation OneSignalReceiveReceiptsController

- (BOOL)isReceiveReceiptsEnabled {
    return [OneSignalUserDefaults.initShared getSavedBoolForKey:OSUD_RECEIVE_RECEIPTS_ENABLED defaultValue:NO];
}

- (void)sendReceiveReceiptWithNotificationId:(NSString *)notificationId {
    let sharedUserDefaults = OneSignalUserDefaults.initShared;
    let playerId = [sharedUserDefaults getSavedStringForKey:OSUD_PLAYER_ID_TO defaultValue:nil];
    let appId = [sharedUserDefaults getSavedStringForKey:OSUD_APP_ID defaultValue:nil];

    [self sendReceiveReceiptWithPlayerId:playerId
                          notificationId:notificationId
                                   appId:appId];
}

- (void)sendReceiveReceiptWithPlayerId:(NSString *)playerId notificationId:(NSString *)notificationId appId:(NSString *)appId {
    [self sendReceiveReceiptWithPlayerId:playerId
                          notificationId:notificationId
                                   appId:appId
                            successBlock:nil
                            failureBlock:nil];
}

- (void)sendReceiveReceiptWithPlayerId:(nonnull NSString *)playerId
                        notificationId:(nonnull NSString *)notificationId
                                 appId:(nonnull NSString *)appId
                          successBlock:(nullable OSResultSuccessBlock)success
                          failureBlock:(nullable OSFailureBlock)failure {
    
    [self sendReceiveReceiptWithPlayerId:playerId
                          notificationId:notificationId
                                   appId:appId
                                   delay:0
                            successBlock:nil
                            failureBlock:nil];
}

- (void)sendReceiveReceiptWithPlayerId:(nonnull NSString *)playerId
                        notificationId:(nonnull NSString *)notificationId
                                 appId:(nonnull NSString *)appId
                                 delay:(int)delay
                          successBlock:(nullable OSResultSuccessBlock)success
                          failureBlock:(nullable OSFailureBlock)failure {
    
    let message = [NSString stringWithFormat:@"OneSignal sendReceiveReceiptWithPlayerId playerId:%@ notificationId: %@, appId: %@", playerId, notificationId, appId];
    [OneSignal onesignal_Log:ONE_S_LL_DEBUG message:message];

    if (!appId) {
        [OneSignal onesignal_Log:ONE_S_LL_DEBUG message:@"appId not available from shared UserDefaults!"];
        return;
    }
    
    if (![self isReceiveReceiptsEnabled]) {
        [OneSignal onesignal_Log:ONE_S_LL_DEBUG message:@"Receieve receipts disabled"];
        return;
    }

    let request = [OSRequestReceiveReceipts withPlayerId:playerId notificationId:notificationId appId:appId];
    
    dispatch_time_t dispatchTime = dispatch_time(DISPATCH_TIME_NOW, delay * NSEC_PER_SEC);
    dispatch_after(dispatchTime, dispatch_get_main_queue(), ^{
        [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"OneSignal sendReceiveReceiptWithPlayerId now sending confirmed delievery after: %i second delay", delay]];
        [OneSignalClient.sharedClient executeRequest:request onSuccess:^(NSDictionary *result) {
            if (success) {
                success(result);
            }
        } onFailure:^(NSError *error) {
            if (failure) {
                failure(error);
            }
        }];
    });
}

@end
