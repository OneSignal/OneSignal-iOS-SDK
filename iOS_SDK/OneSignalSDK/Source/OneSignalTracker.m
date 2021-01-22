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
#import "OneSignalHelper.h"
#import "OneSignalWebView.h"
#import "OneSignalClient.h"
#import "Requests.h"
#import "OSInfluenceDataDefines.h"
#import "OneSignalUserDefaults.h"
#import "OneSignalCommonDefines.h"
#import "OSFocusTimeProcessorFactory.h"
#import "OSBaseFocusTimeProcessor.h"
#import "OSFocusCallParams.h"
#import "OSFocusInfluenceParam.h"
#import "OSMessagingController.h"
#import "OSStateSynchronizer.h"

@interface OneSignal ()

+ (void)registerUser;
+ (BOOL)sendNotificationTypesUpdate;
+ (BOOL)clearBadgeCount:(BOOL)fromNotifOpened;
+ (NSString*)mUserId;
+ (NSString *)mEmailUserId;
+ (NSString *)mEmailAuthToken;
+ (NSString *)mExternalIdAuthToken;
+ (OSStateSynchronizer *)stateSynchronizer;

@end

@implementation OneSignalTracker

static UIBackgroundTaskIdentifier focusBackgroundTask;
static NSTimeInterval lastOpenedTime;
static BOOL lastOnFocusWasToBackground = YES;

+ (void)resetLocals {
    [OSFocusTimeProcessorFactory resetUnsentActiveTime];
     focusBackgroundTask = 0;
    lastOpenedTime = 0;
    lastOnFocusWasToBackground = YES;
}

+ (void)setLastOpenedTime:(NSTimeInterval)lastOpened {
    lastOpenedTime = lastOpened;
}

+ (void)beginBackgroundFocusTask {
    focusBackgroundTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [OneSignalTracker endBackgroundFocusTask];
    }];
}

+ (void)endBackgroundFocusTask {
    [[UIApplication sharedApplication] endBackgroundTask: focusBackgroundTask];
    focusBackgroundTask = UIBackgroundTaskInvalid;
}

+ (void)onFocus:(BOOL)toBackground {
    // return if the user has not granted privacy permissions
    if ([OneSignal requiresUserPrivacyConsent])
        return;
    
    // Prevent the onFocus to be called twice when app being terminated
    //    - Both WillResignActive and willTerminate
    if (lastOnFocusWasToBackground == toBackground)
        return;
    lastOnFocusWasToBackground = toBackground;
    
    if (toBackground) {
        [self applicationBackgrounded];
    } else {
        [self applicationForegrounded];
    }
}

+ (void)applicationForegrounded {
    [OneSignal onesignal_Log:ONE_S_LL_DEBUG message:@"Application Foregrounded started"];
    [OSFocusTimeProcessorFactory cancelFocusCall];
    
    if (OneSignal.appEntryState != NOTIFICATION_CLICK)
        OneSignal.appEntryState = APP_OPEN;
   
    lastOpenedTime = [NSDate date].timeIntervalSince1970;
    
    // on_session tracking when resumming app.
    if ([OneSignal shouldRegisterNow])
        [OneSignal registerUser];
    else {
        // This checks if notification permissions changed when app was backgrounded
        [OneSignal sendNotificationTypesUpdate];
        [OneSignal.sessionManager attemptSessionUpgrade:OneSignal.appEntryState];
        [OneSignal receivedInAppMessageJson:nil];
    }
    
    let wasBadgeSet = [OneSignal clearBadgeCount:false];
    
    if (![OneSignal mUserId])
        return;
    
    // If badge was set, clear it on the server as well.
    if (wasBadgeSet)
        [OneSignal.stateSynchronizer sendBadgeCount:@0 appId:[OneSignal appId]];
}

