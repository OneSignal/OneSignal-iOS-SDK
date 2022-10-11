/*
 Modified MIT License

 Copyright 2022 OneSignal

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 1. The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.

 2. All copies of substantial portions of the Software may only be used in connection
 with services provided by OneSignal.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
 */

#import <XCTest/XCTest.h>
#import "OneSignal.h"

@interface UserModelObjcTests : XCTestCase

@end


@interface OSPushSubscriptionTestObserver: NSObject<OSPushSubscriptionObserver>
- (void)onOSPushSubscriptionChangedWithPrevious:(OSPushSubscriptionState * _Nonnull)previous current:(OSPushSubscriptionState * _Nonnull)current;
@end

@implementation OSPushSubscriptionTestObserver
- (void)onOSPushSubscriptionChangedWithPrevious:(OSPushSubscriptionState * _Nonnull)previous current:(OSPushSubscriptionState * _Nonnull)current {
    NSLog(@"🔥 UnitTest:onOSPushSubscriptionChanged :%@ :%@", previous, current);
    
}
@end

@implementation UserModelObjcTests

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    [super setUp];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

/**
 This test lays out the public APIs of the user model
 */
- (void)testUserModelMethodAccess {

    // User Identity
    [OneSignal login:@"foo"];
    [OneSignal login:@"foo" withToken:@"someToken"];
    [OneSignal login:@"foo" withToken:nil];
    [OneSignal loginWithAliasLabel:@"foo" withAliasId:@"bar"];
    [OneSignal loginWithAliasLabel:@"foo" withAliasId:@"bar" withToken:@"someToken"];
    [OneSignal loginWithAliasLabel:@"foo" withAliasId:@"bar" withToken:nil];
    [OneSignal logout];

    // Aliases
    [OneSignal.User addAliasWithLabel:@"foo" id:@"foo1"];
    [OneSignal.User addAliases:@{@"foo": @"foo1", @"bar": @"bar2"}];
    [OneSignal.User removeAlias:@"foo"];
    [OneSignal.User removeAliases:@[@"foo", @"bar"]];

    // Tags
    [OneSignal.User setTagWithKey:@"foo" value:@"bar"];
    [OneSignal.User setTags:@{@"foo": @"foo1", @"bar": @"bar2"}];
    [OneSignal.User removeTag:@"foo"];
    [OneSignal.User removeTags:@[@"foo", @"bar"]];

    // Outcomes
    [OneSignal.User setOutcome:@"foo"];
    [OneSignal.User setUniqueOutcome:@"foo"];
    [OneSignal.User setOutcomeWithName:@"foo" value:4.5];

    // Email
    [OneSignal.User addEmail:@"person@example.com"];
    [OneSignal.User removeEmail:@"person@example.com"];

    // SMS
    [OneSignal.User addSmsNumber:@"+15551231234"];
    [OneSignal.User removeSmsNumber:@"+15551231234"];

    // Triggers
    [OneSignal.User setTriggerWithKey:@"foo" value:@"bar"];
    [OneSignal.User setTriggers:@{@"foo": @"foo1", @"bar": @"bar2"}];
    [OneSignal.User removeTrigger:@"foo"];
    [OneSignal.User removeTriggers:@[@"foo", @"bar"]];
}

/**
 This is to collect things that should not work, but do for now.
 */
- (void)testTheseShouldNotWork {
    // Should not be settable
    // OneSignal.user.pushSubscription.token = [NSUUID new]; // <- Confirmed that users can't set token
    // OneSignal.user.pushSubscription.subscriptionId = [NSUUID new]; // <- Confirmed that users can't set subscriptionId
}

/**
 Test the access of properties and methods, and setting properties related to the push subscription.
 */
- (void)testPushSubscriptionPropertiesAccess {
    // TODO: Fix these unit tests
//    // Create a user and mock pushSubscription
//    id<OSUser> user = OneSignal.user;
//    [user testCreatePushSubscriptionWithSubscriptionId:[NSUUID new] token:[NSUUID new] enabled:false];
//
//    // Access properties of the pushSubscription
//    NSUUID* subscriptionId = user.pushSubscription.subscriptionId;
//    NSUUID* token = user.pushSubscription.token;
//    bool enabled = user.pushSubscription.enabled; // BOOL or bool preferred?
//
//    // Set the enabled property of the pushSubscription
//    user.pushSubscription.enabled = true;
//
//    // Create a push subscription observer
//    OSPushSubscriptionTestObserver* observer = [OSPushSubscriptionTestObserver new];
    
    // Push subscription observers are not user-scoped
//    [OneSignal addSubscriptionObserver:observer];
//    [OneSignal removeSubscriptionObserver:observer];
}

/**
 Test the model repo hook up via a login with external ID and setting alias.
 Test the operation repo hookup as well and check the deltas being enqueued and flushed.
 */
- (void)testModelAndOperationRepositoryHookUpWithLoginAndSetAlias {
    // login an user with external ID
    [OneSignal login:@"user01"];
        
    // Check that deltas for alias (Identity) are created correctly and enqueued.
    NSLog(@"🔥 Unit Tests adding alias label_01: user_01");
    [OneSignal.User addAliasWithLabel:@"label_01" id:@"user_01"];
    [OneSignal.User removeAlias:@"nonexistent"];
    [OneSignal.User removeAlias:@"label_01"];
    [OneSignal.User addAliasWithLabel:@"label_02" id:@"user_02"];
    [OneSignal.User addAliases:@{@"test1": @"user1", @"test2": @"user2", @"test3": @"user3"}];
    [OneSignal.User removeAliases:@[@"test1", @"label_01", @"test2"]];
    
    [OneSignal.User setTagWithKey:@"foo" value:@"bar"];
    
    // Sleep to allow the flush to be called 1 time.
    [NSThread sleepForTimeInterval:6.0f];
}

/**
 Test login and logout and creation of guest users.
 */
- (void)testLoginLogout {
    // A guest user is created when OneSignal.User is accessed
    [OneSignal.User addEmail:@"test@email.com"];
    
    // ... and more to be added
}

/**
 Test email and sms subscriptions. 2 Deltas are created for each add.
 */
- (void)testEmailAndSmsSubscriptions {
    [OneSignal.User addEmail:@"test@example.com"];
    [OneSignal.User addSmsNumber:@"+15551231234"];
    
    // Sleep to allow the flush to be called 1 time.
    [NSThread sleepForTimeInterval:6.0f];
}

@end
