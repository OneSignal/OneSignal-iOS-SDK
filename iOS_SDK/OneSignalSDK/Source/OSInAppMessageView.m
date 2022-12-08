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

#import "OSInAppMessageView.h"
#import "OneSignalHelper.h"
#import <WebKit/WebKit.h>
#import "OSInAppMessageAction.h"
#import "OneSignalViewHelper.h"

@interface OSInAppMessageView () <UIScrollViewDelegate, WKUIDelegate, WKNavigationDelegate>

@property (strong, nonatomic, nonnull) OSInAppMessageInternal *message;
@property (strong, nonatomic, nonnull) WKWebView *webView;
@property (nonatomic) BOOL loaded;
@property (nonatomic) BOOL isFullscreen;
@end


@implementation OSInAppMessageView

- (instancetype _Nonnull)initWithMessage:(OSInAppMessageInternal *)inAppMessage withScriptMessageHandler:(id<WKScriptMessageHandler>)messageHandler {
    if (self = [super init]) {
        self.message = inAppMessage;
        self.translatesAutoresizingMaskIntoConstraints = false;
        [self setupWebviewWithMessageHandler:messageHandler];
    }
    
    return self;
}

- (NSString *)getTagsString {
    NSError *error;
    NSDictionary<NSString *, NSString*> *tags = [OneSignalUserManagerImpl.sharedInstance getTags];
    if (tags == nil || tags.count <= 0 ) {
        [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:@"[getTagsString] no tags found for the player"];
        return nil;
    }
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:tags
                                                       options:NSJSONWritingPrettyPrinted
                                                         error:&error];
    NSString *jsonString;
    if (!jsonData) {
        [OneSignalLog onesignalLog:ONE_S_LL_ERROR message:
         [NSString stringWithFormat:@"Error parsing tag dictionary to json: %@", error]];
    } else {
         jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    }
    return jsonString;
}

- (NSString *)addTagsToHTML:(NSString *)html {
    NSString *tags = [self getTagsString];
    if (!tags) {
        return html;
    }
    //Script to set the tags for liquid tag substitution
    NSString *newHtml = [NSString stringWithFormat:@"%@ \n\n\
                         <script> \
                            setPlayerTags(%@);\
                         </script>",html, tags];
    return newHtml;
}

- (void)loadedHtmlContent:(NSString *)html withBaseURL:(NSURL *)url {
    // UI Update must be done on the main thread
    NSString *taggedHTML = [self addTagsToHTML:html];
    [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"loadedHtmlContent with Tags: \n%@", taggedHTML]];
    [self.webView loadHTMLString:taggedHTML baseURL:url];
    
}

- (void)setupWebviewWithMessageHandler:(id<WKScriptMessageHandler>)handler {
    let configuration = [WKWebViewConfiguration new];
    [configuration.userContentController addScriptMessageHandler:handler name:@"iosListener"];
    
    CGFloat marginSpacing = [OneSignalViewHelper sizeToScale:MESSAGE_MARGIN];
    
    // WebView should use mainBounds as frame since we need to make sure it spans full possible screen size
    // to prevent text wrapping while obtaining true height of message from JS
    CGRect mainBounds = UIScreen.mainScreen.bounds;
    mainBounds.size.width -= (2.0 * marginSpacing);
    
    // Setup WebView, delegates, and disable scrolling inside of the WebView
    self.webView = [[WKWebView alloc] initWithFrame:mainBounds configuration:configuration];
    self.webView.backgroundColor = [UIColor clearColor];
    self.webView.opaque = NO;
    [self addSubview:self.webView];
    
    [self layoutIfNeeded];
}

- (void)setIsFullscreen:(BOOL)isFullscreen {
    _isFullscreen = isFullscreen;
    [self setWebviewFrame];
}

- (void)setWebviewFrame {
    CGRect mainBounds = UIScreen.mainScreen.bounds;
    if (!self.isFullscreen) {
        CGFloat marginSpacing = [OneSignalViewHelper sizeToScale:MESSAGE_MARGIN];
        mainBounds.size.width -= (2.0 * marginSpacing);
    }
    [self.webView setFrame:mainBounds];
}

/*
 Method for resetting the height of the WebView so the JS can calculate the new height
 WebView will have margins accounted for on width, but height just needs to be phone height or larger
 The issue is that text wrapping can cause incorrect height issues so width is the real concern here
 */
