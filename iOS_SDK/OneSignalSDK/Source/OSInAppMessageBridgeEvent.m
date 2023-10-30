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

#import "OSInAppMessageBridgeEvent.h"
#import "OSInAppMessageAction.h"
#import "OneSignalHelper.h"

@implementation OSInAppMessageBridgeEvent

+ (instancetype)instanceWithData:(NSData *)data {
    NSError *error;
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
    if (error || !json) {
        [OneSignalLog onesignalLog:ONE_S_LL_WARN message:[NSString stringWithFormat:@"Unable to decode JS-bridge event with error: %@", error.description ?: @"Unknown Error"]];
        return nil;
    }
    
    return [OSInAppMessageBridgeEvent instanceWithJson:json];
}

+ (instancetype _Nullable)instanceWithJson:(NSDictionary *)json {
    let instance = [OSInAppMessageBridgeEvent new];
    
    if ([json[@"type"] isKindOfClass:[NSString class]] && OS_IS_VALID_BRIDGE_EVENT_TYPE(json[@"type"]))
        instance.type = OS_BRIDGE_EVENT_TYPE_FROM_STRING(json[@"type"]);
    else
        return nil;
    
    switch (instance.type) {
        case OSInAppMessageBridgeEventTypeActionTaken: {
            // deserialize the action JSON
            if ([json[@"body"] isKindOfClass:[NSDictionary class]]) {
                
                let action = [OSInAppMessageAction instanceWithJson:json[@"body"]];
                
                if (!action)
                    return nil;
                
                instance.userAction = action;
            }
            else
                return nil;
            break;
        }
        case OSInAppMessageBridgeEventTypePageRenderingComplete: {
            instance.renderingComplete = [OSInAppMessageBridgeEventRenderingComplete instanceWithJson:json];
            break;
        }
        case OSInAppMessageBridgeEventTypePageResize: {
            instance.resize = [OSInAppMessageBridgeEventResize instanceWithJson:json];
            break;
        }
        case OSInAppMessageBridgeEventTypePageChange: {
            instance.pageChange = [OSInAppMessageBridgeEventPageChange instanceWithJson:json];
            break;
        }
    }
    return instance;
}

+ (instancetype _Nullable)instancePreviewFromNotification:(OSNotification * _Nonnull)notification {
    return nil;
}

- (NSString *)description{
    return [NSString stringWithFormat:@"OSInAppMessageBridgeEvent type: %lu\nrenderingComplete: %@\nresize: %@\nuserAction: %@", (unsigned long)_type, _renderingComplete, _resize, _userAction];
}

@end


@implementation OSInAppMessageBridgeEventRenderingComplete
+ (instancetype _Nullable)instanceWithData:(NSData *)data {
    return nil;
}

+ (instancetype)instanceWithJson:(NSDictionary *)json {
    let instance = [OSInAppMessageBridgeEventRenderingComplete new];
    
    if (json[@"displayLocation"])
        instance.displayLocation = OS_IN_APP_DISPLAY_POSITION_FROM_STRING(json[@"displayLocation"]);
    else
        instance.displayLocation = OSInAppMessageDisplayPositionFullScreen;
    
    if (json[@"pageMetaData"][@"rect"][@"height"])
        instance.height = json[@"pageMetaData"][@"rect"][@"height"];
    
    if (json[@"dragToDismissDisabled"]) {
        instance.dragToDismissDisabled = [json[@"dragToDismissDisabled"] boolValue];
    }
    
    return instance;
}

+ (instancetype _Nullable)instancePreviewFromNotification:(OSNotification * _Nonnull)notification {
    return nil;
}


- (NSString *)description {
    return [NSString stringWithFormat:@"OSInAppMessageBridgeEventRenderingComplete height: %@\ndisplayLocation: %lu", _height, (unsigned long)_displayLocation];
}
@end

@implementation OSInAppMessageBridgeEventResize
+ (instancetype)instanceWithData:(NSData *)data {
    return nil;
}

+ (instancetype)instanceWithJson:(NSDictionary *)json {
    let instance = [OSInAppMessageBridgeEventResize new];
    
    if (json[@"pageMetaData"][@"rect"][@"height"])
        instance.height = json[@"pageMetaData"][@"rect"][@"height"];
    
    return instance;
}

+ (instancetype _Nullable)instancePreviewFromNotification:(OSNotification * _Nonnull)notification {
    return nil;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"OSInAppMessageBridgeEventResize height: %@", _height];
}
@end

@implementation OSInAppMessageBridgeEventPageChange
+ (instancetype)instanceWithData:(NSData *)data {
    return nil;
}

+ (instancetype)instanceWithJson:(NSDictionary *)json {
    let instance = [OSInAppMessageBridgeEventPageChange new];
    instance.page = [OSInAppMessagePage instanceWithJson:json];
    return instance;
}

+ (instancetype _Nullable)instancePreviewFromNotification:(OSNotification * _Nonnull)notification {
    return nil;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"OSInAppMessageBridgeEventPageChange pageId: %@ pageIndex: %@", _page.pageId, _page.pageIndex];
}

@end

