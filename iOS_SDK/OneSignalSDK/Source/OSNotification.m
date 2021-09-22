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

#import <Foundation/Foundation.h>

#import <UIKit/UIKit.h>

#import "OSNotification+Internal.h"

#import "OneSignal.h"

#import "OneSignalCommonDefines.h"

#import "OneSignalUserDefaults.h"

@implementation OSNotification

 OSNotificationDisplayResponse _completion;
 NSTimer *_timeoutTimer;
 
+ (instancetype)parseWithApns:(nonnull NSDictionary*)message {
    if (!message)
        return nil;
    
    OSNotification *osNotification = [OSNotification new];
    
    [osNotification initWithRawMessage:message];
    return osNotification;
}

- (void)initWithRawMessage:(NSDictionary*)message {
    _rawPayload = [NSDictionary dictionaryWithDictionary:message];
    
    if ([_rawPayload[@"os_data"] isKindOfClass:[NSDictionary class]])
        [self parseOSDataPayload];
    else
        [self parseOriginalPayload];
    
    [self parseOtherApnsFields];
    
    _timeoutTimer = [NSTimer timerWithTimeInterval:CUSTOM_DISPLAY_TYPE_TIMEOUT target:self selector:@selector(timeoutTimerFired:) userInfo:_notificationId repeats:false];
}

// Original OneSignal payload format.
- (void)parseOriginalPayload {
    BOOL remoteSlient = _rawPayload[@"m"] && !_rawPayload[@"aps"][@"alert"];
    if (remoteSlient)
        [self parseRemoteSlient:_rawPayload];
    else {
        [self parseApnsFields];
        _attachments = _rawPayload[@"att"];
        [self parseActionButtons:_rawPayload[@"buttons"]];
    }
    
    [self parseCommonOneSignalFields:_rawPayload[@"custom"]];
    _additionalData = _rawPayload[@"custom"][@"a"];
    
    //fixes an issue where actionSelected was a top level property in _rawPayload
    //and 'actionSelected' was not being set in additionalData
    if (_rawPayload[@"actionSelected"] && !_additionalData) {
        _additionalData = @{@"actionSelected" : _rawPayload[@"actionSelected"]};
    } else if (_rawPayload[@"actionSelected"]) {
        NSMutableDictionary *additional = [_additionalData mutableCopy];
        additional[@"actionSelected"] = _rawPayload[@"actionSelected"];
        _additionalData = additional;
    }
}

// New OneSignal playload format.
//   OneSignal specific features are under "os_data".
- (void)parseOSDataPayload {
    NSDictionary *os_data = _rawPayload[@"os_data"];
    BOOL remoteSlient = os_data[@"buttons"] && !_rawPayload[@"aps"][@"alert"];
    if (remoteSlient)
        [self parseRemoteSlient:os_data[@"buttons"]];
    else {
        [self parseApnsFields];
        _attachments = os_data[@"att"];
        
        // it appears that in iOS 9, the 'buttons' os_data field is an object not array
        // this if statement checks for this condition and parses appropriately
        if ([os_data[@"buttons"] isKindOfClass:[NSArray class]]) {
            [self parseActionButtons:os_data[@"buttons"]];
        } else if (os_data[@"buttons"] && [os_data[@"buttons"] isKindOfClass: [NSDictionary class]] && [os_data[@"buttons"][@"o"] isKindOfClass: [NSArray class]]) {
            [self parseActionButtons:os_data[@"buttons"][@"o"]];
        } else if ([_rawPayload[@"actionbuttons"] isKindOfClass:[NSArray class]]) {
            [self parseActionButtons:_rawPayload[@"actionbuttons"]];
        }
    }
    
    [self parseCommonOneSignalFields:_rawPayload[@"os_data"]];
    [self parseOSDataAdditionalData];
}

- (void)parseOSDataAdditionalData {
    NSMutableDictionary *additional = [_rawPayload mutableCopy];
    [additional removeObjectForKey:@"aps"];
    [additional removeObjectForKey:@"os_data"];
    _additionalData = [[NSDictionary alloc] initWithDictionary:additional];
}

