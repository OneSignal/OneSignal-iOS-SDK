Pod::Spec.new do |s|
  s.name             = "OneSignal"
  s.version          = "5.0.0-beta-05"
  s.summary          = "OneSignal push notification library for mobile apps."
  s.homepage         = "https://onesignal.com"
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { "Joseph Kalash" => "joseph@onesignal.com", "Josh Kasten" => "josh@onesignal.com" , "Brad Hesse" => "brad@onesignal.com"}
  
  s.source           = { :git => "https://github.com/OneSignal/OneSignal-iOS-SDK.git", :tag => s.version.to_s }
  s.platform         = :ios, "11.0"
  s.requires_arc     = true
  s.default_subspec = "OneSignalComplete"
    
    s.subspec 'OneSignalCore' do |ss|
      ss.vendored_frameworks = 'iOS_SDK/OneSignalSDK/OneSignal_Core/OneSignalCore.xcframework'
    end

    s.subspec 'OneSignalOSCore' do |ss|
      ss.dependency 'OneSignal/OneSignalCore'
      ss.vendored_frameworks = 'iOS_SDK/OneSignalSDK/OneSignal_OSCore/OneSignalOSCore.xcframework'
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

    s.subspec 'OneSignalNotifications' do |ss|
      ss.dependency 'OneSignal/OneSignalCore'
      ss.dependency 'OneSignal/OneSignalOutcomes'
      ss.dependency 'OneSignal/OneSignalExtension'
      ss.vendored_frameworks = 'iOS_SDK/OneSignalSDK/OneSignal_Notifications/OneSignalNotifications.xcframework'
    end

    s.subspec 'OneSignalUser' do |ss|
      ss.dependency 'OneSignal/OneSignalCore'
      ss.dependency 'OneSignal/OneSignalOSCore'
      ss.dependency 'OneSignal/OneSignalOutcomes'
      ss.dependency 'OneSignal/OneSignalNotifications'
      ss.vendored_frameworks = 'iOS_SDK/OneSignalSDK/OneSignal_User/OneSignalUser.xcframework'
    end

    s.subspec 'OneSignalLocation' do |ss|
      ss.dependency 'OneSignal/OneSignalCore'
      ss.dependency 'OneSignal/OneSignalOSCore'
      ss.dependency 'OneSignal/OneSignalNotifications'
      ss.dependency 'OneSignal/OneSignalUser'
      ss.vendored_frameworks = 'iOS_SDK/OneSignalSDK/OneSignal_Location/OneSignalLocation.xcframework'
    end

    s.subspec 'OneSignalInAppMessages' do |ss|
      ss.dependency 'OneSignal/OneSignalCore'
      ss.dependency 'OneSignal/OneSignalOSCore'
      ss.dependency 'OneSignal/OneSignalOutcomes'
      ss.dependency 'OneSignal/OneSignalNotifications'
      ss.dependency 'OneSignal/OneSignalUser'
      ss.vendored_frameworks = 'iOS_SDK/OneSignalSDK/OneSignal_InAppMessages/OneSignalInAppMessages.xcframework'
    end

    s.subspec 'OneSignal' do |ss|
      ss.dependency 'OneSignal/OneSignalCore'
      ss.dependency 'OneSignal/OneSignalOSCore'
      ss.dependency 'OneSignal/OneSignalOutcomes'
      ss.dependency 'OneSignal/OneSignalExtension'
      ss.dependency 'OneSignal/OneSignalNotifications'
      ss.dependency 'OneSignal/OneSignalUser'
      ss.ios.vendored_frameworks = 'iOS_SDK/OneSignalSDK/OneSignal_XCFramework/OneSignalFramework.xcframework'
    end

    s.subspec 'OneSignalComplete' do |ss|
      ss.dependency 'OneSignal/OneSignal'
      ss.dependency 'OneSignal/OneSignalLocation'
      ss.dependency 'OneSignal/OneSignalInAppMessages'
    end
end
