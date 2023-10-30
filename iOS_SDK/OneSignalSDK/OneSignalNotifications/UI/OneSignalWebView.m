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

#import <UIKit/UIKit.h>
#import "OneSignalWebView.h"
#import <OneSignalCore/OneSignalCore.h>


@implementation OneSignalWebView

UINavigationController *navController;
UIViewController *viewControllerForPresentation;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _webView = [WKWebView new];
    _webView.navigationDelegate = self;
    // https://webkit.org/blog/13936/enabling-the-inspection-of-web-content-in-apps/
    if (@available(macOS 13.3, iOS 16.4, *)) {
        if ([OneSignalLog getLogLevel] >= ONE_S_LL_DEBUG) {
            if ([_webView respondsToSelector:@selector(setInspectable:)]) {
                NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[_webView methodSignatureForSelector:@selector(setInspectable:)]];
                BOOL value = YES; // Boolean parameters must be captured as a variable before being set as an argument
                [invocation setTarget:_webView];
                [invocation setSelector:@selector(setInspectable:)];
                [invocation setArgument:&value atIndex:2];
                [invocation invoke];
            }
        }
    }
    [self.view addSubview:_webView];
    
    [self pinSubviewToMarginsWithSubview:_webView withSuperview:self.view];
    
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(dismiss:)];
    
    _uiBusy = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    _uiBusy.color = [UIColor blackColor];
    _uiBusy.hidesWhenStopped = YES;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:_uiBusy];
}


- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (_url)
        [_webView loadRequest:[NSURLRequest requestWithURL:_url]];
}

- (void)dismiss:(id)sender {
    [self.navigationController dismissViewControllerAnimated:true completion:^{
        [self clearWebView];
    }];
}

-(void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation {
    [_uiBusy startAnimating];
}

-(void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    [_webView evaluateJavaScript:@"document.title" completionHandler:^(id _Nullable result, NSError * _Nullable error) {
        self.title = result;
        self.navigationController.title = self.title;
        [_uiBusy stopAnimating];
    }];
}

-(void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    [OneSignalLog onesignalLog:ONE_S_LL_ERROR message:[NSString stringWithFormat:@"webView: An error occurred during navigation: %@", error]];
}

- (void)pinSubviewToMarginsWithSubview:(UIView *)subview withSuperview:(UIView *)superview {
    subview.translatesAutoresizingMaskIntoConstraints = false;
    
    let attributes = @[@(NSLayoutAttributeTop), @(NSLayoutAttributeBottom), @(NSLayoutAttributeLeading), @(NSLayoutAttributeTrailing)];
    
    for (NSNumber *layoutAttribute in attributes) {
        let attribute = (NSLayoutAttribute)[layoutAttribute longValue];
        [self.view addConstraint:[NSLayoutConstraint constraintWithItem:subview attribute:attribute relatedBy:NSLayoutRelationEqual toItem:superview attribute:attribute multiplier:1.0 constant:0.0]];
    }
    
    [superview layoutIfNeeded];
}

- (void)showInApp {
    // If already presented, no need to present again
    if (!navController) {
        navController = [[UINavigationController alloc] initWithRootViewController:self];
        navController.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
    }
    navController.presentationController.delegate = self;

    if (!viewControllerForPresentation) {
        viewControllerForPresentation = [[UIViewController alloc] init];
        [[viewControllerForPresentation view] setBackgroundColor:[UIColor clearColor]];
        [[viewControllerForPresentation view] setOpaque:FALSE];
    }
    
    if (navController.isViewLoaded && navController.view.window) {
        // navController is visible only refresh webview
        if (_url)
            [_webView loadRequest:[NSURLRequest requestWithURL:_url]];
        return;
    }
    
    UIWindow* mainWindow = [[UIApplication sharedApplication] keyWindow];
    
    if (!viewControllerForPresentation.view.superview) {
        [mainWindow addSubview:[viewControllerForPresentation view]];
    }
    
    @try {
        [viewControllerForPresentation presentViewController:navController animated:YES completion:nil];
    }
    @catch(NSException* exception) { }
}

- (void)clearWebView {
    [_webView loadHTMLString:@"" baseURL:nil];
    if (viewControllerForPresentation) {
        [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:@"clearing web view"];
        [viewControllerForPresentation.view removeFromSuperview];
    }
        
}

- (void)presentationControllerDidDismiss:(UIPresentationController *)presentationController {
    [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:@"presentation controller did dismiss webview"];
    [self clearWebView];
}

@end