// Fields that share the same format for all OneSignal payload types.
- (void)parseCommonOneSignalFields:(NSDictionary*)payload {
    _notificationId = payload[@"i"];
    _launchURL = payload[@"u"];
    _templateId = payload[@"ti"];
    _templateName = payload[@"tn"];
    _badgeIncrement = [payload[@"badge_inc"] integerValue];
}

- (void)parseApnsFields {
    [self parseAlertField:_rawPayload[@"aps"][@"alert"]];
    _badge = [_rawPayload[@"aps"][@"badge"] intValue];
    _sound = _rawPayload[@"aps"][@"sound"];
}

// Pasrse the APNs alert field, can be a NSString or a NSDictionary
- (void)parseAlertField:(NSObject*)alert {
    if ([alert isKindOfClass:[NSDictionary class]]) {
        NSDictionary *alertDictionary = (NSDictionary*)alert;
        _body = alertDictionary[@"body"];
        _title = alertDictionary[@"title"];
        _subtitle = alertDictionary[@"subtitle"];
    }
    else
        _body = (NSString*)alert;
}

// Only used on iOS 9 and older.
//   - Or if the OneSignal server hasn't received the iOS version update.
// May also be used if OneSignal server hasn't received the SDK version 2.4.0+ update event
- (void)parseRemoteSlient:(NSDictionary*)payload {
    [self parseAlertField:payload[@"m"]];
    _badge = [payload[@"b"] intValue];
    _sound = payload[@"s"];
    _attachments = payload[@"at"];
    [self parseActionButtons:payload[@"o"]];
}

// Parse and convert minified keys for action buttons
- (void)parseActionButtons:(NSArray<NSDictionary*>*)buttons {
    NSMutableArray *buttonArray = [NSMutableArray new];
    for (NSDictionary *button in buttons) {
        
        // check to ensure the button object has the correct
        // format before adding it to the array
        if (!button[@"n"] ||
            (!button[@"i"] && !button[@"n"])) {
            continue;
        }
        
        NSMutableDictionary *actionDict = [NSMutableDictionary new];
        actionDict[@"text"] = button[@"n"];
        actionDict[@"id"] = button[@"i"] ?: button[@"n"];
        
        // Parse Action Icon into system or template icon
        if (button[@"icon_type"] && button[@"path"]) {
            if ([button[@"icon_type"] isEqualToString:@"system"]) {
                actionDict[@"systemIcon"] = button[@"path"];
            } else if ([button[@"icon_type"] isEqualToString:@"custom"]) {
                actionDict[@"templateIcon"] = button[@"path"];
            }
        }
        
        [buttonArray addObject: actionDict];
    }
    
    _actionButtons = buttonArray;
}

- (void)parseOtherApnsFields {
    NSDictionary *aps = _rawPayload[@"aps"];
    if (aps[@"content-available"])
        _contentAvailable = (BOOL)aps[@"content-available"];
    
    if (aps[@"mutable-content"])
        _mutableContent = (BOOL)aps[@"mutable-content"];
    
    if (aps[@"thread-id"]) {
        _threadId = (NSString *)aps[@"thread-id"];
    }

    if (aps[@"relevance-score"]) {
        _relevanceScore = (NSNumber *)aps[@"relevance-score"];
    }
    
    if (aps[@"interruption-level"]) {
        _interruptionLevel = (NSString *)aps[@"interruption-level"];
    }
    
    _category = aps[@"category"];
}

- (NSString *)description {
    return [NSString stringWithFormat: @"notificationId=%@ templateId=%@ templateName=%@ contentAvailable=%@ mutableContent=%@ category=%@ relevanceScore=%@ interruptionLevel=%@ rawPayload=%@", _notificationId, _templateId, _templateName, _contentAvailable ? @"YES" : @"NO", _mutableContent ? @"YES" : @"NO", _category, _relevanceScore, _interruptionLevel, _rawPayload];
}

