Pod::Spec.new do |s|
    s.name             = "OneSignalOutcomes"
    s.version          = "3.9.1"
    s.summary          = "OneSignal's library for tracking user interactions in mobile apps. This should only be used as a part of the OneSignal Pod"
    s.homepage         = "https://onesignal.com"
    s.license          = { :type => 'MIT', :file => 'LICENSE' }
    s.author           = {"Josh Kasten" => "josh@onesignal.com" , "Elliot Mawby" => "elliot@onesignal.com"}
    
    s.source           = { :git => "https://github.com/OneSignal/OneSignal-iOS-SDK.git", :tag => s.version.to_s }
    s.platform         = :ios
    s.requires_arc     = true

    s.dependency 'OneSignalCore'
    
    s.ios.vendored_frameworks = 'iOS_SDK/OneSignalSDK/OneSignal_Outcomes/OneSignalOutcomes.xcframework'
    s.preserve_paths = 'iOS_SDK/OneSignalSDK/OneSignal_Outcomes/OneSignalOutcomes.xcframework'

end
