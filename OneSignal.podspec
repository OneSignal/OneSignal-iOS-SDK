Pod::Spec.new do |s|
  s.name             = "OneSignal"
  s.version          = "3.12.7"
  s.summary          = "OneSignal push notification library for mobile apps."
  s.homepage         = "https://onesignal.com"
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { "Joseph Kalash" => "joseph@onesignal.com", "Josh Kasten" => "josh@onesignal.com" , "Brad Hesse" => "brad@onesignal.com"}
  
  s.source           = { :git => "https://github.com/OneSignal/OneSignal-iOS-SDK.git", :tag => s.version.to_s }
  s.platform         = :ios, "11.0"
  s.requires_arc     = true

  s.ios.vendored_frameworks = 'iOS_SDK/OneSignalSDK/OneSignal_XCFramework/OneSignal.xcframework'
    s.subspec 'OneSignalCore' do |ss|
      ss.vendored_frameworks = 'iOS_SDK/OneSignalSDK/OneSignal_Core/OneSignalCore.xcframework'
    end

    s.subspec 'OneSignalOutcomes' do |ss|
      ss.dependency 'OneSignal/OneSignalCore'
      ss.vendored_frameworks = 'iOS_SDK/OneSignalSDK/OneSignal_Outcomes/OneSignalOutcomes.xcframework'
    end

    s.subspec 'OneSignalExtension' do |ss|
      ss.dependency 'OneSignal/OneSignalCore'
      ss.dependency 'OneSignal/OneSignalOutcomes'
      ss.vendored_frameworks = 'iOS_SDK/OneSignalSDK/OneSignal_Extension/OneSignalExtension.xcframework'
    end
end
