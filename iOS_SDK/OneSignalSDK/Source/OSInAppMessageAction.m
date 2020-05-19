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

#import "OSInAppMessageAction.h"
#import "OSInAppMessagePushPrompt.h"
#import "OSInAppMessageLocationPrompt.h"

@implementation OSInAppMessageAction

#define OS_URL_ACTION_TYPES @[@"browser", @"webview", @"replacement"]
#define OS_IS_VALID_URL_ACTION(string) [OS_URL_ACTION_TYPES containsObject:string]
#define OS_URL_ACTION_TYPE_FROM_STRING(string) (OSInAppMessageActionUrlType)[OS_URL_ACTION_TYPES indexOfObject:string]

+ (instancetype)instanceWithData:(NSData *)data {
    NSError *error;
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    
    if (error || !json) {
        [OneSignal onesignal_Log:ONE_S_LL_ERROR message:[NSString stringWithFormat:@"Unable to decode in-app message JSON: %@", error.description ?: @"No Data"]];
        return nil;
    }
    
    return [self instanceWithJson:json];
}

+ (instancetype)instanceWithJson:(NSDictionary *)tempJson {
    NSMutableDictionary* json = [[NSMutableDictionary alloc] initWithDictionary:tempJson];
    
    OSInAppMessageAction *action = [OSInAppMessageAction new];
    
    if ([json[@"click_type"] isKindOfClass:[NSString class]])
        action.clickType = json[@"click_type"];
    
    if ([json[@"id"] isKindOfClass:[NSString class]])
        action.clickId = json[@"id"];
    
    if ([json[@"url"] isKindOfClass:[NSString class]])
        action.clickUrl = [NSURL URLWithString:json[@"url"]];
    
    if ([json[@"name"] isKindOfClass:[NSString class]])
        action.clickName = json[@"name"];
    
    if ([json[@"url_target"] isKindOfClass:[NSString class]] && OS_IS_VALID_URL_ACTION(json[@"url_target"]))
        action.urlActionType = OS_URL_ACTION_TYPE_FROM_STRING(json[@"url_target"]);
    else
        action.urlActionType = OSInAppMessageActionUrlTypeWebview;
    
    if ([json[@"close"] isKindOfClass:[NSNumber class]])
        action.closesMessage = [json[@"close"] boolValue];
    else
        action.closesMessage = true; // Default behavior

    NSMutableArray *outcomes = [NSMutableArray new];
    //TODO: when backend is ready check that key matches
    if ([json[@"outcomes"] isKindOfClass:[NSArray class]]) {
        NSArray *outcomesString = json[@"outcomes"];
        
        for (NSDictionary *outcomeJson in outcomesString) {
            [outcomes addObject:[OSInAppMessageOutcome instanceWithJson:outcomeJson]];
        }
    }
    action.outcomes = outcomes;

    // TODO: TESTING ONLY
    if (OneSignal.iamV2Outcomes && ![OneSignal.iamV2Outcomes isEqualToString:@""]) {
        NSArray *outcomeSplit = [OneSignal.iamV2Outcomes componentsSeparatedByString:@","];
        NSMutableArray *outcomesToSend = [NSMutableArray new];
        for (int i = 0; i < outcomeSplit.count; i++) {
            NSString *outcome = [outcomeSplit objectAtIndex:i];
            NSArray *splitOutcome = [outcome componentsSeparatedByString:@":"];
            NSString *name = [splitOutcome objectAtIndex:0];
            if (outcomeSplit.count == 1)
                [outcomesToSend addObject:@{
                    @"name": name,
                }];
            else if (outcomeSplit.count == 2) {
                NSString *value = [[outcomeSplit objectAtIndex:1] lowercaseString];
                if ([value isEqualToString:@"true"] || [value isEqualToString:@"false"]) {
                    [outcomesToSend addObject:@{
                        @"name": name,
                        @"unique": @(value.boolValue),
                    }];
                } else {
                    [outcomesToSend addObject:@{
                        @"name": name,
                        @"weight": @(value.doubleValue),
                    }];
                }
            }
        }
        NSMutableArray *outcomes = [NSMutableArray new];
        for (NSDictionary *outcomeJson in outcomesToSend) {
            [outcomes addObject:[OSInAppMessageOutcome instanceWithJson:outcomeJson]];
        }
        action.outcomes = outcomes;
    }
    
    //TODO: when backend is ready check if key match
    if (json[@"tags"]) {
        action.tags= [OSInAppMessageTag instanceWithJson:json[@"tags"]];
    } else {
        action.tags = nil;
    }
    
    // TODO: TESTING ONLY
    if (OneSignal.iamV2Tags && ![OneSignal.iamV2Tags isEqualToString:@""]) {
        NSArray *tagSplit = [OneSignal.iamV2Tags componentsSeparatedByString:@","];
        NSMutableDictionary *allTags = [NSMutableDictionary new];
        NSMutableDictionary *tagsToAdd = [NSMutableDictionary new];
        NSMutableArray *tagsToRemove = [NSMutableArray new];
        for (int i = 0; i < tagSplit.count; i++) {
            NSString *tag = [tagSplit objectAtIndex:i];
            NSArray *splitTag = [tag componentsSeparatedByString:@":"];
            NSString *tagKey = [splitTag objectAtIndex:0];

            if (splitTag.count == 2) {
                NSString *tagValue = [splitTag objectAtIndex:1];
                if ([tagValue isEqualToString:@""]) {
                    [tagsToRemove addObject:tagKey];
                }
                else {
                    tagsToAdd[tagKey] = tagValue;
                }
            } else if (splitTag.count == 1) {
                [tagsToRemove addObject:tagKey];
            }
        }
        allTags[@"adds"] = tagsToAdd;
        allTags[@"removes"] = tagsToRemove;
        action.tags = [OSInAppMessageTag instanceWithJson:allTags];
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

- (NSString *)description {
    return [NSString stringWithFormat:@"OSInAppMessageAction outcome: %@ \ntag: %@ promptAction: %@", _outcomes, _tags, [_promptActions description]];
}

@end