- (void)resetWebViewToMaxBoundsAndResizeHeight:(void (^) (NSNumber *newHeight)) completion {
    [self.webView removeConstraints:[self.webView constraints]];
    
   
    [self setWebviewFrame];
    [self.webView layoutIfNeeded];
    
    // Evaluate JS getPageMetaData() method to obtain the updated height for the messageView to contain the webView contents
    [self.webView evaluateJavaScript:OS_JS_GET_PAGE_META_DATA_METHOD completionHandler:^(NSDictionary *result, NSError *error) {
        if (error) {
            NSString *errorMessage = [NSString stringWithFormat:@"Javascript Method: %@ Evaluated with Error: %@", OS_JS_GET_PAGE_META_DATA_METHOD, error];
            [OneSignalLog onesignalLog:ONE_S_LL_ERROR message:errorMessage];
            return;
        }
        NSString *successMessage = [NSString stringWithFormat:@"Javascript Method: %@ Evaluated with Success: %@", OS_JS_GET_PAGE_META_DATA_METHOD, result];
        [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:successMessage];
        
        [self setupWebViewConstraints];

        // Extract the height from the result and pass it to the current messageView
        NSNumber *height = [self extractHeightFromMetaDataPayload:result];
        completion(height);
    }];
}

- (void)updateSafeAreaInsets {
    if (@available(iOS 11, *)) {
        UIWindow *keyWindow = UIApplication.sharedApplication.keyWindow;
        CGFloat top = keyWindow.safeAreaInsets.top;
        CGFloat bottom = keyWindow.safeAreaInsets.bottom;
        CGFloat right = keyWindow.safeAreaInsets.right;
        CGFloat left = keyWindow.safeAreaInsets.left;
        NSString *safeAreaInsetsObjectString = [NSString stringWithFormat:OS_JS_SAFE_AREA_INSETS_OBJ,top, bottom, right, left];
        
        NSString *setInsetsString = [NSString stringWithFormat:OS_SET_SAFE_AREA_INSETS_METHOD, safeAreaInsetsObjectString];
        [self.webView evaluateJavaScript:setInsetsString completionHandler:^(NSDictionary *result, NSError * _Nullable error) {
            if (error) {
                NSString *errorMessage = [NSString stringWithFormat:@"Javascript Method: %@ Evaluated with Error: %@", OS_SET_SAFE_AREA_INSETS_METHOD, error];
                [OneSignalLog onesignalLog:ONE_S_LL_ERROR message:errorMessage];
                return;
            }
            NSString *successMessage = [NSString stringWithFormat:@"Javascript Method: %@ Evaluated with Success: %@", OS_SET_SAFE_AREA_INSETS_METHOD, result];
            [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:successMessage];
        }];
    }
}

- (NSNumber *)extractHeightFromMetaDataPayload:(NSDictionary *)result {
    return @([result[@"rect"][@"height"] intValue]);
}

- (void)setupWebViewConstraints {
    [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:@"Setting up In-App Message WebView Constraints"];
    
    [self.webView removeConstraints:[self.webView constraints]];
    
    self.webView.translatesAutoresizingMaskIntoConstraints = false;
    self.webView.UIDelegate = self;
    self.webView.navigationDelegate = self;
    self.webView.scrollView.delegate = self;
    self.webView.scrollView.scrollEnabled = false;
    
    self.webView.layer.cornerRadius = 10.0f;
    self.webView.layer.masksToBounds = true;
    
    if (@available(iOS 11, *))
        self.webView.scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    
    [self.webView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor].active = true;
    [self.webView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor].active = true;
    [self.webView.topAnchor constraintEqualToAnchor:self.topAnchor].active = true;
    [self.webView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor].active = true;
    
    [self layoutIfNeeded];
}

/*
 Make sure to call this method when the message view gets dismissed
 Otherwise a memory leak will occur and the entire view controller will be leaked
 */
- (void)removeScriptMessageHandler {
    [self.webView.configuration.userContentController removeScriptMessageHandlerForName:@"iosListener"];
}

- (void)loadReplacementURL:(NSURL *)url {
    [self.webView loadRequest:[NSURLRequest requestWithURL:url]];
}

#pragma mark WKWebViewNavigationDelegate Methods
- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    // WebView finished loading
    if (self.loaded)
        return;
    self.loaded = true;
}

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
    return nil;
}

- (void)scrollViewWillBeginZooming:(UIScrollView *)scrollView
                          withView:(UIView *)view {
    // Disable pinch zooming
    if (scrollView.pinchGestureRecognizer)
        scrollView.pinchGestureRecognizer.enabled = false;
}

@end
