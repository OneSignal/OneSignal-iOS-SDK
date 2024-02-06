//
//  AppIntent.swift
//  OnesignalLaWidget2
//
//  Created by Jordan Chong on 2/1/24.
//  Copyright © 2024 OneSignal. All rights reserved.
//

import WidgetKit
import AppIntents

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Configuration"
    static var description = IntentDescription("This is an example widget.")

    // An example configurable parameter.
    @Parameter(title: "Favorite Emoji", default: "😃")
    var favoriteEmoji: String
}
