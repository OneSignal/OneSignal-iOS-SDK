import WidgetKit
import SwiftUI

@main
struct OneSignalWidgetExtensionBundle: WidgetBundle {
    var body: some Widget {
        if #available(iOS 16.2, *) {
            OneSignalWidgetLiveActivity()
        }
    }
}
