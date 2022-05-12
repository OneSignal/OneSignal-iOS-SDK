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

#ifndef OneSignalCommonDefines_h
#define OneSignalCommonDefines_h

#import <Foundation/Foundation.h>

// Networking
#define OS_API_VERSION @"1"
#define OS_API_ACCEPT_HEADER @"application/vnd.onesignal.v" OS_API_VERSION @"+json"
#define OS_API_SERVER_URL @"https://api.onesignal.com/"
#define OS_IAM_WEBVIEW_BASE_URL @"https://onesignal.com/"

// OneSignalUserDefault keys
// String values start with "OSUD_" to maintain a level of uniqueness from other libs and app code
// Key names should be identical to the string values to prevent confusion
// Add the suffix "_TO" or "_FROM" to any keys with "to" and "from" logic
// TODO: Refactored variable names, but not strings since UserDefaults might need a migration
// Comments next to the NSUserDefault keys are the planned string value and key names
// "?" in comment line ending comment means uncertainty in naming the string value of the associated key and keeping as is for now
// "*" in comment line ending comment means the string value has not been changed
// App

#define ONESIGNAL_VERSION                                                   @"031101"

#define OSUD_APP_ID                                                         @"GT_APP_ID"                                                        // * OSUD_APP_ID
#define OSUD_REGISTERED_WITH_APPLE                                          @"GT_REGISTERED_WITH_APPLE"                                         // * OSUD_REGISTERED_WITH_APPLE
#define OSUD_APP_PROVIDES_NOTIFICATION_SETTINGS                             @"OS_APP_PROVIDES_NOTIFICATION_SETTINGS"                            // * OSUD_APP_PROVIDES_NOTIFICATION_SETTINGS
#define OSUD_PROMPT_BEFORE_NOTIFICATION_LAUNCH_URL_OPENS                    @"PROMPT_BEFORE_OPENING_PUSH_URL"                                   // * OSUD_PROMPT_BEFORE_NOTIFICATION_LAUNCH_URL_OPENS
#define OSUD_PERMISSION_ACCEPTED_TO                                         @"OSUD_PERMISSION_ACCEPTED_TO"                                      // OSUD_PERMISSION_ACCEPTED_TO
#define OSUD_PERMISSION_ACCEPTED_FROM                                       @"ONESIGNAL_PERMISSION_ACCEPTED_LAST"                               // * OSUD_PERMISSION_ACCEPTED_FROM
#define OSUD_WAS_PROMPTED_FOR_NOTIFICATIONS_TO                              @"OSUD_WAS_PROMPTED_FOR_NOTIFICATIONS_TO"                           // OSUD_WAS_PROMPTED_FOR_NOTIFICATIONS_TO
#define OSUD_WAS_PROMPTED_FOR_NOTIFICATIONS_FROM                            @"OS_HAS_PROMPTED_FOR_NOTIFICATIONS_LAST"                           // * OSUD_WAS_PROMPTED_FOR_NOTIFICATIONS_FROM
#define OSUD_WAS_NOTIFICATION_PROMPT_ANSWERED_TO                            @"OS_NOTIFICATION_PROMPT_ANSWERED"                                  // * OSUD_WAS_NOTIFICATION_PROMPT_ANSWERED_TO
#define OSUD_WAS_NOTIFICATION_PROMPT_ANSWERED_FROM                          @"OS_NOTIFICATION_PROMPT_ANSWERED_LAST"                             // * OSUD_WAS_NOTIFICATION_PROMPT_ANSWERED_FROM
#define OSUD_PROVISIONAL_PUSH_AUTHORIZATION_TO                              @"OSUD_PROVISIONAL_PUSH_AUTHORIZATION_TO"                           // OSUD_PROVISIONAL_PUSH_AUTHORIZATION_TO
#define OSUD_PROVISIONAL_PUSH_AUTHORIZATION_FROM                            @"ONESIGNAL_PROVISIONAL_AUTHORIZATION_LAST"                         // * OSUD_PROVISIONAL_PUSH_AUTHORIZATION_FROM
#define OSUD_USES_PROVISIONAL_PUSH_AUTHORIZATION                            @"ONESIGNAL_USES_PROVISIONAL_PUSH_AUTHORIZATION"                    // * OSUD_USES_PROVISIONAL_PUSH_AUTHORIZATION
#define OSUD_PERMISSION_EPHEMERAL_TO                                        @"OSUD_PERMISSION_EPHEMERAL_TO"                                     // * OSUD_PERMISSION_EPHEMERAL_TO
#define OSUD_PERMISSION_EPHEMERAL_FROM                                      @"OSUD_PERMISSION_EPHEMERAL_FROM"                                   // * OSUD_PERMISSION_EPHEMERAL_FROM
#define OSUD_LANGUAGE                                                       @"OSUD_LANGUAGE"                                                    // * OSUD_LANGUAGE
#define DEFAULT_LANGUAGE                                                    @"en"                                                               // * OSUD_LANGUAGE
// Player
#define OSUD_EXTERNAL_USER_ID                                               @"OS_EXTERNAL_USER_ID"                                              // * OSUD_EXTERNAL_USER_ID
#define OSUD_PLAYER_ID_TO                                                   @"GT_PLAYER_ID"                                                     // * OSUD_PLAYER_ID_TO
#define OSUD_PLAYER_ID_FROM                                                 @"GT_PLAYER_ID_LAST"                                                // * OSUD_PLAYER_ID_FROM
#define OSUD_PUSH_TOKEN_TO                                                  @"GT_DEVICE_TOKEN"                                                  // * OSUD_PUSH_TOKEN_TO
#define OSUD_PUSH_TOKEN_FROM                                                @"GT_DEVICE_TOKEN_LAST"                                             // * OSUD_PUSH_TOKEN_FROM
#define OSUD_USER_SUBSCRIPTION_TO                                           @"ONESIGNAL_SUBSCRIPTION"                                           // * OSUD_USER_SUBSCRIPTION_TO
#define OSUD_USER_SUBSCRIPTION_FROM                                         @"ONESIGNAL_SUBSCRIPTION_SETTING"                                   // * OSUD_USER_SUBSCRIPTION_FROM
#define OSUD_EXTERNAL_ID_AUTH_CODE                                          @"OSUD_EXTERNAL_ID_AUTH_CODE"                                       
// Email
#define OSUD_EMAIL_ADDRESS                                                  @"EMAIL_ADDRESS"                                                    // * OSUD_EMAIL_ADDRESS
#define OSUD_EMAIL_PLAYER_ID                                                @"GT_EMAIL_PLAYER_ID"                                               // * OSUD_EMAIL_PLAYER_ID
#define OSUD_EMAIL_EXTERNAL_USER_ID                                         @"OSUD_EMAIL_EXTERNAL_USER_ID"                                      // OSUD_EMAIL_EXTERNAL_USER_ID
#define OSUD_REQUIRE_EMAIL_AUTH                                             @"GT_REQUIRE_EMAIL_AUTH"                                            // * OSUD_REQUIRE_EMAIL_AUTH
#define OSUD_EMAIL_AUTH_CODE                                                @"GT_EMAIL_AUTH_CODE"                                               // * OSUD_EMAIL_AUTH_CODE
// SMS
#define OSUD_SMS_NUMBER                                                     @"OSUD_SMS_NUMBER"
#define OSUD_SMS_PLAYER_ID                                                  @"OSUD_SMS_PLAYER_ID"
#define OSUD_SMS_EXTERNAL_USER_ID                                           @"OSUD_SMS_EXTERNAL_USER_ID"
#define OSUD_REQUIRE_SMS_AUTH                                               @"OSUD_REQUIRE_SMS_AUTH"
#define OSUD_SMS_AUTH_CODE                                                  @"OSUD_SMS_AUTH_CODE"
// Notification
#define OSUD_LAST_MESSAGE_OPENED                                            @"GT_LAST_MESSAGE_OPENED_"                                          // * OSUD_MOST_RECENT_NOTIFICATION_OPENED
#define OSUD_NOTIFICATION_OPEN_LAUNCH_URL                                   @"ONESIGNAL_INAPP_LAUNCH_URL"                                       // * OSUD_NOTIFICATION_OPEN_LAUNCH_URL
#define OSUD_TEMP_CACHED_NOTIFICATION_MEDIA                                 @"OSUD_TEMP_CACHED_NOTIFICATION_MEDIA"                              // OSUD_TEMP_CACHED_NOTIFICATION_MEDIA
// Remote Params
#define OSUD_LOCATION_ENABLED                                               @"OSUD_LOCATION_ENABLED"
#define OSUD_REQUIRES_USER_PRIVACY_CONSENT                                  @"OSUD_REQUIRES_USER_PRIVACY_CONSENT"
// Remote Params - Receive Receipts
#define OSUD_RECEIVE_RECEIPTS_ENABLED                                       @"OS_ENABLE_RECEIVE_RECEIPTS"                                       // * OSUD_RECEIVE_RECEIPTS_ENABLED
// Outcomes
#define OSUD_OUTCOMES_V2                                                    @"OSUD_OUTCOMES_V2"
#define OSUD_NOTIFICATION_LIMIT                                             @"NOTIFICATION_LIMIT"                                               // * OSUD_NOTIFICATION_LIMIT
#define OSUD_IAM_LIMIT                                                      @"OSUD_IAM_LIMIT"
#define OSUD_NOTIFICATION_ATTRIBUTION_WINDOW                                @"NOTIFICATION_ATTRIBUTION_WINDOW"                                  // * OSUD_NOTIFICATION_ATTRIBUTION_WINDOW
#define OSUD_IAM_ATTRIBUTION_WINDOW                                         @"OSUD_IAM_ATTRIBUTION_WINDOW"
#define OSUD_DIRECT_SESSION_ENABLED                                         @"DIRECT_SESSION_ENABLED"                                           // * OSUD_DIRECT_SESSION_ENABLED
#define OSUD_INDIRECT_SESSION_ENABLED                                       @"INDIRECT_SESSION_ENABLED"                                         // * OSUD_INDIRECT_SESSION_ENABLED
#define OSUD_UNATTRIBUTED_SESSION_ENABLED                                   @"UNATTRIBUTED_SESSION_ENABLED"                                     // * OSUD_UNATTRIBUTED_SESSION_ENABLED
#define OSUD_CACHED_NOTIFICATION_INFLUENCE                                  @"CACHED_SESSION"                                                   // * OSUD_CACHED_NOTIFICATION_INFLUENCE
#define OSUD_CACHED_IAM_INFLUENCE                                           @"OSUD_CACHED_IAM_INFLUENCE"
#define OSUD_CACHED_DIRECT_NOTIFICATION_ID                                  @"CACHED_DIRECT_NOTIFICATION_ID"                                    // * OSUD_CACHED_DIRECT_NOTIFICATION_ID
#define OSUD_CACHED_INDIRECT_NOTIFICATION_IDS                               @"CACHED_INDIRECT_NOTIFICATION_IDS"                                 // * OSUD_CACHED_INDIRECT_NOTIFICATION_IDS
#define OSUD_CACHED_RECEIVED_NOTIFICATION_IDS                               @"CACHED_RECEIVED_NOTIFICATION_IDS"                                 // * OSUD_CACHED_RECEIVED_NOTIFICATION_IDS
#define OSUD_CACHED_RECEIVED_IAM_IDS                                        @"OSUD_CACHED_RECEIVED_IAM_IDS"
#define OSUD_CACHED_UNATTRIBUTED_UNIQUE_OUTCOME_EVENTS_SENT                 @"CACHED_UNATTRIBUTED_UNIQUE_OUTCOME_EVENTS_SENT"                   // * OSUD_CACHED_UNATTRIBUTED_UNIQUE_OUTCOME_EVENTS_SENT
#define OSUD_CACHED_ATTRIBUTED_UNIQUE_OUTCOME_EVENT_NOTIFICATION_IDS_SENT   @"CACHED_ATTRIBUTED_UNIQUE_OUTCOME_EVENT_NOTIFICATION_IDS_SENT"     // * OSUD_CACHED_ATTRIBUTED_UNIQUE_OUTCOME_EVENT_NOTIFICATION_IDS_SENT
// Migration
#define OSUD_CACHED_SDK_VERSION                                             @"OSUD_CACHED_SDK_VERSION"
// Time Tracking
#define OSUD_APP_LAST_CLOSED_TIME                                           @"GT_LAST_CLOSED_TIME"                                              // * OSUD_APP_LAST_CLOSED_TIME
#define OSUD_UNSENT_ACTIVE_TIME                                             @"GT_UNSENT_ACTIVE_TIME"                                            // * OSUD_UNSENT_ACTIVE_TIME
#define OSUD_UNSENT_ACTIVE_TIME_ATTRIBUTED                                  @"GT_UNSENT_ACTIVE_TIME_ATTRIBUTED"                                 // * OSUD_UNSENT_ACTIVE_TIME_ATTRIBUTED
#define OSUD_PLAYER_TAGS                                                    @"OSUD_PLAYER_TAGS"
    // * OSUD_PLAYER_TAGS

