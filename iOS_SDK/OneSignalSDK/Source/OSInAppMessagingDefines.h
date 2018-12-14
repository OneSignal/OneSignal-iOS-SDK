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

#ifndef OSInAppMessagingDefines_h
#define OSInAppMessagingDefines_h

#import "OneSignal.h"

typedef NS_ENUM(NSUInteger, OSInAppMessageDisplayPosition) {
    OSInAppMessageDisplayPositionBottom,
    OSInAppMessageDisplayPositionTop,
    OSInAppMessageDisplayPositionCentered
};

typedef NS_ENUM(NSUInteger, OSTriggerOperatorType) {
    OSTriggerOperatorTypeGreaterThan,
    OSTriggerOperatorTypeLessThan,
    OSTriggerOperatorTypeEqualTo,
    OSTriggerOperatorTypeNotEqualTo,
    OSTriggerOperatorTypeLessThanOrEqualTo,
    OSTriggerOperatorTypeGreaterThanOrEqualTo,
    OSTriggerOperatorTypeExists,
    OSTriggerOperatorTypeNotExists,
    OSTriggerOperatorTypeContains
};

// Defines the amount of space (margins) in-app message views are given.
// The higher this value is, the farther away from the edges of the screen
// the in-app messages will be.
#define MESSAGE_MARGIN 0.025f

// Aspect ratios for messages. Note that full-screen messages fill the screen
#define BANNER_ASPECT_RATIO 2.3f
#define CENTERED_MODAL_ASPECT_RATIO 0.81f

// defines the slowest allowable dismissal speed for in-app messages.
#define MAX_DISMISSAL_ANIMATION_DURATION 0.3f

// Key for NSUserDefaults trigger storage
#define OS_TRIGGERS_KEY @"OS_IN_APP_MESSAGING_TRIGGERS"

// Dynamic trigger property types
#define OS_SESSION_DURATION_TRIGGER @"os_session_duration"
#define OS_TIME_TRIGGER @"os_time"

// Trigger for previously viewed messages
#define OS_VIEWED_MESSAGE @"os_viewed_message"
#define OS_VIEWED_MESSAGE_TRIGGER(messageId) [OS_VIEWED_MESSAGE stringByAppendingString:messageId]

// Macro to verify that a string is a correct dynamic trigger
#define OS_IS_DYNAMIC_TRIGGER(type) [@[OS_SESSION_DURATION_TRIGGER, OS_TIME_TRIGGER] containsObject:type]

// Maps OSInAppMessageDisplayType cases to the equivalent OSInAppMessageDisplayPosition cases
#define OS_DISPLAY_POSITION_FOR_TYPE(inAppMessageType) [[@[@(OSInAppMessageDisplayPositionTop), @(OSInAppMessageDisplayPositionCentered), @(OSInAppMessageDisplayPositionCentered), @(OSInAppMessageDisplayPositionBottom)] objectAtIndex: inAppMessageType] intValue]

// Checks if a string is a valid display type
#define OS_IS_VALID_DISPLAY_TYPE(stringType) [@[@"top_banner", @"centered_modal", @"full_screen", @"bottom_banner"] containsObject: stringType]

// Converts OSInAppMessageDisplayType enum cases to and from strings
#define OS_DISPLAY_TYPE_FOR_STRING(stringType) (OSInAppMessageDisplayType)[@[@"top_banner", @"centered_modal", @"full_screen", @"bottom_banner"] indexOfObject: stringType]
#define OS_DISPLAY_TYPE_TO_STRING(displayType) [@[@"top_banner", @"centered_modal", @"full_screen", @"bottom_banner"] objectAtIndex: displayType]

#define OS_OPERATOR_STRINGS @[@"greater", @"less", @"equal", @"not_equal", @"less_or_equal", @"greater_or_equal", @"exists", @"not_exists", @"in"]

// Converts OSTriggerOperatorType enum cases to and from strings
#define OS_OPERATOR_TO_STRING(operator) [OS_OPERATOR_STRINGS objectAtIndex: operator]
#define OS_OPERATOR_FROM_STRING(operatorString) [OS_OPERATOR_STRINGS indexOfObject: operatorString]

#endif /* OSInAppMessagingDefines_h */
