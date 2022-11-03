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

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "UIApplicationDelegate+OneSignal.h"
#import "OneSignal.h"
#import "OneSignalCommonDefines.h"
#import "OneSignalTracker.h"
#import "OneSignalSelectorHelpers.h"
#import "SwizzlingForwarder.h"
#import <objc/runtime.h>

@interface OneSignal (UN_extra)
+ (NSString*) appId;
@end

// This class hooks into the UIApplicationDelegate selectors to receive iOS 9 and older events.
//   - Orignal implementations are called so other plugins and the developers AppDelegate is still called.

@implementation OneSignalAppDelegate

+ (void) oneSignalLoadedTagSelector {}

// A Set to keep track of which classes we have already swizzled so we only
// swizzle each one once. If we swizzled more than once then this will create
// an infinite loop, this includes swizzling with ourselves but also with
// another SDK that swizzles.
static NSMutableSet<Class>* swizzledClasses;

- (void) setOneSignalDelegate:(id<UIApplicationDelegate>)delegate {
    [OneSignalAppDelegate traceCall:@"setOneSignalDelegate:"];
    [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"ONESIGNAL setOneSignalDelegate CALLED: %@", delegate]];
    
    if (swizzledClasses == nil)
        swizzledClasses = [NSMutableSet new];
    
    Class delegateClass = [delegate class];
    
    if (delegate == nil || [OneSignalAppDelegate swizzledClassInHeirarchy:delegateClass]) {
        [self setOneSignalDelegate:delegate];
        return;
    }
    [swizzledClasses addObject:delegateClass];
    
    Class newClass = [OneSignalAppDelegate class];
    // Used to track how long the app has been closed
    injectSelector(
        delegateClass,
        @selector(applicationWillTerminate:),
        newClass,
        @selector(oneSignalApplicationWillTerminate:)
    );
    
    [self setOneSignalDelegate:delegate];
}

-(void)oneSignalApplicationWillTerminate:(UIApplication *)application {
    [OneSignalAppDelegate traceCall:@"oneSignalApplicationWillTerminate:"];
    
    if ([OneSignal appId])
        [OneSignalTracker onFocus:YES];
    
    SwizzlingForwarder *forwarder = [[SwizzlingForwarder alloc]
        initWithTarget:self
        withYourSelector:@selector(
            oneSignalApplicationWillTerminate:
        )
        withOriginalSelector:@selector(
            applicationWillTerminate:
        )
    ];
    [forwarder invokeWithArgs:@[application]];
}

// Used to log all calls, also used in unit tests to observer
// the OneSignalAppDelegate selectors get called.
+(void) traceCall:(NSString*)selector {
    [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:selector];
}

@end
