/**
 * Modified MIT License
 *
 * Copyright 2026 OneSignal
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

NS_ASSUME_NONNULL_BEGIN

@interface OSInAppMessageInsets : NSObject

// Each side is the larger of the margin and its safe area inset. Region frames are in the scene
// view's coordinates; one sitting inside a side safe area, not flush with the edge, adds clearance.
// Both checks allow 1pt of slack: within 1pt of the screen edge counts as flush, and up to 1pt past
// the safe area edge still counts as inside.
// Full screen messages ignore the safe area and regions.
+ (UIEdgeInsets)horizontalInsetsWithMargin:(CGFloat)margin
                                  safeArea:(UIEdgeInsets)safeArea
                                     width:(CGFloat)width
                              regionFrames:(NSArray<NSValue *> *)regionFrames
                              isFullscreen:(BOOL)isFullscreen;

@end

NS_ASSUME_NONNULL_END
