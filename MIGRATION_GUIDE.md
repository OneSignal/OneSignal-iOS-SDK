<h1 align="center">OneSignal iOS SDK v5.0.0-alpha1 Migration Guide</h1>

![OneSignal Omni Channel Banner](https://user-images.githubusercontent.com/11739227/208625336-d28c8d01-a7cf-4f8e-9643-ac8d1948e9ae.png)

# Intro

In this release, we are making a significant shift from a device-centered model to a user-centered model. A user-centered model allows for more powerful omni-channel integrations within the OneSignal platform.

To facilitate this change, the `externalId` approach for identifying users is being replaced by the `login` and `logout` methods. In addition, the SDK now makes use of namespaces such as `User`, `Notifications`, and `InAppMessages` to better separate code.

The iOS SDK is making the jump from `v3` to `v5`, in order to align across OneSignal’s suite of client SDKs. This guide will walk you through the iOS SDK `v5.0.0-alpha1` changes as a result of this shift.

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

### Import Changes
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

Update the version of the OneSignal iOS SDK your application uses to `5.0.0`. Other than updating the import statement above, there are no additional changes needed to import the OneSignal SDK in your Xcode project. See [the existing installation instructions](https://documentation.onesignal.com/docs/ios-sdk-setup#step-3-import-the-onesignal-sdk-into-your-xcode-project).

# API Changes
## Namespaces

The SDK has been split into namespaces, and functionality previously in the static `OneSignal` class has been moved to the appropriate namespace. The namespaces and how to access them in code are as follows:

| **Namespace** | **Access Pattern**            |
| ------------- | ----------------------------- |
| Debug         | `OneSignal.Debug`         |
| InAppMessages | `OneSignal.InAppMessages` |
| Location      | `OneSignal.Location`      |
| Notifications | `OneSignal.Notifications` |
| Session       | `OneSignal.Session`       |
| User          | `OneSignal.User`          |

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
To the match the new initialization:

**Objective-C**
```objc
    [OneSignal initialize:@"YOUR_ONESIGNAL_APP_ID" withLaunchOptions:launchOptions];
```
**Swift**
```swift
    OneSignal.initialize("YOUR_ONESIGNAL_APP_ID", withLaunchOptions: launchOptions)
```
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
Logging out has the affect of reverting to a device-scoped user, which is the new owner of the device’s push subscription.

## Subscriptions

In previous versions of the SDK, a “player” could have up to one email address and up to one phone number for SMS. In the user-centered model, a user can own the current device’s **Push Subscription** along with the ability to have **zero or more** email subscriptions and **zero or more** SMS subscriptions. Note: If a new user logs in via the `login` method, the previous user will no longer longer own that push subscription.

### **Push Subscription**
The current device’s push subscription can be retrieved via:

**Objective-C**
```objc
    id<OSPushSubscription> pushSubscription = OneSignal.User.pushSubscription;
```
**Swift**
```swift
    let pushSubscription: OSPushSubscription = OneSignal.User.pushSubscription
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

Email and/or SMS subscriptions can be added or removed via the following methods. The `remove` methods will return `false` if the specified email or SMS number does not exist on the user within the SDK, and no request will be made.

**Objective-C**
```obj
    // Add email subscription
    [OneSignal.User addEmail:@"customer@company.com"];
    // Remove previously added email subscription
    BOOL success = [OneSignal.User removeEmail:@"customer@company.com"];
    
    // Add SMS subscription
    [OneSignal.User addSmsNumber:@"+15558675309"];
    // Remove previously added SMS subscription
    BOOL succss = [OneSignal.User removeSmsNumber:@"+15558675309"];
```

**Swift**
```swift
    // Add email subscription
    OneSignal.User.addEmail("customer@company.com")
    // Remove previously added email subscription
    let success: Bool = OneSignal.User.removeEmail("customer@company.com")
    
    // Add SMS subscription
    OneSignal.User.addSmsNumber("+15558675309")
    // Remove previously added SMS subscription
    let success: Bool = OneSignal.User.removeSmsNumber("+15558675309")     
```

# API Reference

Below is a comprehensive reference to the `v5.0.0-alpha1` OneSignal SDK.

## OneSignal

The SDK is still accessible via a `OneSignal` static class. It provides access to higher level functionality and is a gateway to each subspace of the SDK.

| **Swift**                                                                                                | **Objective-C**                                                                                          | **Description**                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| -------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `OneSignal.initialize("YOUR_ONESIGNAL_APP_ID", withLaunchOptions: launchOptions)`                    | `[OneSignal initialize:@"YOUR_ONESIGNAL_APP_ID" withLaunchOptions:launchOptions]`                    | *Initializes the OneSignal SDK. This should be called during startup of the application.*                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| `OneSignal.login("USER_EXTERNAL_ID")`                                                                | `[OneSignal login:@"USER_EXTERNAL_ID"]`                                                              | *Login to OneSignal under the user identified by the [externalId] provided. The act of logging a user into the OneSignal SDK will switch the [user] context to that specific user.<br><br> - If the [externalId] exists, the user will be retrieved and the context will be set from that user information. If operations have already been performed under a device-scoped user, they ***will not*** be applied to the now logged in user (they will be lost).<br> - If the [externalId] does not exist the user, the user will be created and the context set from the current local state. If operations have already been performed under a device-scoped user, those operations ***will*** be applied to the newly created user.<br><br>***Push Notifications and In App Messaging***<br>Logging in a new user will automatically transfer the push notification and in app messaging subscription from the current user (if there is one) to the newly logged in user. This is because both push notifications and in- app messages are owned by the device.* |
| `OneSignal.logout()`                                                                                     | `[OneSignal logout]`                                                                                     | *Logout the user previously logged in via [login]. The [user] property now references a new device-scoped user. A device-scoped user has no user identity that can later be retrieved, except through this device as long as the app remains installed and the app data is not cleared.*                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| `let granted: Bool = OneSignal.privacyConsent`<br><br>`OneSignal.privacyConsent = true`                  | `BOOL granted = OneSignal.getPrivacyConsent`<br><br>`[OneSignal setPrivacyConsent:true]`                 | *Indicates whether privacy consent has been granted. This field is only relevant when the application has opted into data privacy protections. See [requiresPrivacyConsent].*                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| `let required: Bool = OneSignal.requiresPrivacyConsent`<br><br>`OneSignal.requiresPrivacyConsent = true` | `BOOL required = [OneSignal requiresPrivacyConsent]`<br><br>`[OneSignal setRequiresPrivacyConsent:true]` | *Determines whether a user must consent to privacy prior to their user data being sent up to OneSignal.  This should be set to `true` prior to the invocation of `initialize` to ensure compliance.*                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| `OneSignal.setLaunchURLsInApp(true)`                                                                     | `[OneSignal setLaunchURLsInApp:true]`                                                                    | *This method can be used to set if launch URLs should be opened in safari or within the application. Set to `true` to launch all notifications with a URL in the app instead of the default web browser. Make sure to call `setLaunchURLsInApp` before the `initialize` call.*                                                                                                                                                                                                                                                                   |                                                                                                                                                  
      



## User Namespace

The User name space is accessible via `OneSignal.User` and provides access to user-scoped functionality.


| **Swift**                                                                                                       | **Objective-C**                                                                                       | **Description**                                                                                                                                                                                                                          |
| --------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `OneSignal.User.setLanguage("en")`                                                                              | `[OneSignal.User setLanguage:@"en"]`                                                                  | *Set the 2-character language  for this user.*                                                                                                                                                                                         |
| `let pushSubscription: OSPushSubscription = OneSignal.User.pushSubscription`                                    | `id<OSPushSubscription> pushSubscription = OneSignal.User.pushSubscription`                           | *The push subscription associated to the current user.*                                                                                                                                                                                  |
| `OneSignal.User.addAlias(label: "ALIAS_LABEL", id: "ALIAS_ID")`                                         | `[OneSignal.User addAliasWithLabel:@"ALIAS_LABEL" id:@"ALIAS_ID"]`                                    | *Set an alias for the current user.  If this alias label already exists on this user, it will be overwritten with the new alias id.*                                                                                         |
| `OneSignal.User.addAliases(["ALIAS_LABEL_01": "ALIAS_ID_01", "ALIAS_LABEL_02": "ALIAS_ID_02"])` | `[OneSignal.User addAliases:@{@"ALIAS_LABEL_01": @"ALIAS_ID_01", @"ALIAS_LABEL_02": @"ALIAS_ID_02"}]` | *Set aliases for the current user. If any alias already exists, it will be overwritten to the new values.*                                                                                                                       |
| `OneSignal.User.removeAlias("ALIAS_LABEL")`                                                                 | `[OneSignal.User removeAlias:@"ALIAS_LABEL"]`                                                         | *Remove an alias from the current user.*                                                                                                                                                                                                 |
| `OneSignal.User.removeAliases(["ALIAS_LABEL_01", "ALIAS_LABEL_02"])`                                    | `[OneSignal.User removeAliases:@[@"ALIAS_LABEL_01", @"ALIAS_LABEL_02"]]`                              | *Remove aliases from the current user.*                                                                                                                                                                                              |
| `OneSignal.User.addEmail("customer@company.com")`                                                           | `[OneSignal.User addEmail:@"customer@company.com"]`                                               | *Add a new email subscription to the current user.*                                                                                                                                                                                      |
| `let success: Bool = OneSignal.User.removeEmail("customer@company.com")`                                | `BOOL success = [OneSignal.User removeEmail:@"customer@company.com"]`                             | *Remove an email subscription from the current user. Returns `false` if the specified email does not exist on the user within the SDK, and no request will be made.*                                                               |
| `OneSignal.User.addSmsNumber("+15558675309")`                                                               | `[OneSignal.User addSmsNumber:@"+15558675309"]`                                                   | *Add a new SMS subscription to the current user.*                                                                                                                                                                                        |
| `let success: Bool = OneSignal.User.removeSmsNumber("+15558675309")`                                    | `BOOL success = [OneSignal.User removeSmsNumber:@"+15558675309"]`                                 | *Remove an SMS subscription from the current user. Returns `false` if the specified SMS number does not exist on the user within the SDK, and no request will be made.*                                                            |
| `OneSignal.User.addTag(key: "KEY", value: "VALUE")`                                                     | `[OneSignal.User addTagWithKey:@"KEY" value:@"VALUE"]`                                                | *Add a tag for the current user.  Tags are key:value pairs used as building blocks for targeting specific users and/or personalizing messages. If the tag key already exists, it will be replaced with the value provided here.*         |
| `OneSignal.User.addTags(["KEY_01": "VALUE_01", "KEY_02": "VALUE_02"])`                          | `[OneSignal.User addTags:@{@"KEY_01": @"VALUE_01", @"KEY_02": @"VALUE_02"}]`                          | *Add multiple tags for the current user.  Tags are key:value pairs used as building blocks for targeting specific users and/or personalizing messages. If the tag key already exists, it will be replaced with the value provided here.* |
| `OneSignal.User.removeTag("KEY")`                                                                           | `[OneSignal.User removeTag:@"KEY"]`                                                                   | *Remove the data tag with the provided key from the current user.*                                                                                                                                                                       |
| `OneSignal.User.removeTags(["KEY_01", "KEY_02"])`                                                       | `[OneSignal.User removeTags:@[@"KEY_01", @"KEY_02"]]`                                                 | *Remove multiple tags with the provided keys from the current user.*                                                                                                                                                             |



## Push Subscription Namespace

The Push Subscription name space is accessible via `OneSignal.User.pushSubscription` and provides access to push subscription-scoped functionality.


| **Swift**                                                                                                         | **Objective-C**                                                                                                                        | **Description**                                                                                                                                                                                                                                                                                                                                                                                    |
| ----------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `let id: String? = OneSignal.User.pushSubscription.id`                                                            | `NSString* id = OneSignal.User.pushSubscription.id`                                                                                    | *The readonly push subscription ID.*                                                                                                                                                                                                                                                                                                                                                               |
| `let token: String? = OneSignal.User.pushSubscription.token`                                                      | `NSString* token = OneSignal.User.pushSubscription.token`                                                                              | *The readonly push token.*                                                                                                                                                                                                                                                                                                                                                                         |
| `let optedIn: Bool = OneSignal.User.pushSubscription.optedIn`                                                     | `BOOL optedIn = OneSignal.User.pushSubscription.optedIn`                                                                               | *Gets a boolean value indicating whether the current user is opted in to push notifications. This returns `true` when the app has notifications permission and `optedOut` is called. ***Note:*** Does not take into account the existence of the subscription ID and push token. This boolean may return `true` but push notifications may still not be received by the user.* |
| `OneSignal.User.pushSubscription.optIn()`                                                                         | `[OneSignal.User.pushSubscription optIn]`                                                                                              | *Call this method to receive push notifications on the device or to resume receiving of push notifications after calling `optOut`. If needed, this method will prompt the user for push notifications permission.*                                                                                                                                                                     |
| `OneSignal.User.pushSubscription.optOut()`                                                                        | `[OneSignal.User.pushSubscription optOut]`                                                                                             | *If at any point you want the user to stop receiving push notifications on the current device (regardless of system-level permission status), you can call this method to opt out.*                                                                                                                                                                                                              |
| `addObserver(_ observer: OSPushSubscriptionObserver) → OSPushSubscriptionState?`<br><br>***See below for usage*** | `(OSPushSubscriptionState * _Nullable)addObserver:(id <OSPushSubscriptionObserver> _Nonnull)observer`<br><br>***See below for usage*** | *The `OSPushSubscriptionObserver.onOSPushSubscriptionChanged` method will be fired on the passed-in object when the push subscription changes. This method returns the current `OSPushSubscriptionState` at the time of adding this observer.*                                                                                                                                 |
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
      OSPushSubscriptionState* state = [OneSignal.User.pushSubscription addObserver:self];
    }
    
    // Add this new method
    - (void)onOSPushSubscriptionChangedWithStateChanges:(OSPushSubscriptionStateChanges*)stateChanges {
       // prints out all properties
       NSLog(@"PushSubscriptionStateChanges:\n%@", stateChanges);
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
        // Add your AppDelegate as an observer, and the current OSPushSubscriptionState will be returned
        let state: OSPushSubscriptionState? = OneSignal.User.pushSubscription.addObserver(self as OSPushSubscriptionObserver)
        print("Current pushSubscriptionState: \n\(state)")
       }
    
      // Add this new method
      func onOSPushSubscriptionChanged(stateChanges: OSPushSubscriptionStateChanges) {
        // prints out all properties
        print("PushSubscriptionStateChanges: \n\(stateChanges)")
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
| `let permission: Bool = OneSignal.Notifications.permission`                                                                                   | `BOOL` `permission` `= [OneSignal.Notifications permission]`                                                                       | *Whether this app has push notification permission.*                                                                                                                                                                                                                                                                                                                                                                        |
| `let canRequest: Bool = OneSignal.Notifications.canRequestPermission`                                                                     | `BOOL canRequest = [OneSignal.Notifications canRequestPermission]`                                                             | *Whether attempting to request notification permission will show a prompt. Returns `true` if the device has not been prompted for push notification permission already.*                                                                                                                                                                                                                                                |
| `OneSignal.Notifications.clearAll()`                                                                                                          | `[OneSignal.Notifications clearAll]`                                                                                               | *Removes all OneSignal notifications.*                                                                                                                                                                                                                                                                                                                                                                                      |
| `func requestPermission(block: OSUserResponseBlock?, fallbackToSettings: Bool)`<br><br>***See below for usage***                              | `(void)requestPermission:(OSUserResponseBlock _Nullable )block fallbackToSettings:(BOOL)fallback`<br><br>***See below for usage*** | *Prompt the user for permission to receive push notifications. This will display the native system prompt to request push notification permission.*                                                                                                                                                                                                                                                                 |
| `func registerForProvisionalAuthorization(block: OSUserResponseBlock?)`<br><br>***See below for usage***                                      | `(void)registerForProvisionalAuthorization:(OSUserResponseBlock _Nullable)block`<br><br>***See below for usage***                  | *Instead of having to prompt the user for permission to send them push notifications, your app can request provisional authorization.*                                                                                                                                                                                                                                                                                      |
| `func addPermissionObserver(observer: OSPermissionObserver)`<br><br>***See below for usage***                                                 | `(void)addPermissionObserver:(NSObject<OSPermissionObserver>*_Nonnull)observer`<br><br>***See below for usage***                   | *The `OSPermissionObserver.onOSPermissionChanged` method will be fired on the passed-in object when a notification permission setting changes. This happens when the user enables or disables notifications for your app from the system settings outside of your app.*                                                                                                                                           |
| `func removePermissionObserver(observer: OSPermissionObserver)`<br><br>***See below for usage***                                              | `(void)removePermissionObserver:(NSObject<OSPermissionObserver>*_Nonnull)observer`<br><br>***See below for usage***        | *Remove a push permission observer that has been previously added.*                                                                                                                                                                                                                                                                                                                                                     |
| `func setNotificationWillShowInForegroundHandler(block: OSNotificationWillShowInForegroundBlock?)`<br><br>***See below for usage*** | `setNotificationWillShowInForegroundHandler:(OSNotificationWillShowInForegroundBlock)block`<br><br>***See below for usage***       | *Sets the handler to run before displaying a notification while the app is in focus. Use this handler to read notification data and change it or decide if the notification ***should*** show or not.<br><br>***Note:*** this runs ***after*** the [Notification Service Extension](https://documentation.onesignal.com/docs/service-extensions) which can be used to modify the notification before showing it.* |
| `func setNotificationOpenedHandler(block: OSNotificationOpenedBlock?)`<br><br>***See below for usage***                             | `(void)setNotificationOpenedHandler:(OSNotificationOpenedBlock _Nullable)block`<br><br>***See below for usage***                   | *Sets a handler that will run whenever a notification is opened by the user.*                                                                                                                                                                                                                                                                                                                                           |

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

Any object implementing the `OSPermissionObserver` protocol can be added as an observer. You can call `removePermissionObserver` to remove any existing listeners.

**Objective-C**
```objc
    // AppDelegate.h
    // Add OSPermissionObserver after UIApplicationDelegate
    @interface AppDelegate : UIResponder <UIApplicationDelegate, OSPermissionObserver>
    @end
    
    // AppDelegate.m
    @implementation AppDelegate
      
    - (BOOL)application:(UIApplication*)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
      // Add your AppDelegate as an observer
      [OneSignal.Notifications addPermissionObserver:self];
    }
    
    // Add this new method
    - (void)onOSPermissionChanged:(OSPermissionStateChanges*)stateChanges {
        // Example of detecting anwsering the permission prompt
        if (stateChanges.from.status == OSNotificationPermissionNotDetermined) {
          if (stateChanges.to.status == OSNotificationPermissionAuthorized)
             NSLog(@"Thanks for accepting notifications!");
          else if (stateChanges.to.status == OSNotificationPermissionDenied)
             NSLog(@"Notifications not accepted. You can turn them on later under your iOS settings.");
        }
        // prints out all properties
        NSLog(@"PermissionStateChanges:\n%@", stateChanges);
    }
    
    // Output:
    /*
     Thanks for accepting notifications!
     PermissionStateChanges:
     <OSPermissionStateChanges:
     from: <OSPermissionState: hasPrompted: 1, status: NotDetermined, provisional: 0>,
     to:   <OSPermissionState: hasPrompted: 1, status: Authorized, provisional: 0>
     >
     */
    
    @end
    
    // Remove the observer
    [OneSignal.Notifications removePermissionObserver:self];
```
**Swift**
```swift
    // AppDelegate.swift
    // Add OSPermissionObserver after UIApplicationDelegate
    class AppDelegate: UIResponder, UIApplicationDelegate, OSPermissionObserver {
    
       func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Add your AppDelegate as an observer
        OneSignal.Notifications.addPermissionObserver(self as OSPermissionObserver)
       }
    
      // Add this new method
      func onOSPermissionChanged(_ stateChanges: OSPermissionStateChanges) {
        // Example of detecting answering the permission prompt
        if stateChanges.from.status == OSNotificationPermission.notDetermined {
           if stateChanges.to.status == OSNotificationPermission.authorized {
              print("Thanks for accepting notifications!")
           } else if stateChanges.to.status == OSNotificationPermission.denied {
              print("Notifications not accepted. You can turn them on later under your iOS settings.")
           }
        }
        // prints out all properties
        print("PermissionStateChanges: \n\(stateChanges)")
      }
    }
    
    // Output:
    /*
     Thanks for accepting notifications!
     PermissionStateChanges:
     <OSPermissionStateChanges:
     from: <OSPermissionState: hasPrompted: 1, status: NotDetermined, provisional: 0>,
     to:   <OSPermissionState: hasPrompted: 1, status: Authorized, provisional: 0>
     >
     */
    
    // Remove the observer
    OneSignal.Notifications.removePermissionObserver(self as OSPermissionObserver)
