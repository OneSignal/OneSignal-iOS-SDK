//
//  OneSignalWebView.m
//  OneSignal
//
//  Created by Joseph Kalash on 7/18/16.
//  Copyright © 2016 Hiptic. All rights reserved.
//

#import "OneSignalWebView.h"

@interface UIApplication (Swizzling)
+(UIViewController*)topmostController:(UIViewController*)base;
@end


@implementation OneSignalWebView


-(void)viewDidLoad {
    
    _webView = [[UIWebView alloc] initWithFrame:self.view.frame];
    _webView.delegate = self;
    [self.view addSubview:_webView];
    
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(dismiss:)];
    
    _uiBusy = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    _uiBusy.color = [UIColor blackColor];
    _uiBusy.hidesWhenStopped = YES;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:_uiBusy];
}

-(void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (_url)
        [_webView loadRequest:[NSURLRequest requestWithURL:_url]];
}


-(void)dismiss:(id)sender {
    [self.navigationController dismissViewControllerAnimated:true completion:NULL];
}

-(void)webViewDidStartLoad:(UIWebView *)webView {
    [_uiBusy startAnimating];
}

-(void)webViewDidFinishLoad:(UIWebView *)webView {
    self.title = [_webView stringByEvaluatingJavaScriptFromString:@"document.title"];
    self.navigationController.title = self.title;
    [_uiBusy stopAnimating];
}


-(void)showInApp {
    if (!self.navigationController) { return; }
    self.navigationController.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
    UIViewController* topmost = [UIApplication topmostController:[UIApplication sharedApplication].keyWindow.rootViewController];
    if (topmost)
       [topmost presentViewController:self.navigationController animated:YES completion:NULL];
}



@end
