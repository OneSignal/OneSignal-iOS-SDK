//
//  OSNotificationClasses.h
//  OneSignalCore
//
//  Created by Elliot Mawby on 9/27/21.
//  Copyright © 2021 Hiptic. All rights reserved.
//
#import "OSNotification.h"

// Pass in nil means a notification will not display
typedef void (^OSNotificationDisplayResponse)(OSNotification* _Nullable  notification);

/* The action type associated to an OSNotificationAction object */
typedef NS_ENUM(NSUInteger, OSNotificationActionType)  {
    OSNotificationActionTypeOpened,
    OSNotificationActionTypeActionTaken
};

@interface OSNotificationAction : NSObject

/* The type of the notification action */
@property(readonly)OSNotificationActionType type;

/* The ID associated with the button tapped. NULL when the actionType is NotificationTapped */
@property(readonly, nullable)NSString* actionId;

@end

@interface OSNotificationOpenedResult : NSObject

@property(readonly, nonnull)OSNotification* notification;
@property(readonly, nonnull)OSNotificationAction *action;

/* Convert object into an NSString that can be convertible into a custom Dictionary / JSON Object */
- (NSString* _Nonnull)stringify;

// Convert the class into a NSDictionary
- (NSDictionary *_Nonnull)jsonRepresentation;

@end;
