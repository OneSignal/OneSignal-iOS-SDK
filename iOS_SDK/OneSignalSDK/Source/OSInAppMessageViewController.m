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
#import "OneSignalViewHelper.h"
#import "OSInAppMessageController.h"
#import "OSSessionManager.h"
#import "OneSignalCommonDefines.h"
#import "OSInAppMessageBridgeEvent.h"

#define HIGHEST_CONSTRAINT_PRIORITY 999.0f
#define HIGH_CONSTRAINT_PRIORITY 990.0f
#define MEDIUM_CONSTRAINT_PRIORITY 950.0f
#define LOW_CONSTRAINT_PRIORITY 900.0f

@interface OneSignal ()

+ (OSSessionManager*)sessionManager;

@end

@interface OSInAppMessageViewController ()

// The actual message subview
@property (nonatomic, nullable) OSInAppMessageView *messageView;

// Before the top and bottom banner IAMs display, this constrains the Y position
// of the message to be off-screen
@property (strong, nonatomic, nonnull) NSLayoutConstraint *initialYConstraint;

// This constrains the Y position once the initial animation is finished
@property (strong, nonatomic, nonnull) NSLayoutConstraint *finalYConstraint;

// This constraint enforces an aspect ratio for the given message type (ie. banner)
@property (strong, nonatomic, nonnull) NSLayoutConstraint *heightConstraint;

// This recognizer lets the user pan (swipe) the message up and down
@property (weak, nonatomic, nullable) UIPanGestureRecognizer *panGestureRecognizer;

// This tap recognizer lets us dismiss the message if the user taps the background
@property (weak, nonatomic, nullable) UITapGestureRecognizer *tapGestureRecognizer;

// Previous orinetation which is assigned at the end of a device orinetation change
@property (nonatomic) ViewOrientation previousOrientation;

@property (nonatomic) ViewOrientation orientationOnBackground;

// This point represents the X/Y location of where the most recent
// pan gesture started. Used to determine the offset
@property (nonatomic) CGPoint initialGestureRecognizerLocation;

// This constraint determines the Y position when panning the message up or down
@property (strong, nonatomic, nullable) NSLayoutConstraint *panVerticalConstraint;

// This timer is used to dismiss in-app messages if the "max_display_time" is set
// We start the timer once the message is displayed (not during loading the content)
@property (nonatomic) double maxDisplayTime;

// This timer is used to dismiss in-app messages if the "max_display_time" is set
// We start the timer once the message is displayed (not during loading the content)
@property (weak, nonatomic, nullable) NSTimer *dismissalTimer;

// BOOL to track when an IAM has started UI setup so we know when to bypass UI changes on dismissal or not
// This is a fail safe for cases where global contraints are nil and we try to modify them on dismissal of an IAM
@property (nonatomic) BOOL didPageRenderingComplete;

// BOOL to track if the message content has loaded before tags have finished loading for liquid templating
@property (nonatomic, nullable) NSString *pendingHTMLContent;

@property (nonatomic) BOOL useHeightMargin;

@property (nonatomic) BOOL useWidthMargin;

@property (nonatomic) BOOL isFullscreen;

@end

@implementation OSInAppMessageViewController

- (instancetype _Nonnull)initWithMessage:(OSInAppMessageInternal *)inAppMessage delegate:(id<OSInAppMessageViewControllerDelegate>)delegate {
    if (self = [super init]) {
        self.message = inAppMessage;
        self.delegate = delegate;
        self.useHeightMargin = YES;
        self.useWidthMargin = YES;
    }
    
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Add observers for BecomeActive and EnterBackground state so that the IAM can be shown correctly when leaving and entering the app (background)
    [self addAppBecomeActiveObserver];
    [self addAppEnterBackgroundObserver];
    
    self.messageView = [[OSInAppMessageView alloc] initWithMessage:self.message withScriptMessageHandler:self];
    self.messageView.delegate = self;
  
    // Loads the HTML content for the IAM
    if (self.message.isPreview)
        [self loadPreviewMessageContent];
    else
        [self loadMessageContent];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [self.dismissalTimer invalidate];
    
    [self.messageView removeScriptMessageHandler];
}

- (void)applicationIsActive:(NSNotification *)notification {
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"Application Active"];
    // Animate the showing of the IAM when opening the app from background
    [self animateAppearance:NO];
}

