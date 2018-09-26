//
//  OneSignalShared.h
//  OneSignal
//
//  Created by Brad Hesse on 9/26/18.
//  Copyright © 2018 Hiptic. All rights reserved.
//

#ifndef OneSignalShared_h
#define OneSignalShared_h


#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, ONE_S_LOG_LEVEL) {
    ONE_S_LL_NONE, ONE_S_LL_FATAL, ONE_S_LL_ERROR, ONE_S_LL_WARN, ONE_S_LL_INFO, ONE_S_LL_DEBUG, ONE_S_LL_VERBOSE
};

// #### Notification Payload Received Object
@interface OSNotificationPayload : NSObject

/* Unique Message Identifier */
@property(readonly)NSString* notificationID;

/* Unique Template Identifier */
@property(readonly)NSString* templateID;

/* Name of Template */
@property(readonly)NSString* templateName;

/* True when the key content-available is set to 1 in the aps payload.
 content-available is used to wake your app when the payload is received.
 See Apple's documenation for more details.
 https://developer.apple.com/documentation/uikit/uiapplicationdelegate/1623013-application
 */
@property(readonly)BOOL contentAvailable;

/* True when the key mutable-content is set to 1 in the aps payload.
 mutable-content is used to wake your Notification Service Extension to modify a notification.
 See Apple's documenation for more details.
 https://developer.apple.com/documentation/usernotifications/unnotificationserviceextension
 */
@property(readonly)BOOL mutableContent;

/*
 Notification category key previously registered to display with.
 This overrides OneSignal's actionButtons.
 See Apple's documenation for more details.
 https://developer.apple.com/library/content/documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/SupportingNotificationsinYourApp.html#//apple_ref/doc/uid/TP40008194-CH4-SW26
 */
@property(readonly)NSString* category;

/* The badge assigned to the application icon */
@property(readonly)NSUInteger badge;
@property(readonly)NSInteger badgeIncrement;

/* The sound parameter passed to the notification
 By default set to UILocalNotificationDefaultSoundName */
@property(readonly)NSString* sound;

/* Main push content */
@property(readonly)NSString* title;
@property(readonly)NSString* subtitle;
@property(readonly)NSString* body;

/* Web address to launch within the app via a UIWebView */
@property(readonly)NSString* launchURL;

/* Additional key value properties set within the payload */
@property(readonly)NSDictionary* additionalData;

/* iOS 10+ : Attachments sent as part of the rich notification */
@property(readonly)NSDictionary* attachments;

/* Action buttons passed */
@property(readonly)NSArray *actionButtons;

/* Holds the original payload received
 Keep the raw value for users that would like to root the push */
@property(readonly)NSDictionary *rawPayload;

@end

#endif /* OneSignalShared_h */
