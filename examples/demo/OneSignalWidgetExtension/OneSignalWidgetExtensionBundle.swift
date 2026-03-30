import WidgetKit
import SwiftUI

@main
struct OneSignalWidgetExtensionBundle: WidgetBundle {
    var body: some Widget {
        OneSignalWidgetExtensionWidget()
        ExampleAppFirstWidget()
        ExampleAppSecondWidget()
        ExampleAppThirdWidget()
        DefaultOneSignalLiveActivityWidget()
    }
}
