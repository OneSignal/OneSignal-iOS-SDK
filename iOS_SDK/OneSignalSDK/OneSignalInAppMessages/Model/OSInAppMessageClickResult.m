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

#import "OneSignalHelper.h"
#import "OSInAppMessageClickResult.h"
#import "OSInAppMessagePushPrompt.h"
#import "OSInAppMessageLocationPrompt.h"

@implementation OSInAppMessageClickResult

#define OS_URL_ACTION_TYPES @[@"browser", @"webview", @"replacement"]
#define OS_IS_VALID_URL_ACTION(string) [OS_URL_ACTION_TYPES containsObject:string]
#define OS_URL_ACTION_TYPE_FROM_STRING(string) (OSInAppMessageActionUrlType)[OS_URL_ACTION_TYPES indexOfObject:string]

+ (instancetype _Nullable)instanceWithData:(NSData *)data {
    NSError *error;
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    
    if (error || !json) {
        [OneSignalLog onesignalLog:ONE_S_LL_ERROR message:[NSString stringWithFormat:@"Unable to decode in-app message JSON: %@", error.description ?: @"No Data"]];
        return nil;
    }
    
    return [self instanceWithJson:json];
}

+ (instancetype _Nullable)instanceWithJson:(NSDictionary *)json {
    OSInAppMessageClickResult *action = [OSInAppMessageClickResult new]; // on click goes here
    
    if ([json[@"click_type"] isKindOfClass:[NSString class]])
        action.clickType = json[@"click_type"];
    
    if ([json[@"id"] isKindOfClass:[NSString class]])
        action.clickId = json[@"id"];
    
    if ([json[@"url"] isKindOfClass:[NSString class]])
        action.url = json[@"url"];
    
    if ([json[@"name"] isKindOfClass:[NSString class]])
        action.actionId = json[@"name"];
    
    if ([json[@"pageId"] isKindOfClass:[NSString class]])
        action.pageId = json[@"pageId"];
    
    if ([json[@"url_target"] isKindOfClass:[NSString class]] && OS_IS_VALID_URL_ACTION(json[@"url_target"]))
        action.urlTarget = OS_URL_ACTION_TYPE_FROM_STRING(json[@"url_target"]);
    else
        action.urlTarget = OSInAppMessageActionUrlTypeWebview;
    
    if ([json[@"close"] isKindOfClass:[NSNumber class]])
        action.closingMessage = [json[@"close"] boolValue];
    else
        action.closingMessage = true; // Default behavior
    
    [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"OSInAppMessageClickResult %@", json]];

    NSMutableArray *outcomes = [NSMutableArray new];
    //TODO: when backend is ready check that key matches
    if ([json[@"outcomes"] isKindOfClass:[NSArray class]]) {
        NSArray *outcomesString = json[@"outcomes"];
        
        for (NSDictionary *outcomeJson in outcomesString) {
            [outcomes addObject:[OSInAppMessageOutcome instanceWithJson:outcomeJson]];
        }
    }
    action.outcomes = outcomes;
    //TODO: when backend is ready check if key match
    if (json[@"tags"]) {
        action.tags= [OSInAppMessageTag instanceWithJson:json[@"tags"]];
    } else {
        action.tags = nil;
    }
    
    NSMutableArray<NSObject<OSInAppMessagePrompt>*> *promptActions = [NSMutableArray new];
    //TODO: when backend is ready check if key match
    if ([json[@"prompts"] isKindOfClass:[NSArray class]]) {
        NSArray<NSString *> *promptActionsStrings = json[@"prompts"];
        
        for (NSString *prompt in promptActionsStrings) {
            // TODO: We should refactor this string handling to enums
            if ([prompt isEqualToString:@"push"]) {
                [promptActions addObject:[[OSInAppMessagePushPrompt alloc] init]];
            } else if ([prompt isEqualToString:@"location"]) {
                [promptActions addObject:[[OSInAppMessageLocationPrompt alloc] init]];
            }
        }

    }
    action.promptActions = promptActions;

    return action;
}

+ (instancetype _Nullable)instancePreviewFromNotification:(OSNotification * _Nonnull)notification {
    return nil;
}

- (NSDictionary *)jsonRepresentation {
    let json = [NSMutableDictionary new];
    
    json[@"actionId"] = self.actionId;
    json[@"urlTarget"] = @(self.urlTarget);
    json[@"closingMessage"] = @(self.closingMessage);
    
    if (self.url)
        json[@"url"] = self.url;
    
    return json;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"OSInAppMessageClickResult actionId: %@ \nurl: %@ urlTarget: %@ closingMessage: %@", _actionId, _url, @(_urlTarget), @(_closingMessage)];
}

@end