- (void)applicationIsInBackground:(NSNotification *)notification {
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"Application Entered Background"];
    
    // Get current orientation of the device
    UIDeviceOrientation currentDeviceOrientation = UIDevice.currentDevice.orientation;
    self.orientationOnBackground = [OneSignalViewHelper validateOrientation:currentDeviceOrientation];
    
    // Make sure pan constraint is no longer active so IAM does not stay in panned location
    self.panVerticalConstraint.active = false;
    self.messageView.hidden = true;
}

- (void)addAppBecomeActiveObserver {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationIsActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
}

- (void)addAppEnterBackgroundObserver {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationIsInBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
}

/*
 Sets up the message UI, while it is still hidden
 Wait until the actual HTML content is loaded before animating appearance
 */
- (void)setupInitialMessageUI {
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"Setting up In-App Message"];
    
    self.messageView.delegate = self;
    
    [self.messageView setupWebViewConstraints];
    
    // Add drop shadow to the messageView
    self.messageView.layer.shadowOffset = CGSizeMake(0, 3);
    self.messageView.layer.shadowColor = [[UIColor blackColor] CGColor];
    self.messageView.layer.shadowRadius = 3.0f;
    self.messageView.layer.shadowOpacity = 0.55f;
    
    [self.view addSubview:self.messageView];
    
    [self addConstraintsForMessage];
    
    [self setupGestureRecognizers];
    
    // Only the center modal and full screen (both centered) IAM should have a dark background
    // So get the alpha based on the IAM being a banner or not
    double alphaBackground = [self.message isBanner] ? 0.0 : 0.5;
    [UIView animateWithDuration:0.3 animations:^{
        self.view.backgroundColor = [UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:alphaBackground];
        self.view.alpha = 1.0;
    } completion:^(BOOL finished) {
        if (!finished)
            return;
        
        [self animateAppearance:YES];
    }];
}

- (void)displayMessage {
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"Displaying In-App Message"];
    
    // Sets up the message view in a hidden position while we wait
    [self setupInitialMessageUI];

    // If the message has a max display time, set up the timer now
    if (self.maxDisplayTime > 0.0f)
        self.dismissalTimer = [NSTimer scheduledTimerWithTimeInterval:self.maxDisplayTime
                                                               target:self
                                                             selector:@selector(maxDisplayTimeTimerFinished)
                                                             userInfo:nil
                                                              repeats:false];
}

- (void)maxDisplayTimeTimerFinished {
    [self dismissCurrentInAppMessage:0.0f];
}

- (OSResultSuccessBlock)messageContentOnSuccess {
    return ^(NSDictionary *data) {
        [OneSignalHelper dispatch_async_on_main_queue:^{
            if (!data) {
                [self encounteredErrorLoadingMessageContent:nil];
                return;
            }
            
            let message = [NSString stringWithFormat:@"In App Messaging htmlContent.html: %@", data[@"html"]];
            [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:message];
            
            if (!self.message.isPreview)
                [[OneSignal sessionManager] onInAppMessageReceived:self.message.messageId];

            let baseUrl = [NSURL URLWithString:OS_IAM_WEBVIEW_BASE_URL];
            [self parseContentData:data];
            if (self.waitForTags) {
                return;
            }
            [self.delegate messageWillDisplay:self.message];
            [self.messageView loadedHtmlContent:self.pendingHTMLContent withBaseURL:baseUrl];
            self.pendingHTMLContent = nil;
        }];
    };
}

- (void)parseContentData:(NSDictionary *)data {
    self.pendingHTMLContent = data[@"html"];
    self.maxDisplayTime = [data[@"display_duration"] doubleValue];
    NSDictionary *styles = data[@"styles"];
    if (styles) {
        // We are currently only allowing default margin or no margin.
        // If we receive a number that isn't 0 we want to use default margin for now.
        if (styles[@"remove_height_margin"]) {
            self.useHeightMargin = ![styles[@"remove_height_margin"] boolValue];
        }
        if (styles[@"remove_width_margin"]) {
            self.useWidthMargin = ![styles[@"remove_width_margin"] boolValue];
        }
    }
    self.isFullscreen = !self.useHeightMargin;
    if (self.isFullscreen) {
        self.pendingHTMLContent = [self setContentInsetsInHTML:self.pendingHTMLContent];
    }
    [self.messageView setIsFullscreen:self.isFullscreen];
}