// Deprecated Selectors
#define DEPRECATED_SELECTORS @[ @"application:didReceiveLocalNotification:", \
                                @"application:handleActionWithIdentifier:forLocalNotification:completionHandler:", \
                                @"application:handleActionWithIdentifier:forLocalNotification:withResponseInfo:completionHandler:" ]

// To avoid undefined symbol compiler errors on older versions of Xcode,
// instead of using UNAuthorizationOptionProvisional directly, we will use
// it indirectly with these macros
#define PROVISIONAL_UNAUTHORIZATIONOPTION (UNAuthorizationOptions)(1 << 6)
#define PROVIDES_SETTINGS_UNAUTHORIZATIONOPTION (UNAuthorizationOptions)(1 << 5)

// These options are defined in all versions of iOS that we support, so we
// can use them directly.
#define DEFAULT_UNAUTHORIZATIONOPTIONS (UNAuthorizationOptionSound + UNAuthorizationOptionBadge + UNAuthorizationOptionAlert)

// iOS Parameter Names
#define IOS_FBA @"fba"
#define IOS_USES_PROVISIONAL_AUTHORIZATION @"uses_provisional_auth"
#define IOS_REQUIRES_EMAIL_AUTHENTICATION @"require_email_auth"
#define IOS_REQUIRES_SMS_AUTHENTICATION @"require_sms_auth"
#define IOS_REQUIRES_USER_ID_AUTHENTICATION @"require_user_id_auth"
#define IOS_RECEIVE_RECEIPTS_ENABLE @"receive_receipts_enable"
#define IOS_OUTCOMES_V2_SERVICE_ENABLE @"v2_enabled"
#define IOS_LOCATION_SHARED @"location_shared"
#define IOS_REQUIRES_USER_PRIVACY_CONSENT @"requires_user_privacy_consent"

