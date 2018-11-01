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

#import "OSInAppMessageViewController.h"
#import "OSInAppMessageView.h"
#import "OneSignalHelper.h"

#define HIGHEST_CONSTRAINT_PRIORITY 999.0f
#define HIGH_CONSTRAINT_PRIORITY 990.0f
#define MEDIUM_CONSTRAINT_PRIORITY 950.0f
#define LOW_CONSTRAINT_PRIORITY 900.0f

@interface OSInAppMessageViewController ()
@property (strong, nonatomic, nonnull) OSInAppMessage *message;
@property (weak, nonatomic, nullable) OSInAppMessageView *messageView;
@property (strong, nonatomic, nonnull) NSLayoutConstraint *initialYConstraint;
@property (strong, nonatomic, nonnull) NSLayoutConstraint *finalYConstraint;

@property (weak, nonatomic, nullable) UIPanGestureRecognizer *panGestureRecognizer;
@property (weak, nonatomic, nullable) UITapGestureRecognizer *tapGestureRecognizer;
@property (nonatomic) CGPoint initialGestureRecognizerLocation;
@property (strong, nonatomic, nullable) NSLayoutConstraint *panVerticalConstraint;
@end

@implementation OSInAppMessageViewController

- (instancetype _Nonnull)initWithMessage:(OSInAppMessage *)inAppMessage {
    if (self = [super init]) {
        self.message = inAppMessage;
    }
    
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.alpha = 0.0;
    
    [self loadMessageContent];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
}

- (void)displayMessage {
    [UIView animateWithDuration:0.3 animations:^{
        self.view.alpha = 1.0;
    } completion:^(BOOL finished) {
        if (!finished)
            return;
        
        [self animateAppearance];
    }];
}

- (void)loadMessageContent {
//    [self.message loadHTMLContentWithResult:^(NSString * _Nonnull html) {
//        [self displayMessageWithHTML:html];
//    } withFailure:^(NSError *error) {
//        [OneSignal onesignal_Log:ONE_S_LL_ERROR message:[NSString stringWithFormat:@"Encountered an error while attempting to download HTML content for message: %@", error.description ?: @"Unknown Error"]];
//    }];
    
    let messageSubview = [[OSInAppMessageView alloc] initWithMessage:self.message];
    self.messageView = messageSubview;
    self.messageView.delegate = self;
    
    self.view.backgroundColor = [UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.3];
    
    self.messageView.translatesAutoresizingMaskIntoConstraints = false;
    self.messageView.backgroundColor = [UIColor blackColor];
    self.messageView.layer.cornerRadius = 10.0f;
    self.messageView.clipsToBounds = true;
    
    [self.view addSubview:self.messageView];
    
    [self addConstraintsForMessage];
    
    [self setupGestureRecognizers];
}

- (void)addConstraintsForMessage {
    
    NSLayoutAnchor *top = self.view.topAnchor, *bottom = self.view.bottomAnchor, *leading = self.view.leadingAnchor, *trailing = self.view.trailingAnchor;
    
    if (@available(iOS 12, *)) {
        let safeArea = self.view.safeAreaLayoutGuide;
        top = safeArea.topAnchor, bottom = safeArea.bottomAnchor, leading = safeArea.leadingAnchor, trailing = safeArea.trailingAnchor;
    }
    
    let marginSpacing = MESSAGE_MARGIN * [UIScreen mainScreen].bounds.size.width;
    
    [self.messageView.leadingAnchor constraintEqualToAnchor:leading constant:marginSpacing].active = true;
    [self.messageView.trailingAnchor constraintEqualToAnchor:trailing constant:-marginSpacing].active = true;
    [self.messageView.heightAnchor constraintEqualToAnchor:self.view.heightAnchor multiplier:self.message.heightRatio].active = true;
    
    // add Y constraints
    // Since we animate the appearance of the message (ie. slide in from top),
    // there are two constraints: initial and final. At initialization, the initial
    // constraint has a higher priority. The pan constraint is used only when panning
    switch (self.message.position) {
        case OSInAppMessageDisplayPositionTop:
            self.initialYConstraint = [self.messageView.bottomAnchor constraintEqualToAnchor:self.view.topAnchor constant:-8.0f];
            self.finalYConstraint = [self.messageView.topAnchor constraintEqualToAnchor:top constant:marginSpacing];
            self.panVerticalConstraint = [self.messageView.topAnchor constraintEqualToAnchor:top constant:marginSpacing];
            break;
        case OSInAppMessageDisplayPositionCentered:
            self.initialYConstraint = [self.messageView.topAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:8.0f];
            self.finalYConstraint = [self.messageView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:0.0f];
            self.panVerticalConstraint = [self.messageView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:0.0f];
            break;
        case OSInAppMessageDisplayPositionBottom:
            self.initialYConstraint = [self.messageView.topAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:8.0f];
            self.finalYConstraint = [self.messageView.bottomAnchor constraintEqualToAnchor:bottom constant:-marginSpacing];
            self.panVerticalConstraint = [self.messageView.bottomAnchor constraintEqualToAnchor:bottom constant:-marginSpacing];
            break;
    }
    
    self.initialYConstraint.priority = HIGH_CONSTRAINT_PRIORITY;
    self.finalYConstraint.priority = MEDIUM_CONSTRAINT_PRIORITY;
    self.panVerticalConstraint.priority = HIGHEST_CONSTRAINT_PRIORITY;
    self.panVerticalConstraint.active = false;
    self.initialYConstraint.active = true;
    self.finalYConstraint.active = true;
    
    [self.view layoutIfNeeded];
}