- (NSString *)setContentInsetsInHTML:(NSString *)html {
    NSMutableString *newHTML = [[NSMutableString alloc] initWithString:html];
    if (@available(iOS 11, *)) {
        UIWindow *keyWindow = UIApplication.sharedApplication.keyWindow;
        CGFloat top = keyWindow.safeAreaInsets.top;
        CGFloat bottom = keyWindow.safeAreaInsets.bottom;
        CGFloat right = keyWindow.safeAreaInsets.right;
        CGFloat left = keyWindow.safeAreaInsets.left;
        NSString *safeAreaInsetsObjectString = [NSString stringWithFormat:OS_JS_SAFE_AREA_INSETS_OBJ,top, bottom, right, left];
        NSString *insetsString = [NSString stringWithFormat:@"\n\n\
                             <script> \
                                setSafeAreaInsets(%@);\
                             </script>",safeAreaInsetsObjectString];
        [newHTML appendString: insetsString];
    }
    return newHTML;
}

- (void)setWaitForTags:(BOOL)waitForTags {
    _waitForTags = waitForTags;
    if (!waitForTags && self.pendingHTMLContent) {
        [self.messageView loadedHtmlContent:self.pendingHTMLContent withBaseURL:[NSURL URLWithString:OS_IAM_WEBVIEW_BASE_URL]];
        self.pendingHTMLContent = nil;
    }
}

- (void)loadMessageContent {
    [self.message loadMessageHTMLContentWithResult:[self messageContentOnSuccess] failure:^(NSError *error) {
        [self encounteredErrorLoadingMessageContent:error];
    }];
}

- (void)loadPreviewMessageContent {
    [self.message loadPreviewMessageHTMLContentWithUUID:self.message.messageId
                                                success:[self messageContentOnSuccess]
                                                failure:^(NSError *error) {
                                                    [self encounteredErrorLoadingMessageContent:error];
                                                }];
}

- (void)encounteredErrorLoadingMessageContent:(NSError * _Nullable)error {
    let message = [NSString stringWithFormat:@"An error occurred while attempting to load message content: %@", error.description ?: @"Unknown Error"];
    if (error.code == 410 || error.code == 404) {
        [self.delegate messageIsNotActive:self.message];
    }
    [OneSignal onesignal_Log:ONE_S_LL_ERROR message:message];
}

/*
 Sets up the message view in its initial (hidden) position
 Adds constraints so that the message view has the correct size
 Once the HTML content is loaded, we call animateAppearance() to show the message view
 */