// SMS Parameter Names
#define SMS_NUMBER_KEY @"sms_number"
#define SMS_NUMBER_AUTH_HASH_KEY @"sms_auth_hash"

// Info.plist key
#define FALLBACK_TO_SETTINGS_MESSAGE @"Onesignal_settings_fallback_message"
#define ONESIGNAL_SUPRESS_LAUNCH_URLS @"OneSignal_suppress_launch_urls"

// GDPR Privacy Consent
#define GDPR_CONSENT_GRANTED @"GDPR_CONSENT_GRANTED"
#define ONESIGNAL_REQUIRE_PRIVACY_CONSENT @"OneSignal_require_privacy_consent"

// Badge handling
#define ONESIGNAL_DISABLE_BADGE_CLEARING @"OneSignal_disable_badge_clearing"
#define ONESIGNAL_APP_GROUP_NAME_KEY @"OneSignal_app_groups_key"
#define ONESIGNAL_BADGE_KEY @"onesignalBadgeCount"

// Firebase
#define ONESIGNAL_FB_ENABLE_FIREBASE @"OS_ENABLE_FIREBASE_ANALYTICS"
#define ONESIGNAL_FB_LAST_TIME_RECEIVED @"OS_LAST_RECIEVED_TIME"
#define ONESIGNAL_FB_LAST_GAF_CAMPAIGN_RECEIVED @"OS_LAST_RECIEVED_GAF_CAMPAIGN"
#define ONESIGNAL_FB_LAST_NOTIFICATION_ID_RECEIVED @"OS_LAST_RECIEVED_NOTIFICATION_ID"

