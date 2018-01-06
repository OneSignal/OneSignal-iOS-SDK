//
//  RedViewController.m
//  OneSignalDemo
//
//  Created by Brad Hesse on 1/5/18.
//  Copyright © 2018 OneSignal. All rights reserved.
//

#import "RedViewController.h"
#import <UIKit/UIKit.h>

@interface RedViewController ()
@property (weak, nonatomic) IBOutlet UIWebView *webView;
@end

@implementation RedViewController

-(void)viewDidLoad {
    [super viewDidLoad];
    
    if (self.receivedUrl) {
        [self.webView loadRequest:[NSURLRequest requestWithURL:self.receivedUrl]];
    }
}

- (IBAction)backButtonPressed:(UIButton *)sender {
    [self dismissViewControllerAnimated:true completion:nil];
}

@end
