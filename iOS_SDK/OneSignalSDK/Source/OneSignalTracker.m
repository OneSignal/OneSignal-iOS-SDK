/**
 * Modified MIT License
 *
 * Copyright 2016 OneSignal
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

#import <UIKit/UIKit.h>

#import "OneSignalInternal.h"
#import "OneSignalTracker.h"
#import "OneSignalWebView.h"
#import <OneSignalCore/OneSignalCore.h>
#import <OneSignalOutcomes/OneSignalOutcomes.h>
#import "OSFocusTimeProcessorFactory.h"
#import "OSFocusCallParams.h"
#import "OSFocusInfluenceParam.h"

@interface OneSignal ()

+ (BOOL)shouldStartNewSession;
+ (void)startNewSession:(BOOL)fromInit;
+ (BOOL)sendNotificationTypesUpdate;
+ (NSString*)mUserId;
+ (NSString *)mEmailUserId;
+ (NSString *)mEmailAuthToken;
+ (NSString *)mExternalIdAuthToken;

@end

@implementation OneSignalTracker

static BOOL lastOnFocusWasToBackground = YES;

+ (void)onFocus:(BOOL)toBackground {
    // return if the user has not granted privacy permissions
    if ([OSPrivacyConsentController requiresUserPrivacyConsent])
        return;
    
    // Prevent the onFocus to be called twice when app being terminated
    //    - Both WillResignActive and willTerminate
    if (lastOnFocusWasToBackground == toBackground)
        return;
    lastOnFocusWasToBackground = toBackground;
    
    if (toBackground) {
        [self applicationBackgrounded];
    } else {
        [self applicationBecameActive];
    }
}

+ (void)applicationBecameActive {
    [OneSignalLog onesignalLog:ONE_S_LL_DEBUG message:@"Application Active started"];
    [OSFocusTimeProcessorFactory cancelFocusCall];
    
    if (OSSessionManager.sharedSessionManager.appEntryState != NOTIFICATION_CLICK)
        OSSessionManager.sharedSessionManager.appEntryState = APP_OPEN;
   
    [OSSessionManager.sharedSessionManager setLastOpenedTime:[[NSDate date] timeIntervalSince1970]];
    
    // on_session tracking when resumming app.
    if ([OneSignal shouldStartNewSession])
        [OneSignal startNewSession:NO];
    else {
        [[OSSessionManager sharedSessionManager] attemptSessionUpgrade];
        // TODO: Here it used to call receivedInAppMessageJson with nil, this method no longer exists
        // [OneSignal receivedInAppMessageJson:nil];
    }
}

+ (void)applicationBackgrounded {
    [OneSignalLog onesignalLog:ONE_S_LL_DEBUG message:@"Application Backgrounded started"];
    [self updateLastClosedTime];
    
    let timeElapsed = [OSSessionManager.sharedSessionManager getTimeFocusedElapsed];
    if (timeElapsed < -1)
        return;
    
    OSSessionManager.sharedSessionManager.appEntryState = APP_CLOSE;

    let influences = [[OSSessionManager sharedSessionManager] getSessionInfluences];
    let focusCallParams = [self createFocusCallParams:influences onSessionEnded:false];
    let timeProcessor = [OSFocusTimeProcessorFactory createTimeProcessorWithInfluences:influences focusEventType:BACKGROUND];
    
    if (timeProcessor)
        [timeProcessor sendOnFocusCall:focusCallParams];
    // user module let them know app is backgrounded
    [OneSignalUserManagerImpl.sharedInstance runBackgroundTasks];
}

// Note: This is not from app backgrounding
// The on_focus call is made right away.
+ (void)onSessionEnded:(NSArray<OSInfluence *> *)lastInfluences {
    [OneSignalLog onesignalLog:ONE_S_LL_DEBUG message:@"onSessionEnded started"];
    let timeElapsed = [OSSessionManager.sharedSessionManager getTimeFocusedElapsed];
    let focusCallParams = [self createFocusCallParams:lastInfluences onSessionEnded:true];
    let timeProcessor = [OSFocusTimeProcessorFactory createTimeProcessorWithInfluences:lastInfluences focusEventType:END_SESSION];
    
    if (!timeProcessor) {
        [OneSignalLog onesignalLog:ONE_S_LL_DEBUG message:@"onSessionEnded no time processor to end"];
        return;
    }
    
    if (timeElapsed < -1)
        // If there is no in focus time to be added we just need to send the time from the last session that just ended.
        [timeProcessor sendUnsentActiveTime:focusCallParams];
    else
        [timeProcessor sendOnFocusCall:focusCallParams];
}

+ (OSFocusCallParams *)createFocusCallParams:(NSArray<OSInfluence *> *)lastInfluences onSessionEnded:(BOOL)onSessionEnded  {
    let timeElapsed = [OSSessionManager.sharedSessionManager getTimeFocusedElapsed];
    NSMutableArray<OSFocusInfluenceParam *> *focusInfluenceParams = [NSMutableArray new];

    for (OSInfluence *influence in lastInfluences) {
        NSString *channelString = [OS_INFLUENCE_CHANNEL_TO_STRING(influence.influenceChannel) lowercaseString];
        OSFocusInfluenceParam * focusInfluenceParam = [[OSFocusInfluenceParam alloc] initWithParamsInfluenceIds:influence.ids
                                                                                                   influenceKey:[NSString stringWithFormat:@"%@_%@", channelString, @"ids"]
                                                                                                directInfluence:influence.influenceType == DIRECT
                                                                                             influenceDirectKey:@"direct"];
        [focusInfluenceParams addObject:focusInfluenceParam];
    }

    return [[OSFocusCallParams alloc] initWithParamsAppId:[OneSignalConfigManager getAppId]
                                              timeElapsed:timeElapsed
                                          influenceParams:focusInfluenceParams
                                           onSessionEnded:onSessionEnded];
}

+ (void)updateLastClosedTime {
    let now = [NSDate date].timeIntervalSince1970;
    [OneSignalUserDefaults.initStandard saveDoubleForKey:OSUD_APP_LAST_CLOSED_TIME withValue:now];
}

@end