- (void)addConstraintsForMessage {
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"Setting up In-App Message Constraints"];
    
    if (![self.view.subviews containsObject:self.messageView]) {
        [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"addConstraintsForMessage: messageView is not a subview of OSInAppMessageViewController"];
        [self.view addSubview:self.messageView];
    }
    
    // Initialize the anchors that describe the edges of the view, such as the top, bottom, etc.
    NSLayoutAnchor *top = self.view.topAnchor,
                   *bottom = self.view.bottomAnchor,
                   *leading = self.view.leadingAnchor,
                   *trailing = self.view.trailingAnchor,
                   *center = self.view.centerXAnchor;
    NSLayoutDimension *height = self.view.heightAnchor;
    
    // The safe area represents the anchors that are not obscurable by  UI such
    // as a notch or a rounded corner on newer iOS devices like iPhone X
    // Note that Safe Area layout guides were only introduced in iOS 11
    if (@available(iOS 11, *)) {
        if (!self.isFullscreen) {
            let safeArea = self.view.safeAreaLayoutGuide;
            top = safeArea.topAnchor;
            bottom = safeArea.bottomAnchor;
            leading = safeArea.leadingAnchor;
            trailing = safeArea.trailingAnchor;
            center = safeArea.centerXAnchor;
            height = safeArea.heightAnchor;
        }
    }
    
    CGRect mainBounds = [OneSignalViewHelper getScreenBounds];
    CGFloat marginSpacing = [OneSignalViewHelper sizeToScale:MESSAGE_MARGIN];
    
    let screenHeight = [NSString stringWithFormat:@"Screen Bounds Height: %f", mainBounds.size.height];
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:screenHeight];
    let screenWidth = [NSString stringWithFormat:@"Screen Bounds Width: %f", mainBounds.size.width];
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:screenWidth];
    let screenScale = [NSString stringWithFormat:@"Screen Bounds Scale: %f", UIScreen.mainScreen.scale];
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:screenScale];
    let heightMessage = [NSString stringWithFormat:@"In App Message Height: %f", self.message.height.doubleValue];
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:heightMessage];
    
    // Height constraint based on the IAM being full screen or any others with a specific height
    // NOTE: full screen IAM payload has no height, so match screen height minus margins
    if (self.message.position == OSInAppMessageDisplayPositionFullScreen)
        self.heightConstraint = [self.messageView.heightAnchor constraintEqualToAnchor:height multiplier:1.0 constant:(self.useHeightMargin ? (2*-marginSpacing) : 0)];
    else
        self.heightConstraint = [self.messageView.heightAnchor constraintEqualToConstant:self.message.height.doubleValue];
    
    // The aspect ratio for each type (ie. Banner) determines the height normally
    // However the actual height of the HTML content takes priority.
    // Makes sure our webview is never taller than our screen.
    [self.messageView.heightAnchor constraintLessThanOrEqualToAnchor:height multiplier:1.0 constant:(self.useHeightMargin ? (2*-marginSpacing) : 0)].active = true;

    // Pins the message view to the left & right
    let leftConstraint = [self.messageView.leadingAnchor constraintEqualToAnchor:leading constant:(self.useWidthMargin ? marginSpacing : 0)];
    let rightConstraint = [self.messageView.trailingAnchor constraintEqualToAnchor:trailing constant:(self.useWidthMargin ? -marginSpacing : 0)];
    
    // Ensure the message view is always centered horizontally
    [self.messageView.centerXAnchor constraintEqualToAnchor:center].active = true;
    
    // Set Y constraints
    // Since we animate the appearance of the message (ie. slide in from top),
    // there are two constraints: initial and final. At initialization, the initial
    // constraint has a higher priority. The pan constraint is used only when panning
    double bannerWidth = mainBounds.size.width;
    double bannerHeight = self.message.height.doubleValue + (2.0f * marginSpacing);
    double bannerMessageY = mainBounds.size.height - bannerHeight;
    switch (self.message.position) {
        case OSInAppMessageDisplayPositionTop:
            if (@available(iOS 11, *)) {
                UIEdgeInsets safeAreaInsets = self.view.window.safeAreaInsets;
                bannerHeight += safeAreaInsets.top + safeAreaInsets.bottom;
            }
            double statusBarHeight = UIApplication.sharedApplication.statusBarFrame.size.height;
            bannerHeight += statusBarHeight;
            self.view.window.frame = CGRectMake(0, 0, bannerWidth, bannerHeight);

            self.initialYConstraint = [self.messageView.bottomAnchor constraintEqualToAnchor:self.view.topAnchor constant:-8.0f];
            self.finalYConstraint = [self.messageView.topAnchor constraintEqualToAnchor:top
                                                                               constant:(self.useHeightMargin ? marginSpacing : 0)];
            self.panVerticalConstraint = [self.messageView.topAnchor constraintEqualToAnchor:top
                                                                                    constant:(self.useHeightMargin ? marginSpacing : 0)];
            break;
        case OSInAppMessageDisplayPositionBottom:
            if (@available(iOS 11, *)) {
                UIEdgeInsets safeAreaInsets = self.view.window.safeAreaInsets;
                bannerHeight += safeAreaInsets.top + safeAreaInsets.bottom;
                bannerMessageY = mainBounds.size.height - bannerHeight;
            }
            self.view.window.frame = CGRectMake(0, bannerMessageY, bannerWidth, bannerHeight);

            self.initialYConstraint = [self.messageView.topAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:8.0f];
            self.finalYConstraint = [self.messageView.bottomAnchor constraintEqualToAnchor:bottom
                                                                                  constant:(self.useHeightMargin ? -marginSpacing : 0)];
            self.panVerticalConstraint = [self.messageView.bottomAnchor constraintEqualToAnchor:bottom
                                                                                       constant:(self.useHeightMargin ? -marginSpacing : 0)];
            break;
        case OSInAppMessageDisplayPositionFullScreen:
        case OSInAppMessageDisplayPositionCenterModal:
            self.view.window.frame = mainBounds;
            NSLayoutAnchor *centerYanchor = self.view.centerYAnchor;
            if (@available(iOS 11, *)) {
                if (!self.isFullscreen) {
                    let safeArea = self.view.safeAreaLayoutGuide;
                    centerYanchor = safeArea.centerYAnchor;
                }
            }

            self.initialYConstraint = [self.messageView.centerYAnchor constraintEqualToAnchor:centerYanchor constant:0.0f];
            self.finalYConstraint = [self.messageView.centerYAnchor constraintEqualToAnchor:centerYanchor constant:0.0f];
            self.panVerticalConstraint = [self.messageView.centerYAnchor constraintEqualToAnchor:centerYanchor constant:0.0f];
            self.messageView.transform = CGAffineTransformMakeScale(0, 0);
            break;
    }
    
    // We use different constraint priorities so that, by changing them, we can do stuff
    // like animating the dismissal of the message view by simply changing one of the
    // Y constraint's priority. Constraints with higher priority take precedence over
    // constraints with lower priorities.
    // Sets the proper intro animation constraints
    self.heightConstraint.priority = HIGH_CONSTRAINT_PRIORITY;
    self.initialYConstraint.priority = HIGH_CONSTRAINT_PRIORITY;
    self.finalYConstraint.priority = MEDIUM_CONSTRAINT_PRIORITY;
    self.panVerticalConstraint.priority = HIGHEST_CONSTRAINT_PRIORITY;
    leftConstraint.priority = MEDIUM_CONSTRAINT_PRIORITY;
    rightConstraint.priority = MEDIUM_CONSTRAINT_PRIORITY;
    
    // Constraints should all be active except for the panVerticalConstraint, which
    // is only active when the user is panning (swiping)
    self.panVerticalConstraint.active = false;
    self.heightConstraint.active = true;
    self.initialYConstraint.active = true;
    self.finalYConstraint.active = true;
    leftConstraint.active = true;
    rightConstraint.active = true;
    
    // Adding all of these constraints has caused the view's needsLayout property
    // to become true, so when we call layoutIfNeeded, it causes the view
    // hierarchy to be updated and our constraints get applied.
    [self.view layoutIfNeeded];
}

