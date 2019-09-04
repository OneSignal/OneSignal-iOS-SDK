Pod::Spec.new do |s|
   s.name             = "OneSignalDynamic"
   s.version          = "2.10.2"
   s.summary          = "OneSignal push notification library for mobile apps."
   s.homepage         = "https://onesignal.com"
   s.license          = { :type => 'MIT', :file => 'LICENSE' }
   s.author           = { "Joseph Kalash" => "joseph@onesignal.com", "Josh Kasten" => "josh@onesignal.com" , "Brad Hesse" => "brad@onesignal.com"}

   s.source           = { :git => "https://github.com/OneSignal/OneSignal-iOS-SDK.git", :tag => s.version.to_s }

   s.platform     = :ios, "8.0"
   s.requires_arc = true

   s.ios.vendored_frameworks = 'iOS_SDK/OneSignalSDK/Framework/Dynamic/OneSignal.framework'
   s.framework               = 'SystemConfiguration', 'UIKit', 'UserNotifications', 'WebKit'
 end
