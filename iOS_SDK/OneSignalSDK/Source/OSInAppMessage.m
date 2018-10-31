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

#import "OSInAppMessage.h"
#import "OneSignalHelper.h"

@implementation OSInAppMessage

-(instancetype)initWithData:(NSData *)data {
    NSError *error;
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    
    if (error || !json) {
        [OneSignal onesignal_Log:ONE_S_LL_ERROR message:[NSString stringWithFormat:@"Unable to decode in-app message JSON: %@", error.description ?: @"No Data"]];
        return nil;
    }
    
    return [self initWithJson:json];
}

- (instancetype)initWithJson:(NSDictionary * _Nonnull)json {
    if (self = [super init]) {
        if (json[@"type"] != nil && [json[@"type"] isKindOfClass:[NSString class]])
            self.type = displayTypeFromString(json[@"type"]);
        else
            return nil;
        
        if (json[@"id"] && [json[@"id"] isKindOfClass:[NSString class]])
            self.messageId = json[@"id"];
        else
            return nil;
        
        if (json[@"content_id"] && [json[@"content_id"] isKindOfClass:[NSString class]])
            self.contentId = json[@"content_id"];
        else
            return nil;
        
        if (json[@"triggers"] && [json[@"triggers"] isKindOfClass:[NSDictionary class]])
            self.triggers = json[@"triggers"];
        else
            return nil;
    }
    
    return self;
}

- (instancetype _Nonnull)initWithType:(OSInAppMessageDisplayType)displayType {
    if (self = [super init]) {
        self.type = displayType;
        
        switch (self.type) {
            case OSInAppMessageDisplayTypeCenteredModal:
                self.position = OSInAppMessageDisplayPositionCentered;
                self.heightRatio = CENTERED_MODAL_HEIGHT;
                break;
            case OSInAppMessageDisplayTypeBottomBanner:
                self.position = OSInAppMessageDisplayPositionBottom;
                self.heightRatio = BANNER_HEIGHT;
                break;
            case OSInAppMessageDisplayTypeFullScreen:
                self.position = OSInAppMessageDisplayPositionCentered;
                self.heightRatio = FULL_SCREEN_HEIGHT;
                break;
            case OSInAppMessageDisplayTypeTopBanner:
                self.position = OSInAppMessageDisplayPositionTop;
                self.heightRatio = BANNER_HEIGHT;
                break;
        }
    }
    
    return self;
}

OSInAppMessageDisplayType displayTypeFromString(NSString *typeString) {
    if ([typeString isEqualToString:@"centered_modal"])
        return OSInAppMessageDisplayTypeCenteredModal;
    else if ([typeString isEqualToString:@"top_banner"])
        return OSInAppMessageDisplayTypeTopBanner;
    else if ([typeString isEqualToString:@"bottom_banner"])
        return OSInAppMessageDisplayTypeBottomBanner;
    else
        return OSInAppMessageDisplayTypeFullScreen;
}

@end