// Calls dismissCurrentInAppMessage with velocity at 0.0f
- (void)dismissCurrentInAppMessage {
    BOOL isTopBanner = self.message.position == OSInAppMessageDisplayPositionTop;
    [self dismissCurrentInAppMessage:isTopBanner
                        withVelocity:0.0f];
}

// Calls dismissCurrentInAppMessage with specified velocity
- (void)dismissCurrentInAppMessage:(double)velocity {
    BOOL isTopBanner = self.message.position == OSInAppMessageDisplayPositionTop;
    [self dismissCurrentInAppMessage:isTopBanner
                        withVelocity:velocity];
}

/*
 Dismisses the message view with a given direction (up or down) and velocity
 If velocity == 0.0, the default dismiss velocity will be used
 */
- (void)dismissCurrentInAppMessage:(BOOL)up withVelocity:(double)velocity {
    // Since the user dimsissed the IAM, cancel the dismissal timer
    if (self.dismissalTimer)
        [self.dismissalTimer invalidate];
    
    // If the rendering event never occurs any constraints being adjusted for dismissal will be nil
    // and we should bypass dismissal adjustments and animations and skip straight to the OSMessagingController callback for dismissing
    if (!self.didPageRenderingComplete) {
        [self dismissViewControllerAnimated:false completion:nil];
        [self.delegate messageViewControllerWasDismissed:self.message displayed:NO];
        return;
    }
        
    [self.delegate messageViewControllerWillDismiss:self.message];
    
    // Inactivate the current Y constraints
    self.finalYConstraint.active = false;
    self.initialYConstraint.active = false;
    
    // The distance that the dismissal animation will travel
    var distance = 0.0f;
    
    // Add new Y constraints
    if (up) {
        distance = self.messageView.frame.origin.y + self.messageView.frame.size.height + 8.0f;
        [self.messageView.bottomAnchor constraintEqualToAnchor:self.view.topAnchor constant:-8.0f].active = true;
    } else {
        distance = self.view.frame.size.height - self.messageView.frame.origin.y + 8.0f;
        [self.messageView.topAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:8.0f].active = true;
    }

    var dismissAnimationDuration = velocity != 0.0f ? distance / fabs(velocity) : 0.3f;
    
    var animationOption = UIViewAnimationOptionCurveLinear;
    
    // Impose a minimum animation speed (max duration)
    if (dismissAnimationDuration > MAX_DISMISSAL_ANIMATION_DURATION) {
        animationOption = UIViewAnimationOptionCurveEaseIn;
        dismissAnimationDuration = MAX_DISMISSAL_ANIMATION_DURATION;
    } else if (dismissAnimationDuration < MIN_DISMISSAL_ANIMATION_DURATION) {
        animationOption = UIViewAnimationOptionCurveEaseIn;
        dismissAnimationDuration = MIN_DISMISSAL_ANIMATION_DURATION;
    }

    [UIView animateWithDuration:dismissAnimationDuration delay:0.0f options:animationOption animations:^{
        self.view.backgroundColor = [UIColor clearColor];
        self.view.alpha = 0.0f;
        [self.view layoutIfNeeded];
    } completion:^(BOOL finished) {
        if (!finished)
            return;

        self.didPageRenderingComplete = false;
        [self.delegate messageViewControllerWasDismissed:self.message displayed:YES];
    }];
}

