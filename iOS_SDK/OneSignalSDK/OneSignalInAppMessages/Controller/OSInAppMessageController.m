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

#import "OSInAppMessageController.h"
#import <OneSignalCore/OneSignalCore.h>
#import <OneSignalOSCore/OneSignalOSCore-Swift.h>
#import "OSMacros.h"
#import <OneSignalUser/OneSignalUser.h>
#import "OSInAppMessagingDefines.h"
#import "OSInAppMessagingRequests.h"


@implementation OSInAppMessageInternal (OSInAppMessageController)

- (void)loadMessageHTMLContentWithResult:(OSResultSuccessBlock _Nullable)successBlock failure:(OSFailureBlock _Nullable)failureBlock {
    let variantId = [self variantId];
    
    if (!variantId) {
        if (failureBlock)
            failureBlock([NSError errorWithDomain:@"onesignal" code:0 userInfo:@{@"error" : [NSString stringWithFormat:@"Unable to find variant ID for languages (%@) for message ID: %@", OneSignalUserManagerImpl.sharedInstance.language, self.messageId]}]);
        
        return;
    }
    
    let request = [OSRequestLoadInAppMessageContent withAppId:OneSignalIdentifiers.currentAppId withMessageId:self.messageId withVariantId:variantId];
    
    [OneSignalCoreImpl.sharedClient executeRequest:request onSuccess:successBlock onFailure:^(OneSignalClientError *error) {
        failureBlock(error.underlyingError);
    }];
}

- (void)loadPreviewMessageHTMLContentWithUUID:(NSString * _Nonnull)previewUUID success:(OSResultSuccessBlock _Nullable)successBlock failure:(OSFailureBlock _Nullable)failureBlock {
    let request = [OSRequestLoadInAppMessagePreviewContent withAppId:OneSignalIdentifiers.currentAppId previewUUID:previewUUID];
    
    [OneSignalCoreImpl.sharedClient executeRequest:request onSuccess:successBlock onFailure:^(OneSignalClientError *error) {
        failureBlock(error.underlyingError);
    }];
}

/**
    The platform type should take precedence over a language match.
    So if, for example, a message has an 'ios' variant but it only
    has 'default' (no language variants), the SDK will prefer this
    variant over lower platforms (ie. 'all') even if they have a
    matching language.
*/
- (NSString * _Nullable)variantId {
    NSString *userLanguage = OneSignalUserManagerImpl.sharedInstance.language;
    NSString *baseLanguage = [[userLanguage componentsSeparatedByString:@"-"] firstObject];
    
    NSString *variantId;
    
    for (NSString *type in PREFERRED_VARIANT_ORDER) {
        NSDictionary<NSString *, NSString *> *languageVariants = self.variants[type];
        if (languageVariants) {
            if (userLanguage) {
                variantId = languageVariants[userLanguage];
            }

            if (!variantId
                && baseLanguage
                && ![baseLanguage isEqualToString:@"zh"]
                && ![baseLanguage isEqualToString:userLanguage]) {
                variantId = languageVariants[baseLanguage];
            }
            
            if (!variantId) {
                variantId = languageVariants[@"default"];
            }
        }
        
        if (variantId) {
            break;
        }
    }
    
    return variantId;
}

@end
