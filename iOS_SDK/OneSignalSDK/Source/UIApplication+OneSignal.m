/**
 * Modified MIT License
 *
 * Copyright 2020 OneSignal
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

#import "UIApplication+OneSignal.h"
#import "OneSignalCommonDefines.h"

@implementation UIApplication (OneSignal)

+ (BOOL)applicationIsActive {
    if ([self isAppUsingUIScene] && [NSThread isMainThread]) {
        if (@available(iOS 13.0, *)) {
            UIWindow *keyWindow = UIApplication.sharedApplication.keyWindow;
            id windowScene = [keyWindow performSelector:@selector(windowScene)];
            id session = [windowScene performSelector:@selector(session)];
            id scene = [session performSelector:@selector(scene)];
            return [scene performSelector:@selector(activationState)] == 0;
        }
    }
    return [[UIApplication sharedApplication] applicationState] == UIApplicationStateActive;
}

+ (BOOL)isAppUsingUIScene {
    if (@available(iOS 13.0, *)) {
        return [[NSBundle mainBundle] objectForInfoDictionaryKey:@"UIApplicationSceneManifest"] != nil;
    }
    return NO;
}

@end