/*
 Once HTML is loaded, the message should be presented
 This method animates the actual appearance of the message view
 For banners the initialYConstraint is set to LOW_CONSTRAINT_PRIORITY
 For center modal and full screen, the transform is set to CGAffineTransformIdentity (original scale)
 */
- (void)animateAppearance:(BOOL)firstDisplay {
    self.initialYConstraint.priority = LOW_CONSTRAINT_PRIORITY;
    
    [UIView animateWithDuration:0.3f animations:^{
        self.messageView.hidden = false;
        self.messageView.transform = CGAffineTransformIdentity;
        [self.view layoutIfNeeded];
    } completion:^(BOOL finished) {
        if (firstDisplay) {
            [self.delegate messageViewControllerDidDisplay:self.message];
        }
    }];
}

- (void)beginPanAtLocation:(CGPoint)location {
    self.panVerticalConstraint.constant = self.finalYConstraint.constant;
    self.initialGestureRecognizerLocation = location;
    self.panVerticalConstraint.active = true;
}

/*
 Adds the pan recognizer (for swiping up and down) and the tap recognizer (for dismissing)
 */
- (void)setupGestureRecognizers {
    
    if (!self.message.dragToDismissDisabled) {
        // Pan gesture recognizer for swiping
        let recognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panGestureRecognizerDidMove:)];
        [self.messageView addGestureRecognizer:recognizer];
        recognizer.maximumNumberOfTouches = 1;
        recognizer.minimumNumberOfTouches = 1;
        
        self.panGestureRecognizer = recognizer;
    }
    
    // Only center modal and full screen should dismiss on background click
    // Banners will allow interacting with the view behind it still
    if (![self.message isBanner]) {
        // Tap gesture recognizer for tapping background (dismissing)
        let tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapGestureRecognizerDidTap:)];

        tapRecognizer.numberOfTapsRequired = 1;

        [self.view addGestureRecognizer:tapRecognizer];

        self.tapGestureRecognizer = tapRecognizer;
    }
}

/*
 Called when the user pans (swipes) the message view
 */
- (void)panGestureRecognizerDidMove:(UIPanGestureRecognizer *)sender {
    
    // Tells us the location of the gesture inside the entire view
    let location = [sender locationInView:self.view];
    
    // Tells us the velocity of the dismissal gesture in points per second
    let velocity = [sender velocityInView:self.view].y;
    
    // Return early if we are just beginning the pan interaction
    // Set up the pan constraints to move the view
    if (sender.state == UIGestureRecognizerStateBegan) {
        [self beginPanAtLocation:location];
        
        // Since the user interacted with the content, cancel the
        // Max display time timer if it is scheduled
        if (self.dismissalTimer)
            [self.dismissalTimer invalidate];
        
        return;
    }
    
    // Tells us the offset from the message view's normal position
    let offset = self.initialGestureRecognizerLocation.y - location.y;
    
    if (sender.state == UIGestureRecognizerStateEnded) {
        
        // Inactivate the pan constraint since we are no longer panning
        self.panVerticalConstraint.active = false;
        
        // Indicates if the in-app message was swiped away
        if ([self shouldDismissMessageWithPanGestureOffset:offset withVelocity:velocity]) {
            
            if ([self.message isBanner]) {
                // Top messages can only be dismissed by swiping up
                // Bottom messages can only be dismissed swiping down
                [self dismissCurrentInAppMessage:velocity];
            } else {
                // Centered messages can be dismissed in either direction (up/down)
                [self dismissCurrentInAppMessage:offset > 0 withVelocity:velocity];
            }
        } else {
            // The pan constraint is now inactive, calling layoutIfNeeded() will cause the message to snap back to normal position
            [UIView animateWithDuration:0.3 animations:^{
                [self.view layoutIfNeeded];
            }];
        }
    } else if (sender.state == UIGestureRecognizerStateChanged) {
        switch (self.message.position) {
            case OSInAppMessageDisplayPositionTop:
                if (self.panVerticalConstraint.constant < self.finalYConstraint.constant + offset) {
                    // The pan interaction is in progress, move the view to match the offset
                    self.panVerticalConstraint.constant = self.finalYConstraint.constant - offset;
                } else {
                    self.panVerticalConstraint.constant = self.finalYConstraint.constant;
                }
                break;
            case OSInAppMessageDisplayPositionBottom:
                if (self.panVerticalConstraint.constant > self.finalYConstraint.constant + offset) {
                    // The pan interaction is in progress, move the view to match the offset
                    self.panVerticalConstraint.constant = self.finalYConstraint.constant - offset;
                } else {
                    self.panVerticalConstraint.constant = self.finalYConstraint.constant;
                }
                break;
            case OSInAppMessageDisplayPositionFullScreen:
            case OSInAppMessageDisplayPositionCenterModal:
                self.panVerticalConstraint.constant = self.finalYConstraint.constant - offset;
                break;
        }
        [self.view layoutIfNeeded];
    }
}