- (void)dismissMessageWithDirection:(BOOL)up {
    // inactivate the current Y constraints
    self.finalYConstraint.active = false;
    self.initialYConstraint.active = false;
    
    // add new Y constraints
    if (up) {
        [self.messageView.bottomAnchor constraintEqualToAnchor:self.view.topAnchor constant:-8.0f].active = true;
    } else {
        [self.messageView.topAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:8.0f].active = true;
    }
    
    [UIView animateWithDuration:0.3 animations:^{
        self.view.backgroundColor = [UIColor clearColor];
        [self.view layoutIfNeeded];
    } completion:^(BOOL finished) {
        if (!finished)
            return;
        
        [self dismissViewControllerAnimated:false completion:nil];
        
        [self.delegate messageViewControllerWasDismissed];
    }];
}

- (void)animateAppearance {
    self.initialYConstraint.priority = LOW_CONSTRAINT_PRIORITY;
    
    [UIView animateWithDuration:0.3f animations:^{
        [self.view layoutIfNeeded];
    }];
}

- (void)beginPanAtLocation:(CGPoint)location {
    self.panVerticalConstraint.constant = self.finalYConstraint.constant;
    self.initialGestureRecognizerLocation = location;
    self.panVerticalConstraint.active = true;
}

- (void)setupGestureRecognizers {
    // Pan gesture recognizer for swiping
    let recognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panGestureRecognizerDidMove:)];
    
    [self.messageView addGestureRecognizer:recognizer];
    
    recognizer.maximumNumberOfTouches = 1;
    recognizer.minimumNumberOfTouches = 1;
    
    self.panGestureRecognizer = recognizer;
    
    // Tap gesture recognizer for tapping background (dismissing)
    let tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapGestureRecognizerDidTap:)];
    
    tapRecognizer.numberOfTapsRequired = 1;
    
    [self.view addGestureRecognizer:tapRecognizer];
    
    self.tapGestureRecognizer = tapRecognizer;
}

// Called when the user pans (swipes) the message view
- (void)panGestureRecognizerDidMove:(UIPanGestureRecognizer *)sender {
    
    // Tells us the location of the gesture inside the entire view
    let location = [sender locationInView:self.view];
    
    // Return early if we are just beginning the pan interaction
    // Set up the pan constraints to move the view
    if (sender.state == UIGestureRecognizerStateBegan) {
        [self beginPanAtLocation:location];
        return;
    }
    
    // tells us the offset from the message view's normal position
    let offset = self.initialGestureRecognizerLocation.y - location.y;
    
    if (sender.state == UIGestureRecognizerStateEnded) {
        
        // Inactivate the pan constraint since we are no longer panning
        self.panVerticalConstraint.active = false;
        
        // Indicates if the in-app message was swiped away
        if ([self shouldDismissMessageWithPanGestureOffset:offset]) {
            
            // Centered messages can be dismissed in either direction (up/down)
            if (self.message.position == OSInAppMessageDisplayPositionCentered) {
                [self dismissMessageWithDirection:offset > 0];
            } else {
                // Top messages can only be dismissed by swiping up
                // Bottom messages can only be dismissed swiping down
                [self dismissMessageWithDirection:self.message.position == OSInAppMessageDisplayPositionTop];
            }
        } else {
            // The pan constraint is now inactive, calling layoutIfNeeded()
            // will cause the message to snap back to normal position
            [UIView animateWithDuration:0.3 animations:^{
                [self.view layoutIfNeeded];
            }];
        }
    } else if (sender.state == UIGestureRecognizerStateChanged) {
        // The pan interaction is in progress, move the view to match the offset
        self.panVerticalConstraint.constant = self.finalYConstraint.constant - offset;
        
        [self.view layoutIfNeeded];
    }
}

// Called when the user taps on the background view
- (void)tapGestureRecognizerDidTap:(UITapGestureRecognizer *)sender {
    [self dismissMessageWithDirection:self.message.position == OSInAppMessageDisplayPositionTop];
}

- (BOOL)shouldDismissMessageWithPanGestureOffset:(double)offset {
    switch (self.message.position) {
        case OSInAppMessageDisplayPositionTop:
            return (offset > self.messageView.bounds.size.height / 2.0f);
        case OSInAppMessageDisplayPositionCentered:
            return (fabs(offset) > self.messageView.bounds.size.height / 2.0f);
        case OSInAppMessageDisplayPositionBottom:
            return (fabs(offset) > self.messageView.bounds.size.height / 2.0f) && offset < 0;
    }
}

#pragma mark OSInAppMessageViewDelegate Methods
// The message view is not displayed until content is fully loaded
-(void)messageViewDidLoadMessageContent {
    [self displayMessage];
}

-(void)messageViewFailedToLoadMessageContent {
    [self.delegate messageViewControllerWasDismissed];
}

// This delegate function gets called when an action button is tapped on the IAM
- (void)messageViewDidTapAction:(NSString *)action withAdditionalData:(NSDictionary *)data {
    [self dismissMessageWithDirection:self.message.position == OSInAppMessageDisplayPositionTop];
    
    [self.delegate messageViewDidSelectAction:action withData:data];
}

- (void)messageViewDidFailToProcessAction {
    [self dismissMessageWithDirection:self.message.position == OSInAppMessageDisplayPositionTop];
}

@end