- (NSDictionary *)jsonRepresentation {
    NSMutableDictionary *obj = [NSMutableDictionary new];
    
    if (self.notificationId)
        [obj setObject:self.notificationId forKeyedSubscript: @"notificationId"];
    
    if (self.sound)
        [obj setObject:self.sound forKeyedSubscript: @"sound"];
    
    if (self.title)
        [obj setObject:self.title forKeyedSubscript: @"title"];
    
    if (self.body)
        [obj setObject:self.body forKeyedSubscript: @"body"];
    
    if (self.subtitle)
        [obj setObject:self.subtitle forKeyedSubscript: @"subtitle"];
    
    if (self.additionalData)
        [obj setObject:self.additionalData forKeyedSubscript: @"additionalData"];
    
    if (self.actionButtons)
        [obj setObject:self.actionButtons forKeyedSubscript: @"actionButtons"];
    
    if (self.attachments)
        [obj setObject:self.attachments forKeyedSubscript: @"attachments"];
    
    if (self.threadId)
        [obj setObject:self.threadId forKeyedSubscript: @"threadId"];
    
    if (self.rawPayload)
        [obj setObject:self.rawPayload forKeyedSubscript: @"rawPayload"];
    
    if (self.launchURL)
        [obj setObject:self.launchURL forKeyedSubscript: @"launchURL"];
    
    if (self.contentAvailable)
        [obj setObject:@(self.contentAvailable) forKeyedSubscript: @"contentAvailable"];
    
    if (self.mutableContent)
        [obj setObject:@(self.mutableContent) forKeyedSubscript: @"mutableContent"];
    
    if (self.templateName)
        [obj setObject:self.templateName forKeyedSubscript: @"templateName"];
    
    if (self.templateId)
        [obj setObject:self.templateId forKeyedSubscript: @"templateId"];
    
    if (self.badge)
        [obj setObject:@(self.badge) forKeyedSubscript: @"badge"];
    
    if (self.badgeIncrement)
        [obj setObject:@(self.badgeIncrement) forKeyedSubscript: @"badgeIncrement"];
    
    if (self.category)
        [obj setObject:self.category forKeyedSubscript: @"category"];
    
    if (self.relevanceScore)
        [obj setObject:self.relevanceScore forKeyedSubscript: @"relevanceScore"];
    
    if (self.interruptionLevel)
        [obj setObject:self.interruptionLevel forKeyedSubscript: @"interruptionLevel"];

    return obj;
}

- (NSString *)stringify {
    NSDictionary *obj = [self jsonRepresentation];
    
    //Convert obj into a serialized
    NSError *err;
    NSData *jsonData = [NSJSONSerialization  dataWithJSONObject:obj options:0 error:&err];
    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}

#pragma mark willShowInForegroundHandler Methods

- (void)setCompletionBlock:(OSNotificationDisplayResponse)completion {
    _completion = completion;
}

 - (OSNotificationDisplayResponse)getCompletionBlock {
     OSNotificationDisplayResponse block = ^(OSNotification *notification){
         /*
          If notification is null here then display was cancelled and we need to
          reset the badge count to the value prior to receipt of this notif
          */
         if (!notification) {
             NSInteger previousBadgeCount = [UIApplication sharedApplication].applicationIconBadgeNumber;
             [OneSignalUserDefaults.initShared saveIntegerForKey:ONESIGNAL_BADGE_KEY withValue:previousBadgeCount];
         }
         [self complete:notification];
     };
     return block;
 }

 - (void)complete:(OSNotification *)notification {
     [_timeoutTimer invalidate];
     if (_completion) {
         _completion(notification);
         _completion = nil;
     }
 }

 - (void)startTimeoutTimer {
     [[NSRunLoop currentRunLoop] addTimer:_timeoutTimer forMode:NSRunLoopCommonModes];
 }

 - (void)timeoutTimerFired:(NSTimer *)timer {
     [OneSignal onesignalLog:ONE_S_LL_ERROR
     message:[NSString stringWithFormat:@"Notification willShowInForeground completion timed out. Completion was not called within %f seconds.", CUSTOM_DISPLAY_TYPE_TIMEOUT]];
     [self complete:self];
 }

 - (void)dealloc {
     if (_timeoutTimer && _completion) {
         [_timeoutTimer invalidate];
     }
 }

@end