/*
 Called when the user taps on the background view
 */
- (void)tapGestureRecognizerDidTap:(UITapGestureRecognizer *)sender {
    [self dismissCurrentInAppMessage];
}

/*
 Returns a boolean indicating if the message view should be dismissed for the given pan offset (ie. if the user has panned far enough up or down)
 */
- (BOOL)shouldDismissMessageWithPanGestureOffset:(double)offset withVelocity:(double)velocity {
    
    // For Centered notifications, only true if the user was swiping in the same direction as the dismissal
    BOOL dismissDirection = (offset > 0 && velocity <= 0) || (offset < 0 && velocity >= 0);
    
    switch (self.message.position) {
        case OSInAppMessageDisplayPositionTop:
            return (offset > self.messageView.bounds.size.height / 2.0f);
        case OSInAppMessageDisplayPositionBottom:
            return (fabs(offset) > self.messageView.bounds.size.height / 2.0f) && offset < 0;
        case OSInAppMessageDisplayPositionFullScreen:
        case OSInAppMessageDisplayPositionCenterModal:
            return dismissDirection && ((fabs(offset) > self.messageView.bounds.size.height / 2.0f) || (fabs(offset) > 100));
    }
}

/*
 This delegate function gets called when in-app html is load or action button is tapped
 */
- (void)jsEventOccurredWithBody:(NSData *)body {
    let event = [OSInAppMessageBridgeEvent instanceWithData:body];
    
    NSString *eventMessage = [NSString stringWithFormat:@"Action Occured with Event: %@", event];
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:eventMessage];
    NSString *eventTypeMessage = [NSString stringWithFormat:@"Action Occured with Event Type: %lu", (unsigned long)event.type];
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:eventTypeMessage];

    if (event) {
        switch (event.type) {
            case OSInAppMessageBridgeEventTypePageRenderingComplete: {
                // BOOL set to true since the JS event fired, meaning the WebView was populated properly with the IAM code
                self.didPageRenderingComplete = true;
               
                self.message.position = event.renderingComplete.displayLocation;
                self.message.height = event.renderingComplete.height;

                // The page is fully loaded and should now be displayed
                // This is only fired once the javascript on the page sends the "rendering_complete" type event
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate webViewContentFinishedLoading:self.message];
                    [OneSignalHelper performSelector:@selector(displayMessage) onMainThreadOnObject:self withObject:nil afterDelay:0.0f];
                });
                break;
            }
            case OSInAppMessageBridgeEventTypePageResize: {
                // Unused resize event for IAM during actions like orientation changes and displaying an IAM
                // self.message.height = event.resize.height;
                if (self.isFullscreen) {
                    [self.messageView updateSafeAreaInsets];
                }
                break;
            }
            case OSInAppMessageBridgeEventTypeActionTaken: {
                if (event.userAction.clickType)
                   [self.delegate messageViewDidSelectAction:self.message withAction:event.userAction];
                if (event.userAction.urlActionType == OSInAppMessageActionUrlTypeReplaceContent)
                   [self.messageView loadReplacementURL:event.userAction.clickUrl];
                if (event.userAction.closesMessage)
                   [self dismissCurrentInAppMessage];
                break;
            }
            case OSInAppMessageBridgeEventTypePageChange: {
                [self.delegate messageViewDidDisplayPage:self.message withPageId: event.pageChange.page.pageId];
                break;
            }
            default:
                break;
        }
    }
}

