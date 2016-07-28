//
//  OneSignalAlertViewDelegate.m
//  OneSignal
//
//  Created by Joseph Kalash on 7/15/16.
//  Copyright © 2016 Hiptic. All rights reserved.
//

#import "OneSignalAlertViewDelegate.h"

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
    if (buttonIndex != 0) {
        NSMutableDictionary* userInfo = [mMessageDict mutableCopy];
        
        if (mMessageDict[@"os_data"])
            userInfo[@"actionSelected"] = mMessageDict[@"actionButtons"][buttonIndex - 1][@"id"];
        else {
            NSMutableDictionary* customDict = [userInfo[@"custom"] mutableCopy];
            NSMutableDictionary* additionalData = [[NSMutableDictionary alloc] initWithDictionary:customDict[@"a"]];
            
            additionalData[@"actionSelected"] = additionalData[@"actionButtons"][buttonIndex - 1][@"id"];
            
            customDict[@"a"] = additionalData;
            userInfo[@"custom"] = customDict;
        }
        
        mMessageDict = userInfo;
    }
    
    #pragma GCC diagnostic ignored "-Wundeclared-selector"
    [[OneSignal class] performSelector:@selector(handleNotificationOpened:isActive:) withObject: mMessageDict withObject: [NSNumber numberWithBool:true]];
    
    [delegateReference removeObject:self];
}

@end
