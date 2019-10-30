/**
 * Modified MIT License
 *
 * Copyright 2019 OneSignal
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

#import "OSFocusTimeProcessorFactory.h"
#import "OneSignalCommonDefines.h"
#import "OSAttributedFocusTimeProcessor.h"
#import "OSUnattributedFocusTimeProcessor.h"
#import "OneSignalHelper.h"

@implementation OSFocusTimeProcessorFactory

static NSDictionary<NSString *, OSBaseFocusTimeProcessor *> *focusTimeProcessors;

+ (void)cancelFocusCall {
    if (!focusTimeProcessors)
        return;
    
    for (NSString *key in focusTimeProcessors) {
        OSBaseFocusTimeProcessor *timeProcesor = [focusTimeProcessors objectForKey:key];
        if (timeProcesor)
            [timeProcesor setOnFocusCallEnabled:NO];
    }
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"cancelFocusCall of %@", focusTimeProcessors]];
}

+ (void)resetUnsentActiveTime {
    if (!focusTimeProcessors)
        return;
    
    for (NSString *key in focusTimeProcessors) {
        OSBaseFocusTimeProcessor *timeProcesor = [focusTimeProcessors objectForKey:key];
        if (timeProcesor)
            [timeProcesor resetUnsentActiveTime];
    }
    
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"resetUnsentActiveTime of %@", focusTimeProcessors]];
}

+ (OSBaseFocusTimeProcessor *)createTimeProcessorWithSessionResult:(OSSessionResult *)result focusEventType:(FocusEventType)focusEventType {
    if (!focusTimeProcessors)
        focusTimeProcessors = [[NSMutableDictionary alloc] init];
    
    let isAttributed = [result isSessionAttributed];
    let attributionState = isAttributed ? ATTRIBUTED : NOATTRIBUTED;
    NSString *key = focusAttributionStateString(attributionState);
    
    OSBaseFocusTimeProcessor *timeProcesor = [focusTimeProcessors objectForKey:key];
    
    if (!timeProcesor) {
        switch (attributionState) {
            case ATTRIBUTED:
                timeProcesor = [[OSAttributedFocusTimeProcessor alloc] init];
                break;
             case NOATTRIBUTED:
                if (focusEventType == END_SESSION)
                    // We only need to send unattributed focus time when the app goes out of focus.
                    break;
                timeProcesor = [[OSUnattributedFocusTimeProcessor alloc] init];
                break;
        }
        
        [focusTimeProcessors setValue:timeProcesor forKey:key];
    }
    
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"TimeProcessor %@ for session attributed %@", timeProcesor, isAttributed ? @"YES" : @"NO"]];
    
    return timeProcesor;
}

@end
