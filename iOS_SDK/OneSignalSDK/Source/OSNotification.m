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

#import "OSNotification+Internal.h"

#import "OneSignal.h"

@implementation OSNotification
/*
 @implementation OSNotification
 @synthesize payload = _payload, shown = _shown, isAppInFocus = _isAppInFocus, silentNotification = _silentNotification, displayType = _displayType, mutableContent = _mutableContent;

 - (id)initWithPayload:(OSNotificationPayload *)payload displayType:(OSNotificationDisplayType)displayType {
     self = [super init];
     if (self) {
         _payload = payload;
         
         _displayType = displayType;
         
         _silentNotification = [OneSignalHelper isRemoteSilentNotification:payload.rawPayload];
         
         _mutableContent = payload.rawPayload[@"aps"][@"mutable-content"] && [payload.rawPayload[@"aps"][@"mutable-content"] isEqual: @YES];
         
         _shown = true;
         
         _isAppInFocus = [[UIApplication sharedApplication] applicationState] == UIApplicationStateActive;
         
         //If remote silent -> shown = false
         //If app is active and in-app alerts are not enabled -> shown = false
         if (_silentNotification ||
             _isAppInFocus)
             _shown = false;
     }
     return self;
 }

 */

/*
 
 @synthesize notificationId = _notificationId, title = _title, body = _body;

 OSNotificationPayload *_payload;
 OSNotificationDisplayTypeResponse _completion;
 NSTimer *_timeoutTimer;
 - (id)initWithPayload:(OSNotificationPayload *)payload completion:(OSNotificationDisplayTypeResponse)completion {
     self = [super init];
     if (self) {
         _payload = payload;
         
         _body = _payload.body;
         
         _title = _payload.title;
         
         _notificationId = _payload.notificationID;
         
         _completion = completion;
         
         _timeoutTimer = [NSTimer timerWithTimeInterval:CUSTOM_DISPLAY_TYPE_TIMEOUT target:self selector:@selector(timeoutTimerFired:) userInfo:_notificationId repeats:false];
     }
     return self;
 }

 - (OSNotificationDisplayTypeResponse)getCompletionBlock {
     OSNotificationDisplayTypeResponse block = ^(OSNotificationDisplayType displayType){
         [self complete:displayType];
     };
     return block;
 }

 - (void)complete:(OSNotificationDisplayType)displayType {
     [_timeoutTimer invalidate];
     if (_completion) {
         _completion(displayType);
         _completion = nil;
     }
 }

 - (void)startTimeoutTimer {
     [[NSRunLoop currentRunLoop] addTimer:_timeoutTimer forMode:NSRunLoopCommonModes];
 }

 - (void)timeoutTimerFired:(NSTimer *)timer {
     [OneSignal onesignal_Log:ONE_S_LL_ERROR
     message:[NSString stringWithFormat:@"NotificationGenerationJob timed out. Complete was not called within %f seconds.", CUSTOM_DISPLAY_TYPE_TIMEOUT]];
     [self complete:OSNotificationDisplayTypeNotification];
 }

 - (void)dealloc {
     if (_timeoutTimer)
         [_timeoutTimer invalidate];
 }

 @end
 */
+(instancetype)parseWithApns:(nonnull NSDictionary*)message {
    if (!message)
        return nil;
    
    OSNotification *osNotification = [OSNotification new];
    
    [osNotification initWithRawMessage:message];
    return osNotification;
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
    _notificationId = payload[@"i"];
    _launchURL = payload[@"u"];
    _templateId = payload[@"ti"];
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
        
        // check to ensure the button object has the correct
        // format before adding it to the array
        if (!button[@"n"] ||
            (!button[@"i"] && !button[@"n"])) {
            continue;
        }
        
        [buttonArray addObject: @{
            @"text" : button[@"n"],
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
    
    if (aps[@"thread-id"]) {
        _threadId = (NSString *)aps[@"thread-id"];
    }
    
    _category = aps[@"category"];
}

- (NSString *)description {
    return [NSString stringWithFormat: @"notificationID=%@ templateID=%@ templateName=%@ contentAvailable=%@ mutableContent=%@ category=%@ rawPayload=%@", _notificationId, _templateId, _templateName, _contentAvailable ? @"YES" : @"NO", _mutableContent ? @"YES" : @"NO", _category, _rawPayload];
}


- (NSString*)stringify {
    NSMutableDictionary *obj = [NSMutableDictionary new];
    [obj setObject:[NSMutableDictionary new] forKeyedSubscript:@"payload"];
    
    if (self.notificationId)
        [obj[@"payload"] setObject:self.notificationId forKeyedSubscript: @"notificationID"];
    
    if (self.sound)
        [obj[@"payload"] setObject:self.sound forKeyedSubscript: @"sound"];
    
    if (self.title)
        [obj[@"payload"] setObject:self.title forKeyedSubscript: @"title"];
    
    if (self.body)
        [obj[@"payload"] setObject:self.body forKeyedSubscript: @"body"];
    
    if (self.subtitle)
        [obj[@"payload"] setObject:self.subtitle forKeyedSubscript: @"subtitle"];
    
    if (self.additionalData)
        [obj[@"payload"] setObject:self.additionalData forKeyedSubscript: @"additionalData"];
    
    if (self.actionButtons)
        [obj[@"payload"] setObject:self.actionButtons forKeyedSubscript: @"actionButtons"];
    
    if (self.rawPayload)
        [obj[@"payload"] setObject:self.rawPayload forKeyedSubscript: @"rawPayload"];
    
    if (self.launchURL)
        [obj[@"payload"] setObject:self.launchURL forKeyedSubscript: @"launchURL"];
    
    if (self.contentAvailable)
        [obj[@"payload"] setObject:@(self.contentAvailable) forKeyedSubscript: @"contentAvailable"];
    
    if (self.badge)
        [obj[@"payload"] setObject:@(self.badge) forKeyedSubscript: @"badge"];
    
    //Convert obj into a serialized
    NSError *err;
    NSData *jsonData = [NSJSONSerialization  dataWithJSONObject:obj options:0 error:&err];
    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}

@end
