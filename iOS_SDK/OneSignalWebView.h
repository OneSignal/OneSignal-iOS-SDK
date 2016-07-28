//
//  OneSignalWebView.h
//  OneSignal
//
//  Created by Joseph Kalash on 7/18/16.
//  Copyright © 2016 Hiptic. All rights reserved.
//

@interface OneSignalWebView : UIViewController <UIWebViewDelegate>

@property(nonatomic, copy)NSURL *url;
@property(nonatomic)UIWebView *webView;
@property(nonatomic)UIActivityIndicatorView *uiBusy;

-(void)dismiss:(id)sender;
-(void)showInApp;

@end
