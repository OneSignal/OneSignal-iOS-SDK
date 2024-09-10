//
//  OSCondition.swift
//  OneSignalOSCore
//
//  Created by Rodrigo Gomez-Palacio on 9/10/24.
//  Copyright © 2024 OneSignal. All rights reserved.
//

import Foundation

@objc public protocol OSCondition: AnyObject {
    // Each conforming class will provide its unique ID
    var conditionId: String { get }
    func isMet(indexedTokens: [String: [NSNumber: OSReadYourWriteData]]) -> Bool
    func getNewestToken(indexedTokens: [String: [NSNumber: OSReadYourWriteData]]) -> OSReadYourWriteData?
}