// APNS params
#define ONESIGNAL_IAM_PREVIEW @"os_in_app_message_preview_id"

#define ONESIGNAL_SUPPORTED_ATTACHMENT_TYPES @[@"aiff", @"wav", @"mp3", @"mp4", @"jpg", @"jpeg", @"png", @"gif", @"mpeg", @"mpg", @"avi", @"m4a", @"m4v"]

// OneSignal Influence Strings
#define OS_INFLUENCE_TYPE_STRINGS @[@"DIRECT", @"INDIRECT", @"UNATTRIBUTED", @"DISABLED"]
// Convert String to Influence enum and vice versa
#define OS_INFLUENCE_TYPE_TO_STRING(enum) [OS_INFLUENCE_TYPE_STRINGS objectAtIndex:enum]
#define OS_INFLUENCE_TYPE_FROM_STRING(string) [OS_INFLUENCE_TYPE_STRINGS indexOfObject:string]

// OneSignal Influence Channel
#define OS_INFLUENCE_CHANNEL_STRING @[@"IN_APP_MESSAGE", @"NOTIFICATION"]
// Convert String to Influence Channel enum and vice versa
#define OS_INFLUENCE_CHANNEL_TO_STRING(enum) [OS_INFLUENCE_CHANNEL_STRING objectAtIndex:enum]
#define OS_INFLUENCE_CHANNEL_FROM_STRING(string) [OS_INFLUENCE_CHANNEL_STRING indexOfObject:string]

