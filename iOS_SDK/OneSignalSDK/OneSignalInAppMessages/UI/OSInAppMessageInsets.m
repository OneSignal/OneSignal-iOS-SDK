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
#import "OSInAppMessageInsets.h"

@implementation OSInAppMessageInsets

+ (UIEdgeInsets)horizontalInsetsWithMargin:(CGFloat)margin
                                  safeArea:(UIEdgeInsets)safeArea
                                     width:(CGFloat)width
                              regionFrames:(NSArray<NSValue *> *)regionFrames
                              isFullscreen:(BOOL)isFullscreen {
    if (isFullscreen) {
        return UIEdgeInsetsMake(0, margin, 0, margin);
    }
    CGFloat left = MAX(margin, safeArea.left);
    CGFloat right = MAX(margin, safeArea.right);
    // Region frames already include UIKit's interactive margins; the message margin is added on top.
    for (NSValue *value in regionFrames) {
        CGRect frame = value.CGRectValue;
        CGFloat minX = CGRectGetMinX(frame);
        CGFloat maxX = CGRectGetMaxX(frame);
        if (minX >= 1 && maxX <= safeArea.left + 1) {
            left = MAX(left, maxX + margin);
        } else if (maxX <= width - 1 && minX >= width - safeArea.right - 1) {
            right = MAX(right, width - minX + margin);
        }
    }
    return UIEdgeInsetsMake(0, left, 0, right);
}

@end
