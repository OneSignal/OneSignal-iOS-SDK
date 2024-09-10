//
//  OSIamFetchOffsetKey.swift
//  OneSignalOSCore
//
//  Created by Rodrigo Gomez-Palacio on 9/10/24.
//  Copyright © 2024 OneSignal. All rights reserved.
//

import Foundation

@objc public enum OSIamFetchOffsetKey: Int, OSConsistencyKeyEnum, Hashable {
    case user = 0
    case subscription = 1
}
