/**
 * Modified MIT License
 *
 * Copyright 2021 OneSignal
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
