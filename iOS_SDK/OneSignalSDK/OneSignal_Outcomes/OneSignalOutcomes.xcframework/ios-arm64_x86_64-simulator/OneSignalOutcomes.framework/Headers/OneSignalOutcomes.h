/*
 Modified MIT License

 Copyright 2021 OneSignal

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

#import "OSSessionManager.h"
#import "OSInfluence.h"
#import "OSIndirectInfluence.h"
#import "OSInAppMessageOutcome.h"
#import "OSOutcomeEvent.h"
#import "OSInfluenceDataDefines.h"
#import "OSOutcomeEventsCache.h"
#import "OSCachedUniqueOutcome.h"
#import "OneSignalOutcomeEventsController.h"
#import "OSInfluenceDataRepository.h"
#import "OSOutcomeEventsFactory.h"
#import "OSTrackerFactory.h"
#import "OSOutcomeEventsRepository.h"
#import "OSFocusInfluenceParam.h"

/**
 Public API for Session namespace.
 */
@protocol OSSession <NSObject>
+ (void)addOutcome:(NSString * _Nonnull)name;
+ (void)addUniqueOutcome:(NSString * _Nonnull)name;
+ (void)addOutcomeWithValue:(NSString * _Nonnull)name value:(NSNumber * _Nonnull)value;
@end

@interface OneSignalOutcomes : NSObject <OSSession>
+ (Class<OSSession>)Session;
+ (OneSignalOutcomeEventsController * _Nullable)sharedController;
+ (void)start;
+ (void)clearStatics;
+ (void)migrate;
@end

