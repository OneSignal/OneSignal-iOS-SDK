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

#ifndef OSOutcomeEventsDefines_h
#define OSOutcomeEventsDefines_h

// Outcome param keys
static NSString * const OUTCOMES_PARAM = @"outcomes";
static NSString * const DIRECT_PARAM = @"direct";
static NSString * const INDIRECT_PARAM = @"indirect";
static NSString * const UNATTRIBUTED_PARAM = @"unattributed";
static NSString * const ENABLED_PARAM = @"enabled";
static NSString * const NOTIFICATION_ATTRIBUTION_PARAM = @"notification_attribution";
static NSString * const MINUTES_SINCE_DISPLAYED_PARAM = @"minutes_since_displayed";
static NSString * const LIMIT_PARAM = @"limit";

// Outcome default param values
static int DEFAULT_INDIRECT_NOTIFICATION_LIMIT = 10;
static int DEFAULT_INDIRECT_ATTRIBUTION_WINDOW = 24 * 60;

#endif /* OSOutcomeEventsDefines_h */