// OneSignal Prompt Action Result
typedef enum {PERMISSION_GRANTED, PERMISSION_DENIED, LOCATION_PERMISSIONS_MISSING_INFO_PLIST, ERROR} PromptActionResult;

// OneSignal App Entry Action Types
typedef enum {NOTIFICATION_CLICK, APP_OPEN, APP_CLOSE} AppEntryAction;

// OneSignal Focus Event Types
typedef enum {BACKGROUND, END_SESSION} FocusEventType;

// OneSignal Focus Types
typedef enum {ATTRIBUTED, NOT_ATTRIBUTED} FocusAttributionState;
#define focusAttributionStateString(enum) [@[@"ATTRIBUTED", @"NOT_ATTRIBUTED"] objectAtIndex:enum]

// OneSignal constants
#define OS_PUSH @"push"
#define OS_EMAIL @"email"
#define OS_SMS @"sms"
#define OS_SUCCESS @"success"

#define OS_CHANNELS @[OS_PUSH, OS_EMAIL, OS_SMS]

// OneSignal API Client Defines
typedef enum {GET, POST, HEAD, PUT, DELETE, OPTIONS, CONNECT, TRACE} HTTPMethod;
#define OS_API_CLIENT_STRINGS @[@"GET", @"POST", @"HEAD", @"PUT", @"DELETE", @"OPTIONS", @"CONNECT", @"TRACE"]
#define httpMethodString(enum) [OS_API_CLIENT_STRINGS objectAtIndex:enum]