```

### Notification Will Show in Foreground Handler

**Objective-C**
```objc
    id notificationWillShowInForegroundBlock = ^(OSNotification *notification, OSNotificationDisplayResponse completion) {
        NSLog(@"Received Notification - %@", notification.notificationId);
        if ([notification.notificationId isEqualToString:@"silent_notif"]) {
            completion(nil);
        } else {
            completion(notification);
        }
    };
    
    [OneSignal.Notifications setNotificationWillShowInForegroundHandler:notificationWillShowInForegroundBlock];
```
**Swift**
```swift
    let notificationWillShowInForegroundBlock: OSNotificationWillShowInForegroundBlock = { notification, completion in
        print("Received Notification: ", notification.notificationId ?? "no id")
        print("launchURL: ", notification.launchURL ?? "no launch url")
        print("content_available = \(notification.contentAvailable)")
    
        if notification.notificationId == "example_silent_notif" {
            // Complete with null means don't show a notification
            completion(nil)
        } else {
            // Complete with a notification means it will show
            completion(notification)
        } 
    }
    OneSignal.Notifications.setNotificationWillShowInForegroundHandler(notificationWillShowInForegroundBlock)
```

### Notification Opened Handler
**Objective-C**
```objc
    id notificationOpenedBlock = ^(OSNotificationOpenedResult *result) {
        OSNotification* notification = result.notification;
        if (notification.additionalData) {
            if (result.action.actionId) {
                NSLog(@"\nPressed ButtonId:%@", result.action.actionId);
            }
        }
    };
    
    [OneSignal.Notifications setNotificationOpenedHandler:notificationOpenedBlock];
