Pod::Spec.new do |s|
  s.name             = "OneSignal"
  s.version          = "1.13.2"
  s.summary          = "OneSignal push notification library for mobile apps."
  s.homepage         = "https://onesignal.com"
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { "Josh Kasten" => "josh@onesignal.com" }
  
  s.source           = { :git => "https://github.com/one-signal/OneSignal-iOS-SDK.git", :tag => s.version.to_s }
  
  s.platform     = :ios
  s.requires_arc = true
  
  s.ios.vendored_frameworks = 'iOS_SDK/Framework/OneSignal.framework'
  s.xcconfig                = { 'OTHER_LDFLAGS' => '-ObjC' }
  s.framework               = 'SystemConfiguration'
end
