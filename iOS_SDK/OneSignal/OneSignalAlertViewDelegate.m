//
//  OneSignalAlertViewDelegate.m
//  OneSignal
//
//  Created by Joseph Kalash on 7/15/16.
//  Copyright © 2016 Hiptic. All rights reserved.
//

#import "OneSignalAlertViewDelegate.h"
#import "OneSignal.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@interface OneSignal ()
+ (void) handleNotificationOpened:(NSDictionary*)messageDict isActive:(BOOL)isActive actionType : (OSNotificationActionType)actionType displayType:(OSNotificationDisplayType)displayType;
@end

@implementation OneSignalAlertViewDelegate

NSDictionary* mMessageDict;

// delegateReference exist to keep ARC from cleaning up this object when it goes out of scope.
// This is becuase UIAlertView delegate is set to weak instead of strong
static NSMutableArray* delegateReference;

- (id)initWithMessageDict:(NSDictionary*)messageDict {
    mMessageDict = messageDict;
    
    if (delegateReference == nil)
        delegateReference = [NSMutableArray array];
    
    [delegateReference addObject:self];
    

    
    return self;
}

- (void)alertView:(UIAlertView*)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    
    OSNotificationActionType actionType = Opened;
    
    if (buttonIndex != 0) {
        
        actionType = ActionTaken;
        
        NSMutableDictionary* userInfo = [mMessageDict mutableCopy];

        if (mMessageDict[@"os_data"])
            userInfo[@"actionSelected"] = mMessageDict[@"os_data"][@"buttons"][@"o"][buttonIndex - 1][@"i"];
        else {
            NSMutableDictionary* customDict = [userInfo[@"custom"] mutableCopy];
            NSMutableDictionary* additionalData = [[NSMutableDictionary alloc] initWithDictionary:customDict[@"a"]];
            
            additionalData[@"actionSelected"] = additionalData[@"actionButtons"][buttonIndex - 1][@"id"];
            
            customDict[@"a"] = additionalData;
            userInfo[@"custom"] = customDict;
        }
        
        mMessageDict = userInfo;
    }
    
    [OneSignal handleNotificationOpened:mMessageDict isActive:YES actionType:actionType displayType:InAppAlert];
    
    [delegateReference removeObject:self];
}

@end
