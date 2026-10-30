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
#import <OneSignalCore/OneSignalCommonDefines.h>
#import <OneSignalCore/OSBundleUtils.h>

@implementation UIApplication (OneSignal)

+ (BOOL)applicationIsActive {
    if ([OSBundleUtils isAppUsingUIScene] && [NSThread isMainThread]) {
        UIWindow *keyWindow = UIApplication.sharedApplication.keyWindow;
        return keyWindow.windowScene.activationState == UISceneActivationStateForegroundActive;
    }
    return [[UIApplication sharedApplication] applicationState] == UIApplicationStateActive;
}

// UIScreen bounds can differ from the window scene, e.g. on foldables where the screen
// reports a single panel, and UIKit forces windows to their scene's size.
+ (CGRect)displayBounds {
    UIWindowScene *scene = UIApplication.sharedApplication.keyWindow.windowScene;
    if (scene) {
        return scene.coordinateSpace.bounds;
    }
    return UIScreen.mainScreen.bounds;
}

@end
