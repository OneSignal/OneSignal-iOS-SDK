Pod::Spec.new do |s|
    s.name             = "OneSignalExtension"
    s.version          = "3.11.0-alpha-01"
    s.summary          = "OneSignal's library for Notification Service Extensions in mobile apps"
    s.homepage         = "https://onesignal.com"
    s.license          = { :type => 'MIT', :file => 'LICENSE' }
    s.author           = {"Josh Kasten" => "josh@onesignal.com" , "Elliot Mawby" => "elliot@onesignal.com"}
    
    s.source           = { :git => "https://github.com/OneSignal/OneSignal-iOS-SDK.git", :tag => s.version.to_s }
    s.platform         = :ios
    s.requires_arc     = true

    s.dependency 'OneSignalCore'
    s.dependency 'OneSignalOutcomes'

    s.ios.vendored_frameworks = 'iOS_SDK/OneSignalSDK/OneSignal_Extension/OneSignalExtension.xcframework'
    s.preserve_paths = 'iOS_SDK/OneSignalSDK/OneSignal_Extension/OneSignalExtension.xcframework'

end
