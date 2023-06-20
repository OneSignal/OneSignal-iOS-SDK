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

#import <Foundation/Foundation.h>
#import "OSInAppMessageLocationPrompt.h"
//#import <OneSignalLocation/OneSignalLocation.h>

//@interface OneSignalLocation ()
//
//+ (void)promptLocationFallbackToSettings:(BOOL)fallback completionHandler:(void (^)(PromptActionResult result))completionHandler;
//
//@end

@implementation OSInAppMessageLocationPrompt

- (instancetype)init
{
    self = [super init];
    if (self) {
        _hasPrompted = NO;
    }
    return self;
}

- (void)handlePrompt:(void (^)(PromptActionResult result))completionHandler {
    id OneSignalLocationClass = NSClassFromString(@"OneSignalLocation");
    BOOL fallback = YES;
    NSMethodSignature* signature = [OneSignalLocationClass instanceMethodSignatureForSelector:@selector(promptLocationFallbackToSettings:completionHandler:)];
    NSInvocation* invocation = [NSInvocation invocationWithMethodSignature: signature];
    [invocation setTarget: OneSignalLocationClass];
    [invocation setSelector: @selector(promptLocationFallbackToSettings:completionHandler:)];
    [invocation setArgument: &fallback atIndex: 2];
    [invocation setArgument: &completionHandler atIndex: 3];
    [invocation invoke];
//    [OneSignalHelper performSelector:@selector(displayWebView:) withObject:url afterDelay:0.5];
//    [OneSignalLocation promptLocationFallbackToSettings:true completionHandler:completionHandler];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"OSInAppMessageLocationPrompt hasPrompted:%@", _hasPrompted ? @"YES" : @"NO"];
}

@end
