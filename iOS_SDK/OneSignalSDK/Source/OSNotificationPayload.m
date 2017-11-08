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
@synthesize actionButtons = _actionButtons, additionalData = _additionalData, badge = _badge, body = _body, contentAvailable = _contentAvailable, notificationID = _notificationID, launchURL = _launchURL, rawPayload = _rawPayload, sound = _sound, subtitle = _subtitle, title = _title, attachments = _attachments;

- (id)initWithRawMessage:(NSDictionary*)message {
    self = [super init];
    if (self && message) {
        _rawPayload = [NSDictionary dictionaryWithDictionary:message];
        
        BOOL is2dot4Format = [_rawPayload[@"os_data"][@"buttons"] isKindOfClass:[NSArray class]];
        
        if (_rawPayload[@"aps"][@"content-available"])
            _contentAvailable = (BOOL)_rawPayload[@"aps"][@"content-available"];
        else
            _contentAvailable = NO;
        
        if (_rawPayload[@"aps"][@"badge"])
            _badge = [_rawPayload[@"aps"][@"badge"] intValue];
        else
            _badge = [_rawPayload[@"badge"] intValue];
        
        _actionButtons = _rawPayload[@"o"];
        if (!_actionButtons) {
            if (is2dot4Format)
                _actionButtons = _rawPayload[@"os_data"][@"buttons"];
            else
                _actionButtons = _rawPayload[@"os_data"][@"buttons"][@"o"];
        }
        
        if(_rawPayload[@"aps"][@"sound"])
            _sound = _rawPayload[@"aps"][@"sound"];
        else if(_rawPayload[@"s"])
            _sound = _rawPayload[@"s"];
        else if (!is2dot4Format)
            _sound = _rawPayload[@"os_data"][@"buttons"][@"s"];
        
        if(_rawPayload[@"custom"]) {
            NSDictionary* custom = _rawPayload[@"custom"];
            if (custom[@"a"])
                _additionalData = [custom[@"a"] copy];
            _notificationID = custom[@"i"];
            _launchURL = custom[@"u"];
            
            _attachments = [_rawPayload[@"at"] copy];
        }
        else if(_rawPayload[@"os_data"]) {
            NSDictionary * os_data = _rawPayload[@"os_data"];
            
            NSMutableDictionary *additional = [_rawPayload mutableCopy];
            [additional removeObjectForKey:@"aps"];
            [additional removeObjectForKey:@"os_data"];
            _additionalData = [[NSDictionary alloc] initWithDictionary:additional];
            
            _notificationID = os_data[@"i"];
            _launchURL = os_data[@"u"];
            
            if (is2dot4Format) {
                if (os_data[@"att"])
                    _attachments = [os_data[@"att"] copy];
            }
            else {
                if (os_data[@"buttons"][@"at"])
                    _attachments = [os_data[@"buttons"][@"at"] copy];
            }
        }
        
        if(_rawPayload[@"m"]) {
            id m = _rawPayload[@"m"];
            if ([m isKindOfClass:[NSDictionary class]]) {
                _body = m[@"body"];
                _title = m[@"title"];
                _subtitle = m[@"subtitle"];
            }
            else
                _body = m;
        }
        else if(_rawPayload[@"aps"][@"alert"]) {
            id a = message[@"aps"][@"alert"];
            if ([a isKindOfClass:[NSDictionary class]]) {
                _body = a[@"body"];
                _title = a[@"title"];
                _subtitle = a[@"subtitle"];
            }
            else
                _body = a;
        }
        else if(_rawPayload[@"os_data"][@"buttons"][@"m"]) {
            id m = _rawPayload[@"os_data"][@"buttons"][@"m"];
            if ([m isKindOfClass:[NSDictionary class]]) {
                _body = m[@"body"];
                _title = m[@"title"];
                _subtitle = m[@"subtitle"];
            }
            else
                _body = m;
        }
    }
    
    return self;
}
@end
