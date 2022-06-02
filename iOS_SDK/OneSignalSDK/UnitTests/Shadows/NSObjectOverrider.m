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
#import "NSObjectOverrider.h"

#import "OneSignalSelectorHelpers.h"
#import "DelayedSelectors.h"

@implementation NSObjectOverrider

static DelayedSelectors* delayedSelectors;
static BOOL instantRunPerformSelectorAfterDelay;
static NSMutableArray* selectorNamesForInstantOnlyForFirstRun;

+ (void)load {
    injectSelector(
        [NSObject class],
        @selector(performSelector:withObject:afterDelay:),
        [NSObjectOverrider class],
        @selector(overridePerformSelector:withObject:afterDelay:)
   );
}

+ (void)reset {
    instantRunPerformSelectorAfterDelay = false;
    selectorNamesForInstantOnlyForFirstRun = [@[] mutableCopy];
    delayedSelectors = [DelayedSelectors new];
}

+ (void)setInstantRunPerformSelectorAfterDelay:(BOOL)value {
    instantRunPerformSelectorAfterDelay = value;
}
+ (void)setSelectorNamesForInstantOnlyForFirstRun:(NSArray*)list {
    selectorNamesForInstantOnlyForFirstRun = [list mutableCopy];
}

- (void)overridePerformSelector:(SEL)aSelector withObject:(nullable id)anArgument afterDelay:(NSTimeInterval)delay {
    // TOOD: Add && for calling from our unit test queue looper.
    /*
     if (![[NSThread mainThread] isEqual:[NSThread currentThread]])
     _XCTPrimitiveFail(currentTestInstance);
     */
    
    if (instantRunPerformSelectorAfterDelay || [selectorNamesForInstantOnlyForFirstRun containsObject:NSStringFromSelector(aSelector)]) {
        [selectorNamesForInstantOnlyForFirstRun removeObject:NSStringFromSelector(aSelector)];
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self performSelector:aSelector withObject:anArgument];
        #pragma clang diagnostic pop
    }
    else
        [delayedSelectors addSelector:aSelector onObject:self withObject:anArgument];
}

+ (void)runPendingSelectors {
    [delayedSelectors runPendingSelectors];
}

@end
