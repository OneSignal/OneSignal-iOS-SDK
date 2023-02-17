Pod::Spec.new do |s|
    s.name             = "OneSignalXCFramework"
    s.version          = "5.0.0-beta-02"
    s.summary          = "OneSignal push notification library for mobile apps."
    s.homepage         = "https://onesignal.com"
    s.license          = { :type => 'MIT', :file => 'LICENSE' }
    s.author           = { "Joseph Kalash" => "joseph@onesignal.com", "Josh Kasten" => "josh@onesignal.com" , "Brad Hesse" => "brad@onesignal.com"}
    
    s.source           = { :git => "https://github.com/OneSignal/OneSignal-iOS-SDK.git", :tag => s.version.to_s }
    s.platform         = :ios, '11.0'
    s.requires_arc     = true
    
    s.ios.vendored_frameworks = 'iOS_SDK/OneSignalSDK/OneSignal_XCFramework/OneSignalFramework.xcframework'

    s.subspec 'OneSignalCore' do |ss|
      ss.vendored_frameworks = 'iOS_SDK/OneSignalSDK/OneSignal_Core/OneSignalCore.xcframework'
    end

    s.subspec 'OneSignalOSCore' do |ss|
      ss.dependency 'OneSignalXCFramework/OneSignalCore'
      ss.vendored_frameworks = 'iOS_SDK/OneSignalSDK/OneSignal_OSCore/OneSignalOSCore.xcframework'
    end

    s.subspec 'OneSignalOutcomes' do |ss|
      ss.dependency 'OneSignalXCFramework/OneSignalCore'
      ss.vendored_frameworks = 'iOS_SDK/OneSignalSDK/OneSignal_Outcomes/OneSignalOutcomes.xcframework'
    end

    s.subspec 'OneSignalExtension' do |ss|
      ss.dependency 'OneSignalXCFramework/OneSignalCore'
      ss.dependency 'OneSignalXCFramework/OneSignalOutcomes'
      ss.vendored_frameworks = 'iOS_SDK/OneSignalSDK/OneSignal_Extension/OneSignalExtension.xcframework'
    end

    s.subspec 'OneSignalNotifications' do |ss|
      ss.dependency 'OneSignalXCFramework/OneSignalCore'
      ss.dependency 'OneSignalXCFramework/OneSignalOutcomes'
      ss.dependency 'OneSignalXCFramework/OneSignalExtension'
      ss.vendored_frameworks = 'iOS_SDK/OneSignalSDK/OneSignal_Notifications/OneSignalNotifications.xcframework'
    end

    s.subspec 'OneSignalUser' do |ss|
      ss.dependency 'OneSignalXCFramework/OneSignalCore'
      ss.dependency 'OneSignalXCFramework/OneSignalOSCore'
      ss.dependency 'OneSignalXCFramework/OneSignalOutcomes'
      ss.dependency 'OneSignalXCFramework/OneSignalNotifications'
      ss.vendored_frameworks = 'iOS_SDK/OneSignalSDK/OneSignal_User/OneSignalUser.xcframework'
    end
  end
  