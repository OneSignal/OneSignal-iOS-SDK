Pod::Spec.new do |s|
  s.name             = "OneSignal"
  s.version          = "2.2.3"
  s.summary          = "OneSignal push notification library for mobile apps."
  s.homepage         = "https://onesignal.com"
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { "Joseph Kalash" => "joseph@onesignal.com", "Josh Kasten" => "josh@onesignal.com" }
  
  s.source           = { :git => "https://github.com/OneSignal/OneSignal-iOS-SDK.git", :tag => s.version.to_s }
  
  s.platform     = :ios
  s.requires_arc = true
  
  s.ios.vendored_frameworks = 'iOS_SDK/Framework/OneSignal.framework'
  s.framework               = 'SystemConfiguration'
end