+ (void)applicationBackgrounded {
    [OneSignal onesignal_Log:ONE_S_LL_DEBUG message:@"Application Backgrounded started"];
    [OneSignal setIsOnSessionSuccessfulForCurrentState:false];
    [self updateLastClosedTime];
    
    let timeElapsed = [self getTimeFocusedElapsed];
    if (timeElapsed < -1)
        return;
    
    OneSignal.appEntryState = APP_CLOSE;

    let influences = [OneSignal.sessionManager getSessionInfluences];
    let focusCallParams = [self createFocusCallParams:influences onSessionEnded:false];
    let timeProcessor = [OSFocusTimeProcessorFactory createTimeProcessorWithInfluences:influences focusEventType:BACKGROUND];
    
    if (timeProcessor)
        [timeProcessor sendOnFocusCall:focusCallParams];
}

+ (void)onSessionEnded:(NSArray<OSInfluence *> *)lastInfluences {
    [OneSignal onesignal_Log:ONE_S_LL_DEBUG message:@"onSessionEnded started"];
    let timeElapsed = [self getTimeFocusedElapsed];
    let focusCallParams = [self createFocusCallParams:lastInfluences onSessionEnded:true];
    let timeProcessor = [OSFocusTimeProcessorFactory createTimeProcessorWithInfluences:lastInfluences focusEventType:END_SESSION];
    
    if (!timeProcessor) {
        [OneSignal onesignal_Log:ONE_S_LL_DEBUG message:@"onSessionEnded no time processor to end"];
        return;
    }
    
    if (timeElapsed < -1)
        // If there is no in focus time to be added we just need to send the time from the last session that just ended.
        [timeProcessor sendUnsentActiveTime:focusCallParams];
    else
        [timeProcessor sendOnFocusCall:focusCallParams];
}

+ (OSFocusCallParams *)createFocusCallParams:(NSArray<OSInfluence *> *)lastInfluences onSessionEnded:(BOOL)onSessionEnded  {
    let timeElapsed = [self getTimeFocusedElapsed];
    NSMutableArray<OSFocusInfluenceParam *> *focusInfluenceParams = [NSMutableArray new];

    for (OSInfluence *influence in lastInfluences) {
        NSString *channelString = [OS_INFLUENCE_CHANNEL_TO_STRING(influence.influenceChannel) lowercaseString];
        OSFocusInfluenceParam * focusInfluenceParam = [[OSFocusInfluenceParam alloc] initWithParamsInfluenceIds:influence.ids
                                                                                                   influenceKey:[NSString stringWithFormat:@"%@_%@", channelString, @"ids"]
                                                                                                directInfluence:influence.influenceType == DIRECT
                                                                                             influenceDirectKey:@"direct"];
        [focusInfluenceParams addObject:focusInfluenceParam];
    }

    return [[OSFocusCallParams alloc] initWithParamsAppId:[OneSignal appId]
                                                   userId:[OneSignal mUserId]
                                              emailUserId:[OneSignal mEmailUserId]
                                           emailAuthToken:[OneSignal mEmailAuthToken]
                                      externalIdAuthToken:[OneSignal mExternalIdAuthToken]
                                                  netType:[OneSignalHelper getNetType]
                                              timeElapsed:timeElapsed
                                          influenceParams:focusInfluenceParams
                                           onSessionEnded:onSessionEnded];
}

+ (NSTimeInterval)getTimeFocusedElapsed {
    if (!lastOpenedTime)
        return -1;
    
    let now = [NSDate date].timeIntervalSince1970;
    let timeElapsed = now - (int)(lastOpenedTime + 0.5);
   
    // Time is invalid if below 1 or over a day
    if (timeElapsed < 0 || timeElapsed > 86400)
        return -1;

    return timeElapsed;
}

+ (void)updateLastClosedTime {
    let now = [NSDate date].timeIntervalSince1970;
    [OneSignalUserDefaults.initStandard saveDoubleForKey:OSUD_APP_LAST_CLOSED_TIME withValue:now];
}

@end
