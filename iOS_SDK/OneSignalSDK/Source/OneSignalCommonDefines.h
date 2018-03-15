//
//  OneSignalCommonDefines.h
//  OneSignal
//
//  Created by Brad Hesse on 2/1/18.
//  Copyright © 2018 Hiptic. All rights reserved.
//

#ifndef OneSignalCommonDefines_h
#define OneSignalCommonDefines_h

// networking
#define API_VERSION @"api/v1/"
#define SERVER_URL @"https://onesignal.com/"

// NSUserDefaults parameter names
#define EMAIL_AUTH_CODE @"GT_EMAIL_AUTH_CODE"
#define SUBSCRIPTION_SETTING @"ONESIGNAL_SUBSCRIPTION_LAST"
#define EMAIL_USERID @"GT_EMAIL_PLAYER_ID"
#define USERID @"GT_PLAYER_ID"
#define USERID_LAST @"GT_PLAYER_ID_LAST"
#define DEVICE_TOKEN @"GT_DEVICE_TOKEN"
#define SUBSCRIPTION @"ONESIGNAL_SUBSCRIPTION"
#define PUSH_TOKEN @"GT_DEVICE_TOKEN_LAST"
#define ACCEPTED_PERMISSION @"ONESIGNAL_PERMISSION_ACCEPTED_LAST"
#define REQUIRE_EMAIL_AUTH @"GT_REQUIRE_EMAIL_AUTH"
#define EMAIL_ADDRESS @"EMAIL_ADDRESS"
#define PROMPT_BEFORE_OPENING_PUSH_URL @"PROMPT_BEFORE_OPENING_PUSH_URL"
#define DEPRECATED_SELECTORS @[@"application:didReceiveLocalNotification:", @"application:handleActionWithIdentifier:forLocalNotification:completionHandler:", @"application:handleActionWithIdentifier:forLocalNotification:withResponseInfo:completionHandler:"]

// Badge handling
#define ONESIGNAL_DISABLE_BADGE_CLEARING @"OneSignal_disable_badge_clearing"
#define ONESIGNAL_APP_GROUP_NAME_KEY @"OneSignal_app_groups_key"
#define ONESIGNAL_BADGE_KEY @"onesignalBadgeCount"

// Firebase
#define ONESIGNAL_FB_ENABLE_FIREBASE @"OS_ENABLE_FIREBASE_ANALYTICS"
#define ONESIGNAL_FB_LAST_TIME_RECEIVED @"OS_LAST_RECIEVED_TIME"
#define ONESIGNAL_FB_LAST_GAF_CAMPAIGN_RECEIVED @"OS_LAST_RECIEVED_GAF_CAMPAIGN"
#define ONESIGNAL_FB_LAST_NOTIFICATION_ID_RECEIVED @"OS_LAST_RECIEVED_NOTIFICATION_ID"

#endif /* OneSignalCommonDefines_h */
