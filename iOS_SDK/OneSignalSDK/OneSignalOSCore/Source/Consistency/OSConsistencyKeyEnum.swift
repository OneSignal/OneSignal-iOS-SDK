//
//  OSConsistencyKeyEnum.swift
//  OneSignalOSCore
//
//  Created by Rodrigo Gomez-Palacio on 9/10/24.
//  Copyright © 2024 OneSignal. All rights reserved.
//

import Foundation

// Protocol for enums with Int raw values.
public protocol OSConsistencyKeyEnum: RawRepresentable where RawValue == Int { }
