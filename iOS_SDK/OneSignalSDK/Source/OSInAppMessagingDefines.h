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

// IAM display position enums
typedef NS_ENUM(NSUInteger, OSInAppMessageDisplayPosition) {
    OSInAppMessageDisplayPositionBottom,
    OSInAppMessageDisplayPositionTop,
    OSInAppMessageDisplayPositionCenterModal,
    OSInAppMessageDisplayPositionFullScreen
};
// IAM display position strings
#define OS_IN_APP_DISPLAY_POSITION_STRING @[@"bottom_banner",@"top_banner",@"center_modal",@"full_screen"]
// Convert string to OSInAppMessageDisplayPosition enum and vice versa
#define OS_IN_APP_DISPLAY_POSITION_TO_STRING(enum) [OS_IN_APP_DISPLAY_POSITION_STRING objectAtIndex:enum]
#define OS_IN_APP_DISPLAY_POSITION_FROM_STRING(string) [OS_IN_APP_DISPLAY_POSITION_STRING indexOfObject:string]

// Trigger operator enums
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
// Trigger operator strings
#define OS_OPERATOR_STRINGS @[@"greater", @"less", @"equal", @"not_equal", @"less_or_equal", @"greater_or_equal", @"exists", @"not_exists", @"in"]
// Convert string to OSTriggerOperatorType enum and vice versa
#define OS_OPERATOR_TO_STRING(operator) [OS_OPERATOR_STRINGS objectAtIndex:operator]
#define OS_OPERATOR_FROM_STRING(operatorString) [OS_OPERATOR_STRINGS indexOfObject:operatorString]

// Defines the amount of space (margins) in-app message views are given
// The higher this value is, the farther away from the edges of the screen the in-app messages will be
#define MESSAGE_MARGIN 8.0f

// Defines the slowest and fastest allowable dismissal speed for in-app messages
#define MIN_DISMISSAL_ANIMATION_DURATION 0.1f
#define MAX_DISMISSAL_ANIMATION_DURATION 0.3f

// In-App Messaging NSUserDefaults
#define OS_IAM_SEEN_SET_KEY @"OS_IAM_SEEN_SET"
#define OS_IAM_CLICKED_SET_KEY @"OS_IAM_CLICKED_SET"
#define OS_IAM_IMPRESSIONED_SET_KEY @"OS_IAM_IMPRESSIONED_SET"
#define OS_IAM_MESSAGES_ARRAY @"OS_IAM_MESSAGES_ARRAY"
#define OS_IAM_REDISPLAY_DICTIONARY @"OS_IAM_REDISPLAY_DICTIONARY"

// Dynamic trigger kind types
#define OS_DYNAMIC_TRIGGER_KIND_CUSTOM @"custom"
#define OS_DYNAMIC_TRIGGER_KIND_SESSION_TIME @"session_time"
#define OS_DYNAMIC_TRIGGER_KIND_MIN_TIME_SINCE @"min_time_since"
#define OS_DYNAMIC_TRIGGER_KIND_STRINGS @[OS_DYNAMIC_TRIGGER_KIND_SESSION_TIME, OS_DYNAMIC_TRIGGER_KIND_MIN_TIME_SINCE]
// Verify that a string is a valid dynamic trigger
#define OS_IS_DYNAMIC_TRIGGER_KIND(kind) [OS_DYNAMIC_TRIGGER_KIND_STRINGS containsObject:kind]

// Trigger property types
#define OS_TRIGGER_PROPERTY_SESSION_TIME @"playtime"
#define OS_TRIGGER_PROPERTY_MIN_TIME_SINCE @"time_since_last_iam"
#define OS_TRIGGER_PROPERTY_STRINGS @[OS_TRIGGER_PROPERTY_SESSION_TIME, OS_TRIGGER_PROPERTY_MIN_TIME_SINCE]
// Verify that a string is a valid dynamic trigger
#define OS_IS_TRIGGER_PROPERTY(kind) [OS_TRIGGER_PROPERTY_STRINGS containsObject:property]

// JavaScript method names
#define OS_JS_GET_PAGE_META_DATA_METHOD @"getPageMetaData()"

#define PREFERRED_VARIANT_ORDER @[@"ios", @"app", @"all"]

#define OS_BRIDGE_EVENT_TYPES @[@"rendering_complete", @"action_taken", @"resize"]
#define OS_IS_VALID_BRIDGE_EVENT_TYPE(string) [OS_BRIDGE_EVENT_TYPES containsObject:string]
#define OS_BRIDGE_EVENT_TYPE_FROM_STRING(string) (OSInAppMessageBridgeEventType)[OS_BRIDGE_EVENT_TYPES indexOfObject:string]

#endif /* OSInAppMessagingDefines_h */
