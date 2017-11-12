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

#import "OneSignalTrackFirebaseAnalyticsOverrider.h"

#import "TestHelperFunctions.h"

#import "OneSignalTrackFirebaseAnalytics.h"

@implementation OneSignalTrackFirebaseAnalyticsOverrider

static NSMutableArray<NSDictionary*> *loggedEvents;
static BOOL hasFIRAnalytics = false;

+(void)reset {
    loggedEvents = [NSMutableArray new];
    hasFIRAnalytics = false;
}

+(NSArray<NSDictionary*>*)loggedEvents {
    return loggedEvents;
}

+(void)setHasFIRAnalytics:(BOOL)enable {
    hasFIRAnalytics = enable;
}

+(void)load {
    [self reset];
    
    injectStaticSelector([OneSignalTrackFirebaseAnalyticsOverrider class], @selector(overrideLogEventWithName:parameters:), [OneSignalTrackFirebaseAnalytics class], @selector(logEventWithName:parameters:));
    injectStaticSelector([OneSignalTrackFirebaseAnalyticsOverrider class], @selector(overrideNeedsRemoteParams), [OneSignalTrackFirebaseAnalytics class], @selector(needsRemoteParams));
}

+(void)overrideLogEventWithName:(NSString*)name parameters:(NSDictionary*)params {
    [loggedEvents addObject:@{name: params}];
}

+(BOOL)overrideNeedsRemoteParams {
    return hasFIRAnalytics;
}

@end
