## Running Example projects.
### Swift Example
1. Open `SwiftExample` in your terminal.
2. Run `sudo gem install cocoapods` to install Cocoapods.
3. Run `pod repo update` to make sure you get the latest OneSignal version.
4. Run `pod install`
5. Open `OneSignalDemo.xcworkspace`
6. Under General in Xcode Change the Bundle identifier to yours.
7. Also change your Team under signing below this.
8. Open `AppDelegate` and change the `appId` passed in OneSignal setAppId to yours.
### Objective-C Example
This example uses Swift Package Manager instead of Cocoapods
1. In the  `ObjectiveCExample` directory open the  `OneSignalDemo.xcodeproj`
2. Under General in Xcode Change the Bundle identifier to yours.
3. Also change your Team under signing below this.
4. Open `AppDelegate` and change the `appId` passed in OneSignal setAppId to yours.
5. You may need to wait for Xcode to fetch the OneSignal Swift Package