```
**Swift**
```swift
    let notificationOpenedBlock: OSNotificationOpenedBlock = { result in
        // This block gets called when the user reacts to a notification received
        let notification: OSNotification = result.notification
        print("Message: ", notification.body ?? "empty body")
        print("badge number: ", notification.badge)
        print("notification sound: ", notification.sound ?? "No sound")
                
        if let additionalData = notification.additionalData {
            print("additionalData: ", additionalData)
            if let actionSelected = notification.actionButtons {
                print("actionSelected: ", actionSelected)
            }
            if let actionID = result.action.actionId {
                //handle the action
            }
        }
    }
    
    OneSignal.Notifications.setNotificationOpenedHandler(notificationOpenedBlock)
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
| `let paused = OneSignal.InAppMessages.Paused`<br><br>`OneSignal.InAppMessages.Paused = true`           | `BOOL paused = [OneSignal.InAppMessages paused]`<br><br>`[OneSignal.InAppMessages paused:true]`                            | *Whether in-app messaging is currently paused.  When set to `true`, no IAM will be presented to the user regardless of whether they qualify for them. When set to `false`, any IAMs the user qualifies for will be presented to the user at the appropriate time.*                                                                                                                                                                                                  |
| `OneSignal.InAppMessages.addTrigger("KEY", withValue: "VALUE")`                                        | `[OneSignal.InAppMessages addTrigger:@"KEY" withValue:@"VALUE"]`                                                           | *Add a trigger for the current user.  Triggers are currently explicitly used to determine whether a specific IAM should be displayed to the user. See [Triggers](https://documentation.onesignal.com/docs/iam-triggers).<br><br>If the trigger key already exists, it will be replaced with the value provided here. Note that triggers are not persisted to the backend. They only exist on the local device and are applicable to the current user.*                    |
| `OneSignal.InAppMessages.addTriggers(["KEY_01": "VALUE_01", "KEY_02": "VALUE_02"])`                    | `[OneSignal.InAppMessages addTriggers:@{@"KEY_01": @"VALUE_01", @"KEY_02": @"VALUE_02"}]`                          | *Add multiple triggers for the current user. Triggers are currently explicitly used to determine whether a specific IAM should be displayed to the user. See [Triggers](https://documentation.onesignal.com/docs/iam-triggers).<br><br>If any trigger key already exists, it will be replaced with the value provided here. Note that triggers are not persisted to the backend. They only exist on the local device and are applicable to the current user.* |
| `OneSignal.InAppMessages.removeTrigger("KEY")`                                                         | `[OneSignal.InAppMessages removeTrigger:@"KEY"]`                                                                           | *Remove the trigger with the provided key from the current user.*                                                                                                                                                                                                                                                                                                                                                                                                               |
| `OneSignal.InAppMessages.removeTriggers(["KEY_01", "KEY_02"])`                                         | `[OneSignal.InAppMessages removeTriggers:@[@"KEY_01", @"KEY_02"]]`                                                         | *Remove multiple triggers from the current user.*                                                                                                                                                                                                                                                                                                                                                                                                                               |
| `OneSignal.InAppMessages.clearTriggers()`                                                              | `[OneSignal.InAppMessages clearTriggers]`                                                                                  | *Clear all triggers from the current user.*                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| `func setLifecycleHandler(delegate: OSInAppMessageLifecycleHandler?)`<br><br>***See below for usage*** | `(void)setLifecycleHandler:(NSObject<OSInAppMessageLifecycleHandler> *_Nullable)delegate`<br><br>***See below for usage*** | *Set the in-app message lifecycle handler.*                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| `func setClickHandler(block: OSInAppMessageClickBlock?)`<br><br>***See below for usage***              | `(void)setClickHandler:(OSInAppMessageClickBlock _Nullable)block`<br><br>***See below for usage***                         | *Set the in-app message click handler.*                                                                                                                                                                                                                                                                                                                                                                                                                                     |



### In-App Message Lifecycle Handler

The `OSInAppMessageLifecycleHandler` protocol includes 4 optional methods.

**Objective-C**
```objc
    // AppDelegate.h
    // Add OSInAppMessageLifecycleHandler as an implemented protocol of the class that will handle the In-App Message lifecycle events.
    @interface AppDelegate : UIResponder <UIApplicationDelegate, OSInAppMessageLifecycleHandler>
    @end
    
    // AppDelegate.m
    @implementation AppDelegate
      
    - (BOOL)application:(UIApplication*)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
        // Add your implementing class as the handler.  
        [OneSignal.InAppMessages setLifecycleHandler:self];
    }
    
    // Add one or more of the following optional lifecycle methods
    
    - (void)onWillDisplayInAppMessage:(OSInAppMessage *)message {
        NSLog(@"OSInAppMessageLifecycleHandler: onWillDisplay Message: %@", message.messageId);
    }
    - (void)onDidDisplayInAppMessage:(OSInAppMessage *)message {
        NSLog(@"OSInAppMessageLifecycleHandler: onDidDisplay Message: %@", message.messageId);
    }
    - (void)onWillDismissInAppMessage:(OSInAppMessage *)message {
        NSLog(@"OSInAppMessageLifecycleHandler: onWillDismiss Message: %@", message.messageId);
    }
    - (void)onDidDismissInAppMessage:(OSInAppMessage *)message {
        NSLog(@"OSInAppMessageLifecycleHandler: onDidDismiss Message: %@", message.messageId);
    }
```
**Swift**
```swift
    // AppDelegate.swift
    // Add OSInAppMessageLifecycleHandler as an implemented protocol of the class that will handle the In-App Message lifecycle events.
    class AppDelegate: UIResponder, UIApplicationDelegate, OSInAppMessageLifecycleHandler {
    
        func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
            // Add your implementing class as the handler  
            OneSignal.InAppMessages.setLifecycleHandler(self)
        }
    
        // Add one or more of the following optional lifecycle methods
    
        func onWillDisplay(_ message: OSInAppMessage) {
            print("OSInAppMessageLifecycleHandler: onWillDisplay Message: \(message.messageId)")
        }
        func onDidDisplay(_ message: OSInAppMessage) {
            print("OSInAppMessageLifecycleHandler: onDidDisplay Message: \(message.messageId)")
        }
        func onWillDismiss(_ message: OSInAppMessage) {
            print("OSInAppMessageLifecycleHandler: onWillDismiss Message: \(message.messageId)")
        }
        func onDidDismiss(_ message: OSInAppMessage) {
            print("OSInAppMessageLifecycleHandler: onDidDismiss Message: \(message.messageId)")
        }
    }
```

### In-App Message Click Handler

**Objective-C**
```objc
    id inAppMessageClickBlock = ^(OSInAppMessageAction *action) {
        NSString *message = [NSString stringWithFormat:@"Click Action Occurred: clickName:%@ clickUrl:%@ firstClick:%i closesMessage:%i",
                             action.clickName,
                             action.clickUrl,
                             action.firstClick,
                             action.closesMessage];
        NSLog(@"%@", message);
    };
    
    [OneSignal.InAppMessages setClickHandler:inAppMessageClickBlock];
```
**Swift**
```swift
    let inAppMessageClickBlock: OSInAppMessageClickBlock = { action in
        print("Click Action Occurred: ", action.jsonRepresentation)
    }
    
    OneSignal.InAppMessages.setClickHandler(inAppMessageClickBlock)
```

## Debug Namespace

The Debug namespace is accessible via `OneSignal.Debug` and provide access to debug-scoped functionality.

| **Swift**                                  | **Objective-C**                                  | **Description**                                                                    |
| ------------------------------------------ | ------------------------------------------------ | ---------------------------------------------------------------------------------- |
| `OneSignal.Debug.setLogLevel(.LL_VERBOSE)` | `[OneSignal.Debug setLogLevel:ONE_S_LL_VERBOSE]` | *Sets the log level the OneSignal SDK should be writing to the Xcode log.* |
| `OneSignal.Debug.setVisualLevel(.LL_NONE)` | `[OneSignal.Debug setVisualLevel:ONE_S_LL_NONE]` | *Sets the logging level to show as alert dialogs.*                                 |


# Glossary

**device-scoped user**
> An anonymous user with no aliases that cannot be retrieved except through the current device or OneSignal dashboard. On app install, the OneSignal SDK is initialized with a *device-scoped user*. A *device-scoped user* can be upgraded to an identified user by calling `OneSignal.login("USER_EXTERNAL_ID")`  to identify the user by the specified external user ID. 

# Limitations

- Recommend using only in development and staging environments for Alpha releases
- Aliases will be available in a future release
- Outcomes will be available in a future release
- Users are deleted when the last Subscription (push, email, or sms) is removed
- Any `User` namespace calls must be invoked **after** initialization. Example: `OneSignal.User.addTag("tag", "2")`

# Known issues
- User properties may not update correctly when Subscriptions are transferred
    - Please report any issues you find with this
- Identity Verification 
    - We will be introducing JWT in a follow up Alpha or Beta release
