//
//  OSEmailSubscription.h
//  OneSignal
//
//  Created by Brad Hesse on 2/7/18.
//  Copyright © 2018 Hiptic. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "OneSignal.h"

#import "OSObservable.h"

#import "OSPermission.h"



@protocol OSEmailSubscriptionStateObserver
-(void)onChanged:(OSEmailSubscriptionState*)state;
@end


typedef OSObservable<NSObject<OSEmailSubscriptionStateObserver>*, OSEmailSubscriptionState*> ObservableEmailSubscriptionStateType;
typedef OSObservable<NSObject<OSEmailSubscriptionObserver>*, OSEmailSubscriptionStateChanges*> ObservableEmailSubscriptionStateChangesType;


@interface OSEmailSubscriptionState ()
@property (nonatomic) ObservableEmailSubscriptionStateType *observable;
@property (strong, nonatomic) NSString *emailAuthCode;
@property (nonatomic) BOOL requiresEmailAuth;
- (void)persist;
- (void)setEmailUserId:(NSString *)emailUserId;
- (void)setEmailAddress:(NSString *)emailAddress;
- (BOOL)compare:(OSEmailSubscriptionState *)from;
@end


@interface OSEmailSubscriptionStateChanges ()
@property (readwrite) OSEmailSubscriptionState* to;
@property (readwrite) OSEmailSubscriptionState* from;
@end


@interface OSEmailSubscriptionChangedInternalObserver : NSObject<OSEmailSubscriptionStateObserver>
+ (void)fireChangesObserver:(OSEmailSubscriptionState*)state;
@end


@interface OneSignal (EmailSubscriptionAdditions)
@property (class) OSEmailSubscriptionState *lastEmailSubscriptionState;
@property (class) OSEmailSubscriptionState *currentEmailSubscriptionState;
@property (class) ObservableEmailSubscriptionStateChangesType *emailSubscriptionStateChangesObserver;
@end
