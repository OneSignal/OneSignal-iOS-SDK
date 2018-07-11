<p align="center">
  <img src="https://onesignal.com/assets/common/logo_onesignal_color.png"/>
</p>

### OneSignal iOS SDK (beta)
[![CocoaPods](https://img.shields.io/cocoapods/v/OneSignal.svg)](https://cocoapods.org/pods/OneSignal) [![CocoaPods](https://img.shields.io/cocoapods/dm/OneSignal.svg)](https://cocoapods.org/pods/OneSignal) [![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg)](https://github.com/Carthage/Carthage) [![Build Status](https://travis-ci.org/OneSignal/OneSignal-iOS-SDK.svg?branch=master)](https://travis-ci.org/OneSignal/OneSignal-iOS-SDK)

---

[OneSignal](https://www.onesignal.com) is a free push notification service for mobile apps. This plugin makes it easy to integrate your native iOS app with OneSignal.

OneSignal has released an iOS 12 Beta SDK update that you can download to test your app in iOS 12.

![alt text](https://onesignal.com/images/ios_10_notification_image.gif)

There are two ways to download the beta, you can either use Cocoapods or add it manually to your project.

### Installation
##### Cocoapods
To download the beta SDK update via cocoapods, you can add this line to your `Podfile`:

```ruby
pod 'OneSignal', :git => 'https://github.com/OneSignal/OneSignal-iOS-SDK.git', :branch => 'beta'
```

After modifying your `Podfile`, run `pod install` to download the beta.

##### Manual 
To manually add the beta SDK update to your project, you need to clone our repo to some location:

```
git clone https://github.com/OneSignal/OneSignal-iOS-SDK.git
cd OneSignal-iOS-SDK
```

Once you've cloned the repo, the `OneSignal.framework` file will be located in `/iOS_SDK/OneSignalSDK/framework/OneSignal.framework`

1. Drag `OneSignal.framework` into your Xcode project, preferably in the `Frameworks` folder for your target.

2. In your target's Build Settings, make sure to add `OneSignal.framework` in the `Link Binary with Libraries` section. You must do this for your app _and_ any other targets that use our SDK (such as the Notification Service Extension)

![xcode details](http://www.hesse.io/guideline.jpg)

Once you've added the framework, you should be able to build your project. We've worked to ensure the beta is still backwards compatible with previous versions of Xcode, so this should not break your tests on CI environments like Travis that might still be compiled using earlier Xcode versions.

#### API
See OneSignal's [iOS Native SDK API](https://documentation.onesignal.com/docs/ios-native-sdk) page for a list of all available methods.

#### Change Log
See this repository's [release tags](https://github.com/OneSignal/OneSignal-iOS-SDK/releases) for a complete change log of every released version.

#### Support
Please visit this repository's [Github issue tracker](https://github.com/OneSignal/OneSignal-iOS-SDK/issues) for feature requests and bug reports related specificly to the SDK.
For account issues and support please contact OneSignal support from the [OneSignal.com](https://onesignal.com) dashboard.

#### Supports:
* Swift and Objective-C Projects
* Supports iOS 7 to iOS 11.3
