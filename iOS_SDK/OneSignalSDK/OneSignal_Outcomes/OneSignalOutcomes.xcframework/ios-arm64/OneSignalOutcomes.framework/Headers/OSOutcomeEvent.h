/**
 Modified MIT License
 
 Copyright 2019 OneSignal
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 
 1. The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.
 
 2. All copies of substantial portions of the Software may only be used in connection
 with services provided by OneSignal.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
 */

#import <Foundation/Foundation.h>
#import "OSOutcomeEventParams.h"
#import "OSInfluence.h"
#import <OneSignalCore/OneSignalCore.h>

@interface OSOutcomeEvent : NSObject

// Session enum (DIRECT, INDIRECT, UNATTRIBUTED, or DISABLED) to determine code route and request params
@property (nonatomic) OSInfluenceType session;

// Notification ids for the current session
@property (strong, nonatomic, nullable) NSArray *notificationIds;

// Id or name of the event
@property (strong, nonatomic, nonnull) NSString *name;

// Time of the event occurring
@property (strong, nonatomic, nonnull) NSNumber *timestamp;

// A weight to attach to the outcome name
@property (strong, nonatomic, nonnull) NSDecimalNumber *weight;

// Convert the object into a NSDictionary
- (NSDictionary * _Nonnull)jsonRepresentation;

@end

@interface OSOutcomeEvent () <OSJSONEncodable>

- (id _Nonnull)initWithSession:(OSInfluenceType)session
               notificationIds:(NSArray * _Nullable)notificationIds
                          name:(NSString * _Nonnull)name
                     timestamp:(NSNumber * _Nonnull)timestamp
                        weight:(NSNumber * _Nonnull)value;

- (id _Nonnull)initFromOutcomeEventParams:(OSOutcomeEventParams * _Nonnull)eventParams;

@end

/*Block for handling outcome event being sent successfully*/
typedef void (^OSSendOutcomeSuccess)(OSOutcomeEvent* _Nullable outcome);
