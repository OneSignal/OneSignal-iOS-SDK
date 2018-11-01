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

#import "OSMessagingController.h"
#import "OneSignalHelper.h"

@interface OSMessagingController ()

@property (strong, nonatomic, nullable) UIWindow *window;

@property (weak, nonatomic, nullable) OSInAppMessageViewController *messageViewController;

@property (strong, nonatomic, nonnull) NSMutableArray <OSInAppMessageDelegate> *delegates;

@end

@implementation OSMessagingController

+ (OSMessagingController * _Nonnull)sharedInstance {
    static OSMessagingController *sharedInstance = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        sharedInstance = [OSMessagingController new];
    });
    return sharedInstance;
}

-(instancetype _Nonnull)init {
    if (self = [super init]) {
        self.delegates = [NSMutableArray<OSInAppMessageDelegate> new];
    }
    
    return self;
}

- (void)addMessageDelegate:(id<OSInAppMessageDelegate>)delegate {
    [self.delegates addObject:delegate];
}

-(void)presentInAppMessage:(OSInAppMessage * _Nonnull)message {
    if (!self.window) {
        self.window = [[UIWindow alloc] init];
        self.window.windowLevel = UIWindowLevelAlert;
        self.window.frame = [[UIScreen mainScreen] bounds];
    }
    
    let viewController = [[OSInAppMessageViewController alloc] initWithMessage:message];
    
    viewController.delegate = self;
    
    self.messageViewController = viewController;
    
    self.window.rootViewController = self.messageViewController;
    
    self.window.backgroundColor = [UIColor clearColor];
    
    self.window.opaque = true;
    
    [self.window makeKeyAndVisible];
}

#pragma mark OSInAppMessageViewControllerDelegate Methods
-(void)messageViewControllerWasDismissed {
    self.window.hidden = true;
    
    [UIApplication.sharedApplication.delegate.window makeKeyWindow];
    
    //nullify our reference to the window to ensure there are no leaks
    self.window = nil;
}

-(void)messageViewDidSelectAction:(NSString *)actionId withData:(NSDictionary *)data {
    for (id<OSInAppMessageDelegate> delegate in self.delegates)
        [delegate handleMessageAction:actionId withData:data];
}

@end
