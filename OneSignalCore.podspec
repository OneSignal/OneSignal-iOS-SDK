Pod::Spec.new do |s|
    s.name             = "OneSignalCore"
    s.version          = "3.11.0-alpha-01"
    s.summary          = "OneSignal's core library for mobile apps. This should only be used as a part of the OneSignal Pod"
    s.homepage         = "https://onesignal.com"
    s.license          = { :type => 'MIT', :file => 'LICENSE' }
    s.author           = {"Josh Kasten" => "josh@onesignal.com" , "Elliot Mawby" => "elliot@onesignal.com"}
    
    s.source           = { :git => "https://github.com/OneSignal/OneSignal-iOS-SDK.git", :tag => s.version.to_s }
    s.platform         = :ios
    s.requires_arc     = true
    
    s.ios.vendored_frameworks = 'iOS_SDK/OneSignalSDK/OneSignal_Core/OneSignalCore.xcframework'
    s.preserve_paths = 'iOS_SDK/OneSignalSDK/OneSignal_Core/OneSignalCore.xcframework'
    
  end