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

#import "OSNotificationPayload+Internal.h"

#import "OneSignal.h"

@implementation OSNotificationPayload

+(instancetype)parseWithApns:(NSDictionary*)message {
    if (!message)
        return nil;
    
    OSNotificationPayload *osPayload = [OSNotificationPayload new];
    
    [osPayload initWithRawMessage:message];
    return osPayload;
}

-(void)initWithRawMessage:(NSDictionary*)message {
    _rawPayload = [NSDictionary dictionaryWithDictionary:message];
    
    if ([_rawPayload[@"os_data"] isKindOfClass:[NSDictionary class]])
        [self parseOSDataPayload];
    else
        [self parseOriginalPayload];
    
    [self parseOtherApnsFields];
}

// Original OneSignal payload format.
-(void)parseOriginalPayload {
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
-(void)parseOSDataPayload {
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

-(void)parseOSDataAdditionalData {
    NSMutableDictionary *additional = [_rawPayload mutableCopy];
    [additional removeObjectForKey:@"aps"];
    [additional removeObjectForKey:@"os_data"];
    _additionalData = [[NSDictionary alloc] initWithDictionary:additional];
}

// Fields that share the same format for all OneSignal payload types.
-(void)parseCommonOneSignalFields:(NSDictionary*)payload {
    _notificationID = payload[@"i"];
    _launchURL = payload[@"u"];
    _templateID = payload[@"ti"];
    _templateName = payload[@"tn"];
    _badgeIncrement = [payload[@"badge_inc"] integerValue];
}

-(void)parseApnsFields {
    [self parseAlertField:_rawPayload[@"aps"][@"alert"]];
    _badge = [_rawPayload[@"aps"][@"badge"] intValue];
    _sound = _rawPayload[@"aps"][@"sound"];
}

// Pasrse the APNs alert field, can be a NSString or a NSDictionary
-(void)parseAlertField:(NSObject*)alert {
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
-(void)parseRemoteSlient:(NSDictionary*)payload {
    [self parseAlertField:payload[@"m"]];
    _badge = [payload[@"b"] intValue];
    _sound = payload[@"s"];
    _attachments = payload[@"at"];
    [self parseActionButtons:payload[@"o"]];
}

// Parse and convert minified keys for action buttons
-(void)parseActionButtons:(NSArray<NSDictionary*>*)buttons {
    NSMutableArray *buttonArray = [NSMutableArray new];
    for (NSDictionary *button in buttons) {
        [buttonArray addObject: @{@"text" : button[@"n"],
                                  @"id" : (button[@"i"] ?: button[@"n"])
                                 }];
    }
    
    _actionButtons = buttonArray;
}

-(void)parseOtherApnsFields {
    NSDictionary *aps = _rawPayload[@"aps"];
    if (aps[@"content-available"])
        _contentAvailable = (BOOL)aps[@"content-available"];
    
    if (aps[@"mutable-content"])
        _mutableContent = (BOOL)aps[@"mutable-content"];
    
    _category = aps[@"category"];
}

@end
