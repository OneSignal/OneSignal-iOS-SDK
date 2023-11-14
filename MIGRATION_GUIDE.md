<h1 align="center">OneSignal iOS SDK v5.0.0 Migration Guide</h1>

![OneSignal Omni Channel Banner](https://user-images.githubusercontent.com/11739227/208625336-d28c8d01-a7cf-4f8e-9643-ac8d1948e9ae.png)

# Intro

In this release, we are making a significant shift from a device-centered model to a user-centered model. A user-centered model allows for more powerful omni-channel integrations within the OneSignal platform.

To facilitate this change, the `externalId` approach for identifying users is being replaced by the `login` and `logout` methods. In addition, the SDK now makes use of namespaces such as `User`, `Notifications`, and `InAppMessages` to better separate code.

The iOS SDK is making the jump from `v3` to `v5`, in order to align across OneSignal’s suite of client SDKs. This guide will walk you through the iOS SDK `5.0.0` changes as a result of this shift.

# Overview

Under the user-centered model, the concept of a "player" is being replaced with three new concepts: **users**, **subscriptions**, and **aliases**.

## Users

A user is a new concept which is meant to represent your end-user. A user has zero or more subscriptions and can be uniquely identified by one or more aliases. In addition to subscriptions, a user can have **data tags** which allows for user attribution.

## Subscription

A subscription refers to the method in which an end-user can receive various communications sent by OneSignal, including push notifications, SMS, and email.  In previous versions of the OneSignal platform, each of these channels was referred to as a “player”. A subscription is in fact identical to the legacy “player” concept.  Each subscription has a **subscription_id** (previously, player_id) to uniquely identify that communication channel.

## Aliases

Aliases are a concept evolved from [external user ids](https://documentation.onesignal.com/docs/external-user-ids) which allows the unique identification of a user within a OneSignal application.  Aliases are a key-value pair made up of an **alias label** (the key) and an **alias id** (the value). The **alias label** can be thought of as a consistent keyword across all users, while the **alias id** is a value specific to each user for that particular label. The combined **alias label** and **alias id** provide uniqueness to successfully identify a user.

OneSignal uses a built-in **alias label** called `external_id` which supports existing use of [external user ids](https://documentation.onesignal.com/docs/external-user-ids). `external_id` is also used as the identification method when a user identifies themselves to the OneSignal SDK via `OneSignal.login`.  Multiple aliases can be created for each user to allow for your own application's unique identifier as well as identifiers from other integrated applications.

# Migration Guide (v3 to v5)

As mentioned above, the iOS SDK is making the jump from `v3` to `v5`, in order to align across OneSignal’s suite of client SDKs.

## Requirements
- Minimum deployment target of iOS 11
- Requires Xcode 14
- If you are using CocoaPods, please use version `1.11.3+` and Ruby version `2.7.5+`.


## SDK Installation

### Code Import Changes
**Objective-C**

```objc
    // Replace the old import statement
    #import <OneSignal/OneSignal.h>

    // With the new import statement
    #import <OneSignalFramework/OneSignalFramework.h>
```
**Swift**
```swift
    // Replace the old import statement
    import OneSignal

    // With the new import statement
    import OneSignalFramework
```

### Option 1. Swift Package Manager
- Update the version of the OneSignal-XCFramework your application uses to `5.0.0`. 
- The Package Product `OneSignal` has been renamed to `OneSignalFramework`. 
- Location functionality has moved to its own Package Product `OneSignalLocation`. If you do not explicitly add this product your app you will not have location functionality. If you include location functionality ensure that your app also depends on the `CoreLocation` framework.
- In App Messaging functionality has moved to its own Package Product `OneSignalInAppMessages`. If you do not explicitly add this product your app you will not have in app messaging functionality. If you include In App Messaging functionality ensure that your app also depends on the `WebKit` framework.
- See [the existing installation instructions](https://documentation.onesignal.com/docs/swift-package-manager-setup).

### Option 2. CocoaPods
The OneSignal pod has added additional subspecs for improved modularity. If you would like to exclude Location or In App Messaging functionality from your app you can do so by using subspecs:
```
  pod 'OneSignal/OneSignal', '>= 5.0.0', '< 6.0'
  # Remove either of the following if the functionality is unwanted
  pod 'OneSignal/OneSignalLocation', '>= 5.0.0', '< 6.0'
  pod 'OneSignal/OneSignalInAppMessages', '>= 5.0.0', '< 6.0'
```
If you would like to include all of OneSignal's functionality you are still able to use the default pod
```
pod 'OneSignal', '>= 5.0.0', '< 6.0'
```
- Update the version of the OneSignalXCFramework your application uses to `5.0.0`. 
- Location functionality has moved to its own subspec `OneSignalLocation`. If you include location functionality ensure that your app also depends on the `CoreLocation` framework.
- In App Messaging functionality has moved to its own subspec `OneSignalInAppMessages`. If you include In App Messaging functionality ensure that your app also depends on the `WebKit` framework.
- See [the existing installation instructions](https://documentation.onesignal.com/docs/ios-sdk-setup#step-3-import-the-onesignal-sdk-into-your-xcode-project).

# API Changes
## Namespaces

The SDK has been split into namespaces, and functionality previously in the static `OneSignal` class has been moved to the appropriate namespace. The namespaces and how to access them in code are as follows:

| **Namespace** | **Access Pattern**            |
| ----------------- | ----------------------------- |
| Debug             | `OneSignal.Debug`             |
| InAppMessages     | `OneSignal.InAppMessages`     |
| Location          | `OneSignal.Location`          |
| LiveActivities    | `OneSignal.LiveActivities`    |
| Notifications     | `OneSignal.Notifications`     |
| Session           | `OneSignal.Session`           |
| User              | `OneSignal.User`              |

## Initialization

Initialization of the OneSignal SDK, although similar to previous versions, has changed.  The `appId` is now provided as part of initialization and cannot be changed.  Previous versions of the OneSignal SDK had an explicit `setAppId` function, which is no longer available.  A typical initialization now looks similar to below.

Navigate to your AppDelegate file and add the OneSignal initialization code to `didFinishLaunchingWithOptions`.

Replace the following:

**Objective-C**
```objc
    [OneSignal initWithLaunchOptions:launchOptions];
    [OneSignal setAppId:@"YOUR_ONESIGNAL_APP_ID"];
```

**Swift**
```swift
    OneSignal.initWithLaunchOptions(launchOptions)
    OneSignal.setAppId("YOUR_ONESIGNAL_APP_ID")
```
To match the new initialization:

**Objective-C**
```objc
    [OneSignal initialize:@"YOUR_ONESIGNAL_APP_ID" withLaunchOptions:launchOptions];
```
**Swift**
```swift
    OneSignal.initialize("YOUR_ONESIGNAL_APP_ID", withLaunchOptions: launchOptions)
```
Remove any usages of `setLaunchURLsInApp` as the method and functionality has been removed.

If your integration is **not** user-centric, there is no additional startup code required. A device-scoped user *(please see definition of “**device-scoped user**” below in Glossary)* is automatically created as part of the push subscription creation, both of which are only accessible from the current device or through the OneSignal dashboard.

If your integration is user-centric, or you want the ability to identify the user beyond the current device, the `login` method should be called to identify the user:

**Objective-C**
```objc
    [OneSignal login:@"USER_EXTERNAL_ID"];
```
**Swift**
```swift
    OneSignal.login("USER_EXTERNAL_ID")
```
The `login` method will associate the device’s push subscription to the user that can be identified via the alias `externalId=USER_EXTERNAL_ID`. If that user doesn’t already exist, it will be created. If the user does already exist, the user will be updated to own the device’s push subscription. Note that the push subscription for the device will always be transferred to the newly logged in user, as that user is the current owner of that push subscription.

Once (or if) the user is no longer identifiable in your app (i.e. they logged out), the `logout` method should be called:

**Objective-C**
```objc
    [OneSignal logout];
```
**Swift**
```swift
    OneSignal.logout()
```
Logging out has the affect of reverting to a device-scoped user, which is the new owner of the device’s push subscription. Note that if the current user is already a device-scoped user at the time `logout` is called, this will result in a no-op and the SDK will continue using the same device-scoped user. Any state that exists on this device-scoped user will be kept. This also means that calling `logout` multiple times will have no effect.

## Subscriptions

In previous versions of the SDK, a “player” could have up to one email address and up to one phone number for SMS. In the user-centered model, a user can own the current device’s **Push Subscription** along with the ability to have **zero or more** email subscriptions and **zero or more** SMS subscriptions. Note: If a new user logs in via the `login` method, the previous user will no longer longer own that push subscription.

### **Push Subscription**
The current device’s push subscription can be retrieved via:

**Objective-C**
```objc
    OneSignal.User.pushSubscription.id;
    OneSignal.User.pushSubscription.token;
    OneSignal.User.pushSubscription.optedIn;
```
**Swift**
```swift
    OneSignal.User.pushSubscription.id
    OneSignal.User.pushSubscription.token
    OneSignal.User.pushSubscription.optedIn
```

### **Opting In and Out of Push Notifications**

To receive push notifications on the device, call the push subscription’s `optIn` method. If needed, this method will prompt the user for push notifications permission.

Note: For greater control over prompting for push notification permission, you may use the `OneSignal.Notifications.requestPermission` method detailed below in the API Reference.

**Objective-C**
```objc
    [OneSignal.User.pushSubscription optIn];
```
**Swift**
```swift
    OneSignal.User.pushSubscription.optIn()
```
If at any point you want the user to stop receiving push notifications on the current device (regardless of system-level permission status), you can use the push subscription to opt out:

**Objective-C**
```objc
    [OneSignal.User.pushSubscription optOut];
```
**Swift**
```swift
    OneSignal.User.pushSubscription.optOut()
```

To resume receiving of push notifications (driving the native permission prompt if permissions are not available), you can opt back in with the `optIn` method from above.

### **Email/SMS Subscriptions**

Email and/or SMS subscriptions can be added or removed via the following methods. The `remove` methods will result in a no-op if the specified email or SMS number does not exist on the user within the SDK, and no request will be made.

**Objective-C**
```obj
    // Add email subscription
    [OneSignal.User addEmail:@"customer@company.com"];
    // Remove previously added email subscription
    [OneSignal.User removeEmail:@"customer@company.com"];

    // Add SMS subscription
    [OneSignal.User addSms:@"+15558675309"];
    // Remove previously added SMS subscription
    [OneSignal.User removeSms:@"+15558675309"];
```

**Swift**
```swift
    // Add email subscription
    OneSignal.User.addEmail("customer@company.com")
    // Remove previously added email subscription
    OneSignal.User.removeEmail("customer@company.com")

    // Add SMS subscription
    OneSignal.User.addSms("+15558675309")
    // Remove previously added SMS subscription
    OneSignal.User.removeSms("+15558675309")
```

# API Reference

Below is a comprehensive reference to the `5.0.0` OneSignal SDK.

## OneSignal

The SDK is still accessible via a `OneSignal` static class. It provides access to higher level functionality and is a gateway to each subspace of the SDK.

| **Swift**                                                                                                | **Objective-C**                                                                                          | **Description**                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| -------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `OneSignal.initialize("YOUR_ONESIGNAL_APP_ID", withLaunchOptions: launchOptions)`                    | `[OneSignal initialize:@"YOUR_ONESIGNAL_APP_ID" withLaunchOptions:launchOptions]`                    | *Initializes the OneSignal SDK. This should be called during startup of the application.*                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| `OneSignal.login("USER_EXTERNAL_ID")`                                                                | `[OneSignal login:@"USER_EXTERNAL_ID"]`                                                              | *Login to OneSignal under the user identified by the [externalId] provided. The act of logging a user into the OneSignal SDK will switch the [user] context to that specific user.<br><br> - If the [externalId] exists, the user will be retrieved and the context will be set from that user information. If operations have already been performed under a device-scoped user, they ***will not*** be applied to the now logged in user (they will be lost).<br> - If the [externalId] does not yet exist, the user will be created and the context set from the current local state. If operations have already been performed under a device-scoped user, those operations ***will*** be applied to the newly created user.<br><br>***Push Notifications and In App Messaging***<br>Logging in a new user will automatically transfer the push notification and in app messaging subscription from the current user (if there is one) to the newly logged in user. This is because both push notifications and in- app messages are owned by the device.* |
| `OneSignal.logout()`                                                                                     | `[OneSignal logout]`                                                                                     | *Logout the user previously logged in via [login]. The [user] property now references a new device-scoped user. A device-scoped user has no user identity that can later be retrieved, except through this device as long as the app remains installed and the app data is not cleared. Note that if the current user is already a device-scoped user at the time `logout` is called, this will result in a no-op and the SDK will continue using the same device-scoped user. Any state that exists on this device-scoped user will be kept. This also means that calling `logout` multiple times will have no effect.*                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| `OneSignal.setConsentGiven(true)`                  | `[OneSignal setConsentGiven:true]`                 | *Indicates whether privacy consent has been granted. This field is only relevant when the application has opted into data privacy protections. See [setConsentRequired].*                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| `OneSignal.setConsentRequired(true)` | `[OneSignal setConsentRequired:true]` | *Determines whether a user must consent to privacy prior to their user data being sent up to OneSignal.  This should be set to `true` prior to the invocation of `initialize` to ensure compliance.*                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |



## Live Activities

Live Activities are a type of interactive push notification. Apple introduced them in October 2022 to enable iOS apps to provide real-time updates to their users that are visible from the lock screen and the dynamic island.

Please refer to OneSignal’s guide on [Live Activities](https://documentation.onesignal.com/docs/live-activities), the [Live Activities Quickstart](https://documentation.onesignal.com/docs/live-activities-quickstart) tutorial, and the [existing SDK reference](https://documentation.onesignal.com/docs/sdk-reference#live-activities) on Live Activities. 


| **Swift**                                                                                                | **Objective-C**                                                                                          | **Description**                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| -------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `OneSignal.LiveActivities.enter("ACTIVITY_ID", withToken: "TOKEN")`<br><br>***See below for usage of callbacks***<br><br>`enter(activityId: String, withToken token: String, withSuccess successBlock: OSResultSuccessBlock?, withFailure failureBlock: OSFailureBlock? = nil)` | `[OneSignal.LiveActivities enter:@"ACTIVITY_ID" withToken:@"TOKEN"]`<br><br>***See below for usage of callbacks***<br><br>`(void)enter:(NSString *)activityId withToken:(NSString *)token withSuccess:(OSResultSuccessBlock _Nullable)successBlock withFailure:(OSFailureBlock _Nullable)failureBlock`<br><br>|*Entering a Live Activity associates an `activityId` with a live activity temporary push `token` on OneSignal's server. The activityId is then used with the OneSignal REST API to update one or multiple Live Activities at one time.*                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| `OneSignal.LiveActivities.exit("ACTIVITY_ID")`<br><br>***See below for usage of callbacks***<br><br>`exit(activityId: String, withSuccess successBlock: OSResultSuccessBlock?, withFailure failureBlock: OSFailureBlock? = nil)`                                                | `[OneSignal.LiveActivities exit:@"ACTIVITY_ID"]`<br><br>***See below for usage of callbacks***<br><br>`(void)exit:(NSString *)activityId withSuccess:(OSResultSuccessBlock _Nullable)successBlock withFailure:(OSFailureBlock _Nullable)failureBlock`<br><br>                                                  |*Exiting a Live activity deletes the association between a customer defined `activityId` with a Live Activity temporary push `token` on OneSignal's server.*                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |

**Objective-C**
```objc
    // Enter a Live Activity
    [OneSignal.LiveActivities enter:@"ACTIVITY_ID" withToken:@"TOKEN" withSuccess:^(NSDictionary *result) {
        NSLog(@"enter success with result: %@", result);
    } withFailure:^(NSError *error) {
        NSLog(@"enter error: %@", error);
    }];

    // Exit a Live Activity
    [OneSignal.LiveActivities exit:@"ACTIVITY_ID" withSuccess:^(NSDictionary *result) {
        NSLog(@"exit success with result: %@", result);
    } withFailure:^(NSError *error) {
        NSLog(@"exit error: %@", error);
        // handle failure case
    }];

    // Success Output Example:
    /*
      {
          success = 1
      }
     */
```
**Swift**
```swift
    // Enter a Live Activity
    OneSignal.LiveActivities.enter("ACTIVITY_ID", withToken: "TOKEN") { result in
        print("enter success with result: \(result ?? [:])")
    } withFailure: { error in
        print("enter error: \(String(describing: error))")
    }

    // Exit a Live Activity
    OneSignal.LiveActivities.exit("ACTIVITY_ID") { result in
        print("exit success with result: \(result ?? [:])")
    } withFailure: { error in
        print("exit error: \(String(describing: error))")
        // handle failure case
    }

    // Success Output Example:
    /*
      {
          success = 1
      }
     */
```

## User Namespace

The User name space is accessible via `OneSignal.User` and provides access to user-scoped functionality.


| **Swift**                                                                                                       | **Objective-C**                                                                                       | **Description**                                                                                                                                                                                                                          |
| --------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `OneSignal.User.setLanguage("en")`                                                                              | `[OneSignal.User setLanguage:@"en"]`                                                                  | *Set the 2-character language  for this user.*                                                                                                                                                                                         |
| `let pushSubscriptionProperty = OneSignal.User.pushSubscription.<PROPERTY>`                                    | `id pushSubscriptionProperty = OneSignal.User.pushSubscription.<PROPERTY>`                           | *The push subscription associated to the current user. Please refer to the Push Subscription Namespace API below for additional details.*                                                                                                                                                                                  |
| `OneSignal.User.addAlias(label: "ALIAS_LABEL", id: "ALIAS_ID")`                                         | `[OneSignal.User addAliasWithLabel:@"ALIAS_LABEL" id:@"ALIAS_ID"]`                                    | *Set an alias for the current user.  If this alias label already exists on this user, it will be overwritten with the new alias id.*                                                                                         |
| `OneSignal.User.addAliases(["ALIAS_LABEL_01": "ALIAS_ID_01", "ALIAS_LABEL_02": "ALIAS_ID_02"])` | `[OneSignal.User addAliases:@{@"ALIAS_LABEL_01": @"ALIAS_ID_01", @"ALIAS_LABEL_02": @"ALIAS_ID_02"}]` | *Set aliases for the current user. If any alias already exists, it will be overwritten to the new values.*                                                                                                                       |
| `OneSignal.User.removeAlias("ALIAS_LABEL")`                                                                 | `[OneSignal.User removeAlias:@"ALIAS_LABEL"]`                                                         | *Remove an alias from the current user.*                                                                                                                                                                                                 |
| `OneSignal.User.removeAliases(["ALIAS_LABEL_01", "ALIAS_LABEL_02"])`                                    | `[OneSignal.User removeAliases:@[@"ALIAS_LABEL_01", @"ALIAS_LABEL_02"]]`                              | *Remove aliases from the current user.*                                                                                                                                                                                              |
| `OneSignal.User.addEmail("customer@company.com")`                                                           | `[OneSignal.User addEmail:@"customer@company.com"]`                                               | *Add a new email subscription to the current user.*                                                                                                                                                                                      |
| `OneSignal.User.removeEmail("customer@company.com")`                                | `[OneSignal.User removeEmail:@"customer@company.com"]`                             | *Remove an email subscription from the current user. Results in a no-op if the specified email does not exist on the user within the SDK, and no request will be made.*                                                               |
| `OneSignal.User.addSms("+15558675309")`                                                               | `[OneSignal.User addSms:@"+15558675309"]`                                                   | *Add a new SMS subscription to the current user.*                                                                                                                                                                                        |
| `OneSignal.User.removeSms("+15558675309")`                                    | `[OneSignal.User removeSms:@"+15558675309"]`                                 | *Remove an SMS subscription from the current user. Results in a no-op if the specified SMS number does not exist on the user within the SDK, and no request will be made.*                                                            |
| `OneSignal.User.addTag(key: "KEY", value: "VALUE")`                                                     | `[OneSignal.User addTagWithKey:@"KEY" value:@"VALUE"]`                                                | *Add a tag for the current user.  Tags are key:value pairs used as building blocks for targeting specific users and/or personalizing messages. If the tag key already exists, it will be replaced with the value provided here.*         |
| `OneSignal.User.addTags(["KEY_01": "VALUE_01", "KEY_02": "VALUE_02"])`                          | `[OneSignal.User addTags:@{@"KEY_01": @"VALUE_01", @"KEY_02": @"VALUE_02"}]`                          | *Add multiple tags for the current user.  Tags are key:value pairs used as building blocks for targeting specific users and/or personalizing messages. If the tag key already exists, it will be replaced with the value provided here.* |
| `OneSignal.User.removeTag("KEY")`                                                                           | `[OneSignal.User removeTag:@"KEY"]`                                                                   | *Remove the data tag with the provided key from the current user.*                                                                                                                                                                       |
| `let tags = OneSignal.User.getTags()`                                                                           | `NSDictionary<NSString *, NSString*> *tags = [OneSignal.User getTags]`                                                                   | *Returns the local tags for the current user.*                                                                                                                                                                       |
| `OneSignal.User.removeTags(["KEY_01", "KEY_02"])`                                                       | `[OneSignal.User removeTags:@[@"KEY_01", @"KEY_02"]]`                                                 | *Remove multiple tags with the provided keys from the current user.*                                                                                                                                                             |



## Push Subscription Namespace

The Push Subscription name space is accessible via `OneSignal.User.pushSubscription` and provides access to push subscription-scoped functionality.


| **Swift**                                                                                                         | **Objective-C**                                                                                                                        | **Description**                                                                                                                                                                                                                                                                                                                                                                                    |
| ----------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `let id: String? = OneSignal.User.pushSubscription.id`                                                            | `NSString* id = OneSignal.User.pushSubscription.id`                                                                                    | *The readonly push subscription ID.*                                                                                                                                                                                                                                                                                                                                                               |
| `let token: String? = OneSignal.User.pushSubscription.token`                                                      | `NSString* token = OneSignal.User.pushSubscription.token`                                                                              | *The readonly push token.*                                                                                                                                                                                                                                                                                                                                                                         |
| `let optedIn: Bool = OneSignal.User.pushSubscription.optedIn`                                                     | `BOOL optedIn = OneSignal.User.pushSubscription.optedIn`                                                                               | *Gets a boolean value indicating whether the current user is opted in to push notifications. This returns `true` when the app has notifications permission and `optOut` is ***not*** called. ***Note:*** Does not take into account the existence of the subscription ID and push token. This boolean may return `true` but push notifications may still not be received by the user.* |
| `OneSignal.User.pushSubscription.optIn()`                                                                         | `[OneSignal.User.pushSubscription optIn]`                                                                                              | *Call this method to receive push notifications on the device or to resume receiving of push notifications after calling `optOut`. If needed, this method will prompt the user for push notifications permission.*                                                                                                                                                                     |
| `OneSignal.User.pushSubscription.optOut()`                                                                        | `[OneSignal.User.pushSubscription optOut]`                                                                                             | *If at any point you want the user to stop receiving push notifications on the current device (regardless of system-level permission status), you can call this method to opt out.*                                                                                                                                                                                                              |
| `addObserver(_ observer: OSPushSubscriptionObserver)`<br><br>***See below for usage*** | `(void)addObserver:(id <OSPushSubscriptionObserver> _Nonnull)observer`<br><br>***See below for usage*** | *The `OSPushSubscriptionObserver.onPushSubscriptionDidChange` method will be fired on the passed-in object when the push subscription changes.*                                                                                                                                 |
| `removeObserver(_ observer: OSPushSubscriptionObserver)`<br><br>***See below for usage***                         | `(void)removeObserver:(id <OSPushSubscriptionObserver> _Nonnull)observer`<br><br>***See below for usage***                             | *Remove a push subscription observer that has been previously added.*                                                                                                                                                                                                                                                                                                                      |

### Push Subscription Observer

Any object implementing the `OSPushSubscriptionObserver` protocol can be added as an observer. You can call `removeObserver` to remove any existing listeners.

**Objective-C**
```objc
    // AppDelegate.h
    // Add OSPushSubscriptionObserver after UIApplicationDelegate
    @interface AppDelegate : UIResponder <UIApplicationDelegate, OSPushSubscriptionObserver>
    @end

    // AppDelegate.m
    @implementation AppDelegate

    - (BOOL)application:(UIApplication*)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
      // Add your AppDelegate as an observer
      [OneSignal.User.pushSubscription addObserver:self];
    }

    // Add this new method
    - (void)onPushSubscriptionDidChangeWithState:(OSPushSubscriptionChangedState*)state {
       // prints out all properties
       NSLog(@"OSPushSubscriptionChangedState:\n%@", state);
    }
    @end

    // Remove the observer
    [OneSignal.User.pushSubscription removeObserver:self];
```
**Swift**
```swift
    // AppDelegate.swift
    // Add OSPushSubscriptionObserver after UIApplicationDelegate
    class AppDelegate: UIResponder, UIApplicationDelegate, OSPushSubscriptionObserver {

       func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Add your AppDelegate as an observer
        OneSignal.User.pushSubscription.addObserver(self as OSPushSubscriptionObserver)
       }

      // Add this new method
      func onPushSubscriptionDidChange(state: OSPushSubscriptionChangedState) {
        // prints out all properties
        print("OSPushSubscriptionStateChanges: \n\(state)")
      }
    }

    // Remove the observer
    OneSignal.User.pushSubscription.removeObserver(self as OSPushSubscriptionObserver)
```

## Session Namespace

The Session namespace is accessible via `OneSignal.Session` and provides access to session-scoped functionality.


| **Swift**                                                 | **Objective-C**                                                              | **Description**                                                                          |
| --------------------------------------------------------- | ---------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| `OneSignal.Session.addOutcome("OUTCOME_NAME")`            | `[OneSignal.Session addOutcome:@"OUTCOME_NAME"]`                             | *Add an outcome with the provided name, captured against the current session.*           |
| `OneSignal.Session.addUniqueOutcome("OUTCOME_NAME")`      | `[OneSignal.Session addUniqueOutcome:@"OUTCOME_NAME"]`                       | *Add a unique outcome with the provided name, captured against the current session.*     |
| `OneSignal.Session.addOutcome("OUTCOME_NAME", 18.76)` | `[OneSignal.Session addOutcomeWithValue:@"OUTCOME_NAME" value:@18.76]` | *Add an outcome with the provided name and value, captured against the current session.* |



## Notifications Namespace

The Notifications namespace is accessible via `OneSignal.Notifications` and provides access to notification-scoped functionality.


| **Swift**                                                                                                                                     | **Objective-C**                                                                                                                    | **Description**                                                                                                                                                                                                                                                                                                                                                                                                             |
| --------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `let permission: Bool = OneSignal.Notifications.permission`                                                                                   | `BOOL permission = [OneSignal.Notifications permission]`                                                                       | *Whether this app has push notification permission. Returns `true` if the user has accepted permissions, or if the app has `ephemeral` or `provisional` permission.*                                                                                                                                                                                                                                                                                                                                                                        |
| `let permissionNative: OSNotificationPermission = OneSignal.Notifications.permissionNative`                                                                                   | `OSNotificationPermission permissionNative = [OneSignal.Notifications permissionNative]`                                                                       | *Returns the enum for the native permission of the device. It will be one of OSNotificationPermissionNotDetermined, OSNotificationPermissionDenied, OSNotificationPermissionAuthorized, OSNotificationPermissionProvisional, OSNotificationPermissionEphemeral.*                                                                                                                                                                                                                                                                                                                                                                        |
| `let canRequest: Bool = OneSignal.Notifications.canRequestPermission`                                                                     | `BOOL canRequest = [OneSignal.Notifications canRequestPermission]`                                                             | *Whether attempting to request notification permission will show a prompt. Returns `true` if the device has not been prompted for push notification permission already.*                                                                                                                                                                                                                                                |
| `OneSignal.Notifications.clearAll()`                                                                                                          | `[OneSignal.Notifications clearAll]`                                                                                               | *Removes all OneSignal notifications.*                                                                                                                                                                                                                                                                                                                                                                                      |
| `func requestPermission(block: OSUserResponseBlock?, fallbackToSettings: Bool)`<br><br>***See below for usage***                              | `(void)requestPermission:(OSUserResponseBlock _Nullable )block fallbackToSettings:(BOOL)fallback`<br><br>***See below for usage*** | *Prompt the user for permission to receive push notifications. This will display the native system prompt to request push notification permission.*                                                                                                                                                                                                                                                                 |
| `func registerForProvisionalAuthorization(block: OSUserResponseBlock?)`<br><br>***See below for usage***                                      | `(void)registerForProvisionalAuthorization:(OSUserResponseBlock _Nullable)block`<br><br>***See below for usage***                  | *Instead of having to prompt the user for permission to send them push notifications, your app can request provisional authorization.*                                                                                                                                                                                                                                                                                      |
| `func addPermissionObserver(observer: OSNotificationPermissionObserver)`<br><br>***See below for usage***                                                 | `(void)addPermissionObserver:(NSObject<OSNotificationPermissionObserver>*_Nonnull)observer`<br><br>***See below for usage***                   | *The `OSNotificationPermissionObserver.onNotificationPermissionDidChange` method will be fired on the passed-in object when a notification permission setting changes. This happens when the user enables or disables notifications for your app from the system settings outside of your app.*                                                                                                                                           |
| `func removePermissionObserver(observer: OSNotificationPermissionObserver)`<br><br>***See below for usage***                                              | `(void)removePermissionObserver:(NSObject<OSNotificationPermissionObserver>*_Nonnull)observer`<br><br>***See below for usage***        | *Remove a push permission observer that has been previously added.*                                                                                                                                                                                                                                                                                                                                                     |
| `func addForegroundLifecycleListener(listener: OSNotificationLifecycleListener?)`<br><br>***See below for usage*** | `addForegroundLifecycleListener:(NSObject<OSNotificationLifecycleListener> *)listener`<br><br>***See below for usage***       | *The `OSNotificationLifecycleListener.onWillDisplayNotification` method will be fired on the passed-in object before displaying a notification while the app is in focus. Use this listener to read notification data and decide if the notification ***should*** show or not. Call `event.preventDefault()` to prevent the notification from displaying and call `event.notification.display()` within 25 seconds to display the notification. <br><br>***Note:*** this runs ***after*** the [Notification Service Extension](https://documentation.onesignal.com/docs/service-extensions) which can be used to modify the notification before showing it. Remove any added listeners with `removeForegroundLifecycleListener(listener)`* |
| `func addClickListener(listener: OSNotificationClickListener)`<br><br>***See below for usage***                             | `(void)addClickListener:(NSObject<OSNotificationClickListener>*)listener`<br><br>***See below for usage***                   | *The `OSNotificationClickListener.onClickNotification` method will be fired on the passed-in object whenever a notification is clicked on by the user. Call `removeClickListener(listener)` to remove.*                                                                                                                                                                                                                                                                                                                                           |

### Prompt for Push Notification Permission with `requestPermission`

**Objective-C**
```objc
    [OneSignal.Notifications requestPermission:^(BOOL accepted) {
        NSLog(@"User accepted notifications: %d", accepted);
    }];

    // If using the fallbackToSettings flag
    [OneSignal.Notifications requestPermission:^(BOOL accepted) {
        NSLog(@"User accepted notifications: %d", accepted);
    } fallbackToSettings:true];
```
**Swift**
```swift
    OneSignal.Notifications.requestPermission { accepted in
        print("User accepted notifications: \(accepted)")
    }

    // If using the fallbackToSettings flag
    OneSignal.Notifications.requestPermission({ accepted in
        print("User accepted notifications: \(accepted)")
    }, fallbackToSettings: true)
```

### Register for Provisional Authorization

**Objective-C**
```objc
    [OneSignal.Notifications registerForProvisionalAuthorization:^(BOOL accepted) {
        // handle authorization
    }];
```
**Swift**
```swift
    OneSignal.Notifications.registerForProvisionalAuthorization({ accepted in
        // handle authorization
    })
```

### Permission Observer

Any object implementing the `OSNotificationPermissionObserver` protocol can be added as an observer. You can call `removePermissionObserver` to remove any existing listeners.

**Objective-C**
```objc
    // AppDelegate.h
    // Add OSNotificationPermissionObserver after UIApplicationDelegate
    @interface AppDelegate : UIResponder <UIApplicationDelegate, OSNotificationPermissionObserver>
    @end

    // AppDelegate.m
    @implementation AppDelegate

    - (BOOL)application:(UIApplication*)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
      // Add your AppDelegate as an observer
      [OneSignal.Notifications addPermissionObserver:self];
    }

    // Add this new method
    - (void)onNotificationPermissionDidChange:(BOOL)permission {
        // Example of detecting the curret permission
        if (permission) {
            NSLog(@"Device has permission to display notifications");
        } else {
             NSLog(@"Device does not have permission to display notifications");
        }
    }

    // Output:
    /*
     Device has permission to display notifications
     */

    @end

    // Remove the observer
    [OneSignal.Notifications removePermissionObserver:self];
```
**Swift**
```swift
    // AppDelegate.swift
    // Add OSNotificationPermissionObserver after UIApplicationDelegate
    class AppDelegate: UIResponder, UIApplicationDelegate, OSNotificationPermissionObserver {

       func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
            // Add your AppDelegate as an observer
            OneSignal.Notifications.addPermissionObserver(self as OSNotificationPermissionObserver)
        }

        // Add this new method
        func onNotificationPermissionDidChange(_ permission: Bool) {
            // Example of detecting the curret permission
            if permission {
                print("Device has permission to display notifications")
            } else {
                print("Device does not have permission to display notifications")
            }
        }
    }

    // Output:
    /*
     Device has permission to display notifications
     PermissionState:
     <OSPermissionState: permission: 1>
     */

    // Remove the observer
    OneSignal.Notifications.removePermissionObserver(self as OSNotificationPermissionObserver)
```

### Notification Foreground Lifecycle Listener
Any object implementing the `OSNotificationLifecycleListener` protocol can be added as a listener. You can call `removeForegroundLifecycleListener` to remove any existing listeners.

**Objective-C**
```objc
    // AppDelegate.h
    // Add OSNotificationLifecycleListener after UIApplicationDelegate
    @interface AppDelegate : UIResponder <UIApplicationDelegate, OSNotificationLifecycleListener>
    @end

    // AppDelegate.m
    @implementation AppDelegate

    - (BOOL)application:(UIApplication*)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
      // Add your AppDelegate as an observer
      [OneSignal.Notifications addForegroundLifecycleListener:self];
    }

    // Add this new method

    - (void)onWillDisplayNotification:(OSNotificationWillDisplayEvent *)event {
        NSLog(@"Received Notification - %@", event.notification.notificationId);
        if ([event.notification.notificationId isEqualToString:@"silent_notif"]) {
            [event preventDefault];
        }

        // If you called preventDefault, you can call display within 25 seconds
        [event.notification display];
    }

    @end

    // Remove the observer
    [OneSignal.Notifications removeForegroundLifecycleListener:self];
```
**Swift**
```swift
class MyNotificationLifecycleListener : NSObject, OSNotificationLifecycleListener {
    func onWillDisplay(event: OSNotificationWillDisplayEvent) {
        // Example of conditionally displaying a notification
        if event.notification.notificationId == "example_silent_notif" {
            event.preventDefault()
        }

        // If you called preventDefault, you can call display within 25 seconds to display the notification
        event.notification.display()
    }
}

// Add your object as a listener
let myListener = MyNotificationLifecycleListener()
OneSignal.Notifications.addForegroundLifecycleListener(myListener)
```

### Notification Click Listener
Any object implementing the `OSNotificationClickListener` protocol can be added as a listener. You can call `removeClickListener` to remove any existing listeners.

**Objective-C**
```objc
// Add this method to object implementing the OSNotificationClickListener protocol
- (void)onClickNotification:(OSNotificationClickEvent * _Nonnull)event {
    OSNotification *notification = event.notification;
    OSNotificationClickResult *result = event.result;
    NSString *actionId = result.actionId;
    NSString *url = result.url;
    NSLog(@"onClickNotification with event %@", [event jsonRepresentation]);
}

// Add your object as a listener
[OneSignal.Notifications addClickListener:myListener];
```

**Swift**
```swift
class MyNotificationClickListener : NSObject, OSNotificationClickListener {
    func onClick(event: OSNotificationClickEvent) {
        let notification: OSNotification = event.notification
        let result: OSNotificationClickResult = event.result
        let actionId = result.actionId
        let url = result.url
    }
}

// Add your object as a listener
let myListener = MyNotificationClickListener()
OneSignal.Notifications.addClickListener(myListener)
```

## Location Namespace

The Location namespace is accessible via `OneSignal.Location` and provide access to location-scoped functionality.

| **Swift**                                                                                      | **Objective-C**                                                                              | **Description**                                                                                                                                          |
| ---------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `let isShared: Bool = OneSignal.Location.isShared`<br><br>`OneSignal.Location.isShared = true` | `BOOL isShared = [OneSignal.Location isShared]`<br><br>`[OneSignal.Location setShared:true]` | *Whether location is currently shared with OneSignal.*                                                                                                   |
| `OneSignal.Location.requestPermission()`                                                       | `[OneSignal.Location requestPermission]`                                                     | *Use this method to manually prompt the user for location permissions. This allows for geotagging so you send notifications to users based on location.* |



## InAppMessages Namespace

The In App Messages namespace is accessible via `OneSignal.InAppMessages` and provide access to in app messages-scoped functionality.

| **Swift**                                                                                              | **Objective-C**                                                                                                                | **Description**                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| ------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `let paused = OneSignal.InAppMessages.paused`<br><br>`OneSignal.InAppMessages.paused = true`           | `BOOL paused = [OneSignal.InAppMessages paused]`<br><br>`[OneSignal.InAppMessages paused:true]`                            | *Whether in-app messaging is currently paused.  When set to `true`, no IAM will be presented to the user regardless of whether they qualify for them. When set to `false`, any IAMs the user qualifies for will be presented to the user at the appropriate time.*                                                                                                                                                                                                  |
| `OneSignal.InAppMessages.addTrigger("KEY", withValue: "VALUE")`                                        | `[OneSignal.InAppMessages addTrigger:@"KEY" withValue:@"VALUE"]`                                                           | *Add a string-value trigger for the current user.  Triggers are currently explicitly used to determine whether a specific IAM should be displayed to the user. See [Triggers](https://documentation.onesignal.com/docs/iam-triggers).<br><br>If the trigger key already exists, it will be replaced with the value provided here. Note that triggers are not persisted to the backend. They only exist on the local device and are applicable to the current user.*                    |
| `OneSignal.InAppMessages.addTriggers(["KEY_01": "VALUE_01", "KEY_02": "VALUE_02"])`                    | `[OneSignal.InAppMessages addTriggers:@{@"KEY_01": @"VALUE_01", @"KEY_02": @"VALUE_02"}]`                          | *Add multiple string-value triggers for the current user. Triggers are currently explicitly used to determine whether a specific IAM should be displayed to the user. See [Triggers](https://documentation.onesignal.com/docs/iam-triggers).<br><br>If any trigger key already exists, it will be replaced with the value provided here. Note that triggers are not persisted to the backend. They only exist on the local device and are applicable to the current user.* |
| `OneSignal.InAppMessages.removeTrigger("KEY")`                                                         | `[OneSignal.InAppMessages removeTrigger:@"KEY"]`                                                                           | *Remove the trigger with the provided key from the current user.*                                                                                                                                                                                                                                                                                                                                                                                                               |
| `OneSignal.InAppMessages.removeTriggers(["KEY_01", "KEY_02"])`                                         | `[OneSignal.InAppMessages removeTriggers:@[@"KEY_01", @"KEY_02"]]`                                                         | *Remove multiple triggers from the current user.*                                                                                                                                                                                                                                                                                                                                                                                                                               |
| `OneSignal.InAppMessages.clearTriggers()`                                                              | `[OneSignal.InAppMessages clearTriggers]`                                                                                  | *Clear all triggers from the current user.*                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| `func addLifecycleListener(listener: OSInAppMessageLifecycleListener?)`<br><br>***See below for usage*** | `(void)addLifecycleListener:(NSObject<OSInAppMessageLifecycleListener> *_Nullable)listener`<br><br>***See below for usage*** | *Add an in-app message lifecycle listener. Remove with `removeLifecycleListener`.*                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| `func addClickListener(listener: OSInAppMessageClickListener)`<br><br>***See below for usage***              | `(void)addClickListener:(NSObject<OSNotificationClickListener>*_Nonnull)listener`<br><br>***See below for usage***                         | *The `OSInAppMessageClickListener.onClickInAppMessage` method will be fired on the passed-in object whenever an in-app message is clicked on by the user. Call `removeClickListener(listener)` to remove*                                                                                                                                                                                                                                                                                                                                                                                                                                     |



### In-App Message Lifecycle Listener

The `OSInAppMessageLifecycleListener` protocol includes 4 optional methods.

**Objective-C**
```objc
    // AppDelegate.h
    // Add OSInAppMessageLifecycleListener as an implemented protocol of the class that will handle the In-App Message lifecycle events.
    @interface AppDelegate : UIResponder <UIApplicationDelegate, OSInAppMessageLifecycleListener>
    @end

    // AppDelegate.m
    @implementation AppDelegate

    - (BOOL)application:(UIApplication*)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
        // Add your implementing class as the listener.
        [OneSignal.InAppMessages addLifecycleListener:self];
    }

    // Add one or more of the following optional lifecycle methods

    - (void)onWillDisplayInAppMessage:(OSInAppMessageWillDisplayEvent *)event {
        NSLog(@"OSInAppMessageLifecycleListener: onWillDisplay Message: %@", event.message.messageId);
    }
    - (void)onDidDisplayInAppMessage:(OSInAppMessageDidDisplayEvent *)event {
        NSLog(@"OSInAppMessageLifecycleListener: onDidDisplay Message: %@", event.message.messageId);
    }
    - (void)onWillDismissInAppMessage:(OSInAppMessageWillDismissEvent *)event {
        NSLog(@"OSInAppMessageLifecycleListener: onWillDismiss Message: %@", event.message.messageId);
    }
    - (void)onDidDismissInAppMessage:(OSInAppMessageDidDismissEvent *)event {
        NSLog(@"OSInAppMessageLifecycleListener: onDidDismiss Message: %@", event.message.messageId);
    }
```
**Swift**
```swift
    // AppDelegate.swift
    // Add OSInAppMessageLifecycleListener as an implemented protocol of the class that will handle the In-App Message lifecycle events.
    class AppDelegate: UIResponder, UIApplicationDelegate, OSInAppMessageLifecycleListener {

        func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
            // Add your implementing class as the listener
            OneSignal.InAppMessages.addLifecycleListener(self)
        }

        // Add one or more of the following optional lifecycle methods

        func onWillDisplay(event: OSInAppMessageWillDisplayEvent) {
            print("OSInAppMessageLifecycleListener: onWillDisplay Message: \(event.message.messageId)")
        }
        func onDidDisplay(event: OSInAppMessageDidDisplayEvent) {
            print("OSInAppMessageLifecycleListener: onDidDisplay Message: \(event.message.messageId)")
        }
        func onWillDismiss(event: OSInAppMessageWillDismissEvent) {
            print("OSInAppMessageLifecycleListener: onWillDismiss Message: \(event.message.messageId)")
        }
        func onDidDisplay(event: OSInAppMessageDidDisplayEvent) {
            print("OSInAppMessageLifecycleListener: onDidDismiss Message: \(event.message.messageId)")
        }
    }
```

### In-App Message Click Listener
Any object implementing the `OSInAppMessageClickListener` protocol can be added as a listener. You can call `removeClickListener` to remove any existing listeners.

**Objective-C**
```objc
// Add this method to object implementing the OSInAppMessageClickListener protocol
- (void)onClickInAppMessage:(OSInAppMessageClickEvent * _Nonnull)event {
    NSLog(@"onClickInAppMessage event: %@", [event jsonRepresentation]);
    NSString *message = [NSString stringWithFormat:@"In App Message Click Occurred: messageId: %@ actionId: %@ url: %@ urlTarget: %@ closingMessage: %i",
                        event.message.messageId,
                        event.result.actionId,
                        event.result.url,
                        @(event.result.urlTarget),
                        event.result.closingMessage];
}

// Add your object as a listener
[OneSignal.InAppMessages addClickListener:self];
```
**Swift**
```swift
class MyInAppMessageClickListener : NSObject, OSInAppMessageClickListener {
    func onClick(event: OSInAppMessageClickEvent) {
        let messageId = event.message.messageId
        let result: OSInAppMessageClickResult = event.result
        let actionId = result.actionId
        let url = result.url
        let urlTarget: OSInAppMessageActionUrlType = result.urlTarget
        let closingMessage = result.closingMessage
    }
}

// Add your object as a listener
let myListener = MyInAppMessageClickListener()
OneSignal.InAppMessages.addClickListener(myListener)
```

## Debug Namespace

The Debug namespace is accessible via `OneSignal.Debug` and provide access to debug-scoped functionality.

| **Swift**                                  | **Objective-C**                                  | **Description**                                                                    |
| ------------------------------------------ | ------------------------------------------------ | ---------------------------------------------------------------------------------- |
| `OneSignal.Debug.setLogLevel(.LL_VERBOSE)` | `[OneSignal.Debug setLogLevel:ONE_S_LL_VERBOSE]` | *Sets the log level the OneSignal SDK should be writing to the Xcode log.* |
| `OneSignal.Debug.setAlertLevel(.LL_NONE)` | `[OneSignal.Debug setAlertLevel:ONE_S_LL_NONE]` | *Sets the logging level to show as alert dialogs.*                                 |


# Glossary

**device-scoped user**
> An anonymous user with no aliases that cannot be retrieved except through the current device or OneSignal dashboard. On app install, the OneSignal SDK is initialized with a *device-scoped user*. A *device-scoped user* can be upgraded to an identified user by calling `OneSignal.login("USER_EXTERNAL_ID")`  to identify the user by the specified external user ID.

# Limitations

- Changing app IDs is not supported.
- Any `User` namespace calls must be invoked **after** initialization. Example: `OneSignal.User.addTag("tag", "2")`
- In the SDK, the user state is only refreshed from the server when a new session is started (cold start or backgrounded for over 30 seconds) or when the user is logged in. This is by design.

# Known issues
- Identity Verification
    - We will be introducing Identity Verification using JWT in a follow up release
