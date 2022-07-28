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
- (void)onOSPushSubscriptionChangedWithPrevious:(OSPushSubscription * _Nonnull)previous current:(OSPushSubscription * _Nonnull)current;
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

- (void)testUserModelMethodAccess {
    // this test lays out the public APIs of the user model

    // User Identity
    __block OSUser* myUser = OneSignal.user;

    [OneSignal login:@"foo" withResult:^(OSUser * _Nonnull user) {
        myUser = user;
    }];

    [OneSignal login:@"foo" withToken:@"someToken" withResult:^(OSUser * _Nonnull user) {
        myUser = user;
    }];

    [OneSignal loginGuest:^(OSUser * _Nonnull user) {
        myUser = user;
    }];

    // Aliases
    [OneSignal.user addAliasWithLabel:@"foo" id:@"foo1"];
    [OneSignal.user addAliases:@{@"foo": @"foo1", @"bar": @"bar2"}];
    [OneSignal.user removeAlias:@"foo"];
    [OneSignal.user removeAliases:@[@"foo", @"bar"]];

    // Tags
    [OneSignal.user setTagWithKey:@"foo" value:@"bar"];
    [OneSignal.user setTags:@{@"foo": @"foo1", @"bar": @"bar2"}];
    [OneSignal.user removeTag:@"foo"];
    [OneSignal.user removeTags:@[@"foo", @"bar"]];
    [OneSignal.user getTag:@"foo"];

    // Outcomes
    [OneSignal.user setOutcome:@"foo"];
    [OneSignal.user setUniqueOutcome:@"foo"];
    [OneSignal.user setOutcomeWithName:@"foo" value:4.5];

    // Email
    [OneSignal.user addEmail:@"person@example.com"];
    [OneSignal.user removeEmail:@"person@example.com"];

    // SMS
    [OneSignal.user addSmsNumber:@"+15551231234"];
    [OneSignal.user removeSmsNumber:@"+15551231234"];

    // Triggers
    [OneSignal.user setTriggerWithKey:@"foo" value:@"bar"];
    [OneSignal.user setTriggers:@{@"foo": @"foo1", @"bar": @"bar2"}];
    [OneSignal.user removeTrigger:@"foo"];
    [OneSignal.user removeTriggers:@[@"foo", @"bar"]];

    XCTAssertNotNil(myUser);
}

- (void)testPushSubscriptionFunctionality {
    
    // Create a user and mock pushSubscription
    OSUser* user = OneSignal.user;
    [user createPushSubscriptionWithId:[NSUUID new] token:[NSUUID new]];
    
    // Add a subscription observer
    OSPushSubscriptionTestObserver* observer = [OSPushSubscriptionTestObserver new];
    [user.pushSubscription addObserver:observer];
    
    // Check accessing some properties
    NSLog(@"🔥 token %@", user.pushSubscription.token);
    NSLog(@"🔥 subscriptionId %@", user.pushSubscription.id);
    
    // Check that the observer fires when enabled is set
    user.pushSubscription.enabled = false;
    
    // Remove the observer and check observer is not fired
    [user.pushSubscription removeObserver:observer];
    user.pushSubscription.enabled = true;
}

- (void)testPushSubscriptionMethodsAccess {
    OSUser* user = OneSignal.user;
    
    NSUUID* subscriptionId = user.pushSubscription.id;
    NSUUID* token = user.pushSubscription.token;
    bool enabled = user.pushSubscription.enabled; // BOOL or bool preferred?
    
    OSPushSubscriptionTestObserver* observer = [OSPushSubscriptionTestObserver new];
    [user.pushSubscription addObserver:observer];
    [user.pushSubscription removeObserver:observer];
}

@end
