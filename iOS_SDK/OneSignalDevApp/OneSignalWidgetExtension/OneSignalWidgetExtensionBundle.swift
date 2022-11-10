//
//  OneSignalWidgetExtensionBundle.swift
//  OneSignalWidgetExtension
//
//  Created by Henry Boswell on 11/9/22.
//  Copyright © 2022 OneSignal. All rights reserved.
//

import WidgetKit
import SwiftUI

@main
struct OneSignalWidgetExtensionBundle: WidgetBundle {
    var body: some Widget {
        OneSignalWidgetExtensionLiveActivity()
    }
}