/*
 Unity overrides orientation behavior and enables all orientations in supportedInterfaceOrientations, regardless of
 the values set in the info.plist. It then uses its own internal logic for restricting the Application's views to
 the selected orientations. This view controller inherits the behavior of all orientations being allowed so we need
 to manually set the supported orientations based on the values in the plist.
 If no values are selected for the orientation key in the plist then we will default to super's behavior.
*/
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    NSUInteger orientationMask = 0;
    NSArray *supportedOrientations = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"UISupportedInterfaceOrientations"];
    if (!supportedOrientations) {
        return [super supportedInterfaceOrientations];
    }
    
    if ([supportedOrientations containsObject:@"UIInterfaceOrientationLandscapeLeft"]) {
        orientationMask += UIInterfaceOrientationMaskLandscapeLeft;
    }
    
    if ([supportedOrientations containsObject:@"UIInterfaceOrientationLandscapeRight"]) {
        orientationMask += UIInterfaceOrientationMaskLandscapeRight;
    }
    
    if ([supportedOrientations containsObject:@"UIInterfaceOrientationPortrait"]) {
        orientationMask += UIInterfaceOrientationMaskPortrait;
    }
    
    if ([supportedOrientations containsObject:@"UIInterfaceOrientationPortraitUpsideDown"]) {
        orientationMask += UIInterfaceOrientationMaskPortraitUpsideDown;
    }
    
    return orientationMask;
    
}

/*
 Override method for handling orientation change within a view controller on iOS 8 or higher
 This specifically handles the resizing and reanimation of a currently showing IAM
 */
- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id <UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];

    /*
     Code here will execute before the orientation change begins
     */
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"Screen Orientation Change Detected"];
    
    UIApplicationState appState = UIApplication.sharedApplication.applicationState;

    // Get current orientation of the device
    UIDeviceOrientation currentDeviceOrientation = UIDevice.currentDevice.orientation;
    ViewOrientation currentOrientation = [OneSignalViewHelper validateOrientation:currentDeviceOrientation];
    // Ignore changes in device orientation if or coming from same orientation or orientation is invalid
    if (currentOrientation == OrientationInvalid &&
        (appState == UIApplicationStateInactive || appState == UIApplicationStateBackground)) {
        
        [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"Orientation Change Ended: Orientation same as previous or invalid orientation"];
        
        self.previousOrientation = currentOrientation;
        
        return;
    }
    
    self.previousOrientation = currentOrientation;

    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"Orientation Change Started: Hiding IAM"];

    // Deactivate the pan constraint while changing the screen orientation
    self.panVerticalConstraint.active = false;
    // Hide the IAM and prepare animation based on display location
    self.messageView.hidden = true;
    
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        
        /*
         Code here will execute during the rotation
         */
        [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"Orientation Change Occurring: Removing all previous IAM constraints"];
        
        // Remove all of the constraints connected to the messageView
        [self.messageView removeConstraints:[self.messageView constraints]];

    } completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        
        /*
         Code here will execute after the rotation has finished
         */
        [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"Orientation Change Complete: Getting new height from JS getPageMetaData()"];
        
        // Evaluate the JS getPageMetaData() to obtain the new height for the webView and use it within the completion callback to set the new height
        [self.messageView resetWebViewToMaxBoundsAndResizeHeight:^(NSNumber *newHeight) {
            [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"Orientation Change Complete with New Height: Adding constraints again and showing IAM"];
            
            // Assign new height to message
            self.message.height = newHeight;
            
            // Add all of the constraints using the new message height obtained from JS code
            [self addConstraintsForMessage];
            
            // Reanimate and show IAM
            [self animateAppearance:NO];
        }];
    }];
}

#pragma mark OSInAppMessageViewDelegate Methods
- (void)messageViewFailedToLoadMessageContent {
    [self.delegate messageViewControllerWasDismissed:self.message displayed:NO];
}

- (void)messageViewDidFailToProcessAction {
    [self dismissCurrentInAppMessage];
}

- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"Received in-app script message: %@", message.body]];
    [self jsEventOccurredWithBody:[message.body dataUsingEncoding:NSUTF8StringEncoding]];
}

@end
