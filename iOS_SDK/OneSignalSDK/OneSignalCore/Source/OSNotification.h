//
//  OSNotification.h
//  OneSignalCore
//
//  Created by Elliot Mawby on 9/27/21.
//  Copyright © 2021 Hiptic. All rights reserved.
//

/* OneSignal OSNotification */
@interface OSNotification : NSObject

/* Unique Message Identifier */
@property(readonly, nullable)NSString* notificationId;

/* Unique Template Identifier */
@property(readonly, nullable)NSString* templateId;

/* Name of Template */
@property(readonly, nullable)NSString* templateName;

/* True when the key content-available is set to 1 in the apns payload.
   content-available is used to wake your app when the payload is received.
   See Apple's documenation for more details.
  https://developer.apple.com/documentation/uikit/uiapplicationdelegate/1623013-application
*/
@property(readonly)BOOL contentAvailable;

/* True when the key mutable-content is set to 1 in the apns payload.
 mutable-content is used to wake your Notification Service Extension to modify a notification.
 See Apple's documenation for more details.
 https://developer.apple.com/documentation/usernotifications/unnotificationserviceextension
 */
@property(readonly, getter=hasMutableContent)BOOL mutableContent;

/*
 Notification category key previously registered to display with.
 This overrides OneSignal's actionButtons.
 See Apple's documenation for more details.
 https://developer.apple.com/library/content/documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/SupportingNotificationsinYourApp.html#//apple_ref/doc/uid/TP40008194-CH4-SW26
*/
@property(readonly, nullable)NSString* category;

/* The badge assigned to the application icon */
@property(readonly)NSInteger badge;
@property(readonly)NSInteger badgeIncrement;

/* The sound parameter passed to the notification
 By default set to UILocalNotificationDefaultSoundName */
@property(readonly, nullable)NSString* sound;

/* Main push content */
@property(readonly, nullable)NSString* title;
@property(readonly, nullable)NSString* subtitle;
@property(readonly, nullable)NSString* body;

/* Web address to launch within the app via a WKWebView */
@property(readonly, nullable)NSString* launchURL;

/* Additional key value properties set within the payload */
@property(readonly, nullable)NSDictionary* additionalData;

/* iOS 10+ : Attachments sent as part of the rich notification */
@property(readonly, nullable)NSDictionary* attachments;

/* Action buttons passed */
@property(readonly, nullable)NSArray *actionButtons;

/* Holds the original payload received
 Keep the raw value for users that would like to root the push */
@property(readonly, nonnull)NSDictionary *rawPayload;

/* iOS 10+ : Groups notifications into threads */
@property(readonly, nullable)NSString *threadId;

/* iOS 15+ : Relevance Score for notification summary */
@property(readonly, nullable)NSNumber *relevanceScore;

/* iOS 15+ : Interruption Level */
@property(readonly)NSString *interruptionLevel;

/* Parses an APNS push payload into a OSNotification object.
   Useful to call from your NotificationServiceExtension when the
      didReceiveNotificationRequest:withContentHandler: method fires. */
+ (instancetype)parseWithApns:(nonnull NSDictionary*)message;

/* Convert object into a custom Dictionary / JSON Object */
- (NSDictionary* _Nonnull)jsonRepresentation;

/* Convert object into an NSString that can be convertible into a custom Dictionary / JSON Object */
- (NSString* _Nonnull)stringify;

@end