// Notification types
#define NOTIFICATION_TYPE_NONE 0
#define NOTIFICATION_TYPE_BADGE 1
#define NOTIFICATION_TYPE_SOUND 2
#define NOTIFICATION_TYPE_ALERT 4
#define NOTIFICATION_TYPE_ALL 7

#define ERROR_PUSH_CAPABLILITY_DISABLED    -13
#define ERROR_PUSH_DELEGATE_NEVER_FIRED    -14
#define ERROR_PUSH_SIMULATOR_NOT_SUPPORTED -15
#define ERROR_PUSH_UNKNOWN_APNS_ERROR      -16
#define ERROR_PUSH_OTHER_3000_ERROR_UNUSED_RESERVED -17
#define ERROR_PUSH_NEVER_PROMPTED          -18
#define ERROR_PUSH_PROMPT_NEVER_ANSWERED   -19

#define AUTH_STATUS_EPHEMERAL 4 //UNAuthorizationStatusEphemeral

// 1 week in seconds
#define WEEK_IN_SECONDS 604800.0

// Registration delay
#define REGISTRATION_DELAY_SECONDS 30.0

// How long the SDK will wait for APNS to respond
// before registering the user anyways
#define APNS_TIMEOUT 25.0

// The SDK saves a list of category ID's allowing multiple notifications
// to have their own unique buttons/etc.
#define SHARED_CATEGORY_LIST @"com.onesignal.shared_registered_categories"

// Device types
#define DEVICE_TYPE_PUSH 0
#define DEVICE_TYPE_EMAIL 11
#define DEVICE_TYPE_SMS 14

#define MAX_NSE_LIFETIME_SECOUNDS 30

#ifndef OS_TEST
    // OneSignal API Client Defines
    #define REATTEMPT_DELAY 30.0
    #define REQUEST_TIMEOUT_REQUEST 120.0 //for most HTTP requests
    #define REQUEST_TIMEOUT_RESOURCE 120.0 //for loading a resource like an image
    #define MAX_ATTEMPT_COUNT 3

    // Send tags batch delay
    #define SEND_TAGS_DELAY 5.0

    // the max number of UNNotificationCategory ID's the SDK will register
    #define MAX_CATEGORIES_SIZE 128

    // Defines how long the SDK will wait for a OSPredisplayNotification's complete method to execute
    #define CUSTOM_DISPLAY_TYPE_TIMEOUT 25.0

    // Defines the maximum delay time for confirmed deliveries
    #define MAX_CONF_DELIVERY_DELAY 25.0
#else
    // Test defines for API Client
    #define REATTEMPT_DELAY 0.004
    #define REQUEST_TIMEOUT_REQUEST 0.02 //for most HTTP requests
    #define REQUEST_TIMEOUT_RESOURCE 0.02 //for loading a resource like an image
    #define MAX_ATTEMPT_COUNT 3

    // Send tags batch delay
    #define SEND_TAGS_DELAY 0.005

    // the max number of UNNotificationCategory ID's the SDK will register
    #define MAX_CATEGORIES_SIZE 5

    // Unit testing value for how long the SDK will wait for a
    // OSPredisplayNotification's complete method to execute
    #define CUSTOM_DISPLAY_TYPE_TIMEOUT 0.05

    // We don't want to delay confirmed deliveries in unit tests
    #define MAX_CONF_DELIVERY_DELAY 0

#endif

// A max timeout for a request, which might include multiple reattempts
#define MAX_TIMEOUT ((REQUEST_TIMEOUT_REQUEST * MAX_ATTEMPT_COUNT) + (REATTEMPT_DELAY * MAX_ATTEMPT_COUNT)) * NSEC_PER_SEC

// To save battery, NSTimer is not exceedingly accurate so timestamp values may be a bit inaccurate
// To make up for this, we can check to make sure the values are close enough to account for
// variance and floating-point error.
#define OS_ROUGHLY_EQUAL(left, right) (fabs(left - right) < 0.03)

#define MAX_NOTIFICATION_MEDIA_SIZE_BYTES 50000000

#endif /* OneSignalCommonDefines_h */
